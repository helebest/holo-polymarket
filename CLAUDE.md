# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Holo Polymarket is a multi-runtime Agent Skills repository for Polymarket
prediction markets. One canonical `skills/` directory is the source of truth and
is packaged as local plugins (Claude Code, Codex, OpenClaw) and published as
skills (ClawHub, Hermes well-known discovery).

Two skills:

- **`polymarket-query`** — read-only market research and whale/position tracking.
  Language: **Bash** (`curl`, `jq`).
- **`polymarket-trade`** — trading via the official CLOB API (buy/sell/balance/
  orders/cancel), dry-run by default. Language: **Python** (`py-clob-client-v2`,
  `requests`).

Distribution tooling lives in `src/holo_polymarket/` (Python, run via `uv`).

## Commands

```bash
# Dev environment
uv sync

# Quality gate (matches CI)
uv run ruff check .
uv run ruff format --check .
uv run holo-polymarket-validate            # cross-runtime repo invariants
uv run holo-polymarket-sync-plugin --check # generated plugin copy in sync
uv run python -m pytest                    # Python tests (repo layout + trade)
bash tests/run_tests.sh                    # Bash skill tests (offline)
RUN_LIVE_TESTS=1 bash tests/run_tests.sh   # + live API integration tests

# Regenerate the committed plugin skills copy after editing canonical skills
uv run holo-polymarket-sync-plugin

# Build release artifacts into dist/ (skill/plugin zips + well-known indexes)
uv run holo-polymarket-build

# Run the skills directly
bash skills/polymarket-query/scripts/polymarket.sh <command> [args...]
python3 skills/polymarket-trade/scripts/trade.py <command> [args...]
```

## Architecture

### polymarket-query (Bash)

Entry point `skills/polymarket-query/scripts/polymarket.sh` sources modules and
dispatches by domain:

- `common.sh` — shared helpers (`require_commands`, `url_encode`, portable
  GNU/BSD date conversion, `pm_error`/`pm_warn`).
- `api.sh` — all HTTP calls (`gamma_get`/`data_get`/`clob_get`), history-series
  fetching, agent-neutral credential resolution (`_pm_resolve_credentials_file`,
  `load_polymarket_bearer_token`).
- `format.sh` — output formatting (reads JSON from stdin, never as an argument).
- `export.sh` — CSV/JSON export for time-series commands.
- `cache.sh` — SHA256-keyed file cache under `~/.cache/holo-polymarket/`.
- `commands_market.sh` / `commands_whale.sh` / `commands_series.sh` — command
  handlers (`hot/search/detail`, `leaderboard/positions/trades`,
  `history/trend/volume-trend`).

### polymarket-trade (Python)

`skills/polymarket-trade/scripts/`:

- `trade.py` — argparse CLI. Orders are dry-run by default; executing requires
  `--execute` plus a matching `--confirm <token>` (a deterministic hash of the
  order parameters). Read commands and dry-run previews need no third-party
  packages.
- `market_data.py` — Gamma API market resolution (slug → token ids, tick size,
  min size, neg-risk, indicative prices). `requests` imported lazily.
- `credentials.py` — agent-neutral credential loading; never prints secrets.
- `clob.py` — live CLOB adapter over `py-clob-client-v2`, imported lazily, with
  version-tolerant method dispatch.

### Distribution tooling (`src/holo_polymarket/`)

- `validate.py` — enforces cross-runtime invariants (skill names/frontmatter,
  manifest versions, Claude string source vs Codex object source, generated
  plugin copy). Language-aware: only Python skills require `requirements.txt`.
- `sync_plugin.py` — regenerates `plugins/holo-polymarket/skills/` from `skills/`.
- `build.py` — skill/plugin archives + AgentSkills 0.2.0 well-known indexes
  (with per-skill `digest`) + checksums.

## Conventions

- **All documentation and code comments are in English.** CLI output is English.
- Each skill's `SKILL.md` `name` must equal its directory name and uses the
  `<skill-dir>` placeholder for paths.
- Bash query skill: all HTTP in `api.sh`, all formatting in `format.sh`; format
  functions read JSON from stdin.
- Credentials are agent-neutral (env → `$POLYMARKET_CREDENTIALS_FILE` →
  `./.credentials` → `~/.config/holo-polymarket/credentials` →
  `~/.openclaw/...`); never hard-code an OpenClaw-only path.
- Trading is dry-run by default; never execute without `--execute --confirm`.
- After editing canonical skills, run `holo-polymarket-sync-plugin` and commit the
  regenerated `plugins/holo-polymarket/skills/` copy.
- Keep manifest versions, both marketplaces, and `pyproject.toml` in lockstep.

## Environment variables

- Query: `NO_CACHE`, `CACHE_TTL`, `CURL_TIMEOUT`, `CURL_RETRY`,
  `GAMMA_API_BASE`/`DATA_API_BASE`/`CLOB_API_BASE`, `POLYMARKET_BEARER_TOKEN`,
  `POLYMARKET_FUNDER` (default address for `positions`/`trades`),
  `HTTP(S)_PROXY` (auto-detected).
- Trade: `POLYMARKET_PRIVATE_KEY`, `POLYMARKET_API_KEY`/`..._API_SECRET`/
  `..._API_PASSPHRASE`, `POLYMARKET_FUNDER`, `POLYMARKET_SIGNATURE_TYPE`,
  `POLYMARKET_CREDENTIALS_FILE`, `POLYMARKET_CLOB_HOST`, `POLYMARKET_CHAIN_ID`.
