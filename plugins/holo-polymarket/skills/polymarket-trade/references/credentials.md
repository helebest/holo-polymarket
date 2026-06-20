# Credentials

`polymarket-trade` (and the optional historical-price auth in `polymarket-query`)
read credentials from a gitignored `KEY=VALUE` file or `POLYMARKET_*` environment
variables. This page is the single reference for which keys exist, what each one
is for, and which of the two core workflows actually use them:

- **Positions / balance lookups** — `trade.py positions`, `trade.py balance`, and
  the query skill's `positions` / `trades`.
- **Trading** — `trade.py buy` / `sell` / `cancel` with `--execute`.

## Which keys each workflow needs

The recommended key name uses the `POLYMARKET_` prefix; the bracketed aliases are
also accepted (case-insensitive), including the short forms Polymarket's own
export uses.

| Recommended key (aliases) | What it is | Positions / balance | Trading (`--execute`) |
| --- | --- | --- | --- |
| `POLYMARKET_FUNDER` (`FUNDER`) | The wallet that **holds collateral and positions**. For an email/Magic or browser login this is your **proxy wallet**, not the signer. | **Required** — positions/balance are read for this address | **Required** — the order's collateral source |
| `POLYMARKET_SIGNATURE_TYPE` (`SIGNATURE_TYPE`) | Wallet type: `0` EOA, `1` email/Magic, `2` browser, `3` deposit | — | **Required** — must match your wallet (email/Magic = `1`) |
| `POLYMARKET_PRIVATE_KEY` (`PRIVATE_KEY`, `PK`) | EOA private key; signs orders (EIP-712) | — | **Required** to place / cancel |
| `POLYMARKET_API_KEY` (`API_KEY`, `CLOB_API_KEY`) | CLOB L2 API key | Required for `balance` / `orders` (not `positions`) | **Required** |
| `POLYMARKET_API_SECRET` (`SECRET`, `API_SECRET`, `CLOB_SECRET`) | CLOB L2 API secret | ″ | **Required** |
| `POLYMARKET_API_PASSPHRASE` (`PASSPHRASE`, `API_PASSPHRASE`, `CLOB_PASS_PHRASE`) | CLOB L2 API passphrase | ″ | **Required** |
| `POLYMARKET_ADDRESS` (`PRIVATE_ADDRESS`, `ADDRESS`, `WALLET_ADDRESS`) | The signer EOA address | Only a fallback for `FUNDER`; shown in `whoami` | Only a fallback for `FUNDER` |
| `POLYMARKET_BEARER_TOKEN` (`BEARER_TOKEN`, `TOKEN`) | Query skill only; optional auth for the historical-price endpoint | Not used | Not used |
| `RECOVERYCODE` | Magic email-wallet recovery phrase | **Ignored** | **Ignored** |

> **Use the proxy wallet, not the signer.** Polymarket email/Magic (and browser)
> logins keep your USDC and positions in a deterministic **proxy wallet** whose
> address differs from the signer/EOA. The Data API and CLOB only ever see that
> proxy — point a skill at the signer address and you get an empty account. Set
> `POLYMARKET_FUNDER` to the proxy and `POLYMARKET_SIGNATURE_TYPE=1` (email/Magic).
>
> **Find your proxy address:** log in at polymarket.com and copy it from the
> profile URL (`polymarket.com/@0x…`) or the account menu under the top-right
> avatar. See [trading.md](trading.md) for the full wallet / funder model.

Once `FUNDER` is set, `ADDRESS`/`PRIVATE_ADDRESS` is only informational (a fallback
for `FUNDER` and a `whoami` display value); `BEARER_TOKEN` matters only for the
query skill's historical-price endpoint; and `RECOVERYCODE` is never read — keep
it secret elsewhere rather than in this file.

## File format

A simple `KEY=VALUE` text file (lines starting with `#` and blank lines are
ignored; keys are case-insensitive; surrounding single/double quotes are
stripped). Recommended layout (values are placeholders):

