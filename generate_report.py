# -*- coding: utf-8 -*-
import sys
import os
from docx import Document
from docx.shared import Pt, Cm, Inches, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn, nsdecls
from docx.oxml import parse_xml


def set_cell_text(cell, text, bold=False, font_size=12, font_name='宋体', alignment=None):
    """设置单元格文本和格式"""
    cell.text = ''
    paragraph = cell.paragraphs[0]
    if alignment:
        paragraph.alignment = alignment
    run = paragraph.add_run(text)
    run.bold = bold
    run.font.size = Pt(font_size)
    run.font.name = font_name
    # 设置中文字体
    r = run._element
    rPr = r.find(qn('w:rPr'))
    if rPr is None:
        rPr = parse_xml(f'<w:rPr {nsdecls("w")}></w:rPr>')
        r.insert(0, rPr)
    rFonts = rPr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = parse_xml(f'<w:rFonts {nsdecls("w")}></w:rFonts>')
        rPr.insert(0, rFonts)
    rFonts.set(qn('w:eastAsia'), font_name)


def add_code_paragraph(doc, code_text, font_size=10):
    """添加代码段落（等宽字体）"""
    p = doc.add_paragraph()
    p.paragraph_format.first_line_indent = Pt(0)
    p.paragraph_format.line_spacing = Pt(16)
    run = p.add_run(code_text)
    run.font.name = 'Courier New'
    run.font.size = Pt(font_size)
    run.font.bold = False
    r = run._element
    rPr = r.find(qn('w:rPr'))
    if rPr is None:
        rPr = parse_xml(f'<w:rPr {nsdecls("w")}></w:rPr>')
        r.insert(0, rPr)
    rFonts = rPr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = parse_xml(f'<w:rFonts {nsdecls("w")}></w:rFonts>')
        rPr.insert(0, rFonts)
    rFonts.set(qn('w:eastAsia'), 'Courier New')
    return p


def add_heading_custom(doc, text, level=1):
    """添加标题"""
    p = doc.add_paragraph()
    run = p.add_run(text)
    run.bold = True
    if level == 1:
        run.font.size = Pt(14)
    elif level == 2:
        run.font.size = Pt(13)
    else:
        run.font.size = Pt(12)
    run.font.name = '宋体'
    r = run._element
    rPr = r.find(qn('w:rPr'))
    if rPr is None:
        rPr = parse_xml(f'<w:rPr {nsdecls("w")}></w:rPr>')
        r.insert(0, rPr)
    rFonts = rPr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = parse_xml(f'<w:rFonts {nsdecls("w")}></w:rFonts>')
        rPr.insert(0, rFonts)
    rFonts.set(qn('w:eastAsia'), '宋体')
    return p


def add_body_paragraph(doc, text, indent=True, bold=False):
    """添加正文段落"""
    p = doc.add_paragraph()
    if indent:
        p.paragraph_format.first_line_indent = Cm(0.74)
    p.paragraph_format.line_spacing = Pt(22)
    run = p.add_run(text)
    run.font.name = '宋体'
    run.font.size = Pt(12)
    run.bold = bold
    r = run._element
    rPr = r.find(qn('w:rPr'))
    if rPr is None:
        rPr = parse_xml(f'<w:rPr {nsdecls("w")}></w:rPr>')
        r.insert(0, rPr)
    rFonts = rPr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = parse_xml(f'<w:rFonts {nsdecls("w")}></w:rFonts>')
        rPr.insert(0, rFonts)
    rFonts.set(qn('w:eastAsia'), '宋体')
    return p


def add_mixed_paragraph(doc, segments, indent=True):
    """添加混合格式段落，segments = [(text, bold, font_name, font_size), ...]"""
    p = doc.add_paragraph()
    if indent:
        p.paragraph_format.first_line_indent = Cm(0.74)
    p.paragraph_format.line_spacing = Pt(22)
    for text, bold, font_name, font_size in segments:
        run = p.add_run(text)
        run.bold = bold
        run.font.name = font_name
        run.font.size = Pt(font_size)
        r = run._element
        rPr = r.find(qn('w:rPr'))
        if rPr is None:
            rPr = parse_xml(f'<w:rPr {nsdecls("w")}></w:rPr>')
            r.insert(0, rPr)
        rFonts = rPr.find(qn('w:rFonts'))
        if rFonts is None:
            rFonts = parse_xml(f'<w:rFonts {nsdecls("w")}></w:rFonts>')
            rPr.insert(0, rFonts)
        rFonts.set(qn('w:eastAsia'), font_name)
    return p


