# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Holo Polymarket is a Bash CLI toolkit for Polymarket prediction markets. It provides market queries, whale tracking, and historical analysis via Polymarket APIs (Gamma, Data, CLOB). It is also deployable as an OpenClaw skill.

Language: **Bash**. Dependencies: `curl`, `jq`.

## Commands

```bash
# Run offline tests (default)
bash tests/run_tests.sh

# Run offline + live integration tests
RUN_LIVE_TESTS=1 bash tests/run_tests.sh

# Run a single test file
bash tests/test_api_unit.sh
bash tests/test_series_args.sh
bash tests/test_api.sh        # requires network
bash tests/test_data_api.sh   # requires network

# Run end-to-end live test (not in run_tests.sh)
bash tests/test_e2e_hot_detail.sh

# Run the CLI
bash scripts/polymarket.sh <command> [args...]

# Run static checks
bash scripts/lint.sh

# Deploy as OpenClaw skill
bash openclaw_deploy_skill.sh ~/.openclaw/skills/polymarket
```

## Architecture

The CLI entry point is `scripts/polymarket.sh`, which sources modules and dispatches commands by domain:

- **`scripts/common.sh`** — Shared helpers:
  - `require_commands`
  - `url_encode`
  - `to_ymd_date`
  - `date_to_epoch_utc`
  - `pm_error` / `pm_warn`
- **`scripts/api.sh`** — All HTTP calls and history-series fetching:
  - `gamma_get`, `data_get`, `clob_get`
  - `fetch_*` API wrappers
  - `fetch_history_series`
  - credential loading (`load_polymarket_bearer_token`)
- **`scripts/format.sh`** — Output formatting (stdin JSON -> human-readable text)
- **`scripts/export.sh`** — CSV/JSON export for time-series commands
- **`scripts/cache.sh`** — SHA256-keyed file cache in `~/.cache/holo-polymarket/`
- **`scripts/commands_market.sh`** — `hot/search/detail`
- **`scripts/commands_whale.sh`** — `leaderboard/positions/trades`
- **`scripts/commands_series.sh`** — `history/trend/volume-trend`

Data flow pattern: CLI command -> API fetch -> formatter (or exporter for series commands).

## Testing

Tests use a shared assertion helper at `tests/helpers/assert.sh`.

Two categories:
- **Offline tests** (default in `run_tests.sh`):
  - `test_format.sh`
  - `test_format_data.sh`
  - `test_cache.sh`
  - `test_history_api.sh`
  - `test_history_format.sh`
  - `test_export.sh`
  - `test_api_unit.sh`
  - `test_series_args.sh`
- **Live integration tests** (`RUN_LIVE_TESTS=1`):
  - `test_api.sh`
  - `test_data_api.sh`

`test_e2e_hot_detail.sh` is a separate live E2E suite and not part of `run_tests.sh`.

## Environment Variables

- `NO_CACHE=1` — bypass cache for a single command
- `CACHE_TTL=<seconds>` — override default 60s cache TTL
- `GAMMA_API_BASE` / `CLOB_API_BASE` / `DATA_API_BASE` — override API endpoints
- `CURL_TIMEOUT` — HTTP timeout (default 15s)
- `CURL_RETRY` — curl retry count (default 2)
- Credentials: `POLYMARKET_BEARER_TOKEN` env var or file at `~/.openclaw/credentials/polymarket_credentials`

## Conventions

- UI language is Chinese (命令输出、错误提示均为中文)
- Command aliases: `lb` = `leaderboard`, `pos` = `positions`
- All API wrappers go in `api.sh`; all formatters go in `format.sh`
- Format functions read JSON from stdin (piped), never take JSON as an argument
- `SKILL.md` uses `{baseDir}` placeholder for the skill installation path