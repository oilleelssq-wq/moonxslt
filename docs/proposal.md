# 申报书：moonxslt —— 纯 MoonBit 的 XSLT 1.0 处理器

- 项目名称：moonxslt
- GitHub：https://github.com/oilleelssq-wq/moonxslt
- Gitlink：待创建并与 GitHub 同步
- 许可证：Apache-2.0；性质：原创项目，不移植、不复用既有 MoonBit 项目

## 一句话说明

用 MoonBit 从零实现 XSLT 1.0：自带 XML 解析器、XPath 1.0 引擎和样式表执行器，把 XML 按样式表转换成 XML、HTML 或纯文本。

## 要解决的问题

MoonBit 生态没有 XSLT 实现（`moon search xslt` 无结果）：现有 XML 包只做解析，`cravan371/xpath-evaluator` 只求值 XPath，都不能执行样式表。本项目补齐「解析 → XPath → 模板执行 → 序列化」整条链路，不绑定 C 库或 JS 运行时。

## 使用场景

1. 文档发布/静态站点：`apply-templates` 分发、`sort` 排序、`method="html"` 出页面（`examples/html`）。
2. 数据交换格式映射：`for-each` 重排、`attribute` 拼主键、`copy-of` 搬运子树（`examples/books`）。
3. 报表与统计：`count`/`sum`/`key()` 聚合、`format-number` 格式化金额，输出 XML 或文本（`examples/report`）。

## 技术方案

`xml` 是 arena 文档模型（整数 id，属性也是节点）；`xpath` 实现 13 个轴与完整函数库；`xslt` 把模式编译成绝对路径并缓存，模板按优先级选择，变量栈提供词法作用域，支持 include/import（loader）、attribute-set、key 与三种输出方法。

## 进度与交付物

三个包 + CLI + 五个可运行示例；97 个测试；CI 跑 check/build/test/格式/接口；Apache-2.0；已发布 mooncakes.io（`oilleelssq-wq/moonxslt` 0.2.0）；`document()` 与少数边缘特性未实现（见 `docs/conformance.md`）。