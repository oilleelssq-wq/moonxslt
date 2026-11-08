// The XPath 1.0 evaluator.
//
// Evaluation follows the W3C recommendation: a location path selects nodes by
// applying each step to every node of the current node-set, predicates are
// evaluated with a position and size local_part to one context node, and the result
// of a step is always returned in document order.

///|
/// A dynamic evaluation error, such as a variable that has no binding.
pub suberror EvaluationError {
  Message(String)
}

///|
/// The evaluation context: a context node, its position and size, the variable
/// bindings and the namespace declarations of the stylesheet.
pub struct EvalContext {
  doc : @xml.Document
  node : Int32
  position : Int32
  size : Int32
  variables : Array[(String, Value)]
  namespaces : Array[(String, String)]
  user_functions : Array[
    (String, (Array[Expr], EvalContext) -> Value raise EvaluationError),
  ]
}

///|
/// Create a context for a single node.
pub fn EvalContext::new(doc : @xml.Document, node : Int32) -> EvalContext {
  {
    doc,
    node,
    position: 1,
    size: 1,
    variables: [],
    namespaces: [],
    user_functions: [],
  }
}

///|
/// Return a copy of the context with the given variable bindings.
pub fn EvalContext::with_variables(
  self : EvalContext,
  variables : Array[(String, Value)],
) -> EvalContext {
  {
    doc: self.doc,
    node: self.node,
    position: self.position,
    size: self.size,
    variables,
    namespaces: self.namespaces,
    user_functions: self.user_functions,
  }
}

///|
/// Return a copy of the context with the given stylesheet namespace bindings.
pub fn EvalContext::with_namespaces(
  self : EvalContext,
  namespaces : Array[(String, String)],
) -> EvalContext {
  {
    doc: self.doc,
    node: self.node,
    position: self.position,
    size: self.size,
    variables: self.variables,
    namespaces,
    user_functions: self.user_functions,
  }
}

///|
/// Return a copy of the context focused on another node.
pub fn EvalContext::with_node(self : EvalContext, node : Int32) -> EvalContext {
  {
    doc: self.doc,
    node,
    position: 1,
    size: 1,
    variables: self.variables,
    namespaces: self.namespaces,
    user_functions: self.user_functions,
  }
}

///|
/// Return a copy of the context with an extra function implementation.
pub fn EvalContext::with_function(
  self : EvalContext,
  name : String,
  function : (Array[Expr], EvalContext) -> Value raise EvaluationError,
) -> EvalContext {
  let functions : Array[
    (String, (Array[Expr], EvalContext) -> Value raise EvaluationError),
  ] = []
  for entry in self.user_functions {
    functions.push(entry)
  }
  functions.push((name, function))
  {
    doc: self.doc,
    node: self.node,
    position: self.position,
    size: self.size,
    variables: self.variables,
    namespaces: self.namespaces,
    user_functions: functions,
  }
}

///|
/// Evaluate an expression against a context.
pub fn evaluate(
  expression : Expr,
  context : EvalContext,
) -> Value raise EvaluationError {
  match expression {
    NumberLiteral(value) => Number(value)
    StringLiteral(value) => String(value)
    VariableReference(name) =>
      match lookup_variable(context, name) {
        Some(value) => value
        None => raise EvaluationError::Message("unbound variable $" + name)
      }
    Or(left, right) =>
      Boolean(
        evaluate(left, context).boolean_value() ||
        evaluate(right, context).boolean_value(),
      )
    And(left, right) =>
      Boolean(
        evaluate(left, context).boolean_value() &&
        evaluate(right, context).boolean_value(),
      )
    Comparison(operator, left, right) => {
      let left_value = evaluate(left, context)
      let right_value = evaluate(right, context)
      Boolean(compare_values(context.doc, operator, left_value, right_value))
    }
    Arithmetic(operator, left, right) => {
      let left_value = evaluate(left, context).number_value(context.doc)
      let right_value = evaluate(right, context).number_value(context.doc)
      Number(apply_arithmetic(operator, left_value, right_value))
    }
    Negate(operand) =>
      Number(-evaluate(operand, context).number_value(context.doc))
    Union(left, right) =>
      match (evaluate(left, context), evaluate(right, context)) {
        (Nodes(left_set), Nodes(right_set)) =>
          Nodes(left_set.union(context.doc, right_set))
        _ => raise EvaluationError::Message("union requires two node-sets")
      }
    LocationPath(absolute, steps) => {
      let start = if absolute {
        [context.doc.root_of(context.node)]
      } else {
        [context.node]
      }
      Nodes(NodeSet::new(context.doc, eval_steps(context, start, steps)))
    }
    Filter(primary, predicates) =>
      match evaluate(primary, context) {
        Nodes(set) => {
          let selected = apply_predicates(
            context,
            set.nodes().to_owned(),
            predicates,
          )
          Nodes(NodeSet::new(context.doc, selected))
        }
        _ => raise EvaluationError::Message("a predicate requires a node-set")
      }
    Path(primary, steps) =>
      match evaluate(primary, context) {
        Nodes(set) => {
          let selected = eval_steps(context, set.nodes().to_owned(), steps)
          Nodes(NodeSet::new(context.doc, selected))
        }
        _ => raise EvaluationError::Message("a path requires a node-set")
      }
    FunctionCall(name, arguments) => call_function(name, arguments, context)
  }
}

