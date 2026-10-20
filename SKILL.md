---
name: skill-creator-pipeline
version: 1.2.0
description: "Skill 创建统一流水线，通过引导式问答（每问附推荐选项）+自动质量门禁（含 writing-for-agents 写作质量 QW 检查：description pointer 化/一分支一触发/完成判据/no-op 清除）+评测闭环，确保任何人创建的 skill 都达到团队基线标准。触发词：创建skill、新建skill、我想做一个skill、帮我写个skill、skill流水线、skill pipeline、new skill、make skill、skill生成、做个自动化、skill向导。明确指令：/skill-creator-pipeline（直接触发本 skill，进入统一创建流水线）。NOT for: 仅做规范检查（用一个 skill linter）、仅做效果评估优化（用 skill-eval-optimizer）、修改已有 skill 的小问题（直接改）。"
license: MIT
allowed-tools:
  - Read
  - Write
  - Edit
  - MultiEdit
  - run_terminal_cmd
  - Agent
  - AskQuestion
---

# Skill 创建统一流水线

> 一站式 Skill 创建工具：从模糊需求到可交付 Skill，全程引导、自动质检、兜底验证。
> 核心价值：**降低创建门槛 + 保证产出质量一致性**。即使描述能力弱、对 AI 认知有限的团队成员，也能产出达标的 Skill。

## 设计理念

1. **选择优于描述** — 用选择题代替开放式提问，降低表达门槛
2. **示例锚定** — 每个需要填写的地方都有高质量示例参照
3. **回显确认** — 把理解结果"说人话"回显，让用户判断对不对而不是判断自己说得好不好
4. **门禁自动化** — 质量检查嵌入流程，不依赖人工判断
5. **最小可行优先** — 先生成能用的版本，再通过评测迭代优化

## 执行流程总览

```
Phase 0: 引导式需求采集（准入判断 → 选择题 → 填空 → 回显确认 → 证据采集）
    ↓ [门禁G0: 需求完整性检查]
Phase 1: 自动生成 Skill（调用 skill-creator 核心逻辑）
    ↓ [门禁G1: skill linter 结构检查 — 0 error]
Phase 2: 自动评测（调用 skill-eval-optimizer 评分）
    ↓ [门禁G2: 总分 ≥ 60/100]
Phase 3: 自动修复循环（40-59 分自动优化，最多 3 轮）
    ↓ [门禁G3: 优化后分数 > 优化前]
Phase 4: 交付确认
```

## 信息唯一出处（单一维护点）

同一内容只在一处定义，本文只保留流程骨架与门禁判定标准；细节一律以下表为准，禁止在本文件复制：

| 内容 | 唯一出处 | 读取时机 |
|------|---------|---------|
| 准入判断、四层采集（Q1-Q4 选择题、填空、回显、证据）话术、防跑偏机制、Phase 0 输出契约 | [references/guided-intake.md](references/guided-intake.md) | Phase 0 开始前 |
| 各门禁检查项/阈值/自动修复策略/团队配置、数据安全基线 | [references/quality-gates.md](references/quality-gates.md) | 各门禁点 |
| 五类 Skill 的默认配置、触发词/输出格式模板、兜底默认值 | [references/type-templates.md](references/type-templates.md) | Phase 0 Step 0.2 |
| 生成模式模板 P1-P5 与生成规则 | `~/.claude/skills/skill-creator/` | Phase 1 Step 1.1 |
| writing-for-agents 写作质量判据（context pointer / 两负载 / 信息层级 / 完成判据 / leading words / 修剪） | `~/.claude/skills/skill-creator/references/writing-for-agents.md` | Phase 1 Step 1.2 生成约束与 G1 写作质量（QW）检查 |

---

## Phase 0：引导式需求采集

> **执行前完整读取 [references/guided-intake.md](references/guided-intake.md)**（含准入判断表、全部问答话术与分支规则）。

