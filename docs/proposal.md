# moonxslt 项目申报书

**基本信息**
- 项目名称：moonxslt —— 纯 MoonBit 的 XSLT 1.0 处理器
- GitHub 仓库链接：https://github.com/oilleelssq-wq/moonxslt
- 参赛者：oilleelssq-wq
- 联系方式：2321130582@qq.com
- 项目方向：文档处理与数据格式转换基础设施；通用性在于任何「XML → XML/HTML/文本」的转换都能用，不绑定具体业务
- 是否为移植项目：否，原创项目

**项目价值与生态定位**
MoonBit 里做 XML 转换只能手写字符串拼接，字段一多变就难维护，也无法复用现成的 XSLT 样式表。生态现状是：XML 包只提供解析（`Milky2018/xml` 等），`cravan371/xpath-evaluator` 只做 XPath 求值，没有组件执行样式表。moonxslt 补的是执行器这一层：自带解析、XPath 和模板引擎，把「解析 → 选节点 → 套模板 → 序列化」串起来，让 MoonBit 项目可以直接消费业界已有的 XSLT 资产。相比自己拼字符串，它的优势是模式匹配、优先级、变量作用域和输出方法都由标准定义，行为可预期。

**预期使用场景**
1. 文档发布 / 静态站点：内容存为 XML，样式表用 `apply-templates` 分发、`sort` 排序、`method="html"` 出页面片段。`examples/html` 是这条链路的最小版本。
2. 数据交换格式映射：供应商 XML 字段名和层级与内部系统不一致，用 `for-each` 重排、`attribute` 和 AVT 拼主键、`copy-of` 原样搬运不需改写的子树，输出内部规范 XML。
3. 报表与统计：明细 XML 用 `count()`、`sum()`、`key()` 聚合，`format-number` 格式化金额，输出汇总 XML 供下游消费，或 `method="text"` 直接出纯文本报表。`examples/report` 演示了按区域分组汇总。

**拟实现的核心功能**
- `xml`：命名空间感知的 arena DOM，递归下降解析器（CDATA、注释、PI、预定义实体、字符引用），可序列化。
- `xpath`：13 个轴、缩写语法、谓词、并集、比较、算术，完整核心函数库。
- `xslt`：模板匹配与优先级、mode、AVT、变量与参数、`if`/`choose`/`for-each`/`sort`、`copy`/`copy-of`、`element`/`attribute`、`comment`/`PI`/`text`、`key`、`format-number`、`number`、`attribute-set`、`include`/`import`（loader）、三种输出方法。
- 交付边界：不实现 `document()`、`xsl:apply-imports`、`xsl:namespace-alias`、`cdata-section-elements`，不做 DTD 校验和自定义实体展开；这些已在 `docs/conformance.md` 逐项标注。

**实现路径与技术理解**
常见路径是绑定 libxslt，但 MoonBit 不能依赖 C 运行时，只能自己写。实现顺序定为「解析器 → XPath → 模板引擎」：XSLT 的模式匹配、变量求值和排序全部建立在 XPath 之上，先有稳定的 XPath 才能把模板引擎做对。关键取舍：文档用 arena + 整数 id，文档序比较便宜且没有父指针环；`match` 模式编译成绝对 XPath 并缓存命中集，模板选择退化为集合查询；变量用栈加栈高实现词法作用域；`format-number`、`key()` 这类需要样式表信息的函数通过 `EvalContext` 的扩展函数钩子注入，而不是塞进 XPath 核心。

**交付状态**
97 个测试通过；`moon check --deny-warn`、`moon fmt --check`、接口一致性检查均通过；GitHub Actions 覆盖检查、构建、测试并运行 5 个示例；`oilleelssq-wq/moonxslt@0.2.1` 已发布到 mooncakes.io；Apache-2.0，仓库无第三方源码。