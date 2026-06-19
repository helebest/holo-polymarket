# AGENTS.md

This file provides guidance to coding agents (Codex and compatible) when working in this repository.

## Project Overview

Holo Polymarket packages Polymarket prediction-market Agent Skills for multiple
runtimes from one canonical `skills/` directory. It is distributed as local
plugins (Claude Code, Codex, OpenClaw) and as skills (ClawHub, Hermes well-known
discovery).

Two skills:

- **`polymarket-query`** (Bash; `curl`, `jq`) — read-only research: hot markets,
  search, event detail, historical price/probability and volume trends, whale
  leaderboard, address positions, and trade history, with CSV/JSON export.
- **`polymarket-trade`** (Python; `py-clob-client-v2`, `requests`) — trading via
  the official CLOB API: buy/sell (market/limit), balance, open orders, cancel.
  Dry-run by default.

## Commands

```bash
uv sync                                    # dev environment

uv run ruff check .
uv run ruff format --check .
uv run holo-polymarket-validate            # repository invariants
uv run holo-polymarket-sync-plugin --check
uv run python -m pytest                    # Python tests
bash tests/run_tests.sh                    # Bash skill tests (offline)
RUN_LIVE_TESTS=1 bash tests/run_tests.sh   # + live integration tests

uv run holo-polymarket-sync-plugin         # regenerate plugin skills copy
uv run holo-polymarket-build               # build release artifacts (dist/)

bash skills/polymarket-query/scripts/polymarket.sh <command> [args...]
python3 skills/polymarket-trade/scripts/trade.py <command> [args...]
```

## Architecture

- `skills/polymarket-query/scripts/` — Bash modules. `polymarket.sh` routes to
  `commands_market.sh`/`commands_whale.sh`/`commands_series.sh`; HTTP lives in
  `api.sh`, formatting in `format.sh` (reads JSON from stdin), caching in
  `cache.sh`, CSV/JSON export in `export.sh`, shared helpers in `common.sh`.
- `skills/polymarket-trade/scripts/` — Python. `trade.py` (CLI, dry-run default),
  `market_data.py` (Gamma resolution, lazy `requests`), `credentials.py`
  (agent-neutral loading, never prints secrets), `clob.py` (live CLOB adapter
  over `py-clob-client-v2`, lazy import, version-tolerant dispatch).
- `src/holo_polymarket/` — `validate.py`, `sync_plugin.py`, `build.py`.
- Plugin manifests: `plugins/holo-polymarket/.claude-plugin/plugin.json`,
  `.codex-plugin/plugin.json` (with `interface`), `openclaw.plugin.json`.
  Marketplaces: `.claude-plugin/marketplace.json` (string source) and
  `.agents/plugins/marketplace.json` (object source + policy).

## Testing

- Python tests (`tests/test_repository_layout.py`, `tests/test_trade.py`) run via
  pytest and cover repo invariants, build artifacts, the docs-are-English check,
  and the trade CLI's dry-run/confirmation safety model (offline).
- Bash tests (`tests/*.sh`) source the query skill modules from
  `skills/polymarket-query/scripts/`. Offline suites run by default;
  `RUN_LIVE_TESTS=1` adds live API calls.

## Conventions

- All documentation, comments, and CLI output are in English.
- `SKILL.md` `name` must equal the skill directory name; use the `<skill-dir>`
  placeholder for paths.
- Bash: keep HTTP in `api.sh` and formatting in `format.sh`; date handling must
  stay GNU/BSD-portable (`epoch_to_ymd_utc` / `ymd_time_to_epoch_utc`).
- Credentials are agent-neutral; never hard-code an OpenClaw-only path.
- Trading is dry-run by default; never execute without `--execute --confirm`.
- After editing canonical skills, run `holo-polymarket-sync-plugin` and commit the
  regenerated `plugins/holo-polymarket/skills/` copy. Keep manifest versions, both
  marketplaces, and `pyproject.toml` in lockstep.
