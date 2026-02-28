# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Holo Polymarket is a Bash CLI toolkit for Polymarket prediction markets. It provides market queries, whale tracking, historical analysis, and live trading via three Polymarket APIs (Gamma, Data, CLOB). It is also deployable as an OpenClaw skill.

Language: **Bash**. Dependencies: `curl`, `jq`.

## Commands

```bash
# Run all tests (8 test suites)
bash tests/run_tests.sh

# Run a single test file
bash tests/test_format.sh
bash tests/test_api.sh        # requires network (live API calls)
bash tests/test_cache.sh      # self-contained, uses temp directory

# Run the CLI
bash scripts/polymarket.sh <command> [args...]

# Deploy as OpenClaw skill
bash openclaw_deploy_skill.sh ~/.openclaw/skills/polymarket
```

## Architecture

The CLI entry point is `scripts/polymarket.sh`, which sources three modules and dispatches commands via a `case` statement:

- **`scripts/api.sh`** — All HTTP calls. Three API layers:
  - `gamma_get()` → Gamma API (`gamma-api.polymarket.com`) — market data, search, event details
  - `data_get()` → Data API (`data-api.polymarket.com`) — leaderboard, positions, trades, history
  - `clob_post()`/`clob_get()` → CLOB API (`clob.polymarket.com`) — authenticated trading (HMAC-SHA256 signing)
  - Also handles credentials loading (`load_polymarket_bearer_token`, `load_clob_credentials`) and time-series fetching (`fetch_history_series`)
- **`scripts/format.sh`** — All output formatting. Receives JSON via stdin pipe, outputs human-readable text. Functions named `format_*` (e.g., `format_hot_events`, `format_leaderboard`, `format_price_history_table`).
- **`scripts/cache.sh`** — SHA256-keyed file cache in `~/.cache/holo-polymarket/`. Functions: `cache_get`, `cache_set`, `cache_clear`, `cache_stats`. Sourced by `api.sh`.
- **`scripts/export.sh`** — CSV/JSON export for time-series commands. Functions: `export_to_csv`, `export_to_json`.

Data flow pattern: `polymarket.sh` calls `api.sh` fetch function → pipes JSON to `format.sh` formatter. For time-series commands (`history`, `trend`, `volume-trend`), `parse_series_command_args()` handles `--format`/`--out` flags and `export_series_if_needed()` conditionally exports instead of formatting.

## Testing

Tests use a custom assertion framework defined inline in each test file (`assert_eq`, `assert_not_empty`, `assert_contains`, `assert_gt`, `assert_status`). Test files source the module they test directly.

Two categories:
- **Unit tests** (no network): `test_format.sh`, `test_format_data.sh`, `test_history_format.sh`, `test_cache.sh`, `test_export.sh` — use mock JSON data
- **Integration tests** (require network): `test_api.sh`, `test_data_api.sh`, `test_history_api.sh` — call live Polymarket APIs

Each test file exits 0 on all-pass, non-zero on any failure. `run_tests.sh` aggregates results.

## Environment Variables

- `DRY_RUN=1` — simulate trading orders without execution
- `NO_CACHE=1` — bypass cache for a single command
- `CACHE_TTL=<seconds>` — override default 60s cache TTL
- `GAMMA_API_BASE` / `CLOB_API_BASE` / `DATA_API_BASE` — override API endpoints
- `CURL_TIMEOUT` — HTTP timeout (default 15s)
- Credentials: `POLYMARKET_BEARER_TOKEN` env var or file at `~/.openclaw/credentials/polymarket_credentials`

## Conventions

- UI language is Chinese (命令输出、错误提示均为中文)
- Command aliases: `lb` = `leaderboard`, `pos` = `positions`
- All API wrappers go in `api.sh`; all formatters go in `format.sh` — keep separation strict
- Format functions read JSON from stdin (piped), never take JSON as an argument
- `SKILL.md` uses `{baseDir}` placeholder for the skill installation path
