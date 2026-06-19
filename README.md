# Holo Polymarket

Agent Skills for Polymarket prediction markets — research and trading — packaged
as local plugins for Claude Code, Codex, and OpenClaw, and published as skills
through ClawHub and Hermes-compatible discovery.

The repository ships two skills from one canonical `skills/` source of truth:

| Skill | Purpose |
| --- | --- |
| [`polymarket-query`](skills/polymarket-query/SKILL.md) | Read-only research: hot markets, search, event detail, historical price/probability and volume trends, whale leaderboard, address positions and trade history, with CSV/JSON export. (Bash + `curl`/`jq`.) |
| [`polymarket-trade`](skills/polymarket-trade/SKILL.md) | Trade via the official CLOB API: buy/sell (market or limit), balance, open orders, cancel. Dry-run by default with explicit confirmation. (Python.) |

## Repository layout

| Path | Purpose |
| --- | --- |
| `skills/` | Canonical Agent Skills (source of truth): `SKILL.md` + `scripts/` + `references/`. |
| `plugins/holo-polymarket/` | Shared plugin wrapper for Claude Code, Codex, and OpenClaw, with a generated `skills/` copy. |
| `.claude-plugin/marketplace.json` | Claude Code marketplace (local plugin `source` is a string path). |
| `.agents/plugins/marketplace.json` | Codex marketplace (`source` object + `policy`). |
| `registry/` | ClawHub/OpenClaw and Hermes publication notes plus the well-known discovery template. |
| `src/holo_polymarket/` | Validation, plugin sync, and release-artifact build tooling. |
| `tests/` | Bash skill tests (offline + live) and Python repository/trade tests. |
| `dist/` | Generated release artifacts (gitignored). |

The copy under `plugins/holo-polymarket/skills/` is generated from `skills/` by
`holo-polymarket-sync-plugin` and committed alongside the wrapper. Do not edit it
by hand.

## Install

### Claude Code

```text
/plugin marketplace add helebest/holo-polymarket
/plugin install holo-polymarket@holo-polymarket
```

Claude Code reads `.claude-plugin/marketplace.json` and loads
`plugins/holo-polymarket/.claude-plugin/plugin.json`, registering both skills.
For local development: `/plugin marketplace add /absolute/path/to/holo-polymarket`.

### Codex

Codex discovers the same plugin via `.agents/plugins/marketplace.json`. Running
Codex inside this directory lists `holo-polymarket` under available plugins; no
extra configuration is needed.

### ClawHub (OpenClaw skill registry)

```bash
npm i -g clawhub
clawhub skill publish skills/polymarket-query
clawhub skill publish skills/polymarket-trade
# install: clawhub install <publisher>/polymarket-query
```

### OpenClaw / Hermes / other agents

The skills use the AgentSkills folder format, so any compatible agent can consume
`skills/` directly:

- **OpenClaw**: copy/symlink folders under `skills/` into an OpenClaw skills
  directory, load `plugins/holo-polymarket/openclaw.plugin.json`, or
  `openclaw skills install`.
- **Hermes**: register this repo's `skills/` directory in `~/.hermes/config.yaml`,
  or host the generated `.well-known/agent-skills/index.json`.

See [registry/openclaw.md](registry/openclaw.md) and
[registry/hermes.md](registry/hermes.md).

## Usage

### Research (polymarket-query)

```bash
bash skills/polymarket-query/scripts/polymarket.sh hot 5
bash skills/polymarket-query/scripts/polymarket.sh search bitcoin 5
bash skills/polymarket-query/scripts/polymarket.sh detail fed-decision-in-march-885
bash skills/polymarket-query/scripts/polymarket.sh lb 10 pnl week
bash skills/polymarket-query/scripts/polymarket.sh pos 0xADDRESS 10 --active
bash skills/polymarket-query/scripts/polymarket.sh history fed-decision-in-march-885 2025-01-01 2025-01-31 1d --format csv
```

Prerequisites: `bash`, `curl`, `jq`. Time args: `from/to` = `YYYY-MM-DD`,
`interval` = `1h`/`4h`/`1d`. See
[skills/polymarket-query/references/commands.md](skills/polymarket-query/references/commands.md).

### Trading (polymarket-trade)

```bash
pip install -r skills/polymarket-trade/scripts/requirements.txt

# Inspect, then preview (dry-run prints a confirmation token)
python3 skills/polymarket-trade/scripts/trade.py market <market-slug>
python3 skills/polymarket-trade/scripts/trade.py buy <market-slug> yes --limit 0.40 --shares 10

# Execute with the token from the dry-run
python3 skills/polymarket-trade/scripts/trade.py buy <market-slug> yes --limit 0.40 --shares 10 \
  --execute --confirm <token>
```

**Every order is dry-run by default.** Executing requires both `--execute` and a
matching `--confirm <token>`. Market **BUY** `--amount` is USDC to spend; market
**SELL** `--amount` is shares to sell. See
[skills/polymarket-trade/SKILL.md](skills/polymarket-trade/SKILL.md) and
[skills/polymarket-trade/references/trading.md](skills/polymarket-trade/references/trading.md).

> Polymarket migrated to **CLOB V2** (pUSD collateral) on 2026-04-28; the legacy
> `py-clob-client` is non-functional. This skill targets `py-clob-client-v2`.
> The live trading surface is still stabilising upstream — preview with dry-runs,
> start small, and verify against your account.

## Credentials

Trading needs Polymarket CLOB credentials in a gitignored `KEY=VALUE` file. They
are resolved agent-neutrally: `POLYMARKET_*` env vars, then
`$POLYMARKET_CREDENTIALS_FILE`, then `./.credentials`,
`~/.config/holo-polymarket/credentials`, and finally
`~/.openclaw/credentials/polymarket_credentials`. See
[skills/polymarket-trade/references/credentials.md](skills/polymarket-trade/references/credentials.md).
The historical-price query also accepts an optional `BEARER_TOKEN` from the same
file. Secrets are never printed; `trade.py whoami` reports only which fields are
present.

## Development

```bash
uv sync
uv run ruff check .
uv run ruff format --check .
uv run holo-polymarket-validate          # repository invariants
uv run holo-polymarket-sync-plugin --check
uv run python -m pytest                  # Python tests
bash tests/run_tests.sh                  # Bash skill tests (offline)
RUN_LIVE_TESTS=1 bash tests/run_tests.sh # + live API integration tests
```

Regenerate the committed plugin skills copy after editing canonical skills:

```bash
uv run holo-polymarket-sync-plugin
```

Build release artifacts (skill/plugin archives + well-known discovery indexes +
checksums) under `dist/`:

```bash
uv run holo-polymarket-build
```

## License

MIT
