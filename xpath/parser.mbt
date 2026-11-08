// Recursive-descent parser for XPath 1.0 expressions.
//
// The grammar follows the W3C XPath 1.0 recommendation, including the
// abbreviated syntax (`//`, `.`, `..`, `@`) and the disambiguation of operator
// keywords (`and`, `or`, `div`, `mod`) by grammatical position.

///|
/// A syntax error with the offset in the source expression.
pub(all) struct ParseErrorInfo {
  message : String
  position : Int32
}

///|
/// Internal parse failure.
pub suberror ParseError {
  Syntax(String, Int32)
}

///|
/// Parse an XPath expression.
pub fn parse(text : String) -> Result[Expr, ParseErrorInfo] {
  Ok(parse_expression(text)) catch {
    ParseError::Syntax(message, position) => Err({ message, position, })
  }
}

///|
/// Parse an XPath expression, raising `ParseError` on invalid syntax.
pub fn parse_expression(text : String) -> Expr raise ParseError {
  let parser = Parser::new(tokenize(text))
  let expression = parser.parse_expr()
  if !parser.at("eof") {
    parser.fail("unexpected " + parser.peek().describe())
  }
  expression
}

///|
/// Stable labels for token kinds, used instead of an `Eq` implementation so
/// that the parser can dispatch on tokens without deriving traits.
fn label_of(kind : TokenKind) -> String {
  match kind {
    Name => "name"
    Number => "number"
    Literal => "literal"
    Slash => "slash"
    DoubleSlash => "double_slash"
    Dot => "dot"
    DotDot => "dot_dot"
    At => "at"
    LeftParen => "left_paren"
    RightParen => "right_paren"
    LeftBracket => "left_bracket"
    RightBracket => "right_bracket"
    Comma => "comma"
    ColonColon => "colon_colon"
    Pipe => "pipe"
    Plus => "plus"
    Minus => "minus"
    Star => "star"
    Equal => "equal"
    NotEqual => "not_equal"
    Less => "less"
    LessOrEqual => "less_or_equal"
    Greater => "greater"
    GreaterOrEqual => "greater_or_equal"
    Dollar => "dollar"
    Eof => "eof"
  }
}

///|
fn Token::label(self : Token) -> String {
  label_of(self.kind)
}

///|
/// The parser state.
priv struct Parser {
  tokens : Array[Token]
  mut pos : Int32
}

///|
fn Parser::new(tokens : Array[Token]) -> Parser {
  { tokens, pos: 0, }
}

///|
fn Parser::peek(self : Parser) -> Token {
  self.tokens[self.pos]
}

///|
fn Parser::peek_ahead(self : Parser, offset : Int32) -> Token {
  let index = self.pos + offset
  if index < self.tokens.length() {
    self.tokens[index]
  } else {
    self.tokens[self.tokens.length() - 1]
  }
}

///|
fn Parser::at(self : Parser, label : String) -> Bool {
  self.peek().label() == label
}

///|
fn Parser::advance(self : Parser) -> Token {
  let token = self.peek()
  if self.pos < self.tokens.length() - 1 {
    self.pos = self.pos + 1
  }
  token
}

///|
fn ignore_token(token : Token) -> Unit {
  let _ = token
}

///|
fn[T] Parser::fail(self : Parser, message : String) -> T raise ParseError {
  raise ParseError::Syntax(message, self.peek().position)
}

///|
fn Parser::expect(self : Parser, label : String) -> Token raise ParseError {
  if self.at(label) {
    self.advance()
  } else {
    self.fail("expected " + label + " but found " + self.peek().describe())
    self.peek()
  }
}

///|
fn Parser::parse_expr(self : Parser) -> Expr raise ParseError {
  self.parse_or()
}

///|
fn Parser::parse_or(self : Parser) -> Expr raise ParseError {
  let mut left = self.parse_and()
  while self.at("name") && self.peek().text == "or" {
    self.advance() |> ignore_token
    let right = self.parse_and()
    left = Or(left, right)
  }
  left
}

///|
fn Parser::parse_and(self : Parser) -> Expr raise ParseError {
  let mut left = self.parse_equality()
  while self.at("name") && self.peek().text == "and" {
    self.advance() |> ignore_token
    let right = self.parse_equality()
    left = And(left, right)
  }
  left
}

///|
fn Parser::parse_equality(self : Parser) -> Expr raise ParseError {
  let mut left = self.parse_relational()
  while true {
    if self.at("equal") {
      self.advance() |> ignore_token
      left = Comparison(ComparisonOp::Equal, left, self.parse_relational())
    } else if self.at("not_equal") {
      self.advance() |> ignore_token
      left = Comparison(ComparisonOp::NotEqual, left, self.parse_relational())
    } else {
      break
    }
  }
  left
}