///|
/// Evaluate every step of a location path against a node-set.
fn eval_steps(
  context : EvalContext,
  start : Array[Int32],
  steps : Array[Step],
) -> Array[Int32] raise EvaluationError {
  let mut current = start
  for step in steps {
    let next : Array[Int32] = []
    for node in current {
      let candidates = axis_nodes(context, node, step)
      let filtered = match step {
        AxisStep(_axis, _test, predicates) =>
          apply_predicates(context, candidates, predicates)
        _ => candidates
      }
      for id in filtered {
        next.push(id)
      }
    }
    current = context.doc.sort_document_order(next)
  }
  current
}

///|
/// Apply predicates to a candidate list, numbering positions from one in the
/// order the axis produced.
fn apply_predicates(
  context : EvalContext,
  candidates : Array[Int32],
  predicates : Array[Expr],
) -> Array[Int32] raise EvaluationError {
  let mut current = candidates
  for predicate in predicates {
    let kept : Array[Int32] = []
    let size = current.length()
    for i in 0..<size {
      let node = current[i]
      let predicate_context : EvalContext = {
        doc: context.doc,
        node,
        position: i + 1,
        size,
        variables: context.variables,
        namespaces: context.namespaces,
        user_functions: context.user_functions,
      }
      let value = evaluate(predicate, predicate_context)
      let keep = match value {
        Number(number) => number == (i + 1).to_double()
        _ => value.boolean_value()
      }
      if keep {
        kept.push(node)
      }
    }
    current = kept
  }
  current
}

///|
/// The nodes selected by one step from a single context node, in axis order.
fn axis_nodes(context : EvalContext, node : Int32, step : Step) -> Array[Int32] {
  match step {
    SelfStep => [node]
    ParentStep =>
      match context.doc.parent(node) {
        Some(parent) => [parent]
        None => []
      }
    AxisStep(axis, node_test, _predicates) => {
      let selected : Array[Int32] = []
      for candidate in axis_candidates(context.doc, node, axis) {
        if matches_node_test(
            context.doc,
            candidate,
            axis,
            node_test,
            context.namespaces,
          ) {
          selected.push(candidate)
        }
      }
      selected
    }
  }
}

///|
/// The unordered node list of an axis, in axis order: forward axes in document
/// order and reverse axes from the nearest node outwards.
fn axis_candidates(
  doc : @xml.Document,
  node : Int32,
  axis : Axis,
) -> Array[Int32] {
  match axis {
    Child => doc.children(node).to_owned()
    Descendant => doc.descendants(node)
    DescendantOrSelf => doc.descendants_or_self(node)
    Self => [node]
    Parent =>
      match doc.parent(node) {
        Some(parent) => [parent]
        None => []
      }
    Ancestor => doc.ancestors(node)
    AncestorOrSelf => doc.ancestors_or_self(node)
    FollowingSibling => doc.following_siblings(node)
    PrecedingSibling => reverse(doc.preceding_siblings(node))
    Following => doc.following(node)
    Preceding => reverse(doc.preceding(node))
    Attribute => doc.attributes(node).to_owned()
    Namespace => []
  }
}

///|
fn reverse(nodes : Array[Int32]) -> Array[Int32] {
  let result : Array[Int32] = []
  let mut i = nodes.length()
  while i > 0 {
    i = i - 1
    result.push(nodes[i])
  }
  result
}

///|
/// Whether a node matches a node node_test on a given axis.
///
/// The namespace declarations of the stylesheet are passed in so that prefixed
/// name tests compare expanded names; when the list is empty, prefixes are
/// compared literally, which keeps the function usable without a stylesheet.
pub fn matches_node_test(
  doc : @xml.Document,
  node : Int32,
  axis : Axis,
  node_test : NodeTest,
  namespaces : Array[(String, String)],
) -> Bool {
  match node_test {
    AnyNodeTest => true
    TextTest => doc.is_text(node)
    CommentTest => doc.is_comment(node)
    ProcessingInstructionTest(target) =>
      doc.is_processing_instruction(node) &&
      (match target {
        Some(name) => doc.qualified_name(node) == name
        None => true
      })
    NameTest(prefix, local_part) => {
      let kind_matches = match axis {
        Attribute => doc.is_attribute(node)
        Namespace => false
        _ => doc.is_element(node)
      }
      if !kind_matches {
        return false
      }
      let node_local = doc.local_name(node)
      if local_part != "*" && node_local != local_part {
        return false
      }
      if prefix == "" {
        return doc.namespace_uri(node) == ""
      }
      match resolve_test_prefix(prefix, namespaces) {
        Some(uri) => doc.namespace_uri(node) == uri
        None => true
      }
    }
  }
}

