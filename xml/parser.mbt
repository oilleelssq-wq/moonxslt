// A recursive-descent XML 1.0 parser producing the arena document model.
//
// Scope: the document is parsed with namespace resolution, comments, CDATA
// sections and processing instructions. The internal DTD subset is skipped but
// not used for entity or attribute-default expansion; only the five predefined
// entities and character references are resolved. This is sufficient for XSLT
// stylesheets and for the documents they are applied to, and the limitation is
// documented in the README.

///|
/// Parse an XML document.
///
/// Returns a descriptive error, including the line and column, when the input is
/// not well formed.
pub fn parse(text : String) -> Result[Document, XmlErrorInfo] {
  Ok(parse_or_raise(text)) catch {
    XmlError::Parse(message, line, column) => Err({ message, line, column, })
  }
}

///|
/// Parse an XML document, raising `XmlError` on malformed input.
pub fn parse_or_raise(text : String) -> Document raise XmlError {
  let parser = Parser::new(text)
  parser.parse_prolog()
  if !parser.eof() {
    parser.fail("unexpected content after the document element")
  }
  parser.doc
}

///|
/// The parser state.
priv struct Parser {
  src : Array[Char]
  mut pos : Int32
  mut line : Int32
  mut column : Int32
  doc : Document
}

///|
fn Parser::new(text : String) -> Parser {
  { src: text.to_array(), pos: 0, line: 1, column: 1, doc: Document::empty(), }
}

///|
fn Parser::eof(self : Parser) -> Bool {
  self.pos >= self.src.length()
}

///|
fn Parser::peek(self : Parser) -> Char {
  if self.pos < self.src.length() {
    self.src[self.pos]
  } else {
    Int32::unsafe_to_char(0)
  }
}

///|
fn Parser::peek_at(self : Parser, offset : Int32) -> Char {
  let index = self.pos + offset
  if index < self.src.length() {
    self.src[index]
  } else {
    Int32::unsafe_to_char(0)
  }
}

///|
fn Parser::bump(self : Parser) -> Char {
  let c = self.src[self.pos]
  self.pos = self.pos + 1
  if c == '\n' {
    self.line = self.line + 1
    self.column = 1
  } else {
    self.column = self.column + 1
  }
  c
}

///|
fn Parser::advance(self : Parser) -> Unit {
  let _ = self.bump()
}

///|
fn Parser::fail(self : Parser, message : String) -> Unit raise XmlError {
  raise XmlError::Parse(message, self.line, self.column)
}

///|
fn Parser::starts_with(self : Parser, literal : String) -> Bool {
  let chars = literal.to_array()
  if self.pos + chars.length() > self.src.length() {
    return false
  }
  for i in 0..<chars.length() {
    if self.src[self.pos + i] != chars[i] {
      return false
    }
  }
  true
}

///|
fn Parser::consume_literal(
  self : Parser,
  literal : String,
) -> Unit raise XmlError {
  if !self.starts_with(literal) {
    self.fail("expected \"" + literal + "\"")
  }
  for _ in 0..<literal.to_array().length() {
    self.advance()
  }
}

///|
fn Parser::skip_whitespace(self : Parser) -> Unit {
  while !self.eof() && is_xml_whitespace(self.peek()) {
    self.advance()
  }
}

///|
/// Parse the XML declaration, the DOCTYPE and any leading comments or
/// processing instructions.
fn Parser::parse_prolog(self : Parser) -> Unit raise XmlError {
  // A leading byte-order mark is not part of the document content.
  if self.peek() == Int32::unsafe_to_char(0xFEFF) {
    self.advance()
  }
  let looks_like_declaration = self.starts_with("<?xml") &&
    (is_xml_whitespace(self.peek_at(5)) || self.peek_at(5) == '?')
  if looks_like_declaration {
    self.consume_literal("<?xml")
    self.skip_until("?>", "unterminated XML declaration")
    self.consume_literal("?>")
  }
  self.parse_misc()
  if self.starts_with("<!DOCTYPE") {
    self.skip_doctype()
    self.parse_misc()
  }
  self.parse_document_element()
  self.parse_misc()
}

///|
/// Parse comments, processing instructions and whitespace between markup items.
fn Parser::parse_misc(self : Parser) -> Unit raise XmlError {
  let mut progressed = true
  while progressed {
    self.skip_whitespace()
    if self.starts_with("<!--") {
      let _ = self.parse_comment(0)
    } else if self.starts_with("<?") {
      let _ = self.parse_processing_instruction(0)
    } else {
      progressed = false
    }
  }
}

