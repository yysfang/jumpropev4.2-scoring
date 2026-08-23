# IJRU Repository Safety Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立适合新手的本地 Git 版本、发布、备份和安全回退机制，同时保留现有文件及远端历史且不执行任何远端推送。

**Architecture:** `scoring-calculator.html` 是唯一可编辑源码，`docs/index.html` 是发布副本，`versions/scoring-calculator-vX.Y.html` 是不可覆盖的发布快照。PowerShell 脚本负责发布、验证和生成 Git bundle；Git 分支、提交与标签负责回退。

**Tech Stack:** Git、PowerShell 7、单文件 HTML/CSS/JavaScript

**Spec:** 本对话中用户批准的“版本管理与回退方案”（2026-08-23）

## Global Constraints

- 不执行 `git push`，不改变 GitHub 或 GitHub Pages。
- `.workbuddy/` 与 `打分记录/` 不得被 Git 跟踪，也不得进入 Git bundle。
- 三份 IJRU v4.2.0 Markdown 规则手册与 `presentation.png` 纳入本地 Git。
- 所有已发布撤销使用新提交或 `git revert`；不得使用 `git reset --hard` 或强制推送。
- 所有本地 Git bundle 写入 `C:\Users\98432\Documents\IJRU-scoring-backups`，不自动删除旧备份。
- 当前计分器发布版本为 `v1.1`，规则版本为 `v4.2.0`。

---

### Task 1: Repository safety policy and beginner documentation

**Files:**
- Create: `.gitignore`
- Create: `.gitattributes`
- Create: `README.md`

**Interfaces:**
- Consumes: 当前静态网页目录结构和已批准的本地维护策略。
- Produces: 明确的隐私边界、换行策略和新手日常工作流。

- [ ] **Step 1:** 增加忽略规则，覆盖 `.workbuddy/`、`打分记录/`、`.worktrees/`、常见临时文件和系统文件。
- [ ] **Step 2:** 对 HTML/Markdown/PowerShell/YAML 固定 LF，对 PNG/JPG/PDF 声明 binary。
- [ ] **Step 3:** 编写中文 README，说明项目、文件角色、版本区别、分支更新流程、发布、备份和非破坏式回退。
- [ ] **Step 4:** 用 `git check-ignore -v` 验证个人目录被忽略，用 `git diff --check` 验证文本策略。
- [ ] **Step 5:** 提交为 `docs: add safe local maintenance workflow`。

### Task 2: Tested maintenance scripts

**Files:**
- Create: `scripts/new-release.ps1`
- Create: `scripts/verify-project.ps1`
- Create: `scripts/backup-repo.ps1`
- Create: `tests/maintenance-scripts.Tests.ps1`

**Interfaces:**
- `new-release.ps1 -Version <major.minor>`：拒绝非法或已存在版本；复制唯一源码到发布页与版本快照；成功后调用验证脚本。
- `verify-project.ps1 -Version <major.minor>`：检查三个 HTML 的 SHA256、必需事件/核心函数、冲突标记和隐私路径跟踪状态；任何问题退出非零。
- `backup-repo.ps1 [-Destination <absolute-directory>]`：默认写入固定 Documents 目录，以时间戳生成 `ijru-scoring-YYYYMMDD-HHmmss.bundle`，随后执行 `git bundle verify`。

- [ ] **Step 1:** 写 Pester 行为测试，覆盖正常验证、HTML 不一致、非法/重复版本、成功发布、默认/自定义 bundle 路径及 bundle 可验证性。
- [ ] **Step 2:** 运行测试并确认因三个脚本尚不存在而失败。
- [ ] **Step 3:** 实现最小脚本使测试通过；所有路径操作使用 `-LiteralPath`，已有版本不得覆盖。
- [ ] **Step 4:** 运行完整 Pester 测试并确认全部通过。
- [ ] **Step 5:** 提交为 `feat: add safe release and backup tools`。

### Task 3: Baseline verification and local release markers

**Files:**
- Verify: `scoring-calculator.html`
- Verify: `docs/index.html`
- Verify: `versions/scoring-calculator-v1.1.html`

**Interfaces:**
- Produces: 本地注释标签 `v1.1` 和经验证的完整 Git bundle。

- [ ] **Step 1:** 运行 `verify-project.ps1 -Version 1.1`。
- [ ] **Step 2:** 浏览器烟雾检查六个项目、计分更新和打印隐藏联系信息。
- [ ] **Step 3:** 创建注释标签 `v1.1`，标签说明同时写明计分器 v1.1 与 IJRU v4.2.0。
- [ ] **Step 4:** 运行 `backup-repo.ps1`，用 `git bundle verify` 验证输出。
- [ ] **Step 5:** 确认工作区干净、个人路径未跟踪、远端 HEAD 仍为实施前的 `bfaf67a`。
