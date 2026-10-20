# 质量门禁配置

> 读取时机：Phase 1-3 各门禁点。定义了每个门禁的检查项、阈值、通过/失败判定规则和自动修复策略。

---

## 门禁总览

```
Phase 0 ──→ [G0: 需求完整性] ──→ Phase 1 ──→ [G1: 结构合规] ──→ Phase 2 ──→ [G2: 评分达标] ──→ Phase 3/4
                                                                                      ↓ (< 60分)
                                                                              [G3: 修复有效性]
                                                                                      ↓
                                                                              Phase 4（交付）
```

---

## G0：需求完整性门禁

### 触发时机

Phase 0 Step 0.5 完成后，进入 Phase 1 前。

### 检查项

| # | 检查项 | 必须 | 通过条件 | 未通过处理 |
|---|--------|------|---------|-----------|
| 1 | 做什么（one_liner） | ✓ | 非空，含动词+对象 | 回到 F2 追问 |
| 2 | 输入定义 | ✓ | 至少知道数据从哪来 | 回到 Q3 追问 |
| 3 | 输出形式 | ✓ | 至少知道结果怎么呈现 | 回到 Q4 追问 |
| 4 | E1 样例输入 | ✓ | 至少 1 条具体样例 | 请求用户补充 |
| 5 | E2 输出样例 | 建议 | 有则+分，无则降级 | 标记置信度为"中" |
| 6 | E3 约束来源 | 可选 | 有则+分，无则用默认 | 不阻塞 |
| 7 | 触发场景 | ✓ | Q2 有选择 | 默认为"被动响应" |
| 8 | Skill名称 | 建议 | kebab-case 格式 | 自动生成 |
| 9 | 何时不触发 | 建议 | 从 F3 与类型排除推断 | 用类型通用排除规则兜底 |
| 10 | 约束 | 建议 | 填空+证据中的规则 | 用该类型通用约束模板兜底 |
| 11 | 依赖 | 建议 | Q3 选 B 时追问提取 | 标记为未知，生成时提示确认 |

### 通过规则

- **强制项**（#1, #2, #3, #4, #7）全部通过 → G0 PASS
- 缺 1 个强制项 → 回到对应步骤追问（最多追问 2 轮）
- 追问 2 轮后仍缺 → 使用默认值兜底，标记 `confidence: low`

### 置信度计算

| 条件 | 置信度 |
|------|--------|
| 强制项全 ✓ + E2 ✓ + E3 ✓ | 高 |
| 强制项全 ✓ + E2 ✓ + E3 ✗ | 高 |
| 强制项全 ✓ + E2 ✗ | 中 |
| 强制项缺 1 项（用默认兜底） | 中 |
| 强制项缺 2 项及以上 | 低（不建议继续，但不硬阻塞） |

### 低置信度处理

置信度为"低"时：
1. 向用户展示风险提示："当前信息较少，生成的 skill 可能需要较多调整。建议补充 [缺失项]。"
2. 用户选择：
   - "继续，我后面再调" → 进入 Phase 1，标记 `needs_iteration: true`
   - "我补充一下" → 回到对应步骤

---

## G1：结构合规门禁

### 触发时机

Phase 1 Step 1.3 写入文件后，调用 skill linter 检查。

### 执行命令

```bash
# 外部 skill linter 脚本路径由环境变量 SKILL_LINTER_SCRIPT 指定（可选）：
python3 "$SKILL_LINTER_SCRIPT" --only {skill-name}
# 或一键执行 G1 完整检查（基础验证 + linter + 自动修复）：
bash ~/.claude/skills/skill-creator-pipeline/scripts/pipeline-runner.sh gate-g1 {skill-name} --fix
```

如果 linter 脚本不存在，降级为内置规则检查。

### 检查项与阈值