///|
/// Parse the single document element.
fn Parser::parse_document_element(self : Parser) -> Unit raise XmlError {
  self.skip_whitespace()
  if self.eof() {
    self.fail("missing document element")
  }
  if self.peek() != '<' {
    self.fail("expected the document element")
  }
  let root = self.parse_element(0)
  self.doc.set_root(root)
}

///|
/// Skip a `<!DOCTYPE ...>` declaration, including an internal subset.
fn Parser::skip_doctype(self : Parser) -> Unit raise XmlError {
  self.consume_literal("<!DOCTYPE")
  let mut bracket_depth = 0
  let mut quote = Int32::unsafe_to_char(0)
  while true {
    if self.eof() {
      self.fail("unterminated DOCTYPE declaration")
    }
    let c = self.bump()
    if quote != Int32::unsafe_to_char(0) {
      if c == quote {
        quote = Int32::unsafe_to_char(0)
      }
    } else if c == '"' || c == '\'' {
      quote = c
    } else if c == '[' {
      bracket_depth = bracket_depth + 1
    } else if c == ']' {
      bracket_depth = bracket_depth - 1
    } else if c == '>' && bracket_depth <= 0 {
      break
    }
  }
}

///|
/// Read characters up to `terminator` without consuming it.
fn Parser::skip_until(
  self : Parser,
  terminator : String,
  message : String,
) -> Unit raise XmlError {
  while !self.starts_with(terminator) {
    if self.eof() {
      self.fail(message)
    }
    self.advance()
  }
}

///|
/// Parse an element, including its attributes, namespace declarations and
/// children, and return its node id.
fn Parser::parse_element(self : Parser, parent : Int32) -> Int32 raise XmlError {
  self.consume_literal("<")
  if self.peek() == '/' || self.peek() == '!' || self.peek() == '?' {
    self.fail("expected an element name")
  }
  let raw_name = self.parse_name()
  let attributes : Array[(String, String)] = []
  let mut self_closing = false
  let mut scanning_attributes = true
  while scanning_attributes {
    self.skip_whitespace()
    let c = self.peek()
    if c == '>' {
      self.advance()
      scanning_attributes = false
    } else if c == '/' {
      self.advance()
      self.consume_literal(">")
      self_closing = true
      scanning_attributes = false
    } else if c == Int32::unsafe_to_char(0) {
      self.fail("unterminated start tag <" + raw_name + ">")
    } else {
      let attribute_name = self.parse_name()
      self.skip_whitespace()
      self.consume_literal("=")
      self.skip_whitespace()
      let attribute_value = self.parse_attribute_value()
      attributes.push((attribute_name, attribute_value))
    }
  }
  self.check_duplicate_attributes(raw_name, attributes)
  let (prefix, local_part) = match split_qname(raw_name) {
    Some(parts) => parts
    None => {
      self.fail("invalid qualified name \"" + raw_name + "\"")
      ("", "")
    }
  }
  let element = self.doc.add_element(parent, QName::new(prefix, local_part, ""))
  self.declare_namespaces(element, attributes)
  let uri = self.resolve_element_prefix(element, prefix, raw_name)
  self.doc.set_element_name(element, prefix, local_part, uri)
  for attribute in attributes {
    let attribute_name = attribute.0
    if attribute_name == "xmlns" || attribute_name.has_prefix("xmlns:") {
      continue
    }
    let attribute_value = attribute.1
    let (attribute_prefix, attribute_local) = match
      split_qname(attribute_name) {
      Some(parts) => parts
      None => {
        self.fail("invalid attribute name \"" + attribute_name + "\"")
        ("", "")
      }
    }
    let attribute_uri = if attribute_prefix == "" {
      ""
    } else {
      match self.doc.resolve_prefix(element, attribute_prefix) {
        Some(uri) => uri
        None => {
          self.fail("undeclared namespace prefix \"" + attribute_prefix + "\"")
          ""
        }
      }
    }
    if self.doc.attribute_by_expanded(element, attribute_uri, attribute_local)
      is Some(_) {
      self.fail(
        "duplicate attribute \"{" + attribute_uri + "}" + attribute_local + "\"",
      )
    }
    let _ = self.doc.add_attribute(
      element,
      QName::new(attribute_prefix, attribute_local, attribute_uri),
      attribute_value,
    )
  }
  if !self_closing {
    self.parse_element_content(element, raw_name)
  }
  element
}

