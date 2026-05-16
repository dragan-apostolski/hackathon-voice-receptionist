#!/bin/bash
#
# Self-contained pytest runner for the rendered :VoiceAgent: Python project.
#
# Contract (per implement-unit-testing-script):
#   - Exit  1 — bad usage (missing argument).
#   - Exit  2 — filesystem problem (can't enter working folder).
#   - Exit 69 — required toolchain not installed (uv).
#   - Any other non-zero — propagated verbatim from pytest.
#
# The script stages the input build folder into .tmp/python_<arg>/, installs
# dependencies into a project-local .venv inside that working folder via `uv
# sync`, and runs `uv run pytest tests/`. The input folder is treated as
# read-only after staging — every artifact lives inside .tmp/python_<arg>/.

set -u

LANG_ID="python"

# --- Step 1: toolchain check ---------------------------------------------------

if ! command -v uv >/dev/null 2>&1; then
    echo "Error: 'uv' is not installed or not on PATH." >&2
    echo "Install it from https://docs.astral.sh/uv/getting-started/installation/" >&2
    exit 69
fi

# --- Step 2: argument validation ----------------------------------------------

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <build_folder>" >&2
    echo "  <build_folder>  path to the rendered :VoiceAgent: project (e.g. plain_modules/agent)" >&2
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

# --- Step 4: copy the build (input folder is read-only after this point) ------

if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$BUILD_FOLDER/" "$WORKING_FOLDER/"
else
    # Fallback: cp -R. Trailing /. on the source copies contents, not the dir itself.
    cp -R "$BUILD_FOLDER/." "$WORKING_FOLDER/"
fi

# --- Step 5: enter the working directory --------------------------------------

cd "$WORKING_FOLDER" 2>/dev/null
if [ "$?" -ne 0 ]; then
    echo "Error: could not enter working folder '$WORKING_FOLDER'." >&2
    exit 2
fi

# --- Step 6: install dependencies into project-local .venv --------------------

echo "Installing Python dependencies into $WORKING_FOLDER/.venv via uv sync ..."
INSTALL_START=$(date +%s)

uv sync --frozen
UV_EXIT=$?

INSTALL_DURATION=$(( $(date +%s) - INSTALL_START ))
echo "uv sync finished in ${INSTALL_DURATION}s with exit code ${UV_EXIT}."

if [ "$UV_EXIT" -ne 0 ]; then
    echo "Error: 'uv sync' failed; aborting before tests run." >&2
    exit "$UV_EXIT"
fi

# --- Step 7: run pytest -------------------------------------------------------

echo "Running pytest in $WORKING_FOLDER ..."
TEST_START=$(date +%s)

uv run pytest tests/
PYTEST_EXIT=$?

TEST_DURATION=$(( $(date +%s) - TEST_START ))
echo "pytest finished in ${TEST_DURATION}s with exit code ${PYTEST_EXIT}."

exit "$PYTEST_EXIT"
