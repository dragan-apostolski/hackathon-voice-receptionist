# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

A `***plain` (codeplain renderer) project for a dental voice receptionist hackathon MVP. The repo is **specs-first**: the source of truth is the `.plain` files at the root and under `template/`. The renderer reads those plus per-module `*.config.yaml` and emits code into `plain_modules/<module>/`.

There is **no hand-written application code** — generated code under `plain_modules/` and the staging tree under `.tmp/` is output, not input.

## Top-level modules

Two top modules, each with its own `.plain` spec and `*.config.yaml` at the repo root:

- **`agent.plain` → `plain_modules/agent/`** — Python 3.11 LiveKit Agents worker. STT (Deepgram) → LLM (Gemini) → TTS (ElevenLabs) pipeline; no DB access; talks to the web app only over HTTP via `httpx`. Dependency manager: `uv` (with `pyproject.toml` + `uv.lock`). Lint/format: `ruff`. Type check: `mypy --strict`.
- **`web.plain` → `plain_modules/web/`** — Next.js 15 (App Router) + TypeScript strict, Tailwind + shadcn/ui, Prisma against Postgres 16 in `docker-compose.yml`, LiveKit token minting via `livekit-server-sdk`, browser client via `@livekit/components-react` + `livekit-client`. Validation with `zod`. Layered: `src/app` (routes) → `src/services` (logic) → `src/repositories` (Prisma) → `src/lib` (cross-cutting). Tests with Vitest.

Both modules import shared definitions:

- `template/practice_domain.plain` — domain concepts (`:Practice:`, `:Service:`, `:Staff:`, `:WorkingHours:`, `:Appointment:`, `:Call:`, `:Patient:`, `:PracticeAdmin:`) used by both modules.
- `template/web_agent_contract.plain` — the HTTP contract (`:WebAgentHttpContract:`, `:PracticeContextAPI:`, `:BookingAPI:`, `:CallLifecycleAPI:`, `:LiveKitTokenAPI:`) shared between the two modules. Field names and shapes must stay stable across both sides.

The voice agent never touches the database — every read/write goes through the web app's HTTP API. When changing one side of an endpoint, check the other side's `.plain` file in the same edit.

## The golden rule: edit `.plain`, not `plain_modules/`

- **Never modify files under `plain_modules/`** to fix behavior. They are renderer output and will be overwritten. If something is wrong with the generated code, fix the corresponding `.plain` file (use the `debug-specs` skill).
- **Never modify files under `.tmp/`**. The test scripts stage builds into `.tmp/<lang>_<build_folder>/` on every run.
- All spec authoring/editing of `.plain` files must go through the appropriate skill (`add-functional-spec`, `add-functional-specs`, `add-concept`, `add-implementation-requirement`, `add-test-requirement`, `add-acceptance-test`, `debug-specs`, etc.). Hand-authoring spec content directly without invoking a skill is forbidden by the project's workflow conventions; see the skill list for which one fits.

## Common commands

Tests run via the self-contained scripts in `test_scripts/`. Each script copies the rendered project into `.tmp/<lang>_<build_folder>/` and runs the test suite there; the input folder is treated as read-only.

```bash
# Run Python (agent) unit tests against the rendered agent project.
# Requires `uv` on PATH. Stages into .tmp/python_<build_folder>/, runs `uv sync` then `uv run pytest tests/`.
./test_scripts/run_unittests_python.sh plain_modules/agent

# Run TypeScript (web) unit tests against the rendered web project.
# Requires node, npm, docker (+ docker compose). Stages into .tmp/typescript_<build_folder>/,
# runs `npm ci`, brings up Postgres via docker-compose, creates `voice_receptionist_test`,
# runs `prisma generate` + `prisma migrate deploy`, then `npx vitest run --coverage=false`.
./test_scripts/run_unittests_typescript.sh plain_modules/web
```

Both scripts follow the same exit-code contract: `1` = bad usage, `2` = filesystem error, `69` = required toolchain missing, anything else = propagated verbatim from the test runner.

Rendering the project (when needed): run `codeplain <top_module>.plain` per top module. The `plain-healthcheck` skill verifies that every `config.yaml` exists, points at scripts that live in `test_scripts/`, and that `codeplain <top_module>.plain --dry-run` passes — run it after finalizing specs.

## When debugging a rendered-code bug

1. Reproduce the bug against `plain_modules/<module>/` (read-only, do not edit).
2. Trace the failing behavior back to the spec it came from (in `<module>.plain` or a shared `template/*.plain`).
3. Fix the `.plain` file. Re-render. Re-run tests via the scripts above.
4. Use the `debug-specs` skill for non-trivial spec-level bug investigations.
