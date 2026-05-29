# CLAUDE.md

## ⚠️ 语言要求（最高优先级）
> **全程中文。所有输出、提问、系统对话框均用中文。代码/命令/路径/API 名保持原文。**

## 启动
- `npm run claude` — 启动（DeepSeek 代理 @ `scripts/deepseek-claude-proxy.cjs`）
- 配置：`.env.local`（已 gitignore）

## ⚠️ 搜索规则
> **本地脚本（首选）→ WebFetch → WebSearch。本地脚本永不失效！**

1. **本地脚本** — `node scripts/tavily-search.cjs search "<关键词>" [max_results]`
   - 使用 Tavily 官方 API Key，无 session 过期问题，100% 可靠
2. **WebFetch** → 3. **WebSearch**（仅前两者无效时使用）
- Agent 结论要亲自验证

## 权限
- 只读操作（查文件/应用/安装位置）可直接执行，无需确认

## Skills
- **find-skills** — `npx skills find/add/check/update`，先查 skills.sh 排行 → 验证(安装量>1K) → 推荐
- **experiment-report-writer** — ML 科研模板，通用实验需调结构
- **experiment-report-writer-2** — python-docx + Pillow 仿真截图，详见 `memory/skill_experiment-report-writer-2.md`
- **ocr** — PaddleOCR(CPU)：`.agents/skills/ocr/scripts/ocr.py <路径> --fast`；Claude Vision 后备用于表格/布局

## 能力速查
- **中文编码** — Python: `sys.stdout.buffer.write(text.encode('utf-8'))`；PDF: pymupdf
- **Computer Use** — 截屏+视觉操作桌面
- **Browser** — MCP 优先，Playwright 备选
- **React/Next.js** — 瀑布消除、打包优化、SSR 性能
- **Node.js** — 错误处理、中间件、DI、异步流
- **数据库** — SQL 优化、索引、N+1、零停机迁移

## 工作流
- 学 skill：记 `memory/skill_{name}.md` → 更新 MEMORY.md → 更新本文件 → settings.local.json 加钩子
- 自我改进：错误/纠正 → 记 `.learnings/`，广泛适用则推广 memory
- 实验报告完成后：删除桌面截图、脚本等临时文件