///|
fn Parser::parse_relational(self : Parser) -> Expr raise ParseError {
  let mut left = self.parse_additive()
  while true {
    let operator = if self.at("less") {
      Some(ComparisonOp::Less)
    } else if self.at("less_or_equal") {
      Some(ComparisonOp::LessOrEqual)
    } else if self.at("greater") {
      Some(ComparisonOp::Greater)
    } else if self.at("greater_or_equal") {
      Some(ComparisonOp::GreaterOrEqual)
    } else {
      None
    }
    match operator {
      Some(operator) => {
        self.advance() |> ignore_token
        left = Comparison(operator, left, self.parse_additive())
      }
      None => break
    }
  }
  left
}

///|
fn Parser::parse_additive(self : Parser) -> Expr raise ParseError {
  let mut left = self.parse_multiplicative()
  while true {
    if self.at("plus") {
      self.advance() |> ignore_token
      left = Arithmetic(Add, left, self.parse_multiplicative())
    } else if self.at("minus") {
      self.advance() |> ignore_token
      left = Arithmetic(Subtract, left, self.parse_multiplicative())
    } else {
      break
    }
  }
  left
}

///|
fn Parser::parse_multiplicative(self : Parser) -> Expr raise ParseError {
  let mut left = self.parse_unary()
  while true {
    if self.at("star") {
      self.advance() |> ignore_token
      left = Arithmetic(Multiply, left, self.parse_unary())
    } else if self.at("name") && self.peek().text == "div" {
      self.advance() |> ignore_token
      left = Arithmetic(Divide, left, self.parse_unary())
    } else if self.at("name") && self.peek().text == "mod" {
      self.advance() |> ignore_token
      left = Arithmetic(Modulo, left, self.parse_unary())
    } else {
      break
    }
  }
  left
}

///|
fn Parser::parse_unary(self : Parser) -> Expr raise ParseError {
  if self.at("minus") {
    self.advance() |> ignore_token
    Negate(self.parse_unary())
  } else {
    self.parse_union()
  }
}

///|
fn Parser::parse_union(self : Parser) -> Expr raise ParseError {
  let mut left = self.parse_path_expr()
  while self.at("pipe") {
    self.advance() |> ignore_token
    left = Union(left, self.parse_path_expr())
  }
  left
}

///|
fn Parser::parse_path_expr(self : Parser) -> Expr raise ParseError {
  if self.at("slash") {
    self.advance() |> ignore_token
    let steps = if self.starts_step() {
      self.parse_relative_steps()
    } else {
      []
    }
    return LocationPath(true, steps)
  }
  if self.at("double_slash") {
    self.advance() |> ignore_token
    let steps : Array[Step] = [AxisStep(DescendantOrSelf, AnyNodeTest, [])]
    for step in self.parse_relative_steps() {
      steps.push(step)
    }
    return LocationPath(true, steps)
  }
  if self.starts_primary() {
    let primary = self.parse_filter_expr()
    if self.at("slash") || self.at("double_slash") {
      let steps = self.parse_relative_steps()
      return Path(primary, steps)
    }
    return primary
  }
  if self.starts_step() {
    return LocationPath(false, self.parse_relative_steps())
  }
  self.fail("unexpected " + self.peek().describe())
}

///|
fn Parser::starts_primary(self : Parser) -> Bool {
  if self.at("literal") ||
    self.at("number") ||
    self.at("dollar") ||
    self.at("left_paren") {
    return true
  }
  if self.at("name") && self.peek_ahead(1).label() == "left_paren" {
    let name = self.peek().text
    return !(name == "text" ||
      name == "comment" ||
      name == "node" ||
      name == "processing-instruction")
  }
  false
}

///|
fn Parser::starts_step(self : Parser) -> Bool {
  self.at("name") ||
  self.at("star") ||
  self.at("at") ||
  self.at("dot") ||
  self.at("dot_dot")
}

///|
fn Parser::parse_filter_expr(self : Parser) -> Expr raise ParseError {
  let primary = self.parse_primary()
  let predicates = self.parse_predicates()
  if predicates.length() == 0 {
    primary
  } else {
    Filter(primary, predicates)
  }
}

///|
fn Parser::parse_predicates(self : Parser) -> Array[Expr] raise ParseError {
  let predicates : Array[Expr] = []
  while self.at("left_bracket") {
    self.advance() |> ignore_token
    predicates.push(self.parse_expr())
    self.expect("right_bracket") |> ignore_token
  }
  predicates
}

///|
fn Parser::parse_primary(self : Parser) -> Expr raise ParseError {
  if self.at("literal") {
    let token = self.advance()
    return StringLiteral(token.text)
  }
  if self.at("number") {
    let token = self.advance()
    return NumberLiteral(parse_number(token.text))
  }
  if self.at("dollar") {
    self.advance() |> ignore_token
    let name = self.expect("name")
    return VariableReference(name.text)
  }
  if self.at("left_paren") {
    self.advance() |> ignore_token
    let expression = self.parse_expr()
    self.expect("right_paren") |> ignore_token
    return expression
  }
  if self.at("name") && self.peek_ahead(1).label() == "left_paren" {
    return self.parse_function_call()
  }
  self.fail("expected a primary expression but found " + self.peek().describe())
}

