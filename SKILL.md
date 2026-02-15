---
name: polymarket
description: Polymarket 预测市场查询。查看热门预测、搜索市场、获取事件详情和概率。
homepage: https://github.com/helebest/holo-polymarket
---

# Polymarket

查询 Polymarket 预测市场数据，包括热门事件、搜索和详情。

## 前置条件

1. `jq` 和 `curl` 已安装
2. 网络访问：能够访问 `gamma-api.polymarket.com`

## 使用方法

### 查看热门预测

```bash
bash {baseDir}/scripts/polymarket.sh hot [limit]
```

### 搜索预测市场

```bash
bash {baseDir}/scripts/polymarket.sh search <关键词> [limit]
```

### 查看事件详情

```bash
bash {baseDir}/scripts/polymarket.sh detail <event-slug>
```

## 示例

```bash
# 查看 Top 5 热门预测
bash {baseDir}/scripts/polymarket.sh hot 5

# 搜索比特币相关
bash {baseDir}/scripts/polymarket.sh search bitcoin

# 查看美联储利率决议详情
bash {baseDir}/scripts/polymarket.sh detail fed-decision-in-march-885
```

## 输出格式

- 事件标题
- 各选项概率
- 24h 交易量
- 总交易量
- 链接
