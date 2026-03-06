# Holo Polymarket

Polymarket 预测市场 Bash 工具：查询市场、追踪大户、分析历史趋势，并支持 CSV/JSON 导出。

## 功能

- `hot`：热门市场（按 24h 交易量）
- `search`：关键词搜索市场
- `detail`：事件详情与 `Token[Yes]/Token[No]`
- `leaderboard` / `lb`：大户榜（盈利/交易量，支持日/周/月/全量）
- `positions` / `pos`：地址持仓与盈亏
- `trades`：地址交易记录
- `history`：历史概率表
- `trend`：起始/结束/变化摘要
- `volume-trend`：交易量趋势表

## 前置条件

- `bash`
- `curl`
- `jq`
- 可访问：
  - `gamma-api.polymarket.com`
  - `data-api.polymarket.com`
  - `clob.polymarket.com`

历史价格接口需要 Bearer Token：
- `POLYMARKET_BEARER_TOKEN`
- 或 `~/.openclaw/credentials/polymarket_credentials`

## 使用方法

```bash
# 市场查询
bash scripts/polymarket.sh hot 5
bash scripts/polymarket.sh search bitcoin 5
bash scripts/polymarket.sh detail fed-decision-in-march-885

# 大户追踪
bash scripts/polymarket.sh lb 10 pnl week
bash scripts/polymarket.sh pos 0xc257ea7e3a81ca8e16df8935d44d513959fa358e 10
bash scripts/polymarket.sh trades 0xc257ea7e3a81ca8e16df8935d44d513959fa358e 10

# 历史趋势
bash scripts/polymarket.sh history fed-decision-in-march-885 2025-01-01 2025-01-31 1d
bash scripts/polymarket.sh trend fed-decision-in-march-885 2025-01-01 2025-01-31 4h
bash scripts/polymarket.sh volume-trend fed-decision-in-march-885 2025-01-01 2025-01-31 1d

# 导出
bash scripts/polymarket.sh history fed-decision-in-march-885 2025-01-01 2025-01-31 --format csv
bash scripts/polymarket.sh trend fed-decision-in-march-885 2025-01-01 2025-01-31 --format json --out /tmp/trend.json
```

时间参数：
- `from/to`：`YYYY-MM-DD`
- `interval`：`1h` / `4h` / `1d`

## 缓存

```bash
# 单次禁用缓存
NO_CACHE=1 bash scripts/polymarket.sh history fed-decision-in-march-885 2025-01-01 2025-01-31

# 缓存统计
bash -c 'source scripts/cache.sh && cache_stats'

# 清空缓存
bash -c 'source scripts/cache.sh && cache_clear'
```

可选环境变量：
- `NO_CACHE=1`
- `CACHE_TTL=<seconds>`
- `CURL_TIMEOUT=<seconds>`
- `CURL_RETRY=<count>`
- `GAMMA_API_BASE` / `DATA_API_BASE` / `CLOB_API_BASE`

## 测试

```bash
# 默认运行离线测试（不依赖外网）
bash tests/run_tests.sh

# 追加在线集成测试
RUN_LIVE_TESTS=1 bash tests/run_tests.sh

# 单独运行
bash tests/test_api_unit.sh
bash tests/test_series_args.sh
bash tests/test_api.sh          # 需要网络
bash tests/test_data_api.sh     # 需要网络
bash tests/test_e2e_hot_detail.sh # 需要网络
```

## 静态检查

```bash
bash scripts/lint.sh
```

## 作为 OpenClaw Skill 部署

```bash
bash openclaw_deploy_skill.sh ~/.openclaw/skills/polymarket
```

部署内容包括：`SKILL.md`、`scripts/`、`references/`。

## 架构

- `scripts/common.sh`：公共工具（依赖检查、URL 编码、日期转换、统一错误输出）
- `scripts/api.sh`：API 调用与历史序列获取
- `scripts/format.sh`：终端输出格式化
- `scripts/export.sh`：CSV/JSON 导出
- `scripts/cache.sh`：本地缓存
- `scripts/commands_market.sh`：`hot/search/detail`
- `scripts/commands_whale.sh`：`leaderboard/positions/trades`
- `scripts/commands_series.sh`：`history/trend/volume-trend`
- `scripts/polymarket.sh`：CLI 入口与路由

## 交易功能

下单/撤单/余额管理请使用官方 [Polymarket CLI](https://github.com/Polymarket/polymarket-cli)。

## License

MIT