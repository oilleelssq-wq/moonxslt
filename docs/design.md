# moonxslt 设计笔记

这份文档记录实现上的取舍，方便后来者判断「为什么是这样」。

## 分层

```
cmd/main        CLI：读文件、调用 transform、写结果
moonxslt        门面包：transform / parse_xml / select / select_string
xslt            样式表编译 + 执行器 + 三种输出方法
xpath           词法、语法、求值、函数库
xml             文档模型、解析器、序列化器
```

依赖方向单一：`xslt → xpath → xml`，`xml` 不认识上层。

## 文档模型

`Document` 是 arena：`nodes : Array[Node]`，节点 id 是数组下标，按文档序分配。`root_id` 单独保存文档元素。

- **文档序**：每个节点带 `order`，元素、属性、子节点的顺序键单调递增；属性与所属元素共享 `order`，比较时用 `(order, id)`，于是「元素 → 属性 → 子节点」的顺序是稳定的。
- **属性是节点**：`attributes(element)` 返回属性 id 数组，属性不进入 `children`。这样 XPath 的属性轴、`@*`、`attribute::` 都能直接用同一套节点表示。
- **命名空间**：`QName { prefix, local_part, uri }`，解析时把前缀解析成 URI；`namespace_declarations(id)` 保存元素上声明的 `xmlns:*`，供样式表与结果树复制。
- **两个文档互不干扰**：`xsl:copy-of` 在结果 arena 里按源节点重建节点，不共享可变状态。

`Document::to_xml` 支持 `indent` 与 `declaration` 两个开关，分别对应 `xsl:output` 的 `indent` 和 `omit-xml-declaration`。

## XPath

- 词法把 `//`、`..`、`::`、`!=`、`<=`、`>=` 收成单 token，避免语法层回溯。
- 语法是递归下降，优先级从低到高：`or` → `and` → 比较 → 加法 → 乘法 → 一元负号 → 并集 → 路径。
- `EvalContext { doc, node, position, size, variables, namespaces }` 是不可变结构，派生新上下文用 `with_node` / `with_position` / `with_variables` / `with_namespaces`。
- 谓词按上下文位置编号求值：先取轴上的候选节点，再对每个候选设 `position/size` 求谓词，最后收敛。
- 比较分两类：节点集与节点集是存在语义（任意一对满足即可），节点集与标量是「先转标量再比」。
- 值转换按 XPath 1.0：字符串去空白、数字用 `round` 语义、布尔遵循「非空节点集 / 非零 / 非空串」。

## XSLT

**编译**：`compile` 扫描样式表，收集 `xsl:template`（match、name、mode、priority）、`xsl:output`、`xsl:strip-space`/`xsl:preserve-space`。没有 priority 时按模式算默认优先级：QName 0，`ns:*` -0.25，`node()` 等 -0.5，带路径或谓词 0.5。

**模式匹配**：`match` 是 XPath 的受限子集。把相对模式前补 `//`、绝对模式保持原样，在源文档上求值，得到「命中集合」并缓存；匹配某节点退化成 `contains(id)`。多条模板按 priority 选，平手取样式表里靠后的那条。

**变量作用域**：变量栈 + 栈高。`instantiate` 进入时记 `mark = variables.length()`，退出时 `truncate(mark)`。`xsl:variable` 压栈后对后续兄弟与子树可见，离开序列构造器即失效。`xsl:param` 先查同名绑定是否存在，存在就跳过默认值——这让 `call-template` 传入的参数优先。

**上下文切换**：`for-each` 逐个设置 `current_node/position/size` 后实例化子节点；`apply-templates` 每次进入模板重置 position/size 为 1。表达式求值统一读这几个字段。

**结果树**：结果 document 与源 document 同构。`literal_element` 复制样式表元素的 QName、命名空间声明和非 XSLT 属性（属性值走 AVT），再实例化子节点。`xsl:copy` 只复制节点本身（元素不含属性），属性交给 `apply-templates select="@*"`，与规范一致。

**排序**：`xsl:sort` 用插入排序，多关键字按声明顺序比较，键相等时保持文档序。

**输出**：`method="xml"` 走 XML 序列化；`html` 不写 XML 声明、不写命名空间声明、void 元素不闭合；`text` 只输出字符数据。

## 错误处理

- 解析错误带行列号（`XmlErrorInfo`）。
- XPath 语法错误带位置（`ParseErrorInfo`），求值错误统一 `EvaluationError::Message`。
- 样式表错误在 `compile` 阶段返回字符串；执行期错误用 `XsltError::Failure` 抛出，`run` 捕获后转成 `Result`。

## 测试

`moon test` 共 97 个用例：

- `xml`：解析、命名空间、CDATA、实体、序列化、错误位置。
- `xpath`：路径、谓词、轴、并集、比较、函数库（字符串/数字/节点集）。
- `xslt`：模板选择与优先级、mode、内置规则、AVT、变量与参数、if/choose/for-each、sort、copy/copy-of、element/attribute、number、strip-space、三种输出方法、错误路径。
- 门面包：`transform`、`parse_xml`、`select`。

CI 在 Ubuntu 上安装 MoonBit 工具链，跑 `moon check --deny-warn`、`moon build`、`moon test`、`moon fmt --check`、`moon info` 的接口一致性检查，并执行一次 CLI 示例。

## 路线图

| 里程碑 | 内容 | 状态 |
| --- | --- | --- |
| 1 | XML DOM、解析器、序列化 | 完成 |
| 2 | XPath 语法与求值 | 完成 |
| 3 | XPath 函数库 | 完成 |
| 4 | XSLT 模板引擎与变量 | 完成 |
| 5 | copy/copy-of、element/attribute | 完成 |
| 6 | 输出方法与空白剥离 | 完成 |
| 7 | 编号与消息 | 完成 |
| 8 | format-number、decimal-format | 完成 |
| 9 | key() | 完成 |
| 10 | include / import（loader） | 完成（import 无优先级差异） |
| 11 | attribute-set | 完成 |
| 12 | document() | 计划 |
| 13 | 发布到 mooncakes.io | 待发布 |