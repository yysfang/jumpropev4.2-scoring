# IJRU Rules 计分系统

这是一个基于 IJRU V4.2 规则的静态网页计分器。项目不需要安装依赖：用浏览器直接打开 HTML 文件即可使用；发布时将静态文件部署到网站托管服务即可。

## 文件角色

| 路径 | 用途 |
| --- | --- |
| `scoring-calculator.html` | 当前维护中的计分器主文件，也是本地直接打开时的入口。 |
| `docs/index.html` | 面向网站托管的发布入口。 |
| `versions/` | 历史版本快照，仅用于对比、追溯和回退参考。 |
| `IJRU_*_Manual_v4.2.0.md` | 计分规则的本地参考资料。 |
| `presentation.png` | 项目展示图片。 |
| `.workbuddy/` | 个人工具工作目录；被 Git 忽略，不共享。 |
| `打分记录/` | 个人/赛事计分记录；被 Git 忽略，不共享。 |

## 版本区别

- 当前计分器的发布版本为 **v1.1**，计分规则版本为 **V4.2.0**。
- 根目录的 `scoring-calculator.html` 是当前本地维护版本；`docs/index.html` 是与其对应的网站发布入口。准备发布 v1.1 的后续维护版本前，应先确认两个入口包含同一份准备上线的内容。
- `versions/scoring-calculator-v1.0.html` 和 `versions/scoring-calculator-v1.1.html` 是历史快照，不应当作日常编辑入口。
- 规则资料标注为 V4.2.0；修改计分逻辑时先核对相应规则资料，再更新当前维护版本。

## 新手日常工作流

1. 开始前确认个人文件仍在忽略范围内：`.workbuddy/`、`打分记录/` 和 `.worktrees/` 均不应提交。
2. 查看工作区状态：`git status --short`。只处理自己预期的改动；看到不认识的文件时先停下确认。
3. 从主线创建一个描述明确的分支，例如：`git switch -c docs/clarify-scoring-note`。
4. 只编辑需要变更的文件，用浏览器打开 `scoring-calculator.html` 或 `docs/index.html` 验证效果。
5. 检查改动：`git diff --check` 和 `git diff`；确认没有计分记录、个人配置或意外文件。
6. 暂存明确文件（例如 `git add README.md`），提交前再执行一次 `git status --short`，然后用清晰的中文或英文说明提交原因。

## 获取主线更新

先保存或提交当前工作，再以快进方式更新主线。下列 `rebase` 流程仅适用于**尚未共享、未用于发布的个人分支**：

```powershell
git switch main
git pull --ff-only
git switch <你的分支>
git rebase main
```

若 `rebase` 出现冲突，先检查冲突文件并手动解决；不确定时可用 `git rebase --abort` 回到 rebase 前，再寻求协助。不要用强制覆盖命令处理陌生改动。

已经共享或用于发布的分支不得执行 `rebase`，以免改写他人或发布历史；改用 `git merge main`，或在 `main` 最新提交上新建分支并通过新的提交完成修改。任何情况下都不要使用强制推送（`git push --force` 或 `git push --force-with-lease`）。

## 发布

发布前在本机打开 `docs/index.html`，检查计分交互、文案和规则版本。发布内容应来自已提交的分支或已确认的 `main`，并保留发布所用提交号，便于追溯。发布后用公开地址做一次基本的页面与交互检查。

## 备份与非破坏式回退

- 本地 Git bundle 是代码备份的固定落点，必须写入 `C:\Users\98432\Documents\IJRU-scoring-backups`；不要把远程仓库当作唯一备份。创建备份时仅追加新的 bundle，绝不自动删除旧 bundle：

  ```powershell
  $backupDir = 'C:\Users\98432\Documents\IJRU-scoring-backups'
  New-Item -ItemType Directory -Force -Path $backupDir
  $bundle = Join-Path $backupDir ("ijru-scoring-$(Get-Date -Format 'yyyyMMdd-HHmmss').bundle")
  git bundle create $bundle --all
  ```

  定期将该目录复制到另一受控位置；保留目录内的全部旧 bundle，便于恢复到任一备份点。
- 个人计分记录另行备份到受控的本地或云端位置，且不要把它们提交到本仓库。
- 在尝试较大修改前先提交一个可说明的检查点，或创建分支；不要直接覆盖现有文件。
- 需要查看旧版本时使用 `git log --oneline`、`git show <提交号> -- <文件>` 或 `versions/` 中的快照。
- 需要撤销已提交的改动时，优先创建一个反向提交：`git revert <提交号>`。这样保留历史，也不会破坏其他人的工作。
- 对未提交改动，先用 `git diff` 审查；不确定时复制文件或先新建分支。避免使用会丢弃工作区内容的命令。

## 文本与隐私约定

HTML、Markdown、PowerShell 和 YAML 文件统一使用 LF 换行；PNG、JPG 和 PDF 按二进制文件处理。`.gitignore` 中列出的个人目录和临时文件不得通过强制添加方式绕过忽略规则。
