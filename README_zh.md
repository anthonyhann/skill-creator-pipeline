<div align="center">

# Skill Creator Pipeline 🏭

### 从一句模糊的话，到一个能交付的 Agent Skill——全程引导、门禁把关、评测兜底。

一条 **5 阶段、4 门禁** 的创建流水线，让不会写 prompt 的人也能产出标准化、高质量的 agent skill：引导式问答（每问附推荐答案）+ 自动质量门禁 + 评测修复闭环。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)
[![版本](https://img.shields.io/badge/version-1.2.0-blue?style=flat-square)](SKILL.md)
[![质量门禁](https://img.shields.io/badge/%E8%B4%A8%E9%87%8F%E9%97%A8%E7%A6%81-4-orange?style=flat-square)](#-4-道质量门禁)
[![评分维度](https://img.shields.io/badge/%E8%AF%84%E5%88%86%E7%BB%B4%E5%BA%A6-8-purple?style=flat-square)](#-4-道质量门禁)
[![评测用例](https://img.shields.io/badge/%E8%AF%84%E6%B5%8B%E7%94%A8%E4%BE%8B-8-brightgreen?style=flat-square)](evals/)
[![Stars](https://img.shields.io/github/stars/anthonyhann/skill-creator-pipeline?style=flat-square)](https://github.com/anthonyhann/skill-creator-pipeline/stargazers)

[快速上手](#-快速上手) · [流水线流程](#-流水线流程) · [质量门禁](#-4-道质量门禁) · [目录结构](#-目录结构) · [什么时候别用](#-什么时候别用它) · [English](README.md)

</div>

---

## 😮‍💨 你的团队是不是也这样？

- 每个人写 skill 各有各的写法——质量取决于谁写的，而不是取决于标准。
- skill 作者自己用得溜，别人怎么都触发不了：description 里塞了 8 个同义触发词，agent 路由到别的 skill 去了。
- 核心步骤写着「整理数据然后输出结果」——没有完成判据，agent 干到一半就宣布胜利。
- 最懂业务的人最不会用「prompt 语言」表达需求——于是他们的 skill 永远没被做出来。

本 skill 把「依赖人的能力」变成「依赖流程的兜底」：用选择题代替描述，用示例代替空白页，用门禁代替意见。

**一段真实的引导式采集（零配置文本 demo）：**

```text
你:    帮我做个自动化。          ← 一句模糊的话就足以启动
Agent: 先告诉我，你想让这个 skill 帮你干什么类型的事情？选最接近的一个：
       A  查数据/排查问题（查日志、查数据库、定位 bug）
       B  生成内容/代码（建表 SQL、代码片段、文档报告）
       C  ⭐ 自动化操作（发消息、创建工单、部署上线）
       D  数据处理/对账（Excel 对比、数据清洗、报表统计）
       E  流程串联（先做 A 再做 B 再做 C 的多步骤）
       F  不确定/以上都不是
```

每道选择题都标注推荐项（⭐），每个填空题都带高质量示例。你只需要判断「它理解得对不对」，而不是「我说得好不好」。

## 🚀 快速上手

**1 · 安装** —— 把这句话粘贴给你的 AI agent（Claude Code、Codex、Cursor……）：

> 帮我安装这个 skill：https://github.com/anthonyhann/skill-creator-pipeline

或执行：`npx skills add anthonyhann/skill-creator-pipeline`

**2 · 触发** —— 对 agent 说 `帮我创建一个 skill`，或使用明确指令 `/skill-creator-pipeline`。

**3 · 回答 4 道选择题** —— 干什么 / 何时用 / 数据从哪来 / 结果怎么呈现。之后流水线会自动完成生成、lint 检查、评分、（如需）修复，并在交付摘要处等你确认。

就这三步，不需要任何 prompt 工程知识。

| 当你说…… | 流水线会…… |
|---|---|
| 「帮我创建一个 skill，根据中文描述生成 MySQL 建表 SQL」 | 进入引导式采集——绝不直接开写 |
| 「帮我做个自动化。」（欠规格） | 用 Q1–Q4 选择题兜底定位类型 |
| 「检查一下某个 skill 写得有没有问题」 | **拒绝**并路由到 skill linter（NOT 边界） |
| 「查日志 + 生成周报 + 自动发群，一个 skill 全搞定」 | 识别范围过大（≥3 类能力），引导你先聚焦一件 |

## 🔄 流水线流程

```text
你的输入（哪怕只有一句模糊的话）
  ↓
Phase 0 · 引导式采集 —— 准入守卫 → 4 道选择题 → 业务填空 → 回显确认 → 证据采集
  ↓ [G0：需求完整性 —— 11 项检查，缺项默认值兜底]
Phase 1 · 自动生成 —— 按模式模板产出 SKILL.md
  ↓ [G1：结构合规 —— 16 条规则，0 error 容忍]
Phase 2 · 自动评测 —— 8 维评分（结构 60% + 效果 40%）
  ↓ [G2：总分 ≥ 60/100]
Phase 3 · 自动修复循环 —— 40–59 分自动修复，最多 3 轮
  ↓ [G3：每轮新分必须高于旧分，否则回滚]
Phase 4 · 交付确认 —— 摘要、文件清单、触发词，等你拍板
```

设计理念：**选择优于描述 · 示例锚定每个空 · 回显确认再动工 · 门禁全自动 · 先 MVP 再迭代。**

## 🚦 4 道质量门禁

| 门禁 | 位置 | 检查什么 | 失败处理 |
|---|---|---|---|
| **G0** 需求完整性 | 采集结束后 | 11 项（5 项强制：做什么 / 输入 / 输出 / 样例 / 触发场景） | 追问（≤2 轮），仍缺则默认值兜底并标记 `confidence: low` |
| **G1** 结构合规 | 生成完成后 | 16 条规则：6 个结构 error、4 条安全红线（硬编码密钥 / 内网 IP / 连接串 / 破坏性操作无防护）、6 条 warning（含 3 条写作质量：description pointer 化 / 一分支一触发词 / 完成判据） | 可修复项自动修复后重检，其余展示给你人工处理 |
| **G2** 评分达标 | 评测完成后 | 8 维评分：**≥80** 优秀 · **60–79** 达标 · **40–59** 修复 · **<40** 回退 Phase 0 | 路由到 Phase 3 或 Phase 0 |
| **G3** 修复有效性 | 每轮修复后 | 新分必须 > 旧分；连续 2 轮无收益即停 | 回滚换维度重试，最终交你三选一 |

所有阈值都可在 [references/quality-gates.md](references/quality-gates.md) 按团队基线调整（`pass_score`、`max_fix_rounds`、`security_level` 等）。每次门禁结果记录到 `{skill-name}/.pipeline-log.json`。

## 📁 目录结构

```text
skill-creator-pipeline/
├── SKILL.md                     # 流程骨架：阶段、门禁、路由（流程唯一出处）
├── README.md                    # English version
├── README_zh.md                 # 本文件
├── LICENSE                      # MIT
├── test-prompts.json            # 7 条行为验证 prompt（happy / over-trigger / under-spec / 边界）
├── references/
│   ├── guided-intake.md         # 准入判断 + 引导式问答完整话术（Phase 0 唯一权威）
│   ├── type-templates.md        # 5 类 skill 的模板库与兜底默认值
│   └── quality-gates.md         # 门禁规则、阈值、团队基线、数据安全基线
├── scripts/
│   ├── pipeline-runner.sh       # G1 门禁自动化（lint / validate / gate-g1 / report）
│   └── run-claude.sh            # 评测引擎 wrapper（认证失效防护 + 瞬时故障重试）
└── evals/
    ├── eval.yaml                # 评测配置
    └── cases/                   # 8 个评测用例，锁定流水线协议行为
```

单一维护点约定：同一内容只在一处定义——SKILL.md 只保留流程骨架，问答话术、门禁规则、类型模板分别收敛在 `references/` 三个文件中。

## ✅ 不信？自己验证

本仓库吃自己的狗粮——它能通过自己的 G1 门禁：

```bash
SKILLS_ROOT=<仓库的上级目录> \
  bash scripts/pipeline-runner.sh validate skill-creator-pipeline
# → 0 errors, 0 warnings, PASS
```

[evals/cases/](evals/cases/) 里的 8 个评测用例锁定了最关键的协议行为：引导优于生成、over-trigger 拒绝路由、under-spec 选择题兜底、范围过大引导聚焦、复用裁决、写作质量 warning。可用任意 skill-up 兼容的 runner 跑 `evals/eval.yaml` 复现。

它也被自己的姊妹项目打过分：[skill-eval-optimizer](https://github.com/anthonyhann/skill-eval-optimizer) 跟踪了本流水线 **5 轮优化：76.3 → 86.3（/100）**——来自一个 **49 个生产级 agent skills、342 条评分记录**（2026-04 至 2026-10）的真实环境。

## 🧩 配套 Skill

流水线编排三种能力，均为可插拔、可降级：

| 能力 | 期望来源 | 缺失时 |
|---|---|---|
| 生成模板与写作规则 | [skill-creator](https://github.com/anthonyhann/skill-creator)——生成引擎（`npx skills add anthonyhann/skill-creator`） | —（Phase 1 必需） |
| 结构 lint | 任意 linter 脚本，路径经 `SKILL_LINTER_SCRIPT` 配置 | 内置最小规则集接管（`lint_mode: degraded`） |
| 8 维评分 | [skill-eval-optimizer](https://github.com/anthonyhann/skill-eval-optimizer)（`npx skills add anthonyhann/skill-eval-optimizer`） | 内置简化评分（`eval_mode: degraded`） |

> **两者的关系：** [skill-creator](https://github.com/anthonyhann/skill-creator) 是*引擎*（模式库、模板、写作规则、验证器）；本流水线是*装配线*（引导问答 → 质量门禁 → 评测闭环），负责驱动引擎。手动精修用 skill-creator，全程引导带门禁用本流水线。

环境变量：`SKILLS_ROOT`（skill 安装根目录，默认 `~/.claude/skills`）、`SKILL_LINTER_SCRIPT`、`SKILL_INTERNAL_DOMAIN_PATTERN`（你组织的内网域名正则，用于泄露检查）。

## ⚠️ 什么时候别用它

- **只想检查现有 skill 是否合规** → 直接用 skill linter；本流水线只负责创建。
- **想给现有 skill 打分/优化** → 用 `skill-eval-optimizer`。
- **已有 skill 的小修改**（加个触发词、改句描述） → 直接编辑它的 `SKILL.md`。
- **需要连真实外部 API 调试才能验证的 skill** → 流水线只能 dry_run。
- **超过 2 种模式组合的复杂 skill** → 先拆分；流水线也会拦下你并要求聚焦。

它也替代不了你的业务判断（「这个需求该不该做」），也不保证第一次就满分——它保证的是基线达标。

## 🤝 参与贡献

欢迎 Issue 和 PR——尤其欢迎新的评测用例，把你在意的行为锁进回归。

如果它把你团队从「skill 质量抽卡」里救了出来，**点个 star**，新门禁、新模板、新用例上线时你会第一时间知道。

## 📝 更新日志

- **2026-10-21** · v1.2.0 —— 首次开源发布：5 阶段流水线、4 道质量门禁、8 维评分、8 个评测用例、5 类 skill 模板库。

## License

MIT © [anthonyhann](https://github.com/anthonyhann) —— 详见 [LICENSE](LICENSE)。
