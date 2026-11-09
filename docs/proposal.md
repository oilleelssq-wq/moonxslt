# 申报书：moonxslt —— 纯 MoonBit 的 XSLT 1.0 处理器

## 一句话说明

用 MoonBit 从零实现 XSLT 1.0：自带 XML 解析器、XPath 1.0 引擎和样式表执行器，让 MoonBit 程序能把一份 XML 按样式表转换成 XML、HTML 或纯文本。

## 要解决的问题

XML 转换是文档发布、数据交换、报表导出里的常规工作，XSLT 是这件事的 W3C 标准。MoonBit 生态目前没有 XSLT 实现：`moon search xslt` 没有任何结果，已有的 XML 包（`Milky2018/xml` 等）只提供拉式解析，`cravan371/xpath-evaluator` 只做 XPath 求值，都不执行样式表。想在 MoonBit 里做「读 XML → 按规则生成另一份文档」，只能自己临时拼字符串。

本项目把这条链路补齐：解析、XPath 求值、模板匹配、结果树构造、序列化，全部用 MoonBit 写，不绑定 C 库或 JS 运行时。

## 与现有项目的区别

| 现有项目 | 能力 | 与本项目的关系 |
| --- | --- | --- |
| `Milky2018/xml`、`marianoguerra/xml`、`moonbit-community/XMLParser` | 拉式/流式 XML 解析 | 本项目自带命名空间感知的 DOM，解析只是其中一层，不替代解析库的定位 |
| `cravan371/xpath-evaluator` | 对已有文档求值 XPath | 本项目在其上再实现 XSLT：模板规则、模式匹配、优先级、模式（mode）、变量作用域、属性值模板、排序、结果树构造、三种输出方法 |
| 模板引擎类项目 | 文本模板替换 | XSLT 的语义来自 XPath 数据模型，与字符串模板不重合 |

项目是新建仓库，不复用、不维护既有项目。

## 使用场景

**1. 文档发布 / 静态站点生成。** 内容以 XML 存放，样式表负责版式。`xsl:apply-templates` 逐节点分发，`xsl:sort` 排序，`xsl:output method="html"` 直接产出页面片段。仓库里的 `examples/html` 就是这个流程的最小版本。

**2. 数据交换格式映射。** 供应商给的 XML 字段名、层级与内部系统不一致时，用 `xsl:for-each` 重排、`xsl:attribute` 和属性值模板拼主键、`xsl:copy-of` 原样搬运不需要改写的子树。`examples/books` 演示了按价格排序并汇总。

**3. 报表与统计摘要。** `count()`、`sum()`、变量和 `xsl:number` 组合，把明细 XML 聚合成一份汇总文档，输出 XML 供下游消费，或 `method="text"` 直接出纯文本报表。

## 技术方案

- **`xml` 包**：arena 文档模型。节点存在一个数组里，用 32 位整数 id 引用，id 按文档序分配；属性也建模成节点，但不进入 `children`，对齐 XPath 对属性轴的定义。递归下降解析器处理命名空间、CDATA、注释、处理指令、预定义实体与数字字符引用。
- **`xpath` 包**：词法、递归下降语法、求值。13 个轴、缩写语法、谓词、并集、四类值及转换、存在语义比较、算术和核心函数库。
- **`xslt` 包**：模板表 + 执行器。`match` 模式翻译成绝对 XPath 表达式求值并缓存，之后判断节点是否命中模板就是集合查询；模板按 priority 选，同优先级取靠后者；变量放在栈上，进入序列构造器记栈高、退出截断，得到词法作用域。
- **CLI**：`moonxslt <stylesheet> <source> [output]`，只是库的薄壳。

## 当前进度

已完成：三个包 + CLI + 三个可运行示例；97 个测试；GitHub Actions 做 `moon check --deny-warn`、构建、测试、格式检查和接口一致性检查。

进行中/计划：`format-number`、`xsl:decimal-format`、`key()`、`document()`、`xsl:import`/`xsl:include`、`disable-output-escaping`。

## 交付物对照验收要求

| 要求 | 现状 |
| --- | --- |
| MoonBit 为主语言 | 全部代码是 MoonBit，无其他语言源码 |
| CI 跑 check/build/test | `.github/workflows/ci.yml` |
| 可运行示例 | `examples/books`、`examples/html`、`examples/identity`，CLI 直接可跑 |
| 完整测试 | 97 个测试，覆盖解析、XPath、模板选择、变量、构造、编号、序列化 |
| OSI 许可证 | Apache-2.0 |
| 发布到 mooncakes.io | 代码已就绪，待发布 |

## 已知限制

`format-number`、`decimal-format`、`key()`、`document()`、`xsl:import`/`xsl:include` 未实现；`disable-output-escaping` 被忽略；解析器不展开自定义实体，不支持 DTD 校验。