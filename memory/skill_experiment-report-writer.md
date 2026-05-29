---
name: experiment-report-writer
description: 结构化实验报告写作 skill，将实验证据（配置、日志、指标、图表）转为清晰的研究报告
metadata:
  type: skill
---

# experiment-report-writer 技能

已安装（全局安装，symlink 到 Claude Code）
- 来源: `a-green-hand-jack/ml-research-skills@experiment-report-writer` (42 installs)
- 安装路径: `~/.agents/skills/experiment-report-writer/`

## 核心原则

1. 每个主张都要有证据支撑（配置、命令、日志、指标、图表、commit hash）
2. 观察结果和解释分开，不要把假设当作测量事实
3. 报告要可复现
4. 解释实验为什么重要
5. 与正确的参考点比较（基线、前一次运行、消融控制、预期行为、已发表数据）
6. 保持不确定性，缺失证据要标明
7. 根据目标受众调整写作风格

## 报告模式

- `single-experiment` — 单次运行或受控比较
- `ablation-report` — 多个变体测试一个因素
- `batch-summary` — 批量运行的总结
- `mentor-update` — 简洁的进度报告
- `paper-section` — 论文级别的精炼文本

## 默认报告结构

```markdown
# [标题]
## Summary
## 1. Experiment Motivation
## 2. Experiment Setup
## 3. Core Algorithm or Method
## 4. Metrics
## 5. Results
## 6. How to Read the Figures
## 7. Interpretation
## 8. Conclusion and Discussion
## 9. Limitations and Caveats
## 10. Next Steps
## Reproducibility Notes
```

## 模板路径
`~/.agents/skills/experiment-report-writer/templates/experiment-report.md`

## 注意事项

- 这个 skill 偏 ML/AI 科研实验报告，对通用的计算机实验（数据结构、OS、网络等）格式偏科研化
- 使用时需要根据实际实验类型调整结构
- 可以与 `research-project-memory` 配合使用
