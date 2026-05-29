---
name: find-skills
description: 帮助用户发现和安装 skills 生态系统中的代理技能，通过 Skills CLI 搜索、验证和安装
metadata:
  type: skill
---

# find-skills 技能

来源: [ModelScope - vercel-labs/find-skills](https://www.modelscope.cn/skills/@vercel-labs/find-skills)
源码: https://github.com/vercel-labs/skills/tree/main/skills/find-skills

## 何时使用

当用户：
- 问"我如何做X"——X 可能是已有 skill 的常见任务
- 说"找一个能X的技能"或"有没有可以X的技能"
- 问"你能做X吗"——X 是某种 specialized 能力
- 表示想扩展 agent 能力
- 想搜索工具、模板或工作流
- 提到希望某个领域（设计、测试、部署等）有帮助

## Skills CLI 命令

| 命令 | 说明 |
|------|------|
| `npx skills find [query]` | 搜索技能（交互式或关键词） |
| `npx skills add <package>` | 从 GitHub 等源安装技能 |
| `npx skills check` | 检查技能更新 |
| `npx skills update` | 更新所有已安装技能 |
| `npx skills init` | 创建自己的技能 |

浏览技能: https://skills.sh/

## 使用流程

### Step 1: 理解需求
确定：领域（React/测试/设计/部署）、具体任务、是否是常见任务

### Step 2: 查看排行榜
先查 https://skills.sh/ 看热门技能：
- `vercel-labs/agent-skills` — React、Next.js、Web 设计（10万+安装）
- `anthropics/skills` — 前端设计、文档处理（10万+安装）

### Step 3: 搜索技能
```bash
npx skills find [query]
```
例如：
- `npx skills find react performance`
- `npx skills find pr review`
- `npx skills find changelog`

### Step 4: 验证质量
- **安装量**: 优先选 1K+ 的，100 以下谨慎
- **来源信誉**: 官方源（vercel-labs、anthropics、microsoft）更可信
- **GitHub stars**: 来源仓库 <100 stars 需谨慎

### Step 5: 推荐给用户
提供：技能名称与功能、安装量和来源、安装命令、skills.sh 链接

### Step 6: 安装
用户确认后：
```bash
npx skills add <owner/repo@skill> -g -y
```

## 常见技能分类

| 分类 | 搜索关键词 |
|------|-----------|
| Web 开发 | react, nextjs, typescript, css, tailwind |
| 测试 | testing, jest, playwright, e2e |
| DevOps | deploy, docker, kubernetes, ci-cd |
| 文档 | docs, readme, changelog, api-docs |
| 代码质量 | review, lint, refactor, best-practices |
| 设计 | ui, ux, design-system, accessibility |
| 效率 | workflow, automation, git |

## 搜索技巧
1. 使用具体关键词："react testing" 优于 "testing"
2. 尝试替代词：如果 "deploy" 不行，试 "deployment" 或 "ci-cd"
3. 检查热门源：vercel-labs/agent-skills、ComposioHQ/awesome-claude-skills

## 没找到技能时
1. 告知用户没有找到相关技能
2. 表示可以直接用通用能力帮助完成任务
3. 建议用户用 `npx skills init` 创建自己的技能
