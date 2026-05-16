#!/bin/bash
#
# Self-contained Vitest runner for the rendered :WebApp: Next.js project.
#
# Contract (per implement-unit-testing-script):
#   - Exit  1 — bad usage (missing argument).
#   - Exit  2 — filesystem problem (can't enter working folder).
#   - Exit 69 — required toolchain not installed (node, npm, docker).
#   - Any other non-zero — propagated verbatim from vitest.
#
# Workflow:
#   1. stage input into .tmp/typescript_<arg>/ (input then read-only),
#   2. npm ci into project-local node_modules,
#   3. docker compose up -d the Postgres service defined by the rendered project,
#   4. wait for Postgres to accept connections,
#   5. ensure the dedicated test database exists,
#   6. prisma generate + prisma migrate deploy against the test DATABASE_URL,
#   7. vitest run with coverage disabled.
#
# TEST_DATABASE_URL can be passed from the environment. If unset, the script
# uses a sensible default that matches the docker-compose service Prisma's
# typical setup expects.

set -u

LANG_ID="typescript"

# --- Step 1: toolchain check --------------------------------------------------

missing=""
for tool in node npm docker; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        missing="$missing $tool"
    fi
done

# docker compose can be either 'docker compose' (v2 plugin) or 'docker-compose' (v1 binary).
if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
    missing="$missing docker-compose"
fi

if [ -n "$missing" ]; then
    echo "Error: required toolchain missing:$missing" >&2
    exit 69
fi

# --- Step 2: argument validation ----------------------------------------------

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <build_folder>" >&2
    echo "  <build_folder>  path to the rendered :WebApp: project (e.g. plain_modules/web)" >&2
    exit 1
fi

BUILD_FOLDER="$1"

if [ ! -d "$BUILD_FOLDER" ]; then
    echo "Error: build folder '$BUILD_FOLDER' does not exist or is not a directory." >&2
    exit 1
fi

# --- Step 3: working directory setup ------------------------------------------

WORKING_FOLDER=".tmp/${LANG_ID}_${BUILD_FOLDER}"

echo "Staging $BUILD_FOLDER into $WORKING_FOLDER ..."
rm -rf "$WORKING_FOLDER"
mkdir -p "$WORKING_FOLDER"

# --- Step 4: copy the build ---------------------------------------------------

if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$BUILD_FOLDER/" "$WORKING_FOLDER/"
else
    cp -R "$BUILD_FOLDER/." "$WORKING_FOLDER/"
fi

# --- Step 5: enter the working directory --------------------------------------

cd "$WORKING_FOLDER" 2>/dev/null
if [ "$?" -ne 0 ]; then
    echo "Error: could not enter working folder '$WORKING_FOLDER'." >&2
    exit 2
fi

# --- Step 6: install dependencies + database setup ----------------------------

INSTALL_START=$(date +%s)

echo "Installing npm dependencies via 'npm ci' ..."
npm ci
NPM_EXIT=$?
if [ "$NPM_EXIT" -ne 0 ]; then
    echo "Error: 'npm ci' failed." >&2
    exit "$NPM_EXIT"
fi

# Bring up Postgres via docker compose. Use 'docker compose' v2 if available.
if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
else
    COMPOSE="docker-compose"
fi

if [ ! -f "docker-compose.yml" ] && [ ! -f "compose.yml" ]; then
    echo "Error: no docker-compose.yml (or compose.yml) found in $WORKING_FOLDER." >&2
    exit 69
fi

echo "Starting Postgres via '$COMPOSE up -d' ..."
$COMPOSE up -d
COMPOSE_EXIT=$?
if [ "$COMPOSE_EXIT" -ne 0 ]; then
    echo "Error: failed to start docker-compose Postgres service." >&2
    exit "$COMPOSE_EXIT"
fi

# Default credentials are derived from the rendered project's docker-compose.yml
# (the spec doesn't pin them, so we use the common default). Override via
# environment if the rendered project uses different values.
PG_USER="${POSTGRES_USER:-postgres}"
PG_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
PG_HOST="${POSTGRES_HOST:-localhost}"
PG_PORT="${POSTGRES_PORT:-5432}"
TEST_DB_NAME="${POSTGRES_TEST_DB:-voice_receptionist_test}"

TEST_DATABASE_URL="${TEST_DATABASE_URL:-postgresql://${PG_USER}:${PG_PASSWORD}@${PG_HOST}:${PG_PORT}/${TEST_DB_NAME}}"

echo "Waiting up to 30s for Postgres to accept connections on $PG_HOST:$PG_PORT ..."
for attempt in $(seq 1 30); do
    if $COMPOSE exec -T -e PGPASSWORD="$PG_PASSWORD" postgres \
        psql -U "$PG_USER" -h localhost -d postgres -c '\q' >/dev/null 2>&1; then
        echo "Postgres is ready (attempt $attempt)."
        break
    fi
    if [ "$attempt" -eq 30 ]; then
        echo "Error: Postgres did not become ready within 30 seconds." >&2
        exit 69
    fi
    sleep 1
done

echo "Ensuring test database '$TEST_DB_NAME' exists ..."
$COMPOSE exec -T -e PGPASSWORD="$PG_PASSWORD" postgres \
    psql -U "$PG_USER" -h localhost -d postgres \
    -tc "SELECT 1 FROM pg_database WHERE datname='$TEST_DB_NAME'" | grep -q 1 \
    || $COMPOSE exec -T -e PGPASSWORD="$PG_PASSWORD" postgres \
        psql -U "$PG_USER" -h localhost -d postgres \
        -c "CREATE DATABASE \"$TEST_DB_NAME\""

echo "Running prisma generate ..."
DATABASE_URL="$TEST_DATABASE_URL" npx prisma generate
PRISMA_GEN_EXIT=$?
if [ "$PRISMA_GEN_EXIT" -ne 0 ]; then
    echo "Error: 'prisma generate' failed." >&2
    exit "$PRISMA_GEN_EXIT"
fi

echo "Running prisma migrate deploy against $TEST_DB_NAME ..."
DATABASE_URL="$TEST_DATABASE_URL" npx prisma migrate deploy
PRISMA_MIGRATE_EXIT=$?
if [ "$PRISMA_MIGRATE_EXIT" -ne 0 ]; then
    echo "Error: 'prisma migrate deploy' failed." >&2
    exit "$PRISMA_MIGRATE_EXIT"
fi

INSTALL_DURATION=$(( $(date +%s) - INSTALL_START ))
echo "Dependencies + database setup finished in ${INSTALL_DURATION}s."

# --- Step 7: run vitest --------------------------------------------------------

echo "Running Vitest in $WORKING_FOLDER ..."
TEST_START=$(date +%s)

DATABASE_URL="$TEST_DATABASE_URL" npx vitest run --coverage=false
VITEST_EXIT=$?

TEST_DURATION=$(( $(date +%s) - TEST_START ))
echo "Vitest finished in ${TEST_DURATION}s with exit code ${VITEST_EXIT}."

exit "$VITEST_EXIT"
