#!/usr/bin/env bash
# skill-creator-pipeline: 质量门禁自动化执行脚本
# 用途：在 Phase 1-3 中自动执行 linter 检查和基础验证
# 注意：本脚本只负责可脚本化的检查部分，评分和修复由 Agent 流程控制
#
# 可配置环境变量：
#   SKILLS_ROOT                    skill 安装根目录（默认 ~/.claude/skills）
#   SKILL_LINTER_SCRIPT            外部 skill linter 脚本路径（可选；未设置或
#                                  不存在时自动降级为内置最小规则检查）
#   SKILL_INTERNAL_DOMAIN_PATTERN  组织内网域名正则（可选；如 'example\.internal'，
#                                  未设置则跳过内网域名检查）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PIPELINE_ROOT="$(dirname "$SCRIPT_DIR")"
SKILLS_ROOT="${SKILLS_ROOT:-${HOME}/.claude/skills}"
LINTER_SCRIPT="${SKILL_LINTER_SCRIPT:-}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  lint <skill-name>     运行 linter 检查"
    echo "  validate <skill-name> 运行基础验证（文件结构+frontmatter）"
    echo "  gate-g1 <skill-name>  执行 G1 门禁完整检查"
    echo "  report <skill-name>   输出门禁状态报告"
    echo ""
    echo "Options:"
    echo "  --fix                 自动修复可修复项（lint 命令）"
    echo "  --json                JSON 格式输出"
    echo ""
    echo "Examples:"
    echo "  $0 lint my-skill"
    echo "  $0 gate-g1 my-skill --fix"
    echo "  $0 report my-skill --json"
}

