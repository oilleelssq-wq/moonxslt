# moonxslt

纯 MoonBit 实现的 **XSLT 1.0 处理器**：自带 XML 解析器、XPath 1.0 引擎和样式表执行引擎，零第三方依赖。

XSLT 是 W3C 的 XML 转换标准。给一份样式表和一份 XML，它输出新的 XML、HTML 或纯文本。文档发布、数据交换、静态站点生成、报表导出都依赖它。MoonBit 生态目前没有 XSLT 处理器（`moon search xslt` 返回 0 条结果），已有的 XML 库只提供拉式解析，没有样式表执行能力。

## 设计目标

- **纯 MoonBit**：解析、求值、序列化全部自己实现，不绑定 C 库或 JS 运行时。
- **W3C 语义**：按 XPath 1.0 与 XSLT 1.0 推荐标准实现，模板匹配、优先级、模式、变量作用域都遵循标准行为。
- **输入输出都是字符串**：核心库不碰文件系统，方便嵌进构建工具、服务端或浏览器。
- **可嵌入**：核心是库，CLI 只是薄壳。

## 快速开始

```bash
moon add oilleelssq-wq/moonxslt
```

库调用只需要两份 XML 文本：

```moonbit nocheck
///|
test {
  let source = "<catalog><book><title>A</title></book></catalog>"
  let stylesheet =
    #|<?xml version="1.0"?>
    #|<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    #|  <xsl:template match="/">
    #|    <titles>
    #|      <xsl:apply-templates select="//title"/>
    #|    </titles>
    #|  </xsl:template>
    #|  <xsl:template match="title">
    #|    <title><xsl:value-of select="."/></title>
    #|  </xsl:template>
    #|</xsl:stylesheet>
  let result = @xslt.transform(source, stylesheet).unwrap()
  println(result) // <titles><title>A</title></titles>
}
```

命令行入口读取文件，把结果写到标准输出或第三个参数指定的文件：

```bash
moon run cmd/main examples/books/books.xsl examples/books/books.xml
moon run cmd/main examples/books/books.xsl examples/books/books.xml out.xml
moon run cmd/main examples/html/books.xsl examples/books/books.xml
moon run cmd/main examples/report/report.xsl examples/report/sales.xml
```

仓库里的三个示例分别演示：按数值排序并汇总（`examples/books`）、HTML 输出方法（`examples/html`）、用 `xsl:copy` 写恒等变换（`examples/identity`）。

## 已实现

| 模块 | 内容 |
| --- | --- |
| `xml` | 命名空间感知的文档模型、递归下降解析器（CDATA、注释、处理指令、预定义实体与数字字符引用）、XML 序列化 |
| `xpath` | XPath 1.0 词法/语法/求值；全部 13 个轴、缩写语法、谓词、并集、比较、算术；核心函数库（`concat`、`substring`、`translate`、`normalize-space`、`sum`、`id`、`lang` 等） |
| `xslt` | 模板匹配与优先级、`mode`、内置模板规则、属性值模板、`xsl:value-of`、`xsl:apply-templates`、`xsl:call-template`/`xsl:with-param`、`xsl:variable`/`xsl:param`、`xsl:if`、`xsl:choose`、`xsl:for-each`、`xsl:sort`、`xsl:copy`/`xsl:copy-of`、`xsl:element`/`xsl:attribute`、`xsl:comment`、`xsl:processing-instruction`、`xsl:text`、`xsl:number`、`xsl:message`、`xsl:strip-space`/`xsl:preserve-space`、`format-number`/`xsl:decimal-format`；xml / html / text 三种输出方法 |
| CLI | `moonxslt <stylesheet> <source> [output]` |

测试共 86 个，覆盖解析、XPath 求值、模板选择、变量作用域、动态构造、编号、键索引、转义控制与序列化。

## 文档模型

文档是 arena：所有节点存在一个数组里，用整数 id 引用，id 按文档序分配。这样做的原因：

- 文档序比较是 XPath 的高频操作，整数比较比指针遍历便宜。
- 没有父指针环，回收简单。
- 结果树与源文档可以共用同一套节点表示，`xsl:copy-of` 只需按 id 复制。

属性也建模成节点，但不进入 `children`，符合 XPath 数据模型对属性轴的定义。属性的文档序键与所属元素相同，排序时用 `(order, id)` 保证「元素 → 属性 → 子节点」的顺序。

## 实现说明

**模式匹配**：XSLT 的 `match` 是 XPath 的受限子集。实现方式是把相对模式前面补 `//`、在样式表上下文里求值，得到模式匹配的全部节点并缓存；之后判断某节点是否命中模板就是一次集合查询。模板规则按 priority 选择，同优先级取文档中靠后者。

**变量作用域**：变量放在一个栈上，每进入一个序列构造器记录栈高，退出时截断。于是 `xsl:variable` 对后续兄弟节点可见，对外层不可见，符合词法作用域。

**排序**：`xsl:sort` 用插入排序，键相同时保持文档序，多关键字按声明顺序逐级比较。

## 已知限制

- `key()`、`document()`、`xsl:import`/`xsl:include` 尚未实现。
- `disable-output-escaping` 属性被忽略。
- `xsl:param` 只按名字查找是否已有绑定，外层同名变量会被误当成已传入的参数。
- 空白剥离只作用于模板处理：显式写 `//text()` 的 XPath 表达式仍能看到被剥离的空白文本节点。
- `xsl:number` 的 `count` 只支持名字测试与 `*`，不支持带谓词或并集的模式。
- `format-number` 只支持定点图片串，科学计数法等写法会原样返回。
- 解析器跳过 DOCTYPE 内部子集，不展开自定义实体，只支持五个预定义实体与数字字符引用。

## 许可证

Apache-2.0