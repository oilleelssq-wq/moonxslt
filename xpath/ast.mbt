// Abstract syntax tree for XPath 1.0.

///|
/// The thirteen XPath axes.
pub(all) enum Axis {
  Ancestor
  AncestorOrSelf
  Attribute
  Child
  Descendant
  DescendantOrSelf
  Following
  FollowingSibling
  Namespace
  Parent
  Preceding
  PrecedingSibling
  Self
}

///|
/// A node test, which filters the nodes selected by an axis.
pub(all) enum NodeTest {
  /// `prefix:local`, `local` or `*`; the prefix is empty when absent.
  NameTest(String, String)
  TextTest
  CommentTest
  AnyNodeTest
  /// `processing-instruction()` or `processing-instruction('target')`.
  ProcessingInstructionTest(String?)
}

///|
/// One step of a location path.
pub(all) enum Step {
  AxisStep(Axis, NodeTest, Array[Expr])
  /// The abbreviated step `.`.
  SelfStep
  /// The abbreviated step `..`.
  ParentStep
}

///|
/// Relational and equality operators.
pub(all) enum ComparisonOp {
  Equal
  NotEqual
  Less
  LessOrEqual
  Greater
  GreaterOrEqual
}

///|
/// Arithmetic operators.
pub(all) enum ArithmeticOp {
  Add
  Subtract
  Multiply
  Divide
  Modulo
}

///|
/// An XPath expression.
pub(all) enum Expr {
  /// A location path; the flag marks an absolute path.
  LocationPath(Bool, Array[Step])
  /// A primary expression followed by predicates.
  Filter(Expr, Array[Expr])
  /// A filter expression followed by a relative location path.
  Path(Expr, Array[Step])
  Union(Expr, Expr)
  Or(Expr, Expr)
  And(Expr, Expr)
  Comparison(ComparisonOp, Expr, Expr)
  Arithmetic(ArithmeticOp, Expr, Expr)
  Negate(Expr)
  NumberLiteral(Double)
  StringLiteral(String)
  VariableReference(String)
  FunctionCall(String, Array[Expr])
}
