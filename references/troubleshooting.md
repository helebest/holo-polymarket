# 排障指南

## 目录

1. 快速诊断顺序
2. 依赖与环境
3. 网络与 API 错误
4. 历史数据/趋势常见问题
5. 导出与文件问题

## 1. 快速诊断顺序

1. 先运行基础命令确认入口可用：
   - `bash {baseDir}/scripts/polymarket.sh hot 1`
2. 再跑目标命令最小参数版本。
3. 出错时先看是否是参数格式错误，再看网络和凭据。

## 2. 依赖与环境

### 症状
- 提示缺少 `curl` 或 `jq`。

### 处理
- 安装缺失依赖后重试。
- 在 CI/容器环境中确认依赖已预装。

## 3. 网络与 API 错误

### 症状
- 输出类似“请求失败: ... (curl=...)”。

### 处理
- 检查是否可访问：
  - `https://gamma-api.polymarket.com`
  - `https://data-api.polymarket.com`
  - `https://clob.polymarket.com`
- 调大超时：`CURL_TIMEOUT=30`。
- 临时重试失败时，稍后重跑。

## 4. 历史数据/趋势常见问题

### 症状 A
- `history/trend` 提示无数据或失败。

### 处理
- 确认事件 slug 正确。
- 确认日期格式为 `YYYY-MM-DD` 且 `from <= to`。
- 确认 `interval` 在 `1h|4h|1d`。
- 若提示 token 问题，设置：
  - 环境变量 `POLYMARKET_BEARER_TOKEN`
  - 或 credentials 文件 `~/.openclaw/credentials/polymarket_credentials`

### 症状 B
- `volume-trend` 返回接口异常。

### 处理
- 说明 Data API 未返回数组结构，稍后重试。
- 开启 `NO_CACHE=1` 重试，避免读取旧缓存。

## 5. 导出与文件问题

### 症状
- `--out` 路径失败。

### 处理
- 确保输出目录存在。
- 只在 `--format csv|json` 时使用 `--out`。
- 先不指定 `--out`，让脚本自动命名验证流程是否可通。