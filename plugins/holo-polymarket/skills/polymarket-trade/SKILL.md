---
name: polymarket-trade
description: Trade on Polymarket prediction markets through the official CLOB API — buy and sell outcome shares (market or limit orders), preview costs, check collateral balance, list open orders, and cancel orders. Every order is dry-run by default and requires an explicit confirmation token to execute. Use when the user wants to place, preview, or cancel real Polymarket trades. For read-only market research, probabilities, positions, and history, use the polymarket-query skill instead.
metadata:
  version: "0.2.1"
---

# Polymarket Trade

Place and manage real trades on Polymarket via the official CLOB API.

> **This skill can spend real money.** Every order command is **dry-run by
> default**: it resolves the market, validates the order, previews the cost, and
> prints a confirmation token — but sends nothing. Executing requires both
> `--execute` and `--confirm <token>`.

## Setup

```bash
pip install -r <skill-dir>/scripts/requirements.txt
```

Market data, dry-run previews, and `whoami` work with no packages installed.
Live placement / cancellation / balance reads need `py-clob-client-v2`.

Provide credentials in a gitignored `KEY=VALUE` file (see
[references/credentials.md](references/credentials.md)). They are looked up
agent-neutrally: `POLYMARKET_*` env vars, then `$POLYMARKET_CREDENTIALS_FILE`,
then `./.credentials`, `~/.config/holo-polymarket/credentials`, and finally
`~/.openclaw/credentials/polymarket_credentials`.

Set `POLYMARKET_FUNDER` to your **proxy wallet** (the address holding funds and
positions — for email/Magic logins it differs from the signer) and
`POLYMARKET_SIGNATURE_TYPE` to match your wallet (`1` email/Magic, `2` browser).
Otherwise `balance` / `positions` resolve to the empty signer EOA. See
[references/credentials.md](references/credentials.md) and
[references/trading.md](references/trading.md).

Verify what was loaded (no secrets are printed):

```bash
python3 <skill-dir>/scripts/trade.py whoami
```

## Commands

```bash
# Inspect a market: token ids, outcomes, tick size, min size, indicative prices
python3 <skill-dir>/scripts/trade.py market <market-slug>

# Limit BUY 10 shares of YES at 0.40 (dry-run preview)
python3 <skill-dir>/scripts/trade.py buy <market-slug> yes --limit 0.40 --shares 10

# Market BUY: spend 25 USDC on YES (amount is USDC for BUY)
python3 <skill-dir>/scripts/trade.py buy <market-slug> yes --amount 25

# Market SELL: sell 50 shares of YES (amount is SHARES for SELL)
python3 <skill-dir>/scripts/trade.py sell <market-slug> yes --amount 50

# Execute: copy the confirm_token printed by the dry-run
python3 <skill-dir>/scripts/trade.py buy <market-slug> yes --limit 0.40 --shares 10 \
  --execute --confirm <token>

# Account + order management (needs API credentials)
python3 <skill-dir>/scripts/trade.py balance
python3 <skill-dir>/scripts/trade.py orders
python3 <skill-dir>/scripts/trade.py positions [address]
python3 <skill-dir>/scripts/trade.py cancel <order-id>                       # dry-run
python3 <skill-dir>/scripts/trade.py cancel <order-id> --execute --confirm <token>
python3 <skill-dir>/scripts/trade.py cancel --all --execute --confirm <token>
```

You can target a CLOB token id directly with `--token-id <id>` instead of
`<market-slug> <outcome>` (useful for offline previews).

## Order semantics (important)

- **Market BUY** `--amount` is **USDC to spend**; shares received ≈ amount / price.
- **Market SELL** `--amount` is **shares to sell**; USDC received ≈ amount × price.
- **Limit** orders use `--limit <price 0..1>` and `--shares <n>`; price must be a
  multiple of the market's tick size.
- **Order type**: `--order-type GTC|GTD|FOK|FAK` overrides the default (`GTC` for
  limit, `FOK` for market). It is bound into the confirm token, so changing it
  re-previews. See [references/trading.md](references/trading.md) for what each
  type means.

## Safety model

1. No state-changing action is sent without `--execute` — this covers `buy`,
   `sell`, and `cancel`.
2. `--execute` also requires `--confirm <token>`, where the token is the
   deterministic value printed by the matching dry-run. For orders the token is
   bound to the **full** order — side, token id, price/amount, size, tick size,
   neg-risk flag, and order type — so changing any of them changes the token and
   a stale confirmation cannot execute a different order. `cancel` prints and
   requires its own token: a single cancel binds it to the order id, and `cancel
   --all` binds it to a snapshot of the currently-open order ids (listed live and
   shown in the preview), so a stale `--all` confirmation can't cancel orders
   placed since you previewed. Previewing `--all` therefore needs API credentials.
3. Order size must be positive, and limit prices are validated against the
   market tick size; sizes below the market minimum produce a warning.
4. Resolve the outcome explicitly (`yes`/`no`/label/index) — do not assume
   index 0 is "Yes" for every market.
5. Before a live order, the funded wallet is sanity-checked: if `signature_type`
   is a proxy type (`1`/`2`/`3`) but `funder` resolves to the bare signer EOA,
   execution is refused (set `POLYMARKET_FUNDER` to your proxy) so an order can't
   silently target an empty wallet. The dry-run surfaces this as a warning.

See [references/trading.md](references/trading.md) for how Polymarket CLOB
trading works (CLOB V2, pUSD collateral, wallet/funder model, neg-risk markets,
allowances) and the current migration caveats.
