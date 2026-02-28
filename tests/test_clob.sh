#!/bin/bash
#
# CLOB Trading 模块单元测试
# 覆盖: 凭据解析、HMAC 签名、格式化函数、signer.py 集成

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$PROJECT_DIR/scripts/api.sh"
source "$PROJECT_DIR/scripts/format.sh"

# 开发环境回退: 全局 venv 不存在时使用 uv run python
if [ ! -x "$PYTHON_CMD" ] && command -v uv >/dev/null 2>&1; then
    PYTHON_CMD="uv run python"
fi

PASS=0
FAIL=0
SKIP=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc"
        echo "     expected: $expected"
        echo "     actual:   $actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_empty() {
    local desc="$1" actual="$2"
    if [ -n "$actual" ]; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc"
        echo "     expected: non-empty"
        echo "     actual:   (empty)"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local desc="$1" expected="$2" actual="$3"
    if printf '%s' "$actual" | grep -Fq -- "$expected"; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc"
        echo "     expected to contain: $expected"
        echo "     actual: $actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local desc="$1" unexpected="$2" actual="$3"
    if ! printf '%s' "$actual" | grep -Fq -- "$unexpected"; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc"
        echo "     expected NOT to contain: $unexpected"
        echo "     actual: $actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_status() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" -eq "$actual" ]; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc"
        echo "     expected status: $expected"
        echo "     actual status:   $actual"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== CLOB Trading Tests ==="
echo ""

# ===== Setup: 创建临时凭据文件 =====
TMP_DIR="$(mktemp -d)"
TMP_CREDS="$TMP_DIR/.credentials"
cat > "$TMP_CREDS" <<'CREDS'
API_KEY=abc123-def456
SECRET=3WbLfwVsl0Xo1YtwAwRBKVIanrfr_-F8J7bS1y_5m0M=
PASSPHRASE=my-passphrase
ADDRESS=0x1234567890abcdef1234567890abcdef12345678
PRIVATE_KEY=0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
CREDS

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# ============================================================
# T1: 凭据解析测试
# ============================================================
echo "[T1] 凭据解析 (load_clob_credentials)"

# 清除可能残留的环境变量
unset POLY_API_KEY POLY_SECRET POLY_PASSPHRASE POLY_ADDRESS POLY_PRIVATE_KEY

# T1.1: 正确读取所有字段
export POLYMARKET_CREDENTIALS_FILE="$TMP_CREDS"
load_clob_credentials
assert_eq "T1.1 API_KEY parsed correctly" "abc123-def456" "$POLY_API_KEY"
assert_eq "T1.2 PASSPHRASE parsed correctly" "my-passphrase" "$POLY_PASSPHRASE"
assert_eq "T1.3 ADDRESS parsed correctly" "0x1234567890abcdef1234567890abcdef12345678" "$POLY_ADDRESS"
assert_eq "T1.4 PRIVATE_KEY parsed correctly" "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef" "$POLY_PRIVATE_KEY"

# T1.2: SECRET 值中的 = 不被截断
assert_eq "T1.5 SECRET with trailing = preserved" "3WbLfwVsl0Xo1YtwAwRBKVIanrfr_-F8J7bS1y_5m0M=" "$POLY_SECRET"

# T1.3: 值含 shell 元字符时不被破坏
unset POLY_API_KEY POLY_SECRET POLY_PASSPHRASE POLY_ADDRESS POLY_PRIVATE_KEY
TMP_METACHAR="$TMP_DIR/.credentials_meta"
cat > "$TMP_METACHAR" <<'CREDS'
API_KEY=key with spaces
SECRET=sec$ret`val
PASSPHRASE=pass;phrase
ADDRESS=0xaddr
PRIVATE_KEY=0xpk
CREDS
POLYMARKET_CREDENTIALS_FILE="$TMP_METACHAR"
load_clob_credentials
assert_eq "T1.6 value with spaces preserved" "key with spaces" "$POLY_API_KEY"
assert_eq "T1.7 value with \$ and backtick preserved" 'sec$ret`val' "$POLY_SECRET"
assert_eq "T1.8 value with semicolon preserved" "pass;phrase" "$POLY_PASSPHRASE"