///|
/// Record the namespace declarations carried by an element's attributes.
fn Parser::declare_namespaces(
  self : Parser,
  element : Int32,
  attributes : Array[(String, String)],
) -> Unit raise XmlError {
  for attribute in attributes {
    let name = attribute.0
    let value = attribute.1
    if name == "xmlns" {
      self.doc.declare_namespace(element, "", value)
    } else if name.has_prefix("xmlns:") {
      let prefix = name[6:].to_owned()
      if prefix == "" || prefix.contains(":") {
        self.fail("invalid namespace declaration \"" + name + "\"")
      }
      if prefix == "xmlns" {
        self.fail("the prefix \"xmlns\" must not be declared")
      }
      if prefix == "xml" && value != "http://www.w3.org/XML/1998/namespace" {
        self.fail("the prefix \"xml\" must be bound to its reserved namespace")
      }
      self.doc.declare_namespace(element, prefix, value)
    }
  }
}

///|
/// Resolve the namespace of an element name, including its own declarations.
fn Parser::resolve_element_prefix(
  self : Parser,
  element : Int32,
  prefix : String,
  raw_name : String,
) -> String raise XmlError {
  match self.doc.resolve_prefix(element, prefix) {
    Some(uri) => uri
    None => {
      self.fail(
        "undeclared namespace prefix \"" + prefix + "\" in <" + raw_name + ">",
      )
      ""
    }
  }
}

///|
/// Parse the children of an element up to and including its end tag.
fn Parser::parse_element_content(
  self : Parser,
  element : Int32,
  raw_name : String,
) -> Unit raise XmlError {
  while true {
    if self.eof() {
      self.fail("unclosed element <" + raw_name + ">")
    }
    if self.starts_with("</") {
      self.consume_literal("</")
      let end_name = self.parse_name()
      self.skip_whitespace()
      self.consume_literal(">")
      if end_name != raw_name {
        self.fail(
          "end tag </" +
          end_name +
          "> does not match start tag <" +
          raw_name +
          ">",
        )
      }
      return
    }
    if self.starts_with("<!--") {
      let _ = self.parse_comment(element)
    } else if self.starts_with("<![CDATA[") {
      self.parse_cdata(element)
    } else if self.starts_with("<?") {
      let _ = self.parse_processing_instruction(element)
    } else if self.peek() == '<' {
      let _ = self.parse_element(element)
    } else {
      self.parse_text(element)
    }
  }
}

///|
/// Parse character data up to the next `<`.
fn Parser::parse_text(self : Parser, parent : Int32) -> Unit raise XmlError {
  let sb = StringBuilder::StringBuilder()
  while !self.eof() && self.peek() != '<' {
    sb.write_char(self.bump())
  }
  let raw = sb.to_string()
  if raw != "" {
    if raw.contains("]]>") {
      self.fail("\"]]>\" is not allowed in character data")
    }
    let decoded = decode_references(raw, self.line, self.column)
    let _ = self.doc.add_text(parent, decoded)
  }
}

///|
/// Parse a CDATA section, which contributes its raw characters as text.
fn Parser::parse_cdata(self : Parser, parent : Int32) -> Unit raise XmlError {
  self.consume_literal("<![CDATA[")
  let sb = StringBuilder::StringBuilder()
  while !self.starts_with("]]>") {
    if self.eof() {
      self.fail("unterminated CDATA section")
    }
    sb.write_char(self.bump())
  }
  self.consume_literal("]]>")
  let _ = self.doc.add_text(parent, sb.to_string())
}

///|
/// Parse a comment node.
fn Parser::parse_comment(self : Parser, parent : Int32) -> Int32 raise XmlError {
  self.consume_literal("<!--")
  let sb = StringBuilder::StringBuilder()
  while !self.starts_with("-->") {
    if self.eof() {
      self.fail("unterminated comment")
    }
    if self.starts_with("--") {
      self.fail("\"--\" is not allowed inside a comment")
    }
    sb.write_char(self.bump())
  }
  self.consume_literal("-->")
  self.doc.add_comment(parent, sb.to_string())
}

///|
/// Parse a processing-instruction node.
fn Parser::parse_processing_instruction(
  self : Parser,
  parent : Int32,
) -> Int32 raise XmlError {
  self.consume_literal("<?")
  let target = self.parse_name()
  if target.to_lower() == "xml" {
    self.fail(
      "the XML declaration is only allowed at the start of the document",
    )
  }
  if self.starts_with("?>") {
    self.consume_literal("?>")
    return self.doc.add_processing_instruction(parent, target, "")
  }
  self.skip_whitespace()
  let sb = StringBuilder::StringBuilder()
  while !self.starts_with("?>") {
    if self.eof() {
      self.fail("unterminated processing instruction")
    }
    sb.write_char(self.bump())
  }
  self.consume_literal("?>")
  self.doc.add_processing_instruction(parent, target, sb.to_string())
}

