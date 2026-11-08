// Tokenizer for XPath 1.0 expressions.

///|
/// The lexical categories of XPath 1.0.
///
/// Operators that are spelled as names (`and`, `or`, `div`, `mod`) are lexed as
/// `Name` and recognised by the parser, as required by the grammar.
pub(all) enum TokenKind {
  Name
  Number
  Literal
  Slash
  DoubleSlash
  Dot
  DotDot
  At
  LeftParen
  RightParen
  LeftBracket
  RightBracket
  Comma
  ColonColon
  Pipe
  Plus
  Minus
  Star
  Equal
  NotEqual
  Less
  LessOrEqual
  Greater
  GreaterOrEqual
  Dollar
  Eof
}

///|
/// A token together with its source offset.
pub struct Token {
  kind : TokenKind
  text : String
  position : Int32
}

///|
/// Human-readable description used in parse errors.
pub fn Token::describe(self : Token) -> String {
  match self.kind {
    Name => "\"" + self.text + "\""
    Number => "number " + self.text
    Literal => "literal " + self.text
    Eof => "end of expression"
    _ => self.text
  }
}

///|
/// Split an XPath expression into tokens.
pub fn tokenize(text : String) -> Array[Token] {
  let lexer = Lexer::new(text)
  let tokens : Array[Token] = []
  while true {
    lexer.skip_whitespace()
    if lexer.at_end() {
      tokens.push({ kind: Eof, text: "", position: lexer.pos, })
      break
    }
    tokens.push(lexer.next_token())
  }
  tokens
}

///|
/// The tokenizer state.
priv struct Lexer {
  src : Array[Char]
  mut pos : Int32
}

///|
fn Lexer::new(text : String) -> Lexer {
  { src: text.to_array(), pos: 0, }
}

///|
fn Lexer::at_end(self : Lexer) -> Bool {
  self.pos >= self.src.length()
}

///|
fn Lexer::peek(self : Lexer) -> Char {
  if self.pos < self.src.length() {
    self.src[self.pos]
  } else {
    Int32::unsafe_to_char(0)
  }
}

///|
fn Lexer::peek_at(self : Lexer, offset : Int32) -> Char {
  let index = self.pos + offset
  if index < self.src.length() {
    self.src[index]
  } else {
    Int32::unsafe_to_char(0)
  }
}

///|
fn Lexer::advance(self : Lexer) -> Unit {
  self.pos = self.pos + 1
}

///|
fn Lexer::skip_whitespace(self : Lexer) -> Unit {
  while !self.at_end() {
    let c = self.peek()
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      self.advance()
    } else {
      break
    }
  }
}

///|
fn Lexer::next_token(self : Lexer) -> Token {
  let start = self.pos
  let c = self.peek()
  if c == '/' && self.peek_at(1) == '/' {
    self.pos = self.pos + 2
    return { kind: DoubleSlash, text: "//", position: start, }
  }
  if c == '/' {
    self.advance()
    return { kind: Slash, text: "/", position: start, }
  }
  if c == ':' && self.peek_at(1) == ':' {
    self.pos = self.pos + 2
    return { kind: ColonColon, text: "::", position: start, }
  }
  if c == '.' && self.peek_at(1) == '.' {
    self.pos = self.pos + 2
    return { kind: DotDot, text: "..", position: start, }
  }
  if c == '.' && is_digit(self.peek_at(1)) {
    return self.scan_number()
  }
  if is_digit(c) {
    return self.scan_number()
  }
  if c == '"' || c == '\'' {
    return self.scan_literal(c)
  }
  if c == '!' && self.peek_at(1) == '=' {
    self.pos = self.pos + 2
    return { kind: NotEqual, text: "!=", position: start, }
  }
  if c == '<' && self.peek_at(1) == '=' {
    self.pos = self.pos + 2
    return { kind: LessOrEqual, text: "<=", position: start, }
  }
  if c == '>' && self.peek_at(1) == '=' {
    self.pos = self.pos + 2
    return { kind: GreaterOrEqual, text: ">=", position: start, }
  }
  if is_name_start_char(c) {
    return self.scan_name()
  }
  self.advance()
  let kind = match c {
    '.' => Dot
    '@' => At
    '(' => LeftParen
    ')' => RightParen
    '[' => LeftBracket
    ']' => RightBracket
    ',' => Comma
    '|' => Pipe
    '+' => Plus
    '-' => Minus
    '*' => Star
    '=' => Equal
    '<' => Less
    '>' => Greater
    '$' => Dollar
    _ => Eof
  }
  { kind, text: String::from_array([c]), position: start, }
}

///|
fn Lexer::scan_number(self : Lexer) -> Token {
  let start = self.pos
  while !self.at_end() && is_digit(self.peek()) {
    self.advance()
  }
  if !self.at_end() && self.peek() == '.' {
    self.advance()
    while !self.at_end() && is_digit(self.peek()) {
      self.advance()
    }
  }
  {
    kind: Number,
    text: String::from_array(self.src[start:self.pos]),
    position: start,
  }
}

///|
fn Lexer::scan_literal(self : Lexer, quote : Char) -> Token {
  let start = self.pos
  self.advance()
  let content_start = self.pos
  while !self.at_end() && self.peek() != quote {
    self.advance()
  }
  let content = String::from_array(self.src[content_start:self.pos])
  if !self.at_end() {
    self.advance()
  }
  { kind: Literal, text: content, position: start, }
}

///|
fn Lexer::scan_name(self : Lexer) -> Token {
  let start = self.pos
  self.advance()
  while !self.at_end() {
    let c = self.peek()
    if c == ':' {
      if self.peek_at(1) == ':' {
        break
      }
      if self.peek_at(1) == '*' {
        self.pos = self.pos + 2
        break
      }
      if is_name_start_char(self.peek_at(1)) {
        self.pos = self.pos + 2
        continue
      }
      break
    }
    if is_name_char(c) && c != ':' {
      self.advance()
      continue
    }
    break
  }
  {
    kind: Name,
    text: String::from_array(self.src[start:self.pos]),
    position: start,
  }
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_name_start_char(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 0x41 && code <= 0x5A) ||
  (code >= 0x61 && code <= 0x7A) ||
  c == '_' ||
  code >= 0x80
}

///|
fn is_name_char(c : Char) -> Bool {
  is_name_start_char(c) || is_digit(c) || c == '-' || c == '.'
}