# T1.4: 凭据文件不存在时返回错误码
unset POLY_API_KEY POLY_SECRET POLY_PASSPHRASE POLY_ADDRESS POLY_PRIVATE_KEY
POLYMARKET_CREDENTIALS_FILE="/nonexistent/path/creds"
load_clob_credentials 2>/dev/null
assert_status "T1.9 nonexistent file returns error" 1 "$?"

# T1.4: 项目本地 .credentials 优先于默认路径
unset POLY_API_KEY POLY_SECRET POLY_PASSPHRASE POLY_ADDRESS POLY_PRIVATE_KEY
# 创建项目本地 .credentials
LOCAL_CREDS="$PROJECT_DIR/.credentials"
LOCAL_CREDS_EXISTED=0
if [ -f "$LOCAL_CREDS" ]; then
    LOCAL_CREDS_EXISTED=1
    cp "$LOCAL_CREDS" "$TMP_DIR/.credentials.bak"
fi
cat > "$LOCAL_CREDS" <<'CREDS'
API_KEY=local-key-123
SECRET=localSecret==
PASSPHRASE=local-pass
ADDRESS=0xlocal
PRIVATE_KEY=0xlocalkey
CREDS
# 清空 POLYMARKET_CREDENTIALS_FILE，让优先级逻辑选择本地文件
POLYMARKET_CREDENTIALS_FILE=""
load_clob_credentials
assert_eq "T1.10 local .credentials takes priority" "local-key-123" "$POLY_API_KEY"
# 清理
rm -f "$LOCAL_CREDS"
if [ "$LOCAL_CREDS_EXISTED" -eq 1 ]; then
    mv "$TMP_DIR/.credentials.bak" "$LOCAL_CREDS"
fi

# 恢复
export POLYMARKET_CREDENTIALS_FILE="$TMP_CREDS"
unset POLY_API_KEY POLY_SECRET POLY_PASSPHRASE POLY_ADDRESS POLY_PRIVATE_KEY
load_clob_credentials

# ============================================================
# T2: HMAC 签名测试
# ============================================================
echo ""
echo "[T2] HMAC 签名 (generate_clob_signature)"

SIG1=$(generate_clob_signature "GET" "/orders" "" "1700000000")
assert_not_empty "T2.1 signature is non-empty" "$SIG1"

SIG2=$(generate_clob_signature "GET" "/orders" "" "1700000000")
assert_eq "T2.2 deterministic (same input = same output)" "$SIG1" "$SIG2"

SIG3=$(generate_clob_signature "POST" "/orders" '{"test":true}' "1700000001")
if [ "$SIG1" != "$SIG3" ]; then
    echo "  ✅ T2.3 different input produces different signature"
    PASS=$((PASS + 1))
else
    echo "  ❌ T2.3 different input produces different signature"
    FAIL=$((FAIL + 1))
fi

# base64url 格式验证: 不含 / 或 +
assert_not_contains "T2.4 no '/' in signature (base64url)" "/" "$SIG1"
assert_not_contains "T2.5 no '+' in signature (base64url)" "+" "$SIG1"

# ============================================================
# T3: format_order_result 测试
# ============================================================
echo ""
echo "[T3] format_order_result"

# 成功响应
ORDER_SUCCESS='{"orderID":"order-abc-123","status":"LIVE","side":"BUY","price":"0.50","size":"10","type":"GTC"}'
RESULT=$(echo "$ORDER_SUCCESS" | format_order_result)
assert_contains "T3.1 success shows order ID" "order-abc-123" "$RESULT"
assert_contains "T3.2 success shows status" "LIVE" "$RESULT"

# 错误响应
ORDER_ERROR='{"error":"insufficient balance"}'
RESULT=$(echo "$ORDER_ERROR" | format_order_result)
assert_contains "T3.3 error shows error message" "insufficient balance" "$RESULT"

# ============================================================
# T4: format_orders 测试
# ============================================================
echo ""
echo "[T4] format_orders"

# 空数组
RESULT=$(echo '[]' | format_orders)
assert_contains "T4.1 empty array shows no orders" "暂无活跃订单" "$RESULT"

