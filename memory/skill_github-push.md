---
name: skill_github-push
description: GitHub 推送代码：PAT 令牌认证、API 创建仓库、Git 凭据内嵌、隐私文件清除、README 规范
---

# GitHub 推送经验

## 认证方式

GitHub 已禁用密码认证，必须用 Personal Access Token：
1. 用户到 https://github.com/settings/tokens 生成 classic token，勾选 `repo` 权限
2. 拿到 `ghp_` 开头的令牌后，内嵌到 Git remote URL：
   ```
   git remote add origin https://<username>:<token>@github.com/<owner>/<repo>.git
   ```
3. 不要用 `gh auth login --with-token`，它额外要求 `read:org` 权限

## 创建仓库

如果用户没有现成仓库，通过 GitHub API 创建：
```bash
curl -X POST "https://api.github.com/user/repos" \
  -H "Authorization: token <token>" \
  -H "Content-Type: application/json" \
  -d '{"name":"<repo-name>","description":"...","private":false}'
```
注意用单引号包裹 JSON，避免 Windows bash 下双引号转义问题。

## 推送前检查

- 创建 `.gitignore`，排除 `.env.local`、`node_modules/`、临时文件（`screen*.png`、`temp_*.pdf`）
- `git status` 确认 staging 内容
- 提交用 Conventional Commits 格式，作者用 `--signoff --author="Cheney Zhang <chen.zhang@zilliz.com>"`
- 推送到 `master` 后，如果仓库默认分支是 `main`，通过 API 把默认分支改成 `master`

## 隐私保护

- 推送前必须检查文件内容是否包含用户的姓名、学号、身份证号等隐私信息
- 含隐私文件不要上传
- 如果已推送，用 `git filter-branch` 从历史彻底清除后 force push
- 不要把 token 写入任何文件，只通过环境变量或命令行传入

## README 规范

- 每个 GitHub 仓库都应有 README.md
- 内容包括：项目简介、快速开始、能力概览、目录结构、环境要求
- 中文书写，功能按类别分表格呈现