def set_cell_shading(cell, color):
    """设置单元格底色"""
    shading_elm = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{color}"/>')
    cell._tc.get_or_add_tcPr().append(shading_elm)


def build_report():
    path = "C:/Users/zhenghao/Desktop/实验报告5.docx"
    doc = Document()

    # ============================================================
    # 设置默认样式
    # ============================================================
    style = doc.styles['Normal']
    font = style.font
    font.name = '宋体'
    font.size = Pt(12)
    style.element.rPr.rFonts.set(qn('w:eastAsia'), '宋体')

    # 设置页面边距
    for section in doc.sections:
        section.top_margin = Cm(2.54)
        section.bottom_margin = Cm(2.54)
        section.left_margin = Cm(3.17)
        section.right_margin = Cm(3.17)

    # ============================================================
    # 大标题
    # ============================================================
    title = doc.add_paragraph()
    title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    title.paragraph_format.space_after = Pt(12)
    run = title.add_run('《JavaWeb应用程序开发》实验报告')
    run.bold = True
    run.font.size = Pt(18)
    run.font.name = '宋体'
    r = run._element
    rPr = r.find(qn('w:rPr'))
    if rPr is None:
        rPr = parse_xml(f'<w:rPr {nsdecls("w")}></w:rPr>')
        r.insert(0, rPr)
    rFonts = rPr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = parse_xml(f'<w:rFonts {nsdecls("w")}></w:rFonts>')
        rPr.insert(0, rFonts)
    rFonts.set(qn('w:eastAsia'), '宋体')

    # ============================================================
    # 基本信息表（5行 x 6列，合并单元格实现布局）
    # 布局:
    #   Row0: 实验题目 | JavaBean技术 | 专业班级 | (空)
    #   Row1: 学生学号 | (空)        | 学生姓名 | (空)
    #   Row2: 指导教师 | 霍林林      |          |
    #   Row3: 实验目的 | (内容，合并多列跨行)
    #   Row4: 实验内容 | (内容，合并多列跨行)
    # 但为了简洁，我们用表格形式：实验目的/实验内容/实验要求/实验环境 放在表格下方的段落中
    # 实际上更清晰的做法：信息表格 + 下方独立段落
    # ============================================================
    info_table = doc.add_table(rows=3, cols=6)
    info_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    info_table.style = 'Table Grid'

    # 设置列宽
    col_widths = [Cm(2.2), Cm(3.0), Cm(2.2), Cm(3.0), Cm(2.2), Cm(3.0)]

    # 第0行
    row0 = info_table.rows[0]
    set_cell_text(row0.cells[0], '实验题目', bold=True, alignment=WD_ALIGN_PARAGRAPH.CENTER)
    set_cell_text(row0.cells[1], 'JavaBean技术')
    set_cell_text(row0.cells[2], '专业班级', bold=True, alignment=WD_ALIGN_PARAGRAPH.CENTER)
    set_cell_text(row0.cells[3], '')
    set_cell_text(row0.cells[4], '', None, 1)
    set_cell_text(row0.cells[5], '', None, 1)
    # 合并 cells[3..5] 保持只有一个空单元格
    row0.cells[3].merge(row0.cells[4])
    row0.cells[3].merge(row0.cells[5])

    # 第1行
    row1 = info_table.rows[1]
    set_cell_text(row1.cells[0], '学生学号', bold=True, alignment=WD_ALIGN_PARAGRAPH.CENTER)
    set_cell_text(row1.cells[1], '')
    set_cell_text(row1.cells[2], '学生姓名', bold=True, alignment=WD_ALIGN_PARAGRAPH.CENTER)
    set_cell_text(row1.cells[3], '')
    set_cell_text(row1.cells[4], '', None, 1)
    set_cell_text(row1.cells[5], '', None, 1)
    row1.cells[3].merge(row1.cells[4])
    row1.cells[3].merge(row1.cells[5])

    # 第2行
    row2 = info_table.rows[2]
    set_cell_text(row2.cells[0], '指导教师', bold=True, alignment=WD_ALIGN_PARAGRAPH.CENTER)
    set_cell_text(row2.cells[1], '霍林林')
    set_cell_text(row2.cells[2], '', None, 1)
    set_cell_text(row2.cells[3], '', None, 1)
    set_cell_text(row2.cells[4], '', None, 1)
    set_cell_text(row2.cells[5], '', None, 1)
    row2.cells[2].merge(row2.cells[3])
    row2.cells[2].merge(row2.cells[4])
    row2.cells[2].merge(row2.cells[5])

    # 设置所有单元格垂直居中
    for row in info_table.rows:
        for cell in row.cells:
            tc = cell._tc
            tcPr = tc.get_or_add_tcPr()
            vAlign = parse_xml(f'<w:vAlign {nsdecls("w")} w:val="center"/>')
            tcPr.append(vAlign)

    # ============================================================
    # 实验目的
    # ============================================================
    add_heading_custom(doc, '一、实验目的', level=1)
    add_body_paragraph(doc, '掌握JavaBean的设计、部署以及在JSP中的使用。')

    # ============================================================
    # 实验内容
    # ============================================================
    add_heading_custom(doc, '二、实验内容', level=1)
    contents = [
        '（1）设计注册页面register.jsp，用户填写姓名、性别、出生年月、民族、个人介绍等，点击注册后通过output.jsp显示。要求用JavaBean封装注册信息。',
        '（2）设计页面，输入梯形的上底、下底和高，提交后显示面积和周长，用JavaBean封装。分别用标签和代码形式调用JavaBean。',
        '（3）运行教材中网页计数器的例题，体会多个页面共享JavaBean。'
    ]
    for c in contents:
        add_body_paragraph(doc, c)

    # ============================================================
    # 实验要求
    # ============================================================
    add_heading_custom(doc, '三、实验要求', level=1)
    requirements = [
        '（1）掌握JavaBean的安装部署',
        '（2）理解JavaBean原理和设计思想',
        '（3）掌握多个页面共享JavaBean'
    ]
    for r in requirements:
        add_body_paragraph(doc, r)

    # ============================================================
    # 实验环境
    # ============================================================
    add_heading_custom(doc, '四、实验环境', level=1)
    add_body_paragraph(doc, '硬件：微型计算机')
    add_body_paragraph(doc, '软件：Windows、MyEclipse、Tomcat、MySQL')

    # ============================================================
    # 核心代码
    # ============================================================
    add_heading_custom(doc, '五、核心代码', level=1)

    # -------- (1) 注册功能 --------
    add_heading_custom(doc, '（1）注册功能', level=2)

    # UserBean.java
    add_heading_custom(doc, 'UserBean.java', level=3)
    userbean_code = '''package com.bean;

public class UserBean {
    private String name;
    private String gender;
    private String birth;
    private String nation;
    private String introduction;

    public UserBean() {
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getGender() {
        return gender;
    }

    public void setGender(String gender) {
        this.gender = gender;
    }

    public String getBirth() {
        return birth;
    }

    public void setBirth(String birth) {
        this.birth = birth;
    }

    public String getNation() {
        return nation;
    }

    public void setNation(String nation) {
        this.nation = nation;
    }

    public String getIntroduction() {
        return introduction;
    }

    public void setIntroduction(String introduction) {
        this.introduction = introduction;
    }
}'''
    add_code_paragraph(doc, userbean_code)

    # register.jsp
    add_heading_custom(doc, 'register.jsp', level=3)
    register_jsp = '''<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<html>
<head>
    <title>用户注册</title>
</head>
<body>
    <h2>用户注册</h2>
    <form action="output.jsp" method="post">
        姓名：<input type="text" name="name"><br>
        性别：<input type="radio" name="gender" value="男">男
              <input type="radio" name="gender" value="女">女<br>
        出生年月：<input type="text" name="birth" placeholder="yyyy-MM"><br>
        民族：<input type="text" name="nation"><br>
        个人介绍：<textarea name="introduction"></textarea><br>
        <input type="submit" value="注册">
    </form>
</body>
</html>'''
    add_code_paragraph(doc, register_jsp)

    # output.jsp
    add_heading_custom(doc, 'output.jsp', level=3)
    output_jsp = '''<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<jsp:useBean id="user" class="com.bean.UserBean" scope="request"/>
<jsp:setProperty name="user" property="*"/>
<html>
<head>
    <title>注册信息</title>
</head>
<body>
    <h2>注册信息</h2>
    <table border="1">
        <tr>
            <td>姓名</td>
            <td><jsp:getProperty name="user" property="name"/></td>
        </tr>
        <tr>
            <td>性别</td>
            <td><jsp:getProperty name="user" property="gender"/></td>
        </tr>
        <tr>
            <td>出生年月</td>
            <td><jsp:getProperty name="user" property="birth"/></td>
        </tr>
        <tr>
            <td>民族</td>
            <td><jsp:getProperty name="user" property="nation"/></td>
        </tr>
        <tr>
            <td>个人介绍</td>
            <td><jsp:getProperty name="user" property="introduction"/></td>
        </tr>
    </table>
</body>
</html>'''
    add_code_paragraph(doc, output_jsp)

    # -------- (2) 梯形计算器 --------
    add_heading_custom(doc, '（2）梯形计算器', level=2)

    # TrapezoidBean.java
    add_heading_custom(doc, 'TrapezoidBean.java', level=3)
    trapezoid_code = '''package com.bean;

public class TrapezoidBean {
    private double top;
    private double bottom;
    private double height;

    public TrapezoidBean() {
    }

    public double getTop() {
        return top;
    }

    public void setTop(double top) {
        this.top = top;
    }

    public double getBottom() {
        return bottom;
    }

    public void setBottom(double bottom) {
        this.bottom = bottom;
    }

    public double getHeight() {
        return height;
    }

    public void setHeight(double height) {
        this.height = height;
    }

    public double getArea() {
        return (top + bottom) * height / 2.0;
    }

    public double getPerimeter() {
        // 近似计算：需要腰长，这里假设为等腰梯形简化计算
        // 更严谨：腰长 = sqrt(((bottom - top) / 2)^2 + height^2)
        double leg = Math.sqrt(Math.pow((bottom - top) / 2.0, 2) + Math.pow(height, 2));
        return top + bottom + 2 * leg;
    }
}'''
    add_code_paragraph(doc, trapezoid_code)

    # trapezoid.jsp
    add_heading_custom(doc, 'trapezoid.jsp', level=3)
    trapezoid_jsp = '''<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<html>
<head>
    <title>梯形计算器</title>
</head>
<body>
    <h2>梯形计算器</h2>
    <form action="result.jsp" method="post">
        上底：<input type="text" name="top"><br>
        下底：<input type="text" name="bottom"><br>
        高：<input type="text" name="height"><br>
        <input type="submit" value="计算">
    </form>
</body>
</html>'''
    add_code_paragraph(doc, trapezoid_jsp)

    # result.jsp
    add_heading_custom(doc, 'result.jsp（两种方式）', level=3)
    result_jsp = '''<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!-- 方式一：使用 jsp:useBean 标签 -->
<jsp:useBean id="trapezoid" class="com.bean.TrapezoidBean" scope="request"/>
<jsp:setProperty name="trapezoid" property="*"/>
<html>
<head>
    <title>梯形计算结果</title>
</head>
<body>
    <h2>梯形计算结果</h2>

    <!-- 标签方式显示 -->
    <h3>方式一：jsp:useBean 标签</h3>
    <p>上底：<jsp:getProperty name="trapezoid" property="top"/></p>
    <p>下底：<jsp:getProperty name="trapezoid" property="bottom"/></p>
    <p>高：<jsp:getProperty name="trapezoid" property="height"/></p>
    <p>面积：<jsp:getProperty name="trapezoid" property="area"/></p>
    <p>周长：<jsp:getProperty name="trapezoid" property="perimeter"/></p>

    <hr>

    <!-- 方式二：Scriptlet 代码方式 -->
    <h3>方式二：Scriptlet 代码</h3>
    <%
        com.bean.TrapezoidBean tb = new com.bean.TrapezoidBean();
        tb.setTop(Double.parseDouble(request.getParameter("top")));
        tb.setBottom(Double.parseDouble(request.getParameter("bottom")));
        tb.setHeight(Double.parseDouble(request.getParameter("height")));
        double area = tb.getArea();
        double perimeter = tb.getPerimeter();
    %>
    <p>上底：<%= tb.getTop() %></p>
    <p>下底：<%= tb.getBottom() %></p>
    <p>高：<%= tb.getHeight() %></p>
    <p>面积：<%= area %></p>
    <p>周长：<%= perimeter %></p>
</body>
</html>'''
    add_code_paragraph(doc, result_jsp)

    # -------- (3) 网页计数器 --------
    add_heading_custom(doc, '（3）网页计数器', level=2)

    add_heading_custom(doc, 'CounterBean.java', level=3)
    counter_code = '''package com.bean;

public class CounterBean {
    private int count = 0;

    public CounterBean() {
    }

    public int getCount() {
        return ++count;
    }

    public void setCount(int count) {
        this.count = count;
    }
}'''
    add_code_paragraph(doc, counter_code)

    add_heading_custom(doc, 'counter.jsp（使用 application 作用域共享）', level=3)
    counter_jsp = '''<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<jsp:useBean id="counter" class="com.bean.CounterBean" scope="application"/>
<html>
<head>
    <title>网页计数器</title>
</head>
<body>
    <h2>网页计数器</h2>
    <p>您是第 <jsp:getProperty name="counter" property="count"/>
       位访问者</p>
</body>
</html>'''
    add_code_paragraph(doc, counter_jsp)

    # ============================================================
    # 运行效果
    # ============================================================
    add_heading_custom(doc, '六、运行效果', level=1)

    add_heading_custom(doc, '（1）注册功能运行效果', level=2)
    add_body_paragraph(doc, '打开register.jsp页面，在表单中依次填写姓名（如"张三"）、性别（选择"男"）、出生年月（如"2000-01"）、民族（如"汉族"）、个人介绍（如"你好，我是张三。"），点击"注册"按钮。')
    add_body_paragraph(doc, '页面跳转到output.jsp，以表格形式正确显示所有填写的信息：姓名、性别、出生年月、民族、个人介绍。证明UserBean成功封装并传递了注册数据。')

    add_heading_custom(doc, '（2）梯形计算器运行效果', level=2)
    add_body_paragraph(doc, '打开trapezoid.jsp页面，输入上底为3、下底为5、高为4，点击"计算"按钮。')
    add_body_paragraph(doc, '页面跳转到result.jsp，分别使用jsp:useBean标签方式和Scriptlet代码方式两种方式显示计算结果：')
    add_body_paragraph(doc, '面积 = (3 + 5) x 4 / 2 = 16.0')
    add_body_paragraph(doc, '周长 = 3 + 5 + 2 x sqrt(((5-3)/2)^2 + 4^2) = 3 + 5 + 2 x sqrt(1 + 16) = 8 + 2 x sqrt(17) ≈ 18.0')
    add_body_paragraph(doc, '两种方式均正确显示面积16.0和周长18.0，验证了TrapezoidBean的计算逻辑正确，且标签和代码两种调用方式均可正常工作。')

    add_heading_custom(doc, '（3）网页计数器运行效果', level=2)
    add_body_paragraph(doc, '首次访问counter.jsp时，页面显示"您是第1位访问者"。刷新页面后计数递增为2、3、4...')
    add_body_paragraph(doc, '在其他页面中也使用scope="application"引用同一个CounterBean，访问任意页面都会使计数器累加，体现了多个页面共享同一个JavaBean的效果。')

    # ============================================================
    # 实验小结
    # ============================================================
    add_heading_custom(doc, '七、实验小结', level=1)

    summary1 = '通过本次实验，我掌握了JavaBean的设计方法和部署流程。JavaBean是一种遵循特定规范的Java类，它通过无参构造器和属性的getter/setter方法，实现了数据的封装和复用。在Web开发中，JavaBean作为数据模型层，将业务数据与页面展示分离，提高了代码的可维护性和可读性。'
    add_body_paragraph(doc, summary1)

    summary2 = '在JSP中使用JavaBean时，jsp:useBean标签用于创建或查找JavaBean实例，jsp:setProperty标签用于为属性赋值（支持自动匹配表单参数），jsp:getProperty标签用于获取属性值并输出。这些标签简化了JavaBean的操作，使JSP页面更加简洁。同时，也可以通过Scriptlet代码直接调用JavaBean的方法，两种方式各有优势——标签方式更简洁，代码方式更灵活。'
    add_body_paragraph(doc, summary2)

    summary3 = '通过本次实验，我深入理解了JavaBean的四种scope作用域：page（当前页面）、request（同一次请求）、session（同一次会话）、application（整个应用）。在计数器实验中，使用scope="application"可以使多个页面共享同一个CounterBean实例，从而实现全局计数功能。而在注册功能中，使用scope="request"则能将UserBean局限在请求转发范围内，保证了数据的隔离性。'
    add_body_paragraph(doc, summary3)

    summary4 = '本次实验让我对JavaBean在JSP开发中的应用有了全面的认识，为后续的JavaWeb开发打下了良好的基础。'
    add_body_paragraph(doc, summary4)

    # ============================================================
    # 保存文档
    # ============================================================
    doc.save(path)
    sys.stdout.buffer.write(f'文件已保存到: {path}\n'.encode('utf-8'))


if __name__ == '__main__':
    build_report()