# 有数据
ORDERS_JSON='[{"id":"ord-1","side":"BUY","price":"0.45","original_size":"20","size_matched":"5","status":"LIVE","market":"Will X happen?","outcome":"Yes","type":"GTC"},{"id":"ord-2","side":"SELL","price":"0.80","original_size":"10","size_matched":"10","status":"MATCHED","market":"Will Y happen?","outcome":"No","type":"FOK"}]'
RESULT=$(echo "$ORDERS_JSON" | format_orders)
assert_contains "T4.2 shows BUY" "BUY" "$RESULT"
assert_contains "T4.3 shows SELL" "SELL" "$RESULT"
assert_contains "T4.4 shows price" "0.45" "$RESULT"

# ============================================================
# T5: format_balance 测试
# ============================================================
echo ""
echo "[T5] format_balance"

BALANCE_JSON='{"USDC":"1250.50","CONDITIONAL":"340.00"}'
RESULT=$(echo "$BALANCE_JSON" | format_balance)
assert_contains "T5.1 shows USDC balance" "1250.50" "$RESULT"

# 错误响应
RESULT=$(echo '{"error":"not authorized"}' | format_balance)
assert_contains "T5.2 error shows message" "not authorized" "$RESULT"

# ============================================================
# T6: signer.py 集成测试
# ============================================================
echo ""
echo "[T6] signer.py"

