---
name: holo-polymarket
description: Polymarket 预测市场工具。查询热门预测、搜索市场、分析概率趋势、追踪大户持仓。
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
```

## 别名

- `lb` = `leaderboard`
- `pos` = `positions`

## 典型工作流

1. `leaderboard` 找到高盈利/高交易量大户
2. `positions <地址>` 查看大户当前押注了什么
3. `trades <地址>` 查看大户最近交易动向
4. `detail <slug>` 深入了解某个预测市场