- **Step 0.0 准入守卫（首个动作，必须先于一切采集执行）**：按 guided-intake「第零层」逐行匹配用户意图；命中非创建行时**照抄 guided-intake「拒绝话术模板」**（唯一权威，不自由发挥、不展开帮忙做事）；范围 ≥3 类能力 → 引导聚焦；判断不了时默认进入 Step 0.1 选择题澄清（以 guided-intake「判断不了时」行为为准），不阻塞。
- **Step 0.0.5 复用快检（防重复造轮子，判定不了是否新建时先做）**：扫描已安装 skill 目录（存在哪个扫哪个：`~/.claude/skills/`、`~/.agents/skills/`、`$PWD/.claude/skills/`），命中疑似同类 skill 时**停等用户裁决**，使用 guided-intake「复用裁决」话术（三选项：试用现有 / 补强现有 / 确认新建）；裁决为「确认新建」才进入 Step 0.1。未命中直接进入 Step 0.1
- **Step 0.1 类型定位**：用 AskQuestion 提出 Q1-Q4 四道单选题（干什么 / 何时用 / 数据从哪来 / 结果怎么呈现），题目与选项见 guided-intake 第一层；用户首条消息已明确的信息（如一句话描述、数据源）直接预填对应项，不重复追问
- **Step 0.2 业务填空**：按 Q1 类型使用 guided-intake 第二层对应类型的填空题（A-E），并结合 type-templates 的默认配置与输出格式模板；每个空必带示例，允许跳过
- **Step 0.3 回显确认**：生成一句话总结回显给用户确认；用户否定时按 guided-intake 第三层精准追问偏差点，不回到开头重来
- **Step 0.4 证据采集**：按 guided-intake 第四层采集 E1 真实使用例句、E2 期望输出样本、E3 约束来源（可选）
- **Step 0.5 门禁 G0**：判定标准——强制项（做什么 / 输入 / 输出 / E1 / 触发场景）缺一则回到对应步骤追问（最多 2 轮），仍缺则默认值兜底并标记 `confidence: low`。通过后按 guided-intake「输出契约」产出结构化需求 JSON，并向用户展示采集摘要

---

## Phase 1：自动生成 Skill

### Step 1.1：模式确认

根据 Phase 0 推荐的模式（`P{N}`）读取 skill-creator 对应模板；「场景特征 → 主模式 → 模板文件」映射唯一权威：`~/.claude/skills/skill-creator/references/generation-playbook.md`「模板映射」表（Step 1.2 读取该文件时一并获得，此处不重复维护）。

### Step 1.2：生成 Skill 草稿

按照 [skill-creator 的 generation-playbook](~/.claude/skills/skill-creator/references/generation-playbook.md) 生成完整 SKILL.md，包括：

1. Frontmatter（name/description/allowed-tools）
2. 核心流程（按模式模板填充）
3. 输入输出定义
4. 异常处理表
5. 诚实边界
6. 输出格式模板

**生成约束：**
- 正文 ≤ 500 行
- 每步有明确动词 + 对象 + 产物，且结束于可判定完成判据（completion criterion）
- 触发词覆盖口语 + 英文 + 缩写变体，遵循「一分支一触发词」（同义触发词收敛，判据见 writing-for-agents）
- description 按 context-pointer 化写法（leading word 前置 + 触发分支列表，判据见 writing-for-agents）
- references 按 progressive disclosure 分层（全分支需要的内联，部分分支的下推）
- 安全红线检查（S001-S004）；涉及敏感数据时按 quality-gates「数据安全基线」声明脱敏

### Step 1.3：写入文件

```
目标路径：~/.claude/skills/{skill-name}/SKILL.md
同时生成：
  - README.md（最小骨架）
  - .env.example（如涉及外部连接）
```

test-prompts.json 由 Phase 2 Step 2.1 统一写入，本阶段不生成。

### Step 1.4：门禁 G1 — 结构检查

```bash
bash ~/.claude/skills/skill-creator-pipeline/scripts/pipeline-runner.sh gate-g1 {skill-name} --fix
```

**判定标准：** 0 个 error（warning 记录不阻塞）。检查项清单、自动修复策略与 linter 不可用降级唯一权威：quality-gates G1（可自动修复项修复后重检；E005/S001 展示问题请用户人工介入；降级标记 `lint_mode: degraded`）。

---

## Phase 2：自动评测

### Step 2.1：设计测试 Prompt

为新生成的 Skill 自动设计测试 prompt，写入 `{skill-name}/test-prompts.json`（schema 与断言类型与 skill-creator 协议一致，唯一权威：`~/.claude/skills/skill-creator/scripts/test_prompts_validator.py`；必含 over-trigger 与 under-spec 各 ≥1 条）：

1. **Happy path**：正常场景，用 Phase 0 采集的 E1 样例
2. **边界场景**：输入不完整或略有歧义的情况
3. **负面场景**：不该触发的场景（验证 NOT 边界，即 over-trigger）
4. **欠规格场景**：一句话模糊请求须先追问/选择题兜底（under-spec）

### Step 2.2：执行评估

读取 `~/.claude/skills/skill-eval-optimizer/references/rubric.md`（8 维评分标准与权重的唯一权威），按 8 维度评分：

- **D1-D6 结构维度（权重合计 60%）**：主 agent 逐维打 1-10 分，每维附简短理由
- **D7-D8 效果维度（权重合计 40%）**：D8 用 `test-prompts.json` 跑实测（full_test / dry_run 判定与降级规则唯一权威：quality-gates G2「评分降级」）
- **总分** = Σ(维度分 × 权重) ÷ 10，保留 1 位小数（与 rubric.md 公式一致）

