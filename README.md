# Holo Polymarket

Polymarket 预测市场工具 — 查询、分析、追踪大户，一站式接入全球最大预测市场。

## 功能

### 已实现
- **hot** — 查看当前热门预测市场（按24h交易量排序）
- **search** — 按关键词搜索预测市场
- **detail** — 查看特定事件的详细概率数据
- **leaderboard** — 排行榜（按盈利或交易量排名）
- **positions** — 查看任意用户的当前持仓与盈亏
- **trades** — 查看任意用户的交易记录

### 规划中
- 历史数据查询与概率趋势分析
- 交易下单（市价单/限价单）
- 持仓管理与盈亏追踪

## 前置条件

- `jq` 已安装
- `curl` 已安装
- 网络访问：能够访问 `gamma-api.polymarket.com`

## 使用方法

```bash
# 查看热门预测（默认5条）
bash scripts/polymarket.sh hot [limit]

# 搜索预测市场
bash scripts/polymarket.sh search <关键词> [limit]

# 查看事件详情
bash scripts/polymarket.sh detail <event-slug>

# 排行榜（按盈利或交易量）
bash scripts/polymarket.sh leaderboard [limit] [pnl|vol]

# 查看用户持仓
bash scripts/polymarket.sh positions <钱包地址> [limit]

# 查看用户交易记录
bash scripts/polymarket.sh trades <钱包地址> [limit]

# 历史价格（默认 interval=1d）
bash scripts/polymarket.sh history <event-slug> <from> <to> [interval]

# 概率趋势（汇总起始/结束/变化）
bash scripts/polymarket.sh trend <event-slug> <from> <to> [interval]

# 交易量趋势
bash scripts/polymarket.sh volume-trend <event-slug> <from> <to> [interval]
```

## Phase 2b：历史数据与趋势分析

### 新增命令

```bash
# 历史价格表格
bash scripts/polymarket.sh history fed-decision-in-march-885 2025-01-01 2025-01-31 1d

# 概率趋势汇总（支持 1h / 4h / 1d）
bash scripts/polymarket.sh trend fed-decision-in-march-885 2025-01-01 2025-01-31 4h

# 交易量趋势表格
bash scripts/polymarket.sh volume-trend fed-decision-in-march-885 2025-01-01 2025-01-31 1d
```

### 时间范围参数

- `from`: 开始日期，格式 `YYYY-MM-DD`
- `to`: 结束日期，格式 `YYYY-MM-DD`
- `interval`: 采样间隔，仅支持 `1h` / `4h` / `1d`，默认 `1d`
- 在 CLI 中对应位置参数：`<from> <to> [interval]`（语义等同于 `--from` / `--to` / `--interval`）

### 导出功能

支持在 `history` / `trend` / `volume-trend` 中导出结果：

```bash
# 导出 CSV（自动文件名）
bash scripts/polymarket.sh history fed-decision-in-march-885 2025-01-01 2025-01-31 --format csv

# 导出 JSON（指定输出路径）
bash scripts/polymarket.sh trend fed-decision-in-march-885 2025-01-01 2025-01-31 1d --format json --out /tmp/trend.json
```

- `--format`: `csv` 或 `json`
- `--out`: 输出文件路径（仅可与 `--format` 一起使用）

### 缓存功能

历史序列请求默认启用本地缓存（默认 TTL 为 60 秒）。

```bash
# 关闭缓存（本次命令）
NO_CACHE=1 bash scripts/polymarket.sh history fed-decision-in-march-885 2025-01-01 2025-01-31

# 查看缓存统计
bash -c 'source scripts/cache.sh && cache_stats'

# 清空缓存
bash -c 'source scripts/cache.sh && cache_clear'
```

可选环境变量：
- `NO_CACHE=1`：禁用读写缓存
- `CACHE_TTL=<秒>`：自定义缓存过期时间
- `CACHE_DIR=<目录>`：自定义缓存目录（默认 `~/.cache/holo-polymarket`）

## API

基于两个公开免费 API（均无需认证）：

- **Gamma API**: `https://gamma-api.polymarket.com` — 市场数据、事件查询
- **Data API**: `https://data-api.polymarket.com` — 排行榜、用户持仓、交易记录
- 文档: https://docs.polymarket.com/developers/gamma-markets-api/overview

## 作为 OpenClaw 技能使用

```bash
# 部署到 OpenClaw 技能目录
bash openclaw_deploy_skill.sh ~/.openclaw/skills/polymarket
```

## 开发

```bash
# 运行测试
bash tests/run_tests.sh
```

## 迭代计划

### ✅ Phase 1 — 市场数据查询

基于 Gamma API（免费、无需认证）

- [x] 热门事件查询（按24h交易量排序）
- [x] 关键词搜索预测市场
- [x] 事件详情与概率查看
- [x] 格式化输出（人类可读）
- [x] TDD 测试覆盖
- [x] OpenClaw 技能部署脚本

### ✅ Phase 2a — 大户追踪

基于 Data API（免费、无需认证）

- [x] 排行榜查询（按盈利/交易量排名）
- [x] 用户持仓查询（任意钱包地址）
- [x] 用户交易记录查询
- [x] 格式化输出（盈亏、百分比、时间）
- [x] TDD 测试覆盖（32 + 19 = 51 项新测试）

### 🔜 Phase 2b — 历史数据与分析

基于 Data API

- [x] 历史价格查询（按时间段）
- [x] 概率趋势变化（日/周/月）
- [x] 交易量趋势分析
- [x] 数据导出（CSV/JSON）
- [x] 本地缓存（减少 API 调用）

### 🔮 Phase 3 — 交易下单

基于 CLOB Trading API（需要钱包认证）

- [ ] 钱包接入与 API Key 派生
- [ ] 查看账户持仓与余额
- [ ] 市价单 / 限价单下单
- [ ] 订单状态查询与取消
- [ ] 持仓盈亏追踪
- [ ] 风控：确认提示、金额上限

### 💡 未来可能

- [ ] 市场创建提醒（新热门事件通知）
- [ ] 自定义关注列表
- [ ] 概率异常波动预警
- [ ] 与 RSS 技能联动（新闻 + 预测概率对比）

## License

MIT
