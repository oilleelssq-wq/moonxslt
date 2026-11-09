# 更新记录

## 0.2.0

这一版补齐了 XSLT 1.0 中最常用的剩余特性，处理器的功能面基本完整。

### 新增

- `format-number()` 与 `xsl:decimal-format`：分组、最小/最大小数位、正负子模式、
  百分比与千分比、Infinity/NaN、命名格式。
- `xsl:key` 与 `key()`：变换前建索引，支持节点集参数与多节点值。
- `disable-output-escaping`：文本节点带转义标志，XML 与 HTML 序列化器都遵守。
- `xsl:include` / `xsl:import`：通过 `Loader` 展开，CLI 直接读文件系统；循环
  包含、加载失败、缺少 loader 都有明确报错。
- `xsl:attribute-set` 与 `use-attribute-sets`：支持嵌套引用，后写入的属性覆盖
  先写入的同名属性。
- CLI 支持包含外部样式表的输入；新增 `examples/report` 与 `examples/include`
  两个可运行示例。

### 修复

- XPath 解析器不消费过滤器表达式后的 `/`，导致 `key(...)/@amount`、
  `(//book)[1]/title` 之类的表达式报错。
- `DisableOutputEscaping` 文本与普通文本相邻时的合并行为。
- `moon check --deny-warn` 下 `ArrayView::to_array` 的弃用告警。

### 测试

97 个黑盒测试，覆盖解析、XPath 求值、模板匹配、变量作用域、动态构造、编号、
键索引、外部样式表、属性集、转义控制与三种输出方法。

## 0.1.0

首个版本：命名空间感知的 XML 解析与序列化、XPath 1.0 求值与函数库、XSLT 模板
引擎（模板选择、优先级、mode、变量/参数、if/choose/for-each/sort、copy/
copy-of、element/attribute、number、message）、xml/html/text 三种输出方法、CLI、
三个示例与 GitHub Actions CI。