### Step 2.3：门禁 G2 — 评分阈值（四级判定）

四级判定阈值唯一权威：quality-gates G2（维度权重唯一权威：`~/.claude/skills/skill-eval-optimizer/references/rubric.md`）。摘要：**≥60 PASS**（≥80 优秀直接交付）→ Phase 4；**40-59 FAIL** → Phase 3 修复；**<40 BLOCK** → 回退 Phase 0。总分达标但任一维度低于最低接受分时，该维度在 Phase 3 优先修复。

---

## Phase 3：自动修复循环

> G2 判定 FAIL（40-59 分）时自动触发，无需人工判断"该怎么改"。

```
for round in 1..3:
    1. 定位最低维度（加权 gap 最大；优先级 D5 > D2 > D3 > D8）
    2. 按 quality-gates G3 修复策略表自动修复（Edit SKILL.md）
    3. 重新评分
    4. 新分 > 旧分 → 保留，继续下一轮
       新分 ≤ 旧分 → 回滚（git revert HEAD），换维度重试
    5. 连续 2 轮无收益 → 停止修复，交由用户决定
    6. 总分 ≥ 60 → 通过，进入 Phase 4
```

**3 轮后仍 < 60 分**：暂停，展示当前状态与短板，用户三选一：
A. 降低要求接受当前版本 / B. 补充更多需求信息后回到 Phase 0 / C. 人工介入修改

---

## Phase 4：交付确认

### Step 4.1：展示交付摘要

```markdown
## 交付摘要

Skill: {name}
路径: ~/.claude/skills/{name}/
模式: P{N}（{模式名}）
Lint: PASS（0 error, {N} warning）
评分: {score}/100（{eval_mode}）
门禁: G0 ✓ G1 ✓ G2 ✓ G3 {通过/跳过}

### 文件清单
- [x] SKILL.md
- [x] README.md
- [x] test-prompts.json
- [x] .env.example（如需要）

### 使用方式
触发词：{triggers}
明确指令：/{skill-name}
```

### Step 4.2：用户确认

展示摘要后等待用户确认：
- **确认交付** → 完成
- **还需调整** → 说明调整点，回到对应阶段

---

## 异常处理

| 场景 | 处理 |
|------|------|
| 用户全程只说了一句模糊的话 | Step 0.1 选择题兜底，最差情况也能定位到类型（见 quality-gates G0 默认值策略） |
| 选择题选了 F（不确定） | 追问"你最想省掉哪个重复劳动"，从具体痛点入手 |
| 填空题全部跳过 | 置信度标记为"低"，生成最小 MVP 版本 + 标注需迭代 |
| linter 检查发现安全红线 | 自动修复不含敏感信息的项；含密钥/内网地址的提示用户手动处理 |
| 引导中途发现是改现有 skill / 范围过大 | 暂停引导，回到 Step 0.0 重新路由，已采集信息不浪费 |
| 用户中途放弃或连续无响应 | 不强推，保存已采集片段，提示"随时回来继续，已记录到此处" |

---

## 数据安全基线

脱敏规则格式表唯一权威：`~/.claude/skills/skill-creator/SKILL.md` Step 1.3「敏感数据脱敏」（共享权威源）；执行约束与门禁位置见 quality-gates「数据安全基线」（涉及敏感数据必须声明脱敏/禁止硬编码真实敏感数据/用户数据不持久化）。

---

## 诚实边界

- 本 skill **做不到**：
  1. 替代用户的业务判断（如"这个需求该不该做"）
  2. 生成需要外部 API 实时调试才能验证的 skill（只能 dry_run）
  3. 保证生成的 skill 第一次就满分（但保证基线达标）
  4. 处理超过 2 种模式组合的复杂 skill（建议拆分）

- 信息不足时的降级策略：
  1. 只有 Q1 选择 → 生成最小骨架，标记"需补充"
  2. 缺证据 E1/E2 → 生成后评分降级处理
  3. 用户无法提供约束 → 使用该类型的通用约束模板

---

## 资源文件

| 文件 | 内容 | 何时读取 |
|------|------|---------|
| [references/guided-intake.md](references/guided-intake.md) | 引导式问答完整细节和话术 | Phase 0 开始前 |
| [references/type-templates.md](references/type-templates.md) | 按类型的填空模板库 | Phase 0 Step 0.2 |
| [references/quality-gates.md](references/quality-gates.md) | 各门禁的详细规则和阈值 | Phase 1-3 各门禁点 |
| [scripts/pipeline-runner.sh](scripts/pipeline-runner.sh) | G1 门禁自动化脚本（lint/validate/gate-g1/report） | Phase 1 Step 1.4 |
