# Changelog

All notable changes to this project are documented here.

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
