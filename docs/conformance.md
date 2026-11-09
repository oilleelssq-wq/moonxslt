# XSLT 1.0 / XPath 1.0 实现对照

这张表说明哪些特性已经实现、哪些只是部分实现、哪些没有实现，避免使用者
按规范的完整能力去预期。

图例：✅ 实现，◐ 部分实现，❌ 未实现。

## XSLT 1.0 元素

| 元素 | 状态 | 说明 |
| --- | --- | --- |
| `xsl:template` | ✅ | `match`、`name`、`mode`、`priority` |
| `xsl:apply-templates` | ✅ | `select`、`mode`、`xsl:sort`、`xsl:with-param` |
| `xsl:call-template` | ✅ | `name`、`xsl:with-param` |
| `xsl:with-param` / `xsl:param` | ◐ | 按名字绑定；外层同名变量可能被误当成已传入的参数 |
| `xsl:variable` | ✅ | 结果树片段、字符串、数字、布尔、节点集 |
| `xsl:value-of` | ✅ | `select`、AVT、`disable-output-escaping` |
| `xsl:for-each` | ✅ | `select`、`xsl:sort`、`position()`、`last()` |
| `xsl:if` / `xsl:choose` | ✅ | `test`、`when`、`otherwise` |
| `xsl:copy` / `xsl:copy-of` | ✅ | 浅复制 / 深复制，命名空间随节点复制 |
| `xsl:element` / `xsl:attribute` | ✅ | `name`、`namespace`、`use-attribute-sets` 未实现 |
| `xsl:comment` / `xsl:processing-instruction` | ✅ | 内容为文本 |
| `xsl:text` | ✅ | `disable-output-escaping` |
| `xsl:sort` | ◐ | `select`、`data-type`（text/number）、`order`；`case-order`、`lang` 被忽略 |
| `xsl:number` | ◐ | `value`、`count`（名字测试与 `*`）、`level`（single/multiple/any）、`format` 的数字/字母/罗马数字；`grouping-separator` 等未实现 |
| `xsl:key` / `key()` | ✅ | 索引在变换前建好，支持节点集参数 |
| `format-number()` | ✅ | 定点图片串、分组、正负数子模式、百分比与千分比、无穷与 NaN |
| `xsl:decimal-format` | ✅ | 全部字符属性 |
| `xsl:message` | ✅ | `terminate="yes"` 中止变换 |
| `xsl:output` | ✅ | `method`（xml/html/text）、`indent`、`omit-xml-declaration`；`doctype-*`、`cdata-section-elements` 未实现 |
| `xsl:strip-space` / `xsl:preserve-space` | ◐ | 按元素名或 `*` 生效，但只影响模板处理，显式 `//text()` 仍看得到空白文本 |
| `xsl:apply-imports` | ❌ | 需要 import precedence |
| `xsl:import` / `xsl:include` | ✅ | 通过 loader 展开；`import` 与 `include` 等价，没有优先级差异 |
| `document()` | ❌ | 需要把外部文档并入 XPath 数据模型 |
| `xsl:attribute-set` | ❌ | |
| `xsl:namespace-alias` | ❌ | |
| `xsl:fallback` | ❌ | 不支持的前向兼容元素会直接报错 |
| `xsl:preserve-space` 的 `elements` 前缀形式 | ◐ | 只比较本地名 |

## 匹配模式

| 形式 | 状态 |
| --- | --- |
| `/`、`QName`、`prefix:*`、`*`、`@QName`、`@*` | ✅ |
| `node()`、`text()`、`comment()`、`processing-instruction()` | ✅ |
| `//`、`/` 组成的多步模式 | ✅ |
| 并集 `a \| b` | ✅ |
| 带谓词的步骤 | ✅ |
| `id()` / `key()` 作为模式 | ❌ |

默认优先级按规范计算：QName 为 0，`ns:*` 为 -0.25，`node()` 一类为 -0.5，
带路径或谓词为 0.5；显式 `priority` 覆盖默认值。

## XPath 1.0

| 部分 | 状态 | 说明 |
| --- | --- | --- |
| 13 个轴 | ✅ | 命名空间轴由元素上的 `xmlns` 声明推导 |
| 缩写语法 | ✅ | `.`、`..`、`//`、`@` |
| 谓词 | ✅ | 位置与大小按候选节点计算 |
| 并集、比较、算术 | ✅ | 节点集与标量的比较按规范转换 |
| 核心函数库 | ✅ | 字符串、数字、布尔、节点集四类 |
| `id()` | ◐ | 按 `xml:id` 与名为 `id` 的属性匹配，不读取 DTD |
| `lang()` | ✅ | 沿祖先链检查 `xml:lang` |
| `namespace-uri()` | ✅ | 来自解析后的 QName |
| 扩展函数 | ✅ | 由 `EvalContext::with_function` 注入，目前有 `format-number()` 与 `key()` |

## 与规范的差异

- `xsl:param` 的默认值只在没有同名绑定时生效；外层同名变量会被误当成已传入的
  参数。
- `xsl:import` 与 `xsl:include` 等价：被导入的模板与包含进来的模板优先级相同，
  `xsl:apply-imports` 不支持。
- 空白剥离在解析后的文档上做，而不是在解析阶段；`//text()` 能绕过剥离。
- 文本节点相邻时合并，但 `disable-output-escaping` 不同的相邻文本不会合并。
- 解析器跳过 DOCTYPE 内部子集，不展开自定义实体；只支持五个预定义实体与
  数字字符引用。
- `xsl:output` 的 `doctype-public`/`doctype-system`、`cdata-section-elements`
  被忽略。
- HTML 输出方法不写 XML 声明与命名空间声明，void 元素不闭合，但没有实现
  规范的转义例外表（例如 `<script>` 内的转义）。