<div align="center">

# Skill Creator Pipeline 🏭

### From a vague sentence to a production-ready agent skill — guided, gated, scored.

A 5-phase, 4-gate pipeline that lets **anyone** — even people who can't write prompts — ship standardized, high-quality agent skills. Guided Q&A with recommended answers + automatic quality gates + an evaluation-repair loop.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.2.0-blue?style=flat-square)](SKILL.md)
[![Quality Gates](https://img.shields.io/badge/quality%20gates-4-orange?style=flat-square)](#-the-4-quality-gates)
[![Scoring Dimensions](https://img.shields.io/badge/scoring%20dimensions-8-purple?style=flat-square)](#-the-4-quality-gates)
[![Eval Cases](https://img.shields.io/badge/eval%20cases-8-brightgreen?style=flat-square)](evals/)
[![Stars](https://img.shields.io/github/stars/anthonyhann/skill-creator-pipeline?style=flat-square)](https://github.com/anthonyhann/skill-creator-pipeline/stargazers)

[Quickstart](#-quickstart) · [How It Works](#-how-it-works) · [Quality Gates](#-the-4-quality-gates) · [Structure](#-whats-inside) · [When NOT to Use](#-when-not-to-use-it) · [中文](README_zh.md)

</div>

---

## 😮‍💨 Sound familiar?

- Everyone on the team writes skills their own way — quality depends on who wrote it, not on any standard.
- A skill works for its author, but nobody else can trigger it: the description is stuffed with 8 synonymous trigger words, and the agent routes to the wrong skill.
- Core steps say "organize the data, then output results" — with no completion criterion, so the agent declares victory halfway through.
- The people who know the business best can't express what they want in "prompt language" — so their skills never get built.

This skill replaces *depending on people's ability* with *depending on the process*: choices over descriptions, examples over blank pages, gates over opinions.

**A real intake session (zero-config text demo):**

```text
You:   帮我做个自动化。          ← one vague sentence is enough to start
Agent: 先告诉我，你想让这个 skill 帮你干什么类型的事情？选最接近的一个：
       A  查数据/排查问题（查日志、查数据库、定位 bug）
       B  生成内容/代码（建表 SQL、代码片段、文档报告）
       C  ⭐ 自动化操作（发消息、创建工单、部署上线）
       D  数据处理/对账（Excel 对比、数据清洗、报表统计）
       E  流程串联（先做 A 再做 B 再做 C 的多步骤）
       F  不确定/以上都不是
```

Every question ships with a recommended answer (⭐); every blank comes with a high-quality example. You judge *"did it understand me?"* instead of *"did I say it right?"*

## 🚀 Quickstart

**1 · Install** — paste this to your AI agent (Claude Code, Codex, Cursor, …):

> Install the skill at https://github.com/anthonyhann/skill-creator-pipeline

or run: `npx skills add anthonyhann/skill-creator-pipeline`

**2 · Trigger** — tell your agent `help me create a skill` (or `帮我创建一个 skill`), or use the explicit command `/skill-creator-pipeline`.

**3 · Answer 4 multiple-choice questions** — what it does / when it's used / where data comes from / how results look. The pipeline then generates, lints, scores, and (if needed) repairs the skill for you, and stops at a delivery summary for your confirmation.

That's it. No prompt-engineering knowledge required.

| When you say… | The pipeline… |
|---|---|
| "帮我创建一个 skill，根据中文描述生成 MySQL 建表 SQL" | Enters guided intake — never jumps straight to generation |
| "帮我做个自动化。" (under-specified) | Falls back to the Q1–Q4 choice questions to locate the type |
| "检查一下某个 skill 写得有没有问题" | **Refuses** and routes you to a skill linter (NOT-boundary) |
| "查日志 + 生成周报 + 自动发群，一个 skill 全搞定" | Detects over-scope (≥3 capabilities) and guides you to focus |

## 🔄 How It Works

```text
Your input (even one vague sentence)
  ↓
Phase 0 · Guided intake — admission guard → 4 choice questions → fill-in-blanks
          → echo confirmation → evidence capture
  ↓ [G0: requirement completeness — 11 checks, defaults fill the gaps]
Phase 1 · Auto-generation — SKILL.md drafted from pattern templates
  ↓ [G1: structural lint — 0 errors tolerated across 16 rules]
Phase 2 · Auto-evaluation — 8-dimension rubric (60% structure + 40% effectiveness)
  ↓ [G2: total score ≥ 60/100]
Phase 3 · Auto-repair loop — scores of 40–59 get up to 3 repair rounds
  ↓ [G3: each round must beat the previous score, or it rolls back]
Phase 4 · Delivery — summary, file checklist, trigger words, your confirmation
```

Design principles: **choices beat descriptions · examples anchor every blank · echo before building · gates are automatic · MVP first, then iterate.**

## 🚦 The 4 Quality Gates

| Gate | Where | What it checks | On failure |
|---|---|---|---|
| **G0** Requirement completeness | After intake | 11 items (5 mandatory: what / input / output / sample / trigger scene) | Asks again (≤2 rounds), then fills defaults and marks `confidence: low` |
| **G1** Structural compliance | After generation | 16 rules: 6 structural errors, 4 security red lines (no hardcoded secrets / internal IPs / connection strings / unguarded destructive ops), 6 warnings incl. 3 writing-quality checks (context-pointer description, one-trigger-per-branch, completion criteria) | Auto-fixes what's fixable, re-checks, escalates the rest to you |
| **G2** Score threshold | After evaluation | 8-dimension rubric; **≥80** excellent · **60–79** pass · **40–59** repair · **<40** back to Phase 0 | Routes to Phase 3 or Phase 0 |
| **G3** Repair effectiveness | Each repair round | New score must beat old score; 2 rounds without gain stops the loop | Rolls back, tries another dimension, then asks you to decide |

All thresholds are team-tunable in [references/quality-gates.md](references/quality-gates.md) (`pass_score`, `max_fix_rounds`, `security_level`, …). Every gate run is logged to `{skill-name}/.pipeline-log.json`.

## 📁 What's Inside

```text
skill-creator-pipeline/
├── SKILL.md                     # Pipeline skeleton: phases, gates, routing (single source of flow)
├── README.md                    # This file
├── README_zh.md                 # 中文版
├── LICENSE                      # MIT
├── test-prompts.json            # 7 behavior prompts (happy / over-trigger / under-spec / boundary)
├── references/
│   ├── guided-intake.md         # Admission routing + full Q&A scripts (Phase 0 authority)
│   ├── type-templates.md        # 5 skill-type template libraries with fallback defaults
│   └── quality-gates.md         # Gate rules, thresholds, team baseline, data-safety baseline
├── scripts/
│   ├── pipeline-runner.sh       # G1 gate automation (lint / validate / gate-g1 / report)
│   └── run-claude.sh            # Eval engine wrapper (auth-failure guard + transient-error retry)
└── evals/
    ├── eval.yaml                # Eval config
    └── cases/                   # 8 eval cases locking the pipeline's protocol behavior
```

Single-source-of-truth convention: each topic lives in exactly one file — SKILL.md keeps only the flow skeleton; Q&A scripts, gate rules, and type templates live in `references/`.

## ✅ Verify It Yourself

This repo eats its own cooking — it passes its own G1 gate:

```bash
SKILLS_ROOT=<parent-dir-of-the-repo> \
  bash scripts/pipeline-runner.sh validate skill-creator-pipeline
# → 0 errors, 0 warnings, PASS
```

The 8 eval cases in [evals/cases/](evals/cases/) lock the protocol behaviors that matter: guided intake over blind generation, over-trigger refusal, under-spec fallback, over-scope focusing, reuse verdict, and the writing-quality warnings. Run them with any skill-up-compatible runner against `evals/eval.yaml`.

It has also been scored by its own sibling: [skill-eval-optimizer](https://github.com/anthonyhann/skill-eval-optimizer) tracked this pipeline over **5 optimization rounds, 76.3 → 86.3 / 100** — inside a production fleet of **49 agent skills** with **342 scored records** (2026-04 → 2026-10).

## 🧩 Companion Skills

The pipeline orchestrates three capabilities. Each is pluggable and degrades gracefully:

| Capability | Expected from | If missing |
|---|---|---|
| Generation templates & writing rules | [skill-creator](https://github.com/anthonyhann/skill-creator) — the generation engine (`npx skills add anthonyhann/skill-creator`) | — (required for Phase 1) |
| Structural lint | any linter script, path via `SKILL_LINTER_SCRIPT` | Built-in minimal checks take over (`lint_mode: degraded`) |
| 8-dimension scoring | [skill-eval-optimizer](https://github.com/anthonyhann/skill-eval-optimizer) (`npx skills add anthonyhann/skill-eval-optimizer`) | Built-in simplified scoring (`eval_mode: degraded`) |

> **How they relate:** [skill-creator](https://github.com/anthonyhann/skill-creator) is the *engine* (patterns, templates, writing rules, validators); this pipeline is the *assembly line* (intake → gates → eval loop) that drives it. Use skill-creator alone for hands-on generation, or this pipeline for the full guided, gated flow.

Environment knobs: `SKILLS_ROOT` (skill install root, default `~/.claude/skills`), `SKILL_LINTER_SCRIPT`, `SKILL_INTERNAL_DOMAIN_PATTERN` (your org's internal-domain regex for the leak check).

## ⚠️ When NOT to Use It

- **You just want to lint an existing skill** → use a skill linter directly; this pipeline only creates.
- **You want to score or optimize an existing skill** → use `skill-eval-optimizer`.
- **Small tweaks to an existing skill** (a trigger word, a description fix) → just edit its `SKILL.md`.
- **Skills that need live external-API debugging to verify** → the pipeline can only `dry_run` those.
- **A monster skill combining >2 patterns** → split it first; the pipeline will push back and ask you to focus.

It also can't replace your business judgment ("should this exist at all?"), and it doesn't guarantee a perfect score on the first pass — it guarantees the baseline.

## 🤝 Contributing

Issues and PRs welcome — especially new eval cases that lock behaviors you care about.

If this saved your team from skill-quality roulette, **star the repo** to get notified when new gates, templates, and eval cases land.

## 📝 Changelog

- **2026-10-21** · v1.2.0 — first public open-source release: 5-phase pipeline, 4 quality gates, 8-dimension scoring, 8 eval cases, 5 skill-type template libraries.

## License

MIT © [anthonyhann](https://github.com/anthonyhann) — see [LICENSE](LICENSE).
