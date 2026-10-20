#!/bin/bash
# skill-up custom engine wrapper — invokes a Claude Code-compatible CLI in
# non-interactive mode and works around two known failure classes.
#
# 用法（由 eval.yaml engine.custom.local 驱动）：
#   run-claude.sh <input_file>
# 输入：SessionInput JSON（messages 为完整对话历史）
# 输出：最终回复文本输出到 stdout（response_format: text）
#
# ─── CLI 通道选择 ──────────────────────────────────────────────────────────
# 默认: claude —— Claude Code CLI，需先交互式完成 OAuth 登录（claude /login）。
# 覆盖: SKILLUP_CLAUDE_CMD 环境变量，如 SKILLUP_CLAUDE_CMD="claude"。
#       任何与 Claude Code 参数兼容的 CLI 均可作为通道。
#
# ─── 已规避的问题 ──────────────────────────────────────────────────────────
# 1) --session-id 400：内置 claude_code 引擎固定传 --session-id，部分 API 网关
#    对该参数间歇性返回 400；本 wrapper 不带该参数，并对「API Error: 400」做
#    多次退避重试。
# 2) 认证失效伪装成 FAIL：认证失效时 CLI 可能以 exit 0 返回合成消息
#    "Not logged in · Please run /login"（stream-json 中
#    error=authentication_failed），若不拦截会被 judge 当作模型回复判成 case
#    FAIL，把环境故障伪装成能力缺陷，污染 pass_rate。防护：
#    - 启动预检：跑 case 前轻量探测（结果缓存 5 分钟），失效 fail-fast
#    - 中途拦截：每次运行后检测认证失败签名，命中即非零退出 → skill-up 记
#      ERROR（环境故障，不进 pass_rate）而非 FAIL（能力缺陷）
#
# 输出聚合：--output-format stream-json 捕获**全部** assistant 文本消息并按序
# 拼接（jq select(.type=="assistant") 只提取 assistant 行，CLI 的版本检查噪音
# 等非 JSON 输出自动被过滤）。
#
# 修复指引（认证/通道故障，环境层 layer=env）：
#   - claude 通道: 交互式执行 claude /login
#   - 登录/修复前如需记录评分，维度 8 按 skill-eval-optimizer 的 skill-up 参考
#     文档降级 dry_run，note 记 blocked_by=claude_auth_expired
#
# 限制：单轮用例（当前加载 case 均为单轮）；多轮 turns 用例会把历史拼接为单轮。
set -uo pipefail

