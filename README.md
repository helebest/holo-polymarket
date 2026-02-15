# Holo Polymarket

Polymarket 预测市场查询工具，支持热门事件、搜索和详情查看。

## 功能

- **hot** — 查看当前热门预测市场（按24h交易量排序）
- **search** — 按关键词搜索预测市场
- **detail** — 查看特定事件的详细概率数据

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
```

## API

基于 Polymarket Gamma API（免费、无需认证）：
- Base URL: `https://gamma-api.polymarket.com`
- 文档: https://docs.polymarket.com/developers/gamma-markets-api/overview

## 作为 OpenClaw 技能使用

将 `SKILL.md` 和 `scripts/` 目录复制到 `~/.openclaw/skills/polymarket/` 即可。

## 开发

```bash
# 运行测试
bash tests/run_tests.sh
```

## License

MIT
