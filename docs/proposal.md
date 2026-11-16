# moonxslt 项目申报书

**基本信息**
- 项目名称：moonxslt —— 纯 MoonBit 的 XSLT 1.0 处理器
- 参赛者：oilleelssq-wq
- 联系方式：2321130582@qq.com
- GitHub 仓库链接：https://github.com/oilleelssq-wq/moonxslt
- 项目方向：MoonBit 文档处理与数据格式转换基础设施
- 是否为移植项目：否，原创项目

**项目简介**

moonxslt 用 MoonBit 从零实现 XSLT 1.0：自带命名空间感知的 XML 解析器、XPath 1.0 引擎和样式表执行器。输入一份 XML 和一份样式表，输出新的 XML、HTML 或纯文本。它面向需要在 MoonBit 里做文档发布、数据交换、报表导出的开发者，补齐 MoonBit 生态缺失的「解析 → XPath → 模板执行 → 序列化」链路，不绑定 C 库或 JS 运行时，核心是库，CLI 只是薄壳。

**适用场景**

1. 文档发布与静态站点：`xsl:apply-templates` 按节点分发模板，`xsl:sort` 排序，`xsl:output method="html"` 直接生成页面片段。
2. 数据交换格式映射：供应商 XML 字段与内部系统不一致时，用 `xsl:for-each` 重排层级、`xsl:attribute` 拼主键、`xsl:copy-of` 原样搬运子树。
3. 报表与统计摘要：`count()`、`sum()`、`key()` 聚合明细，`format-number` 格式化金额，输出 XML 供下游消费或用 `method="text"` 出纯文本报表。

**核心功能范围**

- `xml` 包：命名空间感知 DOM（整数 id 的 arena，属性也是节点），递归下降解析器支持 CDATA、注释、处理指令、预定义实体与数字字符引用，并可序列化。
- `xpath` 包：13 个轴、缩写语法、谓词、并集、比较与算术、完整核心函数库；`EvalContext` 提供扩展函数钩子。
- `xslt` 包：模板匹配与优先级、mode、内置规则、AVT、变量与参数、`if`/`choose`/`for-each`/`sort`、`copy`/`copy-of`、`element`/`attribute`、`comment`/`processing-instruction`/`text`。
- 高级特性：`xsl:key`、`format-number`/`xsl:decimal-format`、`xsl:number`、`strip-space`、`disable-output-escaping`、`xsl:message`、`xsl:attribute-set`。
- 外部样式表：`xsl:include`/`xsl:import` 通过 `Loader` 展开，CLI 以文件系统实现加载器；循环包含与加载失败均有明确报错。
- 输出与入口：xml/html/text 三种输出方法；`moonxslt <stylesheet> <source> [output]`；5 个可运行示例与 `docs/conformance.md` 特性对照表。

**原创与参考说明**

项目为新建原创仓库，不移植、不维护既有项目。实现参考 W3C 的 XPath 1.0 与 XSLT 1.0 推荐标准（规范文本，非代码）；mooncakes 上现有的 XML 包只做解析、`cravan371/xpath-evaluator` 只做 XPath 求值，都不执行样式表，本项目的独立贡献是完整的样式表执行器。仓库无第三方源码，许可证为 Apache-2.0。

**交付状态**

97 个测试全部通过；GitHub Actions 覆盖 `moon check --deny-warn`、构建、测试、格式检查与接口一致性；`oilleelssq-wq/moonxslt@0.2.0` 已发布到 mooncakes.io。`document()` 等少数边缘特性尚未实现，已在 `docs/conformance.md` 如实标注。

**许可证**

Apache-2.0