# Claude Code 工作区

个人 Claude Code 配置与技能集合，支持 DeepSeek 代理、搜索增强、自动化脚本和 AI 辅助编程。

## 快速开始

```bash
npm install
npm run claude
```

通过 DeepSeek 代理启动 Claude Code，配置文件在 `.env.local`。

## 能力概览

### AI 编程技能（10+）

| 技能 | 用途 |
|------|------|
| 代码审查 | 坏味道检测、复杂度评估、技术债务分析 |
| Git 工作流 | 分支管理、提交签名、PR 创建与合并 |
| GitHub 仓库管理 | 全生命周期：创建、推送、分支、PR |
| 数据库 | SQL 优化、索引策略、零停机迁移 |
| React/Next.js | 性能优化、SSR、打包分析 |
| Node.js | 错误处理、中间件、DI、异步流 |
| Python 代码质量 | ruff lint/format、pre-commit、CI 门禁 |
| QA 安全重构 | 行为保持重构、坏味道目录、遗留代码现代化 |

### 自动化

- **OCR** — PaddleOCR 文字提取，Claude Vision 结构理解后备
- **搜索** — Tavily API 本地脚本，100% 可靠
- **浏览器自动化** — MCP + Playwright
- **桌面操作** — Computer Use 截图+视觉操控

### 实验报告生成

python-docx + Pillow 生成仿真实验报告，支持表格、图片嵌入。

## 目录结构

```
├── .agents/skills/    # Agent 技能定义
├── .claude/           # Claude Code 配置和本地设置
├── memory/            # 持久化经验记忆
├── scripts/           # 启动、代理、搜索脚本
├── prompts/           # 提示词模板
├── assets/            # 图标和桌面宠物资源
├── docs/              # 文档
└── .env.local         # 环境变量（已 gitignore）
```

## 环境要求

- Node.js 18+
- Python 3.9+（OCR 模块）
- Windows（桌面宠物和启动脚本针对 Windows）