///|
fn resolve_test_prefix(
  prefix : String,
  namespaces : Array[(String, String)],
) -> String? {
  for declaration in namespaces {
    if declaration.0 == prefix {
      return Some(declaration.1)
    }
  }
  None
}

///|
fn lookup_variable(context : EvalContext, name : String) -> Value? {
  for binding in context.variables {
    if binding.0 == name {
      return Some(binding.1)
    }
  }
  None
}

///|
fn apply_arithmetic(
  operator : ArithmeticOp,
  left : Double,
  right : Double,
) -> Double {
  match operator {
    Add => left + right
    Subtract => left - right
    Multiply => left * right
    Divide => left / right
    Modulo => left - right * (left / right).trunc()
  }
}

///|
fn is_equality(operator : ComparisonOp) -> Bool {
  match operator {
    Equal => true
    _ => false
  }
}

///|
fn is_inequality(operator : ComparisonOp) -> Bool {
  match operator {
    NotEqual => true
    _ => false
  }
}

///|
/// Mirror an operator so that a node-set on the right can be compared from the
/// left without duplicating the node-set logic.
fn mirror(operator : ComparisonOp) -> ComparisonOp {
  match operator {
    Less => Greater
    LessOrEqual => GreaterOrEqual
    Greater => Less
    GreaterOrEqual => LessOrEqual
    Equal => Equal
    NotEqual => NotEqual
  }
}

///|
/// XPath comparisons, including the existential semantics over node-sets.
fn compare_values(
  doc : @xml.Document,
  operator : ComparisonOp,
  left : Value,
  right : Value,
) -> Bool {
  match (left, right) {
    (Nodes(left_set), Nodes(right_set)) =>
      compare_node_sets(doc, operator, left_set, right_set)
    (Nodes(set), other) =>
      compare_node_set_with_value(doc, operator, set, other)
    (other, Nodes(set)) =>
      compare_node_set_with_value(doc, mirror(operator), set, other)
    _ => compare_scalars(doc, operator, left, right)
  }
}

///|
fn compare_node_sets(
  doc : @xml.Document,
  operator : ComparisonOp,
  left : NodeSet,
  right : NodeSet,
) -> Bool {
  let equality = is_equality(operator)
  let inequality = is_inequality(operator)
  for left_node in left.nodes() {
    for right_node in right.nodes() {
      if equality || inequality {
        let a = string_of_node(doc, left_node)
        let b = string_of_node(doc, right_node)
        if equality && a == b {
          return true
        }
        if inequality && a != b {
          return true
        }
      } else {
        let a = parse_number(string_of_node(doc, left_node))
        let b = parse_number(string_of_node(doc, right_node))
        if compare_numbers(operator, a, b) {
          return true
        }
      }
    }
  }
  false
}

///|
fn compare_node_set_with_value(
  doc : @xml.Document,
  operator : ComparisonOp,
  set : NodeSet,
  other : Value,
) -> Bool {
  let equality = is_equality(operator)
  let inequality = is_inequality(operator)
  if !equality && !inequality {
    let target = other.number_value(doc)
    for node in set.nodes() {
      let value = parse_number(string_of_node(doc, node))
      if compare_numbers(operator, value, target) {
        return true
      }
    }
    return false
  }
  match other {
    Boolean(value) => {
      let set_value = !set.is_empty()
      if equality {
        set_value == value
      } else {
        set_value != value
      }
    }
    Number(number) => {
      for node in set.nodes() {
        let value = parse_number(string_of_node(doc, node))
        let matched = if equality { value == number } else { value != number }
        if matched {
          return true
        }
      }
      false
    }
    String(text) => {
      for node in set.nodes() {
        let value = string_of_node(doc, node)
        let matched = if equality { value == text } else { value != text }
        if matched {
          return true
        }
      }
      false
    }
    Nodes(_) => false
  }
}