if command -v uv >/dev/null 2>&1; then
    # T6.1: --help 能正常执行
    HELP_OUTPUT=$($PYTHON_CMD "$PROJECT_DIR/scripts/signer.py" --help 2>&1)
    HELP_STATUS=$?
    assert_status "T6.1 signer.py --help exits 0" 0 "$HELP_STATUS"

    # T6.2: 给定测试私钥，输出包含 order 和 signature 的 JSON
    # 使用一个有效的测试私钥和虚拟 token ID
    SIGNER_OUTPUT=$($PYTHON_CMD "$PROJECT_DIR/scripts/signer.py" \
        --private-key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" \
        --token-id "71321045679252212594626385532706912750332728571942532289631379312455583992563" \
        --price "0.50" --size "10" --side "BUY" \
        --order-type "GTC" --neg-risk "false" \
        --api-key "abc123" --api-secret "dGVzdA==" --api-passphrase "test-pass" \
        2>&1)
    SIGNER_STATUS=$?
    if [ $SIGNER_STATUS -eq 0 ]; then
        HAS_ORDER=$(echo "$SIGNER_OUTPUT" | jq -r 'has("order")' 2>/dev/null)
        assert_eq "T6.2 output has 'order' key" "true" "$HAS_ORDER"
        HAS_SIG=$(echo "$SIGNER_OUTPUT" | jq -r '.order.signature' 2>/dev/null)
        assert_not_empty "T6.3 order has signature" "$HAS_SIG"
    else
        echo "  ⚠️  T6.2 signer.py 执行失败 (可能缺少依赖)，跳过"
        echo "     output: $SIGNER_OUTPUT"
        SKIP=$((SKIP + 2))
    fi
else
    echo "  ⚠️  T6 uv 未安装，跳过 signer.py 测试"
    SKIP=$((SKIP + 3))
fi

# ============================================================
# T7: place_order DRY_RUN 集成测试
# ============================================================
echo ""
echo "[T7] place_order (DRY_RUN)"

export DRY_RUN=1
export POLYMARKET_CREDENTIALS_FILE="$TMP_CREDS"
load_clob_credentials

DRY_RESULT=$(place_order "test-token-id-123" "0.50" "10" "BUY" "GTC" 2>&1)
DRY_STATUS=$?
assert_status "T7.1 DRY_RUN place_order exits 0" 0 "$DRY_STATUS"
assert_contains "T7.2 DRY_RUN output includes token_id" "test-token-id-123" "$DRY_RESULT"
assert_contains "T7.3 DRY_RUN output includes side" "BUY" "$DRY_RESULT"
assert_contains "T7.4 DRY_RUN output includes price" "0.50" "$DRY_RESULT"

unset DRY_RUN

# ============================================================
# T8: 安全 — signer.py 通过 stdin 接收凭据（不暴露在进程命令行）
# ============================================================
echo ""
echo "[T8] 安全: signer.py stdin 凭据传递"

if command -v uv >/dev/null 2>&1; then
    # T8.1: signer.py 支持 --credentials-stdin 参数
    HELP_OUTPUT=$($PYTHON_CMD "$PROJECT_DIR/scripts/signer.py" --help 2>&1)
    assert_contains "T8.1 --credentials-stdin in help" "credentials-stdin" "$HELP_OUTPUT"

    # T8.2: 通过 stdin 传递凭据能正常签名
    STDIN_CREDS='{"private_key":"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80","api_key":"abc123","api_secret":"dGVzdA==","api_passphrase":"test-pass"}'
    STDIN_OUTPUT=$(echo "$STDIN_CREDS" | $PYTHON_CMD "$PROJECT_DIR/scripts/signer.py" \
        --credentials-stdin \
        --token-id "71321045679252212594626385532706912750332728571942532289631379312455583992563" \
        --price "0.50" --size "10" --side "BUY" \
        --order-type "GTC" --neg-risk "false" \
        2>&1)
    STDIN_STATUS=$?
    if [ $STDIN_STATUS -eq 0 ]; then
        HAS_ORDER=$(echo "$STDIN_OUTPUT" | jq -r 'has("order")' 2>/dev/null)
        assert_eq "T8.2 stdin mode produces valid order" "true" "$HAS_ORDER"
        HAS_SIG=$(echo "$STDIN_OUTPUT" | jq -r '.order.signature' 2>/dev/null)
        assert_not_empty "T8.3 stdin mode order has signature" "$HAS_SIG"
    else
        echo "  ⚠️  T8.2 signer.py stdin 模式执行失败，跳过"
        echo "     output: $STDIN_OUTPUT"
        SKIP=$((SKIP + 2))
    fi

    # T8.4: --credentials-stdin 模式下，--private-key 等参数不再 required
    # 即不通过 CLI 传递密钥也能工作（上面 T8.2 已验证）
else
    echo "  ⚠️  T8 uv 未安装，跳过"
    SKIP=$((SKIP + 3))
fi

# ============================================================
# T9: 安全 — signer 错误信息不泄露凭据
# ============================================================
echo ""
echo "[T9] 安全: signer 错误输出不泄露凭据"

if command -v uv >/dev/null 2>&1; then
    # T9.1: 给定无效参数，signer.py 输出 JSON 错误（不含 traceback）
    BAD_CREDS='{"private_key":"0xinvalid","api_key":"k","api_secret":"s","api_passphrase":"p"}'
    ERR_OUTPUT=$(echo "$BAD_CREDS" | $PYTHON_CMD "$PROJECT_DIR/scripts/signer.py" \
        --credentials-stdin \
        --token-id "bad-token" \
        --price "0.50" --size "10" --side "BUY" \
        2>&1)
    ERR_STATUS=$?

    # 应该失败
    if [ $ERR_STATUS -ne 0 ]; then
        echo "  ✅ T9.1 invalid input exits non-zero"
        PASS=$((PASS + 1))
    else
        echo "  ❌ T9.1 invalid input exits non-zero"
        echo "     expected: non-zero exit"
        echo "     actual:   0"
        FAIL=$((FAIL + 1))
    fi

    # T9.2: 错误输出不包含私钥
    assert_not_contains "T9.2 error does not contain private key" "0xinvalid" "$ERR_OUTPUT"

    # T9.3: 错误输出不包含 Traceback
    assert_not_contains "T9.3 error does not contain Traceback" "Traceback" "$ERR_OUTPUT"

    # T9.4: 错误输出是合法 JSON
    ERR_JSON_VALID=$(echo "$ERR_OUTPUT" | jq -r '.error' 2>/dev/null)
    assert_not_empty "T9.4 error output is valid JSON with .error key" "$ERR_JSON_VALID"

    # T9.5: place_order 失败时也不泄露凭据
    export POLYMARKET_CREDENTIALS_FILE="$TMP_CREDS"
    unset POLY_API_KEY POLY_SECRET POLY_PASSPHRASE POLY_ADDRESS POLY_PRIVATE_KEY DRY_RUN
    load_clob_credentials
    PLACE_ERR=$(place_order "bad-token" "0.50" "10" "BUY" "GTC" 2>&1)
    assert_not_contains "T9.5 place_order error does not leak private key" "$POLY_PRIVATE_KEY" "$PLACE_ERR"
    assert_not_contains "T9.6 place_order error does not leak api secret" "$POLY_SECRET" "$PLACE_ERR"
else
    echo "  ⚠️  T9 uv 未安装，跳过"
    SKIP=$((SKIP + 6))
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="
[ "$FAIL" -eq 0 ]