```text
# --- Trading: required ---
POLYMARKET_PRIVATE_KEY=0xYourPrivateKey
POLYMARKET_API_KEY=00000000-0000-0000-0000-000000000000
POLYMARKET_API_SECRET=base64-secret==
POLYMARKET_API_PASSPHRASE=hex-passphrase
POLYMARKET_FUNDER=0xYourProxyWallet          # proxy that holds funds/positions
POLYMARKET_SIGNATURE_TYPE=1                   # 0 EOA, 1 email/Magic, 2 browser, 3 deposit

# --- Optional ---
POLYMARKET_ADDRESS=0xYourSignerEOA           # informational; FUNDER fallback
# POLYMARKET_BEARER_TOKEN=...                 # query skill historical-price auth only

# --- Ignored by the skills (keep your recovery code secret elsewhere) ---
# RECOVERYCODE=...
```

The short forms (`API_KEY`, `SECRET`, `PASSPHRASE`, `PRIVATE_KEY`,
`PRIVATE_ADDRESS`, `FUNDER`, `SIGNATURE_TYPE`) are accepted too — that is the
format Polymarket's own export uses — so an exported file works as-is once you
add `FUNDER` (your proxy) and `SIGNATURE_TYPE`.

## Recognised keys and aliases

| Field | Accepted keys |
| --- | --- |
| private key | `POLYMARKET_PRIVATE_KEY`, `PRIVATE_KEY`, `PK` |
| address (signer EOA) | `POLYMARKET_ADDRESS`, `PRIVATE_ADDRESS`, `ADDRESS`, `WALLET_ADDRESS` |
| API key | `POLYMARKET_API_KEY`, `API_KEY`, `CLOB_API_KEY` |
| API secret | `POLYMARKET_API_SECRET`, `SECRET`, `API_SECRET`, `CLOB_SECRET` |
| API passphrase | `POLYMARKET_API_PASSPHRASE`, `PASSPHRASE`, `API_PASSPHRASE`, `CLOB_PASS_PHRASE` |
| funder | `POLYMARKET_FUNDER`, `FUNDER` |
| signature type | `POLYMARKET_SIGNATURE_TYPE`, `SIGNATURE_TYPE` |
| bearer token (query only) | `POLYMARKET_BEARER_TOKEN`, `BEARER_TOKEN`, `TOKEN` |

## Lookup order

1. Process environment variables (the keys above).
2. The file named by `$POLYMARKET_CREDENTIALS_FILE` (used exclusively when set).
3. `./.credentials` in the current working directory.
4. `~/.config/holo-polymarket/credentials`.
5. `~/.openclaw/credentials/polymarket_credentials` (legacy fallback).

Environment variables always override file values.

## Security

- **Keep the credentials file out of git.** `./.credentials` is gitignored by
  this repo; if you place it elsewhere, ensure that path is ignored too. Commit
  only the placeholder `.credentials.example`.
- The skill never prints secret values. `trade.py whoami` reports only which
  fields are present plus the public address / funder / signature type.
- The `PRIVATE_KEY` controls funds — treat it like a password. Prefer a
  dedicated trading wallet with a limited balance.
- `RECOVERYCODE` is not used by the skills; do not store your Magic recovery
  phrase alongside trading credentials.

## What each credential is for

- **Funder** (collateral wallet): the address that holds your USDC and positions.
  For proxy/deposit wallets it differs from the signing key and must be set
  explicitly. Positions and balances are always read for this wallet.
- **API key / secret / passphrase** (L2): authenticate REST calls that read your
  orders/balances and submit signed orders.
- **Private key** (L1): signs orders (EIP-712). Required to place or cancel.
- If only a private key is present, the client can derive L2 API credentials at
  runtime; providing them explicitly avoids that round-trip.

## Obtaining credentials

- **Proxy/funder address:** copy it from the logged-in Polymarket UI (profile URL
  `polymarket.com/@0x…` or the top-right account menu).
- **API credentials** are created from your funded Polymarket account/wallet (e.g.
  via the official client's `create_or_derive_api_creds` flow or the Polymarket
  UI). See [trading.md](trading.md) for the CLOB V2 wallet/funder model that
  determines which `signature_type` and `funder` you should use.
