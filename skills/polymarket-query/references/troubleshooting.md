# Troubleshooting Guide

## Contents

1. Quick diagnostic order
2. Dependencies and environment
3. Network and API errors
4. Common historical data/trend issues
5. Export and file issues

## 1. Quick diagnostic order

1. First run a basic command to confirm the entry point works:
   - `bash <skill-dir>/scripts/polymarket.sh hot 1`
2. Then run the target command with minimal arguments.
3. On error, first check whether it is an argument format error, then check the network and credentials.

## 2. Dependencies and environment

### Symptom
- Reports that `curl` or `jq` is missing.

### Resolution
- Install the missing dependencies and retry.
- In CI/container environments, confirm the dependencies are pre-installed.

## 2b. `positions` / `trades` show nothing for a real account

### Symptom
- You hold positions on polymarket.com, but `positions <address>` returns
  "No positions" (and `value`/PnL look empty).

### Resolution
- You are almost certainly querying the **signer/EOA** address. Polymarket
  email/Magic (and browser) logins keep funds and positions in a separate
  **proxy wallet**. Query that proxy address instead.
- Find the proxy: log in at polymarket.com and copy the address from the profile
  URL (`polymarket.com/@0x…`) or the top-right account menu.
- To default to it, set `POLYMARKET_FUNDER` (or `FUNDER` in the credentials file)
  to the proxy address; then `positions` / `trades` work with no address argument.

## 3. Network and API errors

### Symptom
- Output similar to "Request failed: ... (curl=...)".

### Resolution
- Check that the following are reachable:
  - `https://gamma-api.polymarket.com`
  - `https://data-api.polymarket.com`
  - `https://clob.polymarket.com`
- Increase the timeout: `CURL_TIMEOUT=30`.
- On transient retry failures, rerun later.

## 4. Common historical data/trend issues

### Symptom A
- `history/trend` reports no data or fails.

### Resolution
- Confirm the event slug is correct.
- Confirm the date format is `YYYY-MM-DD` and `from <= to`.
- Confirm `interval` is one of `1h|4h|1d`.
- Historical price data uses Polymarket's public `prices-history` endpoint and
  normally needs no token. If your deployment reports a token issue, provide one
  via either:
  - the environment variable `POLYMARKET_BEARER_TOKEN`, or
  - a `BEARER_TOKEN` (or `TOKEN`) entry in a credentials file, resolved in the
    same agent-neutral order as the trade skill: `$POLYMARKET_CREDENTIALS_FILE`,
    then `./.credentials`, `~/.config/holo-polymarket/credentials`, and finally
    the legacy `~/.openclaw/credentials/polymarket_credentials`.

### Symptom B
- `volume-trend` returns an endpoint error.

### Resolution
- This indicates the Data API did not return an array structure; retry later.
- Enable `NO_CACHE=1` and retry to avoid reading a stale cache.

## 5. Export and file issues

### Symptom
- The `--out` path fails.

### Resolution
- Make sure the output directory exists.
- Only use `--out` together with `--format csv|json`.
- First omit `--out` and let the script auto-name the file to verify whether the flow works.