IN="$1"
[[ "$IN" != /* ]] && IN="$PWD/$IN"   # 相对路径基于 workspace（skill-up 以 cwd=${workspace} 执行）

PROMPT=$(jq -r '
  .messages
  | map(select(.role == "user"))
  | map(.content | if type == "array" then (map(.text // "") | join("")) else . end)
  | join("\n\n")
' "$IN")

# CLI 通道（默认 claude；SKILLUP_CLAUDE_CMD 可覆盖）
read -r -a CLI <<< "${SKILLUP_CLAUDE_CMD:-claude}"

# 评测纯净模式：默认 --strict-mcp-config + 空 mcpServers，不加载用户全局 MCP/
# 插件服务（实测禁用后单次调用显著加快；全局 MCP pending 会拖慢甚至撑爆 case
# 超时，且引入与被测 skill 无关的变量）。被测 skill 只依赖 Read/Bash 等内建
# 工具；若某评测确实要 MCP，设 SKILLUP_KEEP_MCP=1 跳过禁用
MCP_FLAGS=(--strict-mcp-config --mcp-config '{"mcpServers":{}}')
if [[ "${SKILLUP_KEEP_MCP:-0}" == "1" ]]; then
  MCP_FLAGS=()
fi

run_once() {
  "${CLI[@]}" --settings '{"disableAllHooks":true}' ${MCP_FLAGS[@]+"${MCP_FLAGS[@]}"} \
    -p --permission-mode=bypassPermissions \
    --output-format stream-json --verbose "$PROMPT" 2>&1
}

# 拼接全部 assistant 文本块；无 assistant 文本时输出为空。
# 用 -R fromjson? 逐行安全解析：CLI 首行可能输出版本检查噪音（非 JSON），
# 普通 jq 遇到会 parse error 立即退出并丢弃后续合法行（曾致 case 整批伪
# FAIL/ERROR）；fromjson? 对非法行返回 empty 静默跳过
extract() {
  jq -R -r 'fromjson? | select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' 2>/dev/null
}

# ─── 认证/通道失效检测 ──────────────────────────────────────────────────────
# 签名（按可靠性排序）：
#   1. stream-json 事件里的 "error":"authentication_failed"
#   2. 合成回复同时含 "Not logged in" 与 "Please run /login"
# （单看自然语言签名可能与 prompt/回复内容误撞，故要求双签名或 JSON 级签名）
is_auth_failure() {
  local raw="$1"
  if printf '%s' "$raw" | grep -q '"error":"authentication_failed"'; then
    return 0
  fi
  if printf '%s' "$raw" | grep -q 'Not logged in' && printf '%s' "$raw" | grep -q 'Please run /login'; then
    return 0
  fi
  return 1
}

auth_fail_msg() {
  cat >&2 <<MSG
错误: 评测 CLI 通道认证失效（Not logged in / authentication_failed / 通道不可用）。
当前通道: ${CLI[*]}（可用 SKILLUP_CLAUDE_CMD 覆盖）
这是环境层(layer=env)故障，不是被测 skill 的能力缺陷：
  - claude 通道: 交互终端执行 claude /login
  修复后重跑: skill-up run <eval.yaml>
  修复前如需记录评分，维度 8 降级 dry_run，note 记 blocked_by=claude_auth_expired
MSG
}

# ─── 启动预检（结果缓存 5 分钟）─────────────────────────────────────────────
# 预检价值：通道已失效时 fail-fast，避免烧完 N 个 case 才发现全是伪 FAIL；
# 缓存价值：一次评测通常跑多个 case（每次都调本 wrapper），并行评测也会并发调用，
# 5 分钟缓存把探测开销收敛到每个评测批次约 1 次。
# 时效判断：把探测时间戳写进缓存文件**内容**（不用 stat 查 mtime——macOS BSD
# stat 与 GNU stat 的 -f 语义冲突，非数字输出进入算术展开会被当变量名解引用，
# set -u 下报 "unbound variable" 致预检崩溃，case 批量空输出伪 FAIL）
# 注意：预检通过不代表中途不会失效（认证可能中途过期），中途拦截兜底。
AUTH_CACHE="${TMPDIR:-/tmp}/skill-up-claude-auth.$UID"

auth_probe() {
  local now cached
  now=$(date +%s)
  if [[ -f "$AUTH_CACHE" ]]; then
    cached=$(cat "$AUTH_CACHE" 2>/dev/null)
    if [[ "$cached" =~ ^[0-9]+$ ]] && (( now - cached < 300 )); then
      return 0
    fi
  fi
  # 通道一：CLI 本身不存在 → 直接失败
  if ! command -v "${CLI[0]}" >/dev/null; then
    echo "错误: 未找到 CLI '${CLI[0]}'（请先安装 Claude Code，或用 SKILLUP_CLAUDE_CMD 指定兼容 CLI）" >&2
    exit 1
  fi
  # 通道二：轻量真实探测（认证签名检测；同纯净模式参数，保证探测与真实调用环境一致）
  local probe_out
  probe_out="$("${CLI[@]}" --settings '{"disableAllHooks":true}' ${MCP_FLAGS[@]+"${MCP_FLAGS[@]}"} -p --permission-mode=bypassPermissions 'ping' 2>&1)"
  if is_auth_failure "$probe_out"; then
    auth_fail_msg
    exit 1
  fi
  # 探测通过：刷新缓存（时间戳写入文件内容；探测输出非认证失败即视为可继续，
  # 空输出等异常由后续真实调用兜底）
  echo "$now" > "$AUTH_CACHE" 2>/dev/null
}

auth_probe

# ─── 主循环 ────────────────────────────────────────────────────────────────
# 重试两类瞬时故障（各多次退避）：
#   1) 网关 400：grep "API Error:"；此时流里可能已含部分 assistant 消息，不能
#      据此判成功，必须整次重试
#   2) 模型侧 api_error：流尾部 terminal_reason":"api_error / is_error":true
#      （注意正常流的 "api_error_status":null，匹配必须精确，勿用裸 "api_error"）
# 另对无错误签名的空输出也退避重试，避免瞬时异常直接判失败
LAST_ERR=""
# 网关 400 为瞬时高频故障，重试预算 8 次；退避 attempt*3s 封顶 12s，控制在
# case 600s 超时内
for attempt in 1 2 3 4 5 6 7 8; do
  RAW="$(run_once)"
  # 中途认证/通道失效：立即致命退出（重试无意义），并作废预检缓存，
  # 避免下次评测带着过期的"通道正常"结论启动
  if is_auth_failure "$RAW"; then
    rm -f "$AUTH_CACHE" 2>/dev/null
    auth_fail_msg
    exit 1
  fi
  OUT="$(printf '%s\n' "$RAW" | extract)"
  if printf '%s' "$RAW" | grep -qE 'API Error:|terminal_reason":"api_error|"is_error":true'; then
    LAST_ERR="$RAW"
    sleep $(( attempt * 3 > 12 ? 12 : attempt * 3 ))
    continue
  fi
  if [[ -n "${OUT//[[:space:]]/}" ]]; then
    printf '%s\n' "$OUT"
    exit 0
  fi
  LAST_ERR="$RAW"
  sleep $(( attempt * 2 ))
done
printf '%s\n' "$LAST_ERR" >&2
exit 1
