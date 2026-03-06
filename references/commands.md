# 命令参考

## 目录

1. 市场查询
2. 大户追踪
3. 历史趋势与导出
4. 缓存与环境变量
5. 官方交易 CLI

## 1. 市场查询

```bash
# 热门市场（按 24h 交易量）
bash {baseDir}/scripts/polymarket.sh hot [limit]

# 关键词搜索
bash {baseDir}/scripts/polymarket.sh search <关键词> [limit]

# 事件详情（含 Token[Yes]/Token[No]）
bash {baseDir}/scripts/polymarket.sh detail <event-slug>
```

## 2. 大户追踪

```bash
# 排行榜（别名 lb）
bash {baseDir}/scripts/polymarket.sh leaderboard [limit] [pnl|vol] [day|week|month|all]
bash {baseDir}/scripts/polymarket.sh lb 10 pnl week

# 持仓（别名 pos）
bash {baseDir}/scripts/polymarket.sh positions <钱包地址> [limit]
bash {baseDir}/scripts/polymarket.sh pos 0xabc... 10

# 交易记录
bash {baseDir}/scripts/polymarket.sh trades <钱包地址> [limit]
```

## 3. 历史趋势与导出

```bash
# 历史价格表
bash {baseDir}/scripts/polymarket.sh history <event-slug> <from> <to> [interval]

# 趋势摘要（起始/结束/变化）
bash {baseDir}/scripts/polymarket.sh trend <event-slug> <from> <to> [interval]

# 交易量趋势
bash {baseDir}/scripts/polymarket.sh volume-trend <event-slug> <from> <to> [interval]
```

参数约束：
- `from/to`：`YYYY-MM-DD`
- `interval`：`1h` / `4h` / `1d`

导出：

```bash
# 自动命名导出文件
bash {baseDir}/scripts/polymarket.sh history <slug> 2025-01-01 2025-01-31 --format csv

# 指定输出文件
bash {baseDir}/scripts/polymarket.sh trend <slug> 2025-01-01 2025-01-31 --format json --out /tmp/trend.json
```

## 4. 缓存与环境变量

```bash
# 单次禁用缓存
NO_CACHE=1 bash {baseDir}/scripts/polymarket.sh history <slug> 2025-01-01 2025-01-31

# 缓存统计
bash -c 'source {baseDir}/scripts/cache.sh && cache_stats'

# 清理缓存
bash -c 'source {baseDir}/scripts/cache.sh && cache_clear'
```

常用环境变量：
- `NO_CACHE=1`
- `CACHE_TTL=<seconds>`
- `CURL_TIMEOUT=<seconds>`
- `GAMMA_API_BASE` / `DATA_API_BASE` / `CLOB_API_BASE`
- `POLYMARKET_BEARER_TOKEN`

## 5. 官方交易 CLI

```bash
polymarket clob balance --asset-type collateral
polymarket clob market-order --token <TOKEN_ID> --side buy --amount 5
polymarket clob create-order --token <TOKEN_ID> --side buy --price 0.50 --size 10
polymarket clob orders
polymarket clob cancel <ORDER_ID>
```