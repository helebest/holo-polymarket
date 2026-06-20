# Changelog

All notable changes to this project are documented here.

## 0.2.0

### Added

- `polymarket-trade`: pre-flight wallet guard — a live order is refused (and the
  dry-run warns) when `signature_type` is a proxy type (`1`/`2`/`3`) but `funder`
  resolves to the bare signer EOA, so an order can't silently target an empty
  wallet. Set `POLYMARKET_FUNDER` to your proxy to proceed.
- Documented the `--order-type GTC|GTD|FOK|FAK` flag (it is bound into the
  confirm token) in the trade `SKILL.md` and `trading.md`.
- `polymarket-query`: documented the leaderboard `-t|--time <period>` form and
  the short forms it accepts (`d|w|m|a`, `volume`), plus a "Reading the output"
  section that explains success vs valid-empty vs error states.
- Tables of contents in the trade `credentials.md` / `trading.md` references, for
  parity with the query references.

### Fixed

- The `trade.py` module docstring no longer claims `positions` / `market` run
  with no third-party packages — both use `requests`; only `whoami` and offline
  `--token-id` dry-run previews are genuinely dependency-free.

### Changed

- CI and release workflows now run on the Node 24 runtime (Actions bumped:
  `checkout` v7, `setup-uv` v7, `upload-artifact` v7).

## 0.1.1

### Fixed

- `polymarket-trade positions` now defaults to the **funder** (the proxy wallet
  that holds funds/positions) instead of the bare signer EOA, so a configured
  account resolves to the wallet that actually has positions.
- CLOB v2 method-name drift in the live adapter: `orders` now uses
  `get_open_orders` (was `get_orders`), and `cancel` / `cancel --all` use the v2
  `cancel_order(OrderPayload)` / `cancel_orders(list)` calls (v1 names kept as
  fallbacks).
- `--execute` now reports any client/exchange failure (e.g. `PolyApiException`)
  as a clean, secret-scrubbed `mode: error` instead of leaking an uncaught
  traceback.

### Added

- `polymarket-query` `positions` / `trades` default to `POLYMARKET_FUNDER`
  (`FUNDER`) when no address is given, so you can look up your own holdings
  without pasting your proxy address each time.
- Order dry-run previews now surface the `funder` and `signature_type` the order
  would use, so you can confirm it targets the proxy before executing.
- A committed `.credentials.example` template.

### Changed

- Standardised credentials documentation on the `POLYMARKET_*` key names (short
  aliases still accepted) and added a per-workflow breakdown of which keys
  positions/balance and trading actually use, including the proxy-wallet vs EOA
  distinction and that `RECOVERYCODE` is ignored. Updated README, the trade
  `credentials.md`, query SKILL/commands/troubleshooting docs, and CLAUDE.md.

## 0.1.0

Initial multi-runtime release.

### Added

- Multi-runtime packaging from a single canonical `skills/` directory: Claude
  Code and Codex marketplaces, a shared plugin wrapper with Claude/Codex/OpenClaw
  manifests, ClawHub publishing notes, and Hermes well-known discovery.
- `polymarket-trade` skill: buy/sell (market or limit), collateral balance, open
  orders, and cancel via the official CLOB API (`py-clob-client-v2`). Dry-run by
  default with a deterministic `--confirm` token required to execute. Read-only
  commands and dry-run previews need no third-party packages.
- Distribution tooling in `src/holo_polymarket/`: `validate`, `sync-plugin`, and
  `build` (the well-known discovery index includes the AgentSkills 0.2.0
  per-skill `digest`).
- Python tests for repository invariants and the trade CLI safety model; CI
  workflow running ruff, validate, sync-check, pytest, and the Bash suite.

### Changed

- Restructured the former single Bash skill into `skills/polymarket-query/` and
  renamed it `polymarket-query`.
- Decoupled from OpenClaw: credential lookup is now agent-neutral (env →
  `$POLYMARKET_CREDENTIALS_FILE` → `./.credentials` →
  `~/.config/holo-polymarket/credentials` → legacy `~/.openclaw/...`).
- Made the Bash date helpers portable across GNU and BSD/macOS `date`.
- Translated all documentation, code comments, and CLI output to English.

### Removed

- `openclaw_deploy_skill.sh` (OpenClaw-specific). Use the plugin wrapper, ClawHub,
  or a direct `skills/` copy instead.