# === 基础验证（不依赖 linter 脚本）===
validate_skill() {
    local skill_name="$1"
    local skill_dir="${SKILLS_ROOT}/${skill_name}"
    local errors=0
    local warnings=0

    echo -e "${BLUE}=== 验证 Skill: ${skill_name} ===${NC}"
    echo ""

    # 检查目录存在
    if [[ ! -d "$skill_dir" ]]; then
        echo -e "${RED}[ERROR] 目录不存在: ${skill_dir}${NC}"
        return 1
    fi

    # E001: SKILL.md 存在且大小写正确
    if [[ -f "${skill_dir}/SKILL.md" ]]; then
        echo -e "${GREEN}[PASS] E001: SKILL.md 存在${NC}"
    elif [[ -f "${skill_dir}/skill.md" ]]; then
        echo -e "${RED}[FAIL] E001: skill.md 大小写错误（应为 SKILL.md）${NC}"
        ((errors++))
    else
        echo -e "${RED}[FAIL] E001: SKILL.md 不存在${NC}"
        ((errors++))
    fi

    # E002: frontmatter 可解析
    if [[ -f "${skill_dir}/SKILL.md" ]]; then
        local first_line
        first_line=$(head -1 "${skill_dir}/SKILL.md")
        if [[ "$first_line" == "---" ]]; then
            # 检查是否有闭合的 ---
            local close_line
            close_line=$(tail -n +2 "${skill_dir}/SKILL.md" | grep -n "^---$" | head -1 | cut -d: -f1)
            if [[ -n "$close_line" ]]; then
                echo -e "${GREEN}[PASS] E002: frontmatter 格式正确${NC}"
            else
                echo -e "${RED}[FAIL] E002: frontmatter 未闭合${NC}"
                ((errors++))
            fi
        else
            echo -e "${RED}[FAIL] E002: 缺少 frontmatter（首行不是 ---）${NC}"
            ((errors++))
        fi
    fi

    # E003: name 字段存在且为 kebab-case
    if [[ -f "${skill_dir}/SKILL.md" ]]; then
        local name_field
        name_field=$(sed -n '/^---$/,/^---$/p' "${skill_dir}/SKILL.md" | grep "^name:" | head -1 | sed 's/^name:[[:space:]]*//')
        if [[ -n "$name_field" ]]; then
            if echo "$name_field" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
                echo -e "${GREEN}[PASS] E003: name 为 kebab-case（${name_field}）${NC}"
            else
                echo -e "${RED}[FAIL] E003: name 不是 kebab-case（${name_field}）${NC}"
                ((errors++))
            fi
        else
            echo -e "${RED}[FAIL] E003: 缺少 name 字段${NC}"
            ((errors++))
        fi
    fi

    # E004: description 存在
    if [[ -f "${skill_dir}/SKILL.md" ]]; then
        local desc
        desc=$(sed -n '/^---$/,/^---$/p' "${skill_dir}/SKILL.md" | grep -c "description:")
        if [[ "$desc" -gt 0 ]]; then
            echo -e "${GREEN}[PASS] E004: description 存在${NC}"
        else
            echo -e "${RED}[FAIL] E004: 缺少 description 字段${NC}"
            ((errors++))
        fi
    fi

    # E006: README.md 存在
    if [[ -f "${skill_dir}/README.md" ]]; then
        echo -e "${GREEN}[PASS] E006: README.md 存在${NC}"
    else
        echo -e "${YELLOW}[WARN] E006: README.md 不存在（可自动生成）${NC}"
        ((warnings++))
    fi

    # S002: 内网地址检测
    if [[ -f "${skill_dir}/SKILL.md" ]]; then
        local internal_ips
        internal_ips=$(grep -nE '\b(10|172\.(1[6-9]|2[0-9]|3[01])|192\.168)\.[0-9]+\.[0-9]+\b' "${skill_dir}/SKILL.md" 2>/dev/null || true)
        if [[ -n "$internal_ips" ]]; then
            echo -e "${RED}[FAIL] S002: 检测到内网 IP 地址${NC}"
            echo "       $internal_ips"
            ((errors++))
        else
            echo -e "${GREEN}[PASS] S002: 无内网 IP 暴露${NC}"
        fi
    fi

    # S002b: 组织内网域名检测（模式由 SKILL_INTERNAL_DOMAIN_PATTERN 配置，未配置则跳过）
    if [[ -f "${skill_dir}/SKILL.md" && -n "${SKILL_INTERNAL_DOMAIN_PATTERN:-}" ]]; then
        local internal_domains
        internal_domains=$(grep -nE "${SKILL_INTERNAL_DOMAIN_PATTERN}" "${skill_dir}/SKILL.md" 2>/dev/null || true)
        if [[ -n "$internal_domains" ]]; then
            echo -e "${RED}[FAIL] S002: 检测到内网域名${NC}"
            echo "       $internal_domains"
            ((errors++))
        else
            echo -e "${GREEN}[PASS] S002: 无内网域名暴露${NC}"
        fi
    fi

    # S003: 数据库连接串检测
    if [[ -f "${skill_dir}/SKILL.md" ]]; then
        local db_conn
        db_conn=$(grep -nE '(mysql|jdbc|mongodb|redis)://[^$]' "${skill_dir}/SKILL.md" 2>/dev/null || true)
        if [[ -n "$db_conn" ]]; then
            echo -e "${RED}[FAIL] S003: 检测到硬编码连接串${NC}"
            echo "       $db_conn"
            ((errors++))
        else
            echo -e "${GREEN}[PASS] S003: 无硬编码连接串${NC}"
        fi
    fi

    echo ""
    echo -e "${BLUE}=== 验证结果 ===${NC}"
    echo -e "Errors:   ${RED}${errors}${NC}"
    echo -e "Warnings: ${YELLOW}${warnings}${NC}"

    if [[ $errors -eq 0 ]]; then
        echo -e "${GREEN}结论: PASS${NC}"
        return 0
    else
        echo -e "${RED}结论: FAIL（需修复 ${errors} 个 error）${NC}"
        return 1
    fi
}

# === Linter 检查（调用外部 skill linter，可选）===
run_lint() {
    local skill_name="$1"
    local fix_mode="${2:-}"

    if [[ -z "$LINTER_SCRIPT" || ! -f "$LINTER_SCRIPT" ]]; then
        echo -e "${YELLOW}[WARN] 外部 skill linter 不可用（SKILL_LINTER_SCRIPT 未设置或脚本不存在），降级为内置验证${NC}"
        validate_skill "$skill_name"
        return $?
    fi

    echo -e "${BLUE}=== Linter 检查: ${skill_name} ===${NC}"

    if [[ "$fix_mode" == "--fix" ]]; then
        echo -e "${YELLOW}执行自动修复模式...${NC}"
        python3 "$LINTER_SCRIPT" --only "$skill_name" 2>&1 || true
        echo ""
        echo -e "${BLUE}修复后重检...${NC}"
        python3 "$LINTER_SCRIPT" --only "$skill_name" 2>&1
    else
        python3 "$LINTER_SCRIPT" --only "$skill_name" 2>&1
    fi
}

