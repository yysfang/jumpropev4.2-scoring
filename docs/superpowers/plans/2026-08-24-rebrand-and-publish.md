# 国际规则花样算分改名与发布计划

**Goal:** 将现有静态计分器去官方化、移除全部引流信息，作为 v1.2 发布，并把 GitHub 仓库改名为 `jumpropev4.2-scoring`。

**Architecture:** `scoring-calculator.html` 继续作为唯一可编辑源码；`docs/index.html` 是 GitHub Pages 发布页；`versions/scoring-calculator-v1.2.html` 是新版本快照。品牌规则由 `verify-project.ps1` 自动执行，远端改名和发布由控制器在本地审查通过后串行完成。

## Global Constraints

- 页面浏览器标题和页首可见名称必须是“国际规则花样算分”，副标题只显示“V4.2”。
- 所有当前 HTML 文件必须移除 `IJRU` 品牌标题、`Championship Scoring System`、`加入跳绳圈`、`方泽伟 Richard`、`a17724605074` 及完整联系方式区块。
- v1.0、v1.1 当前工作区快照一并清理，但不重写 Git 历史；规则手册中的 IJRU 原始出处和内部校验变量不改。
- README 必须使用中性名称，并说明这是个人维护的非官方工具。
- 新版本为 `v1.2`；源码、发布页和 v1.2 快照必须字节一致。
- `.workbuddy/`、`打分记录/`、`.worktrees/` 不得被 Git 跟踪或进入任何 bundle。
- 发布前后均创建并验证完整 bundle；不强推，不重写历史。
- 远端只推送 `main` 和 `v1.2` 标签；安全分支及恢复标签保持本地。
- Pages 继续使用 `main/docs`；旧 Pages 地址不建立跳转。

### Task 1: Test-driven rebrand, cleanup, and v1.2 release files

**Files:**
- Modify: `tests/maintenance-scripts.Tests.ps1`
- Modify: `scripts/verify-project.ps1`
- Modify: `scoring-calculator.html`
- Modify: `docs/index.html`
- Modify: `versions/scoring-calculator-v1.0.html`
- Modify: `versions/scoring-calculator-v1.1.html`
- Create: `versions/scoring-calculator-v1.2.html`
- Modify: `README.md`

**Required behavior:**
- 先增加真实行为测试：验证器应在任一当前 HTML 中出现旧品牌或引流文字时退出非零，并在干净的 v1.2 项目上通过；测试必须先在旧实现上按预期失败。
- 扩展 `verify-project.ps1 -Version <major.minor>`：除原有完整性、脚本和隐私检查外，扫描仓库当前 HTML，拒绝 `IJRU`、`Championship Scoring System`、`加入跳绳圈`、`方泽伟 Richard` 和 `a17724605074`；当前发布三件套必须包含“国际规则花样算分”和可见副标题“V4.2”。
- 将所有当前 HTML 的浏览器标题与页首改为“国际规则花样算分”，副标题只留“V4.2”；删除联系方式块和仅为该块服务的 `.noprint` 打印规则。
- 清理 v1.0、v1.1 当前快照，然后用 `new-release.ps1 -Version 1.2` 生成发布页和不覆盖的 v1.2 快照。
- README 标题改为“国际规则花样算分”，将项目描述为基于国际跳绳规则 v4.2.0 整理的个人维护、非官方工具；保留安全发布、备份和回退说明，并把当前发布版本更新为 v1.2。
- 运行完整 Pester、`verify-project.ps1 -Version 1.2`、`git diff --check`；确认源码、发布页和 v1.2 快照 SHA256 一致，并确认当前 HTML 不含全部禁用文字。
- 提交清晰的本地 Git 提交，不创建标签、不推送、不修改远端；在报告中记录 RED 和 GREEN 证据。

## Controller-owned deployment

- 审查通过后创建并验证发布前最终 bundle，创建注释标签 `v1.2`。
- 将 `yysfang/ijru-scoring` 改名为 `yysfang/jumpropev4.2-scoring`，更新本地 `origin`，设置中性仓库描述与新 Pages 地址。
- 推送 `main` 与 `v1.2`，等待 Pages 状态为 built，并在新网址完成标题、六赛事、计分、重置、手机和打印布局、控制台检查。
- 发布后再次创建并验证完整 bundle，核对远端 SHA、标签、Pages 来源和隐私路径。