///|
fn Parser::parse_function_call(self : Parser) -> Expr raise ParseError {
  let name = self.advance().text
  self.expect("left_paren") |> ignore_token
  let arguments : Array[Expr] = []
  if !self.at("right_paren") {
    arguments.push(self.parse_expr())
    while self.at("comma") {
      self.advance() |> ignore_token
      arguments.push(self.parse_expr())
    }
  }
  self.expect("right_paren") |> ignore_token
  FunctionCall(name, arguments)
}

///|
/// Parse a relative location path, expanding the `//` abbreviation into an
/// explicit `descendant-or-self::node()` step.
fn Parser::parse_relative_steps(self : Parser) -> Array[Step] raise ParseError {
  let steps : Array[Step] = [self.parse_step()]
  while true {
    if self.at("slash") {
      self.advance() |> ignore_token
      steps.push(self.parse_step())
    } else if self.at("double_slash") {
      self.advance() |> ignore_token
      steps.push(AxisStep(DescendantOrSelf, AnyNodeTest, []))
      steps.push(self.parse_step())
    } else {
      break
    }
  }
  steps
}

///|
fn Parser::parse_step(self : Parser) -> Step raise ParseError {
  if self.at("dot") {
    self.advance() |> ignore_token
    return SelfStep
  }
  if self.at("dot_dot") {
    self.advance() |> ignore_token
    return ParentStep
  }
  let mut axis = Child
  if self.at("at") {
    self.advance() |> ignore_token
    axis = Attribute
  } else if self.at("name") && self.peek_ahead(1).label() == "colon_colon" {
    let axis_name = self.peek().text
    axis = match axis_from_name(axis_name) {
      Some(axis) => axis
      None => self.fail("unknown axis \"" + axis_name + "\"")
    }
    self.advance() |> ignore_token
    self.advance() |> ignore_token
  }
  let node_test = self.parse_node_test()
  let predicates = self.parse_predicates()
  AxisStep(axis, node_test, predicates)
}

///|
fn Parser::parse_node_test(self : Parser) -> NodeTest raise ParseError {
  if self.at("star") {
    self.advance() |> ignore_token
    return NameTest("", "*")
  }
  if !self.at("name") {
    self.fail("expected a node node_test but found " + self.peek().describe())
  }
  let name = self.peek().text
  let followed_by_paren = self.peek_ahead(1).label() == "left_paren"
  if followed_by_paren && name == "text" {
    self.advance() |> ignore_token
    self.advance() |> ignore_token
    self.expect("right_paren") |> ignore_token
    return TextTest
  }
  if followed_by_paren && name == "comment" {
    self.advance() |> ignore_token
    self.advance() |> ignore_token
    self.expect("right_paren") |> ignore_token
    return CommentTest
  }
  if followed_by_paren && name == "node" {
    self.advance() |> ignore_token
    self.advance() |> ignore_token
    self.expect("right_paren") |> ignore_token
    return AnyNodeTest
  }
  if followed_by_paren && name == "processing-instruction" {
    self.advance() |> ignore_token
    self.advance() |> ignore_token
    let target = if self.at("literal") {
      Some(self.advance().text)
    } else {
      None
    }
    self.expect("right_paren") |> ignore_token
    return ProcessingInstructionTest(target)
  }
  self.advance() |> ignore_token
  match split_test_name(name) {
    Some(parts) => NameTest(parts.0, parts.1)
    None => self.fail("invalid node node_test \"" + name + "\"")
  }
}

///|
/// Split a name node_test into its prefix and local_part part, where either the local_part
/// part may be `*` or the prefix may be absent.
fn split_test_name(name : String) -> (String, String)? {
  let chars = name.to_array()
  let mut colon = -1
  for i in 0..<chars.length() {
    if chars[i] == ':' {
      if colon >= 0 {
        return None
      }
      colon = i
    }
  }
  if colon < 0 {
    return Some(("", name))
  }
  let prefix = String::from_array(chars[0:colon])
  let local_part = String::from_array(chars[colon + 1:])
  if prefix == "" || local_part == "" {
    return None
  }
  Some((prefix, local_part))
}

///|
fn axis_from_name(name : String) -> Axis? {
  if name == "ancestor" {
    Some(Ancestor)
  } else if name == "ancestor-or-self" {
    Some(AncestorOrSelf)
  } else if name == "attribute" {
    Some(Attribute)
  } else if name == "child" {
    Some(Child)
  } else if name == "descendant" {
    Some(Descendant)
  } else if name == "descendant-or-self" {
    Some(DescendantOrSelf)
  } else if name == "following" {
    Some(Following)
  } else if name == "following-sibling" {
    Some(FollowingSibling)
  } else if name == "namespace" {
    Some(Namespace)
  } else if name == "parent" {
    Some(Parent)
  } else if name == "preceding" {
    Some(Preceding)
  } else if name == "preceding-sibling" {
    Some(PrecedingSibling)
  } else if name == "self" {
    Some(Self)
  } else {
    None
  }
}
