---
name: polymarket-query
description: Read-only research on Polymarket prediction markets — hot events, keyword search, event detail and tokens, historical price/probability trends, volume trends, plus whale leaderboard, any address's positions and P&L, and trade history, with CSV/JSON export. Use when the user wants market research, current probabilities, position/P&L lookups, whale tracking, time-series review, or data export. To place real buy/sell orders, use the polymarket-trade skill instead.
---

# Polymarket Query

A read-only skill for researching Polymarket prediction markets (it never places
orders). It covers two needs:

- **Market research**: hot events, search, event detail, historical price and
  probability/volume trends.
- **Positions & whale tracking**: leaderboard, any address's positions and P&L,
  and trade history.

> To actually **buy/sell** (place orders, cancel, balances, order management),
> use the **`polymarket-trade`** skill.

## Quick start

1. Check the environment: `bash`, `curl`, `jq`, and access to
   `gamma-api.polymarket.com` / `data-api.polymarket.com` / `clob.polymarket.com`.
2. Pick a task type: market info / whales & positions / historical trends.
3. Run the matching command: `bash <skill-dir>/scripts/polymarket.sh <command> [args...]`.

Full command list: [references/commands.md](references/commands.md). Troubleshooting:
[references/troubleshooting.md](references/troubleshooting.md).

## Choosing a command

- Quick market heat: `hot [limit]`.
- Find markets by keyword: `search <keyword> [limit]`.
- Inspect an event by slug (with tokens): `detail <event-slug>`.
- Track top traders / check positions: `leaderboard` (alias `lb`) → `positions`
  (alias `pos`) → `trades`.
  - Only open positions: `positions <address> [limit] --active`.
- Time-series review:
  - Probability table: `history`
  - Start/end change summary: `trend`
  - Volume changes: `volume-trend`
- File export: add `--format csv|json` and optional `--out <file>` to
  `history/trend/volume-trend`.

## Minimal examples

```bash
# 1) Hot markets
bash <skill-dir>/scripts/polymarket.sh hot 5

# 2) Search + detail
bash <skill-dir>/scripts/polymarket.sh search bitcoin 5
bash <skill-dir>/scripts/polymarket.sh detail fed-decision-in-march-885

# 3) Whale & position tracking
bash <skill-dir>/scripts/polymarket.sh lb 10 pnl week
bash <skill-dir>/scripts/polymarket.sh pos 0xc257ea... 10
bash <skill-dir>/scripts/polymarket.sh pos 0xc257ea... 10 --active   # open only
bash <skill-dir>/scripts/polymarket.sh trades 0xc257ea... 10

# 4) Historical trends + export
bash <skill-dir>/scripts/polymarket.sh history fed-decision-in-march-885 2025-01-01 2025-01-31 1d
bash <skill-dir>/scripts/polymarket.sh trend fed-decision-in-march-885 2025-01-01 2025-01-31 --format csv
bash <skill-dir>/scripts/polymarket.sh volume-trend fed-decision-in-march-885 2025-01-01 2025-01-31 --format json --out /tmp/volume.json
```

Parameter rules: `from/to` are `YYYY-MM-DD`; `interval` is `1h` / `4h` / `1d`.

## Common failures

- Missing dependencies: install `curl` / `jq`.
- Network failures: check API reachability and timeouts; raise `CURL_TIMEOUT` if
  needed. In a proxy environment, `HTTPS_PROXY` is auto-detected.
- Historical price failures: check `POLYMARKET_BEARER_TOKEN` or a credentials
  file (see below).
- Argument errors: re-check command usage and the date format (`YYYY-MM-DD`).

## Credentials (only the historical-price endpoint needs one)

The historical-price endpoint may require a bearer token. It is resolved in this
order (agent-neutral, not tied to any runtime):

1. `POLYMARKET_BEARER_TOKEN` environment variable
2. the file named by `POLYMARKET_CREDENTIALS_FILE`
3. `./.credentials` in the project directory (should be gitignored)
4. `~/.config/holo-polymarket/credentials`
5. `~/.openclaw/credentials/polymarket_credentials` (legacy fallback)

The credentials file is `KEY=VALUE` and supports the `BEARER_TOKEN` / `TOKEN`
fields.

## Trading boundary

This skill is **read-only** and never places orders. For buying/selling,
cancelling, balances, and order management, use the **`polymarket-trade`** skill
(built on the official CLOB API).
