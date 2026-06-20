# Command Reference

## Contents

1. Market queries
2. Whale tracking
3. Historical trends and export
4. Cache and environment variables
5. Official trading CLI

## 1. Market queries

```bash
# Hot markets (by 24h volume)
bash <skill-dir>/scripts/polymarket.sh hot [limit]

# Keyword search
bash <skill-dir>/scripts/polymarket.sh search <keyword> [limit]

# Event detail (includes Token[Yes]/Token[No])
bash <skill-dir>/scripts/polymarket.sh detail <event-slug>
```

## 2. Whale tracking

```bash
# Leaderboard (alias lb)
bash <skill-dir>/scripts/polymarket.sh leaderboard [limit] [pnl|vol] [day|week|month|all]
bash <skill-dir>/scripts/polymarket.sh lb 10 pnl week

# Positions (alias pos)
bash <skill-dir>/scripts/polymarket.sh positions <wallet-address> [limit]
bash <skill-dir>/scripts/polymarket.sh pos 0xabc... 10
bash <skill-dir>/scripts/polymarket.sh pos 0xabc... 10 --active  # Show only unresolved markets

# Trade history
bash <skill-dir>/scripts/polymarket.sh trades <wallet-address> [limit]
```

## 3. Historical trends and export

```bash
# Historical price table
bash <skill-dir>/scripts/polymarket.sh history <event-slug> <from> <to> [interval]

# Trend summary (start/end/change)
bash <skill-dir>/scripts/polymarket.sh trend <event-slug> <from> <to> [interval]

# Volume trend
bash <skill-dir>/scripts/polymarket.sh volume-trend <event-slug> <from> <to> [interval]
```

Parameter constraints:
- `from/to`: `YYYY-MM-DD`
- `interval`: `1h` / `4h` / `1d`

Export:

```bash
# Auto-named export file
bash <skill-dir>/scripts/polymarket.sh history <slug> 2025-01-01 2025-01-31 --format csv

# Specify the output file
bash <skill-dir>/scripts/polymarket.sh trend <slug> 2025-01-01 2025-01-31 --format json --out /tmp/trend.json
```

## 4. Cache and environment variables

```bash
# Disable cache for a single run
NO_CACHE=1 bash <skill-dir>/scripts/polymarket.sh history <slug> 2025-01-01 2025-01-31

# Cache statistics
bash -c 'source <skill-dir>/scripts/cache.sh && cache_stats'

# Clear the cache
bash -c 'source <skill-dir>/scripts/cache.sh && cache_clear'
```

Common environment variables:
- `NO_CACHE=1`
- `CACHE_TTL=<seconds>`
- `CURL_TIMEOUT=<seconds>`
- `GAMMA_API_BASE` / `DATA_API_BASE` / `CLOB_API_BASE`
- `POLYMARKET_BEARER_TOKEN` (optional auth for the historical-price endpoint)
- `POLYMARKET_FUNDER` / `FUNDER` (default wallet for `positions` / `trades` when no
  address is given — use your proxy wallet, not the signer/EOA)
- `HTTP_PROXY` / `HTTPS_PROXY` / `http_proxy` / `https_proxy` (proxy)

## 5. Trading (polymarket-trade skill)

This skill is read-only. To place, preview, or cancel real orders, use the
sibling **polymarket-trade** skill (Python, dry-run by default; executing
requires `--execute` plus a matching `--confirm <token>`):

```bash
python3 <skill-dir>/../polymarket-trade/scripts/trade.py market <MARKET_SLUG>
python3 <skill-dir>/../polymarket-trade/scripts/trade.py balance
python3 <skill-dir>/../polymarket-trade/scripts/trade.py buy <MARKET_SLUG> yes --amount 5
python3 <skill-dir>/../polymarket-trade/scripts/trade.py buy <MARKET_SLUG> yes --limit 0.50 --shares 10
python3 <skill-dir>/../polymarket-trade/scripts/trade.py orders
python3 <skill-dir>/../polymarket-trade/scripts/trade.py cancel <ORDER_ID>
```
