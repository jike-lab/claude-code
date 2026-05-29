---
name: experiment-report-writer-2
description: python-docx 操作 .docx + Pillow 仿真截图的关键经验
metadata:
  type: skill
---

# 实验报告写作 skill（补充经验）

## 核心工具链
- **python-docx** 操作 `.docx` 文件（段落、run、图片、表格、XML）
- **Pillow** 生成仿真网页截图（无需真实部署服务器）
- **python-docx** 是操作 `.docx` 的唯一可靠方式，不要尝试手动改 ZIP/XML

## 关键坑点与解决方案

### 0. Pillow 生成仿真网页截图
- 用 `Image.new("RGB")` + `ImageDraw` 绘制模拟浏览器窗口
- **浏览器结构**：灰色标题栏（显示 ● ● ● + 标题）→ 白色地址栏 → 页面内容区
- **推荐抽象**：页面元素用字典列表表示，类型字段用单字母缩写
  - `t`=title标题, `x`=text文本, `i`=input输入框, `b`=button按钮, `r`=result结果
  - `-`=separator分隔线, `h`=table_header表头, `R`=table_row表格行
  - 坐标字段：`s`=size字号, `v`=value输入值, `c`=cols列内容, `cw`=col_width列宽
  - 所有 y 坐标相对于内容区起始（y0=80），方便整体下移
- **代码截图**：深色背景 `(40,44,52)` + 行号 + Consolas 等宽字体
  - 用 `getbbox()` 计算动态宽度，标题栏高度固定 36px

### 1. 在模板 docx 中插入内容（addnext 法）
- **绝对不能重建 body**，否则多次运行会重复插入
- 用 `addnext()` 在目标 XML 元素后插入新元素
  ```python
  target = None
  for child in body:
      if child.tag == qn("w:p"):
          ts = child.findall(".//"+qn("w:t"))
          txt = "".join(t.text or "" for t in ts)
          if "4、核心代码" in txt: target = child
  # 逆序插入保证顺序正确
  for elem in reversed(insert_list):
      target.addnext(elem)
  ```
- **每次运行前确保模板是干净的**（原始模板 ~23KB / 32段落）
- 被污染的特征：文件大小暴涨（23KB → 300KB+），段落重复

### 2. 表格表头格式（标签无下划线 + 内容有下划线）
- 在单元格内放两个段落（`<w:p>`），第一个放标签（无下划线），第二个放内容（有下划线）
- 下划线用 `run.underline = True`，不要用边框线
- 对齐用全角空格 `　` 调整

### 3. 图片插入（务必用 add_picture）
- `run.add_picture(path, width)` 是唯一可靠的方式
- 不要手动 `Part()` 构造图片——本地有缓存能显示，换台机器就看不到
- 图片段落插入到 body：用 `addnext` 而非重建 body

### 4. WPS 红色波浪线无法通过 XML 去除
- `w:noProof` / `w:proofState` 对 WPS 无效
- 必须在 UI 手动关闭：左上角 logo → 选项 → 拼写检查

### 5. 字体单位陷阱
- `<w:sz>` 的 val 单位是 half-pt（半磅），pt × 2
  - 12pt → val=24（不是 12，也不是 1200）
  - 22pt → val=44

### 6. 构建策略
- **推荐：addnext 增量插入法**——打开模板 → 找到目标段落 → addnext 插入
- 避免模板修改法导致的 IndexError 和内容重复

### 7. Windows 中文编码
- Python 输出中文：`sys.stdout.buffer.write(text.encode('utf-8'))`
- 或在脚本开头：`sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')`
- 读中文 PDF：pymupdf（`import fitz`）
- Bash heredoc 在 Windows 下可能 exit code 49，改用写文件执行

### 8. 文件锁定问题
- WPS 打开文件时会锁定，python-docx 写入 PermissionError
- 解决方案：复制到临时文件，修改，再覆盖回去

### 9. 生成后验证
- 遍历 `doc.paragraphs` 打印段落文本，确认模板内容顺序正确
- 检查文件大小：原始模板 ~23KB，含图片后 300-400KB