///|
fn compare_scalars(
  doc : @xml.Document,
  operator : ComparisonOp,
  left : Value,
  right : Value,
) -> Bool {
  let equality = is_equality(operator)
  let inequality = is_inequality(operator)
  if !equality && !inequality {
    return compare_numbers(
      operator,
      left.number_value(doc),
      right.number_value(doc),
    )
  }
  if is_boolean_value(left) || is_boolean_value(right) {
    let equal = left.boolean_value() == right.boolean_value()
    if equality {
      equal
    } else {
      !equal
    }
  } else if is_number_value(left) || is_number_value(right) {
    let a = left.number_value(doc)
    let b = right.number_value(doc)
    if equality {
      a == b
    } else {
      a != b
    }
  } else {
    let a = left.string_value(doc)
    let b = right.string_value(doc)
    if equality {
      a == b
    } else {
      a != b
    }
  }
}

///|
fn is_boolean_value(value : Value) -> Bool {
  match value {
    Boolean(_) => true
    _ => false
  }
}

///|
fn is_number_value(value : Value) -> Bool {
  match value {
    Number(_) => true
    _ => false
  }
}

///|
fn compare_numbers(
  operator : ComparisonOp,
  left : Double,
  right : Double,
) -> Bool {
  match operator {
    Equal => left == right
    NotEqual => left != right
    Less => left < right
    LessOrEqual => left <= right
    Greater => left > right
    GreaterOrEqual => left >= right
  }
}

///|
/// Dispatch a builtin function call.
fn call_function(
  name : String,
  arguments : Array[Expr],
  context : EvalContext,
) -> Value raise EvaluationError {
  match name {
    "position" => Number(context.position.to_double())
    "last" => Number(context.size.to_double())
    "count" => {
      expect_arity(name, arguments, 1)
      match evaluate(arguments[0], context) {
        Nodes(set) => Number(set.length().to_double())
        _ => raise EvaluationError::Message("count() requires a node-set")
      }
    }
    "name" => {
      let node = optional_node_argument(name, arguments, context)
      match node {
        Some(id) => String(context.doc.qualified_name(id))
        None => String("")
      }
    }
    "local_part-name" => {
      let node = optional_node_argument(name, arguments, context)
      match node {
        Some(id) => String(context.doc.local_name(id))
        None => String("")
      }
    }
    "namespace-uri" => {
      let node = optional_node_argument(name, arguments, context)
      match node {
        Some(id) => String(context.doc.namespace_uri(id))
        None => String("")
      }
    }
    "string" =>
      if arguments.length() == 0 {
        String(string_of_node(context.doc, context.node))
      } else {
        String(evaluate(arguments[0], context).string_value(context.doc))
      }
    "number" =>
      if arguments.length() == 0 {
        Number(parse_number(string_of_node(context.doc, context.node)))
      } else {
        Number(evaluate(arguments[0], context).number_value(context.doc))
      }
    "boolean" => {
      expect_arity(name, arguments, 1)
      Boolean(evaluate(arguments[0], context).boolean_value())
    }
    "not" => {
      expect_arity(name, arguments, 1)
      Boolean(!evaluate(arguments[0], context).boolean_value())
    }
    "true" => Boolean(true)
    "false" => Boolean(false)
    _ => {
      let mut implemented : Value? = None
      for entry in context.user_functions {
        if entry.0 == name {
          implemented = Some((entry.1)(arguments, context))
        }
      }
      match implemented {
        Some(value) => value
        None => call_library_function(name, arguments, context)
      }
    }
  }
}

///|
fn expect_arity(
  name : String,
  arguments : Array[Expr],
  expected : Int32,
) -> Unit raise EvaluationError {
  if arguments.length() != expected {
    raise EvaluationError::Message(
      name + "() expects " + expected.to_string() + " argument(s)",
    )
  }
}

///|
/// Evaluate an optional node-set argument and return its first node.
fn optional_node_argument(
  name : String,
  arguments : Array[Expr],
  context : EvalContext,
) -> Int32? raise EvaluationError {
  if arguments.length() == 0 {
    Some(context.node)
  } else if arguments.length() == 1 {
    match evaluate(arguments[0], context) {
      Nodes(set) => set.first()
      _ => raise EvaluationError::Message(name + "() requires a node-set")
    }
  } else {
    raise EvaluationError::Message(name + "() expects at most one argument")
  }
}

///|
/// Return a copy of the context with the given proximity position and size.
pub fn EvalContext::with_position(
  self : EvalContext,
  position : Int32,
  size : Int32,
) -> EvalContext {
  {
    doc: self.doc,
    node: self.node,
    position,
    size,
    variables: self.variables,
    namespaces: self.namespaces,
    user_functions: self.user_functions,
  }
}

///|
/// The document the context evaluates against.
pub fn EvalContext::document(self : EvalContext) -> @xml.Document {
  self.doc
}

///|
/// Raise a dynamic evaluation error with the given message.
pub fn[T] raise_function_error(message : String) -> T raise EvaluationError {
  raise EvaluationError::Message(message)
}