| 级别 | 规则 | 阈值 | 自动修复 |
|------|------|------|---------|
| 🔴 Error | E001 SKILL.md 存在且大小写正确 | 0 容忍 | ✓ 自动重命名 |
| 🔴 Error | E002 frontmatter 合法 YAML | 0 容忍 | ✓ 自动修正格式 |
| 🔴 Error | E003 name 为 kebab-case | 0 容忍 | ✓ 自动转换 |
| 🔴 Error | E004 description 非空且≤1024 | 0 容忍 | ✓ 自动截断/补充 |
| 🔴 Error | E005 目录名=frontmatter.name | 0 容忍 | ⚠️ 需确认后修复 |
| 🔴 Error | E006 README.md 存在 | 0 容忍 | ✓ 自动生成骨架 |
| 🔴 Security | S001 无硬编码密钥 | 0 容忍 | ⚠️ 提示人工处理 |
| 🔴 Security | S002 无内网地址暴露 | 0 容忍 | ✓ 替换为环境变量 |
| 🔴 Security | S003 无硬编码连接串 | 0 容忍 | ✓ 替换为环境变量 |
| 🔴 Security | S004 破坏性操作有防护 | 0 容忍 | ✓ 补充安全声明 |
| ⚠️ Warning | W001 正文≤800行 | 记录不阻塞 | — |
| ⚠️ Warning | W002 description含触发词 | 记录不阻塞 | ✓ 补充触发词 |
| ⚠️ Warning | W003 README 含标准章节 | 记录不阻塞 | ✓ 补充章节 |
| ⚠️ Warning | QW1 description 已 context-pointer 化（leading word 前置 + 一分支一触发词，同义触发词收敛） | 记录不阻塞；>3 个触发分支未收敛、leading word 不前置或同一分支被多个同义词重命名时标记 | ✎ Agent 按 writing-for-agents 重写/合并同义分支（非全自动） |
| ⚠️ Warning | QW3 关键步骤有完成判据（completion criterion） | 记录不阻塞；核心 steps 缺可判定判据时标记 | ✎ Agent 锐化为可核对且穷尽的条件 |
| ⚠️ Warning | QW4 无 no-op 句（相对模型默认不改变行为的指令） | 记录不阻塞；逐句判据「相对默认它改变行为吗」 | ✎ Agent 删整句（非删词） |

> 编号说明：QW = 写作质量检查，沿用 `skill-creator` SKILL.md Step 1.4 的 QW1-QW6 编号空间，**独立于 skill linter 的 W001-W008 编号空间**（两套 W 编号语义不同，勿混用）；QW 项由 Agent 执行，非 linter 脚本输出。

### 通过规则

- **0 个 Error** → G1 PASS
- 有 Error 但全部可自动修复 → 自动修复 → 重检 → PASS
- 有 Error 且含不可自动修复项（E005, S001） → 展示问题，请用户处理

### 自动修复流程

```
1. 检查 → 发现 errors
2. 分类：可自动修复 vs 需人工
3. 自动修复可修复项
4. 重新检查
5. 仍有 error → 展示给用户
6. 0 error → PASS
```

### 写作质量检查（QW）

QW 检查项（QW1/QW3/QW4）的判定依据与修复手法唯一权威源：`~/.claude/skills/skill-creator/references/writing-for-agents.md`（共享权威源，本文件只保留门禁定义不复制判据）。这些 warning **记录不阻塞** G1，但计入 `.pipeline-log.json`，并作为 Phase 3 修复优先级参考（排在 D5 指令具体性之后、D2 之前）；修复由 Agent 参照权威源执行（context pointer 化 / 同义分支收敛 / 判据锐化 / no-op 整句删除），非脚本全自动。

### 降级模式（linter 不可用）

如果 linter 脚本不存在或执行失败，使用内置最小规则集：

1. SKILL.md 文件是否存在
2. frontmatter 是否可解析（检查 `---` 分隔符）
3. name 字段是否存在
4. description 字段是否存在
5. 是否包含内网 IP 模式（正则：`\b(?:10|172\.(?:1[6-9]|2\d|3[01])|192\.168)\.\d+\.\d+\b`）
6. 是否包含组织内网域名（模式通过环境变量 `SKILL_INTERNAL_DOMAIN_PATTERN` 配置，未配置则跳过）

标记 `lint_mode: degraded`。

---

## G2：评分达标门禁

### 触发时机

Phase 2 Step 2.3 评分完成后。

### 执行方式

调用 skill-eval-optimizer 的评分逻辑，8 维度评分。

### 阈值配置

| 等级 | 总分范围 | 判定 | 处理 |
|------|---------|------|------|
| 优秀 | ≥ 80/100 | PASS | 直接进入 Phase 4 交付 |
| 达标 | 60-79/100 | PASS | 进入 Phase 4，建议后续优化 |
| 待改进 | 40-59/100 | FAIL | 进入 Phase 3 自动修复 |
| 严重不足 | < 40/100 | BLOCK | 回退到 Phase 0 重新采集需求 |

### 维度权重

维度定义、权重（D1-D6 结构合计 60%，D7-D8 效果合计 40%）与评分标准唯一权威：`~/.claude/skills/skill-eval-optimizer/references/rubric.md`（D7「整体架构」属于效果维度，与 rubric.md 维度归属一致），本文件不重复维护。总分 = Σ(维度分 × 权重) ÷ 10。

**pipeline 附加门禁**：即使总分达标，任一维度低于最低接受分（D1/D2/D5/D7 ≥5，D3/D4/D8 ≥4，D6 ≥3）时，该维度需在 Phase 3 优先修复。

### 评分降级