///|
/// Parse a quoted attribute value, normalising whitespace and decoding
/// character and entity references.
fn Parser::parse_attribute_value(self : Parser) -> String raise XmlError {
  let quote = self.peek()
  if quote != '"' && quote != '\'' {
    self.fail("expected a quoted attribute value")
  }
  self.advance()
  let sb = StringBuilder::StringBuilder()
  while true {
    if self.eof() {
      self.fail("unterminated attribute value")
    }
    let c = self.bump()
    if c == quote {
      break
    }
    if c == '<' {
      self.fail("\"<\" is not allowed in an attribute value")
    }
    if c == '\t' || c == '\n' || c == '\r' {
      sb.write_char(' ')
    } else {
      sb.write_char(c)
    }
  }
  decode_references(sb.to_string(), self.line, self.column)
}

///|
/// Parse an XML name. Non-ASCII characters are accepted as name characters,
/// which is sufficient for the practical documents this parser targets.
fn Parser::parse_name(self : Parser) -> String raise XmlError {
  if !is_name_start_char(self.peek()) {
    self.fail("expected a name")
  }
  let start = self.pos
  self.advance()
  while is_name_char(self.peek()) {
    self.advance()
  }
  String::from_array(self.src[start:self.pos])
}

///|
fn Parser::check_duplicate_attributes(
  self : Parser,
  raw_name : String,
  attributes : Array[(String, String)],
) -> Unit raise XmlError {
  for i in 0..<attributes.length() {
    for j in (i + 1)..<attributes.length() {
      if attributes[i].0 == attributes[j].0 {
        self.fail(
          "duplicate attribute \"" +
          attributes[i].0 +
          "\" on <" +
          raw_name +
          ">",
        )
      }
    }
  }
}

///|
/// XML 1.0 name start characters, accepting all non-ASCII code points.
fn is_name_start_char(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 0x41 && code <= 0x5A) ||
  (code >= 0x61 && code <= 0x7A) ||
  c == '_' ||
  c == ':' ||
  code >= 0x80
}

///|
/// XML 1.0 name characters.
fn is_name_char(c : Char) -> Bool {
  is_name_start_char(c) || (c >= '0' && c <= '9') || c == '-' || c == '.'
}

///|
/// Decode the predefined entities and numeric character references in `raw`.
fn decode_references(
  raw : String,
  line : Int32,
  column : Int32,
) -> String raise XmlError {
  let chars = raw.to_array()
  let sb = StringBuilder::StringBuilder()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c != '&' {
      sb.write_char(c)
      i = i + 1
      continue
    }
    let mut j = i + 1
    while j < chars.length() && chars[j] != ';' {
      j = j + 1
    }
    if j >= chars.length() {
      raise XmlError::Parse("unterminated reference", line, column)
    }
    let name = String::from_array(chars[i + 1:j])
    if name == "amp" {
      sb.write_char('&')
    } else if name == "lt" {
      sb.write_char('<')
    } else if name == "gt" {
      sb.write_char('>')
    } else if name == "quot" {
      sb.write_char('"')
    } else if name == "apos" {
      sb.write_char('\'')
    } else if name.has_prefix("#") {
      let code = parse_character_reference(name, line, column)
      sb.write_char(Int32::unsafe_to_char(code))
    } else {
      raise XmlError::Parse("unknown entity \"" + name + "\"", line, column)
    }
    i = j + 1
  }
  sb.to_string()
}

///|
/// Parse `#123` or `#x1F600` into a code point.
fn parse_character_reference(
  name : String,
  line : Int32,
  column : Int32,
) -> Int32 raise XmlError {
  let digits = name[1:].to_owned()
  let mut code = 0
  if digits.has_prefix("x") || digits.has_prefix("X") {
    let hex = digits[1:].to_owned()
    if hex == "" {
      raise XmlError::Parse("empty character reference", line, column)
    }
    for c in hex {
      let digit = match hex_digit_value(c) {
        Some(value) => value
        None =>
          raise XmlError::Parse("invalid character reference", line, column)
      }
      code = code * 16 + digit
    }
  } else {
    if digits == "" {
      raise XmlError::Parse("empty character reference", line, column)
    }
    for c in digits {
      if c < '0' || c > '9' {
        raise XmlError::Parse("invalid character reference", line, column)
      }
      code = code * 10 + (c.to_int() - '0'.to_int())
    }
  }
  if code <= 0 || code > 0x10FFFF {
    raise XmlError::Parse("character reference out of range", line, column)
  }
  code
}

///|
fn hex_digit_value(c : Char) -> Int32? {
  let code = c.to_int()
  if code >= 0x30 && code <= 0x39 {
    Some(code - 0x30)
  } else if code >= 0x41 && code <= 0x46 {
    Some(code - 0x41 + 10)
  } else if code >= 0x61 && code <= 0x66 {
    Some(code - 0x61 + 10)
  } else {
    None
  }
}
