// Convenience entry points for evaluating XPath expressions.
//
// The evaluator itself works on parsed expressions and raises `EvaluationError`;
// these helpers combine parsing, evaluation and conversion so that callers (the
// XSLT engine, the CLI and the tests) do not have to repeat the plumbing.

///|
/// Parse and evaluate an expression, returning the raw value.
pub fn evaluate_path(
  doc : @xml.Document,
  node : Int32,
  path : String,
) -> Result[Value, String] {
  let expression = match parse(path) {
    Ok(expression) => expression
    Err(info) => return Err(info.message)
  }
  Ok(evaluate(expression, EvalContext::new(doc, node))) catch {
    EvaluationError::Message(message) => Err(message)
  }
}

///|
/// Evaluate an expression against a context, returning the raw value.
pub fn evaluate_with(
  context : EvalContext,
  expression : Expr,
) -> Result[Value, String] {
  Ok(evaluate(expression, context)) catch {
    EvaluationError::Message(message) => Err(message)
  }
}

///|
/// Select the nodes matched by an expression.
pub fn select(
  doc : @xml.Document,
  node : Int32,
  path : String,
) -> Result[NodeSet, String] {
  match evaluate_path(doc, node, path) {
    Ok(Nodes(set)) => Ok(set)
    Ok(_) => Err("expression does not select nodes")
    Err(message) => Err(message)
  }
}

///|
/// Select the nodes matched by an already parsed expression.
pub fn select_nodes(
  context : EvalContext,
  expression : Expr,
) -> Result[NodeSet, String] {
  match evaluate_with(context, expression) {
    Ok(Nodes(set)) => Ok(set)
    Ok(_) => Err("expression does not select nodes")
    Err(message) => Err(message)
  }
}

///|
/// The XPath `string()` of an expression result.
pub fn select_string(
  doc : @xml.Document,
  node : Int32,
  path : String,
) -> Result[String, String] {
  match evaluate_path(doc, node, path) {
    Ok(value) => Ok(value.string_value(doc))
    Err(message) => Err(message)
  }
}

///|
/// The XPath `number()` of an expression result.
pub fn select_number(
  doc : @xml.Document,
  node : Int32,
  path : String,
) -> Result[Double, String] {
  match evaluate_path(doc, node, path) {
    Ok(value) => Ok(value.number_value(doc))
    Err(message) => Err(message)
  }
}

///|
/// The XPath `boolean()` of an expression result.
pub fn select_boolean(
  doc : @xml.Document,
  node : Int32,
  path : String,
) -> Result[Bool, String] {
  match evaluate_path(doc, node, path) {
    Ok(value) => Ok(value.boolean_value())
    Err(message) => Err(message)
  }
}

///|
/// The XPath string() of an already parsed expression.
pub fn string_of(
  context : EvalContext,
  expression : Expr,
) -> Result[String, String] {
  match evaluate_with(context, expression) {
    Ok(value) => Ok(value.string_value(context.doc))
    Err(message) => Err(message)
  }
}

///|
/// The XPath number conversion of an already parsed expression.
pub fn number_of(
  context : EvalContext,
  expression : Expr,
) -> Result[Double, String] {
  match evaluate_with(context, expression) {
    Ok(value) => Ok(value.number_value(context.doc))
    Err(message) => Err(message)
  }
}

///|
/// The XPath boolean conversion of an already parsed expression.
pub fn boolean_of(
  context : EvalContext,
  expression : Expr,
) -> Result[Bool, String] {
  match evaluate_with(context, expression) {
    Ok(value) => Ok(value.boolean_value())
    Err(message) => Err(message)
  }
}