- skill-eval-optimizer 不可用 → 降级为内置简化评分（仅维度 1-7，dry_run）
- 子 agent 不可用 → 维度 8 使用 dry_run 模式
- 标记 `eval_mode: dry_run` 或 `eval_mode: degraded`

---

## G3：修复有效性门禁

### 触发时机

Phase 3 每轮修复后。

### 通过规则

- **新分 > 旧分** → 保留修改，继续下一轮或完成
- **新分 ≤ 旧分** → 回滚修改，换一个维度尝试
- **连续 2 轮无收益** → 停止修复，交由用户决定

### 修复循环配置

| 参数 | 默认值 | 说明 |
|------|--------|------|
| MAX_ROUNDS | 3 | 最大修复轮次 |
| TARGET_SCORE | 60 | 目标分数 |
| DIMENSION_PRIORITY | D5 > D2 > D3 > D8 | 维度修复优先级 |
| ROLLBACK_STRATEGY | git revert HEAD | 回滚方式 |

### 修复策略选择

根据最低维度自动选择修复策略：

| 最低维度 | 典型修复 | 修复动作 |
|---------|---------|---------|
| D1 | Frontmatter 不规范 | 重写 frontmatter，补触发词 |
| D2 | 工作流不清晰 | 加步骤编号，补输入输出定义 |
| D3 | 边界条件缺失 | 补异常处理表，加 fallback |
| D4 | 缺检查点 | 在关键步骤后加确认点 |
| D5 | 指令模糊 | 把模糊动词替换为具体命令+参数 |
| D6 | 资源引用断裂 | 检查并修复路径引用 |
| D7 | 结构混乱 | 重组章节层级 |
| D8 | 实测表现差 | 优化核心流程逻辑 |

### 最终降级

3 轮修复后仍 < 60 分时，展示给用户三个选项：

```
当前得分：{score}/100（目标 60 分）
自动修复未能达标，建议：

A. 降低要求，接受当前版本（后续可手动优化）
B. 补充更多需求信息后重来（回到 Phase 0）
C. 我来手动调整（展示具体短板和建议改法）
```

---

## 数据安全基线

本基线是脱敏执行约束的权威（SKILL.md 与 type-templates 仅引用不复制）；脱敏规则**格式表**的唯一权威为 `~/.claude/skills/skill-creator/SKILL.md` Step 1.3「敏感数据脱敏」（共享权威源，本文件不复制）。pipeline 引导创建的 Skill 若涉及敏感数据字段（如手机号、身份证、地址、银行卡等），生成的 SKILL.md 必须按该权威表声明对应的脱敏规范。

**约束**：
- 生成的 Skill 若涉及敏感数据查询或展示，必须在 SKILL.md 中声明脱敏规则（格式按 creator Step 1.3 权威表）
- 禁止在 Skill 中硬编码真实敏感数据作为示例
- 用户提供的真实数据仅用于流程演示，不持久化存储

---

## 门禁日志格式

每次门禁检查的结果记录到 `{skill-name}/.pipeline-log.json`：

```json
{
  "pipeline_run": "2026-06-17T10:30:00Z",
  "gates": {
    "G0": {
      "status": "PASS",
      "confidence": "高",
      "missing_items": [],
      "defaults_used": []
    },
    "G1": {
      "status": "PASS",
      "lint_mode": "full",
      "errors_found": 2,
      "errors_fixed": 2,
      "warnings": 3
    },
    "G2": {
      "status": "PASS",
      "score": 72,
      "eval_mode": "dry_run",
      "lowest_dimension": "D5",
      "dimensions": {"D1": 8, "D2": 7, "D3": 6, "D4": 7, "D5": 5, "D6": 7, "D7": 8, "D8": 6}
    },
    "G3": {
      "status": "SKIPPED",
      "reason": "G2 已通过"
    }
  },
  "final_score": 72,
  "delivery_status": "delivered"
}
```

---

## 团队基线配置

### 可调参数

团队可以根据实际情况调整以下参数：

```yaml
# 团队质量基线配置
quality_baseline:
  # G2 通过阈值（60-80，建议从 60 开始逐步提高）
  pass_score: 60
  
  # G3 最大修复轮次（2-5）
  max_fix_rounds: 3
  
  # 是否强制要求 E2 输出样例
  require_e2: false
  
  # 是否强制要求 E3 约束来源
  require_e3: false
  
  # 低置信度是否阻塞
  block_on_low_confidence: false
  
  # 安全检查级别（strict/normal/relaxed）
  security_level: normal
```

### 分级建议

| 团队阶段 | 建议配置 | 说明 |
|---------|---------|------|
| 起步期 | pass_score=50, relaxed | 先让大家跑起来，有产出 |
| 成长期 | pass_score=60, normal | 标准配置，平衡效率和质量 |
| 成熟期 | pass_score=70, strict | 高标准，适合 skill 已成熟的团队 |
