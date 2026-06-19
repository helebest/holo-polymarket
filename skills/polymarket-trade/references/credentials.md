# Credentials

## File format

A simple `KEY=VALUE` text file (lines starting with `#` and blank lines are
ignored). Example layout (values are placeholders):

```text
# CLOB L2 API credentials
API_KEY=00000000-0000-0000-0000-000000000000
SECRET=base64-secret==
PASSPHRASE=hex-passphrase

# EOA signer
PRIVATE_ADDRESS=0xYourWalletAddress
PRIVATE_KEY=0xYourPrivateKey

# Optional
# FUNDER=0xFundingWalletAddress      # defaults to PRIVATE_ADDRESS
# SIGNATURE_TYPE=0                    # 0 EOA, 1 email/Magic, 2 browser, 3 deposit wallet
```

## Recognised keys and aliases

| Field | Accepted keys |
| --- | --- |
| private key | `PRIVATE_KEY`, `PK`, `POLYMARKET_PRIVATE_KEY` |
| address | `PRIVATE_ADDRESS`, `ADDRESS`, `WALLET_ADDRESS`, `POLYMARKET_ADDRESS` |
| API key | `API_KEY`, `CLOB_API_KEY`, `POLYMARKET_API_KEY` |
| API secret | `SECRET`, `API_SECRET`, `CLOB_SECRET`, `POLYMARKET_API_SECRET` |
| API passphrase | `PASSPHRASE`, `API_PASSPHRASE`, `CLOB_PASS_PHRASE`, `POLYMARKET_API_PASSPHRASE` |
| funder | `FUNDER`, `POLYMARKET_FUNDER` |
| signature type | `SIGNATURE_TYPE`, `POLYMARKET_SIGNATURE_TYPE` |

## Lookup order

1. Process environment variables (the keys above).
2. The file named by `$POLYMARKET_CREDENTIALS_FILE` (used exclusively when set).
3. `./.credentials` in the current working directory.
4. `~/.config/holo-polymarket/credentials`.
5. `~/.openclaw/credentials/polymarket_credentials` (legacy fallback).

Environment variables always override file values.

## Security

- **Keep the credentials file out of git.** `./.credentials` is gitignored by
  this repo; if you place it elsewhere, ensure that path is ignored too.
- The skill never prints secret values. `trade.py whoami` reports only which
  fields are present plus the public address/funder.
- The `PRIVATE_KEY` controls funds — treat it like a password. Prefer a
  dedicated trading wallet with a limited balance.

## What each credential is for

- **API key / secret / passphrase** (L2): authenticate REST calls that read your
  orders/balances and submit signed orders.
- **Private key** (L1): signs orders (EIP-712). Required to place or cancel.
- If only a private key is present, the client can derive L2 API credentials at
  runtime; providing them explicitly avoids that round-trip.

## Obtaining credentials

API credentials are created from your funded Polymarket account/wallet (e.g. via
the official client's `create_or_derive_api_creds` flow or the Polymarket UI).
See [trading.md](trading.md) for the CLOB V2 wallet/funder model that determines
which `signature_type` and `funder` you should use.