# === G1 门禁完整检查 ===
gate_g1() {
    local skill_name="$1"
    local fix_mode="${2:-}"
    local result=0

    echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   G1 门禁: 结构合规检查              ║${NC}"
    echo -e "${BLUE}║   Skill: ${skill_name}${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
    echo ""

    # Step 1: 基础验证
    echo -e "${BLUE}--- Step 1: 基础验证 ---${NC}"
    if validate_skill "$skill_name"; then
        echo -e "${GREEN}基础验证通过${NC}"
    else
        result=1
        if [[ "$fix_mode" == "--fix" ]]; then
            echo -e "${YELLOW}尝试自动修复...${NC}"
            auto_fix_basics "$skill_name"
            echo -e "${BLUE}修复后重验...${NC}"
            if validate_skill "$skill_name"; then
                echo -e "${GREEN}修复后通过${NC}"
                result=0
            fi
        fi
    fi
    echo ""

    # Step 2: Linter 检查
    echo -e "${BLUE}--- Step 2: Linter 检查 ---${NC}"
    if run_lint "$skill_name" "$fix_mode"; then
        echo -e "${GREEN}Linter 检查通过${NC}"
    else
        result=1
    fi
    echo ""

    # 最终结论
    echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}║   G1 门禁: PASS ✓                    ║${NC}"
    else
        echo -e "${RED}║   G1 门禁: FAIL ✗                    ║${NC}"
    fi
    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"

    return $result
}

# === 自动修复基础项 ===
auto_fix_basics() {
    local skill_name="$1"
    local skill_dir="${SKILLS_ROOT}/${skill_name}"

    # 修复 E001: skill.md → SKILL.md
    if [[ -f "${skill_dir}/skill.md" && ! -f "${skill_dir}/SKILL.md" ]]; then
        mv "${skill_dir}/skill.md" "${skill_dir}/SKILL.md"
        echo -e "${GREEN}  [FIX] E001: skill.md → SKILL.md${NC}"
    fi

    # 修复 E006: 生成 README.md
    if [[ ! -f "${skill_dir}/README.md" ]]; then
        cat > "${skill_dir}/README.md" <<EOF
# ${skill_name}

## 简介

{待补充}

## 使用方式

{待补充}

## 依赖

{待补充}
EOF
        echo -e "${GREEN}  [FIX] E006: 生成 README.md 骨架${NC}"
    fi
}

# === 状态报告 ===
report() {
    local skill_name="$1"
    local json_mode="${2:-}"
    local skill_dir="${SKILLS_ROOT}/${skill_name}"
    local log_file="${skill_dir}/.pipeline-log.json"

    if [[ "$json_mode" == "--json" ]]; then
        if [[ -f "$log_file" ]]; then
            cat "$log_file"
        else
            echo '{"error": "no pipeline log found"}'
        fi
    else
        echo -e "${BLUE}=== Pipeline 状态报告: ${skill_name} ===${NC}"
        if [[ -f "$log_file" ]]; then
            echo "最近运行记录："
            cat "$log_file" | python3 -m json.tool 2>/dev/null || cat "$log_file"
        else
            echo "暂无运行记录（尚未通过 pipeline 创建）"
        fi
    fi
}

# === 主入口 ===
main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    local command="$1"
    shift

    case "$command" in
        lint)
            if [[ $# -lt 1 ]]; then
                echo "Error: 请指定 skill 名称"
                exit 1
            fi
            run_lint "$1" "${2:-}"
            ;;
        validate)
            if [[ $# -lt 1 ]]; then
                echo "Error: 请指定 skill 名称"
                exit 1
            fi
            validate_skill "$1"
            ;;
        gate-g1)
            if [[ $# -lt 1 ]]; then
                echo "Error: 请指定 skill 名称"
                exit 1
            fi
            gate_g1 "$1" "${2:-}"
            ;;
        report)
            if [[ $# -lt 1 ]]; then
                echo "Error: 请指定 skill 名称"
                exit 1
            fi
            report "$1" "${2:-}"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

main "$@"
