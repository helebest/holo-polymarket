---
name: holo-polymarket
description: 用于查询与分析 Polymarket 预测市场的 Bash 技能（热门事件、搜索、事件详情、大户排行榜/持仓/交易、历史价格与趋势导出）。当用户需要市场研究、交易行为跟踪、时间序列复盘时使用本技能；当用户需要实际下单、撤单、余额与订单管理时，改用官方 polymarket CLI。
---

# Holo Polymarket

## 快速入口

1. 先确认环境：`curl`、`jq`、可访问 `gamma-api.polymarket.com` / `data-api.polymarket.com`。
2. 先选任务类型：市场信息 / 大户追踪 / 历史趋势。
3. 再执行对应命令：`{baseDir}/scripts/polymarket.sh <command>`。
4. 需要交易动作（下单/撤单/余额）时，不走本技能脚本，直接使用官方 `polymarket` CLI。

详细命令清单见 [references/commands.md](references/commands.md)。

## 命令选择决策

- 想快速看热度：`hot`。
- 已有关键词想找市场：`search <关键词>`。
- 已有事件 slug 想看细节和 token：`detail <event-slug>`。
- 想跟踪交易高手：`leaderboard` → `positions` → `trades`。
- 想做时间序列复盘：
  - 概率明细表：`history`
  - 起止变化摘要：`trend`
  - 交易量变化：`volume-trend`
- 需要文件导出：给 `history/trend/volume-trend` 增加 `--format csv|json` 与可选 `--out`。

## 常见失败处理

- 依赖缺失：安装 `curl` / `jq`。
- 网络失败：检查 API 可达性与超时，必要时增大 `CURL_TIMEOUT`。
- 历史价格失败：检查 `POLYMARKET_BEARER_TOKEN` 或 credentials 文件。
- 参数错误：优先对照命令用法与日期格式（`YYYY-MM-DD`）。

完整排障流程见 [references/troubleshooting.md](references/troubleshooting.md)。

## 最小示例

```bash
# 1) 热门市场
bash {baseDir}/scripts/polymarket.sh hot 5

# 2) 搜索 + 详情
bash {baseDir}/scripts/polymarket.sh search bitcoin 5
bash {baseDir}/scripts/polymarket.sh detail fed-decision-in-march-885

# 3) 大户追踪
bash {baseDir}/scripts/polymarket.sh lb 10 pnl week
bash {baseDir}/scripts/polymarket.sh pos 0xc257ea7e3a81ca8e16df8935d44d513959fa358e 10
bash {baseDir}/scripts/polymarket.sh trades 0xc257ea7e3a81ca8e16df8935d44d513959fa358e 10

# 4) 历史趋势 + 导出
bash {baseDir}/scripts/polymarket.sh history fed-decision-in-march-885 2025-01-01 2025-01-31 1d
bash {baseDir}/scripts/polymarket.sh trend fed-decision-in-march-885 2025-01-01 2025-01-31 --format csv
bash {baseDir}/scripts/polymarket.sh volume-trend fed-decision-in-march-885 2025-01-01 2025-01-31 --format json --out /tmp/volume.json
```

## 交易边界

以下动作一律使用官方 CLI：
- `polymarket clob balance`
- `polymarket clob market-order`
- `polymarket clob create-order`
- `polymarket clob orders`
- `polymarket clob cancel` / `cancel-all`
