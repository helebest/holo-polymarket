# How Polymarket CLOB trading works

## Markets, outcomes, and token ids

- Each binary market has exactly two ERC-1155 outcome tokens (e.g. `Yes` / `No`)
  on Polygon (chain id 137), managed by the Gnosis Conditional Token Framework.
- Each outcome has its own numeric **CLOB token id** (`clobTokenId`). You "buy
  Yes" or "buy No" by submitting an order against that side's token id.
- Resolve a market slug to its tokens with the Gamma API. `clobTokenIds` and
  `outcomes` are aligned index-for-index, so `outcomes[i]` corresponds to
  `clobTokenIds[i]`. The `market` command does this for you.
- **Always confirm the outcome label** — do not assume index 0 is "Yes" in every
  market. Token ids are very large integers; keep them as strings.

## Prices and sizes

- Price is in `(0, 1)` USD-collateral per share; size is in shares; notional
  cost ≈ `price × size`.
- **Market BUY**: `amount` is the **USDC to spend** (shares ≈ amount / price).
- **Market SELL**: `amount` is the **number of shares to sell** (USDC ≈ amount × price).
- Each market has a **tick size** (minimum price increment, e.g. `0.01`) and a
  **minimum order size**. Orders that violate either are rejected. The `market`
  command reports both (`tick_size`, `min_size`).

## Order types

- `GTC` — Good-Til-Cancelled limit order (rests on the book). Default for limit orders.
- `GTD` — Good-Til-Date limit order.
- `FOK` — Fill-Or-Kill (all-or-nothing, immediate). Default for market orders.
- `FAK` — Fill-And-Kill (fill what's available, cancel the rest).

A market order's `price`, if set, is a **worst-price / slippage bound**, not the
execution price.

## CLOB V2 migration (read this before going live)

On **2026-04-28** Polymarket performed a full exchange upgrade to **CLOB V2**:

- The legacy `py-clob-client` (v1) is archived and its orders are **rejected by
  production**. This skill targets **`py-clob-client-v2`** (`pip install
  py-clob-client-v2`).
- Collateral migrated from bridged USDC.e to **pUSD** (an ERC-20 backed 1:1 by
  USDC). Balances must be held/approved in pUSD; USDC.e must be wrapped via the
  Collateral Onramp first.
- V2 introduced new exchange contracts. EOA users must (one time) approve pUSD
  (ERC-20) and set `setApprovalForAll` on the Conditional Tokens (ERC-1155) to
  the V2 CTF Exchange and, for neg-risk markets, the V2 Neg Risk Exchange /
  Adapter. py-clob-client does **not** set allowances for you.
- The live programmatic-trading surface is still stabilising upstream (EOA-only
  flows may be restricted in favour of "deposit wallets" / `signature_type=3`,
  and there are open client bugs). **Preview every order with a dry-run, start
  with tiny sizes, and verify against your account before trusting automation.**

## Wallet / funder model

`signature_type` selects how orders are signed and who funds them:

| Value | Meaning | `funder` |
| --- | --- | --- |
| `0` | Standard EOA (you hold the private key) | your EOA address (default) |
| `1` | Email / Magic proxy wallet | the proxy address |
| `2` | Browser wallet proxy | the proxy address |
| `3` | Deposit wallet (POLY_1271), recommended for new API users | the deposit wallet |

The `funder` is the address that actually holds collateral and positions. For a
bare EOA, `funder` defaults to your address. For proxy/deposit wallets it differs
from the signing key and must be set explicitly (`FUNDER` / `SIGNATURE_TYPE` in
the credentials file, or `POLYMARKET_FUNDER` / `POLYMARKET_SIGNATURE_TYPE`).

## Neg-risk markets

Multi-outcome events (3+ outcomes) use a different exchange and require the
`neg_risk` flag. When you trade by slug the flag is read from the market; when
using `--token-id` directly, pass `--neg-risk` if applicable.

## Safety checklist for automated trading

- Dry-run first; copy the printed `confirm_token` to execute the exact order.
- Assert BUY `--amount` is USDC and SELL `--amount` is shares (the units differ).
- Validate price against tick size and size against the market minimum.
- Set a slippage bound on market orders; prefer FOK/FAK so partial bad fills
  don't linger.
- Keep balance, allowances, and `funder` consistent on a single address.
- Don't trade placeholder/"Other" outcomes in augmented neg-risk events.
