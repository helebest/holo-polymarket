---
name: holo-polymarket
description: Polymarket 预测市场工具。查询热门预测、搜索市场、分析概率趋势、追踪大户持仓、实盘交易下单。
homepage: https://github.com/helebest/holo-polymarket
---

# Polymarket

一站式接入 Polymarket 预测市场 — 查询、分析、追踪大户。

## 前置条件

1. `jq` 和 `curl` 已安装
2. 网络访问：能够访问 `gamma-api.polymarket.com` 和 `data-api.polymarket.com`

## 使用方法

### 市场数据（Gamma API）

```bash
# 查看热门预测
bash {baseDir}/scripts/polymarket.sh hot [limit]

# 搜索预测市场
bash {baseDir}/scripts/polymarket.sh search <关键词> [limit]

# 查看事件详情
bash {baseDir}/scripts/polymarket.sh detail <event-slug>
```

### 大户追踪（Data API）

```bash
# 查看排行榜（按盈利/交易量）
bash {baseDir}/scripts/polymarket.sh leaderboard [limit] [pnl|vol]

# 查看用户持仓
bash {baseDir}/scripts/polymarket.sh positions <钱包地址> [limit]

# 查看用户交易记录
bash {baseDir}/scripts/polymarket.sh trades <钱包地址> [limit]
```

### 历史与趋势分析（Phase 2b）

```bash
# 历史价格（默认 interval=1d）
bash {baseDir}/scripts/polymarket.sh history <event-slug> <from> <to> [interval]

# 概率趋势（起始/结束/变化）
bash {baseDir}/scripts/polymarket.sh trend <event-slug> <from> <to> [interval]

# 交易量趋势
bash {baseDir}/scripts/polymarket.sh volume-trend <event-slug> <from> <to> [interval]
```

### 交易下单（CLOB API）

```bash
# 买入（开多）
bash {baseDir}/scripts/polymarket.sh buy <event-slug> <outcome> <price> <amount> [order_type]

# 卖出（开空）
bash {baseDir}/scripts/polymarket.sh sell <event-slug> <outcome> <price> <amount> [order_type]
```

参数说明：
- `event-slug`: 市场 slug（从 search 或 detail 获取）
- `outcome`: Yes 或 No
- `price`: 价格（0.01-0.99）
- `amount`: 数量（美元）
- `order_type`: GTC(默认) | FOK | GTD

### 订单管理与余额（CLOB API）

```bash
# 查看活跃订单
bash {baseDir}/scripts/polymarket.sh orders [market-slug]

# 取消指定订单
bash {baseDir}/scripts/polymarket.sh cancel <order_id>

# 取消所有订单
bash {baseDir}/scripts/polymarket.sh cancel-all

# 查看账户余额
bash {baseDir}/scripts/polymarket.sh balance [USDC|CONDITIONAL]
```

⚠️ **重要**: 交易功能需要正确的 CLOB API 认证凭据和 `uv`（Python 包管理器）。使用 `DRY_RUN=1` 模拟测试：

时间范围参数：
- `from`: 开始日期（`YYYY-MM-DD`）
- `to`: 结束日期（`YYYY-MM-DD`）
- `interval`: `1h` / `4h` / `1d`（默认 `1d`）
- CLI 中为位置参数 `<from> <to> [interval]`，语义等同 `--from` / `--to` / `--interval`

导出参数：
- `--format csv|json`
- `--out <文件路径>`（必须与 `--format` 一起使用）

## 示例

```bash
# 查看 Top 5 热门预测
bash {baseDir}/scripts/polymarket.sh hot 5

# 搜索比特币相关
bash {baseDir}/scripts/polymarket.sh search bitcoin

# 排行榜 Top 10（按盈利）
bash {baseDir}/scripts/polymarket.sh lb 10

# 排行榜 Top 5（按交易量）
bash {baseDir}/scripts/polymarket.sh lb 5 vol

# 查看大户持仓
bash {baseDir}/scripts/polymarket.sh pos 0xc257ea7e3a81ca8e16df8935d44d513959fa358e

# 查看大户交易记录
bash {baseDir}/scripts/polymarket.sh trades 0xc257ea7e3a81ca8e16df8935d44d513959fa358e 5

# 历史价格（按天）
bash {baseDir}/scripts/polymarket.sh history fed-decision-in-march-885 2025-01-01 2025-01-31 1d

# 概率趋势（按4小时）
bash {baseDir}/scripts/polymarket.sh trend fed-decision-in-march-885 2025-01-01 2025-01-31 4h

# 交易量趋势并导出 CSV
bash {baseDir}/scripts/polymarket.sh volume-trend fed-decision-in-march-885 2025-01-01 2025-01-31 --format csv --out /tmp/volume.csv

# 买入预测（模拟测试）
DRY_RUN=1 bash {baseDir}/scripts/polymarket.sh buy will-meteora-be-accused-of-insider-trading Yes 0.30 10

# 真实买入（会提示确认）
bash {baseDir}/scripts/polymarket.sh buy will-meteora-be-accused-of-insider-trading Yes 0.30 10
```

## 别名

- `lb` = `leaderboard`
- `pos` = `positions`
- `bal` = `balance`

## 典型工作流

1. `leaderboard` 找到高盈利/高交易量大户
2. `positions <地址>` 查看大户当前押注了什么
3. `trades <地址>` 查看大户最近交易动向
4. `detail <slug>` 深入了解某个预测市场
5. `history/trend/volume-trend` 复盘价格与交易量变化
6. `buy/sell` 下单交易，`orders` 查看订单状态
7. `balance` 查看账户余额

## 缓存

历史类请求默认使用本地缓存（默认 TTL 60 秒）：

```bash
# 禁用缓存（单次）
NO_CACHE=1 bash {baseDir}/scripts/polymarket.sh history fed-decision-in-march-885 2025-01-01 2025-01-31

# 查看缓存统计
bash -c 'source {baseDir}/scripts/cache.sh && cache_stats'

# 清理缓存
bash -c 'source {baseDir}/scripts/cache.sh && cache_clear'
```
