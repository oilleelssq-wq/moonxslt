// Stylesheet compilation: turning the stylesheet document into the template
// tables and output settings the transformer works with.

///|
/// The XSLT 1.0 namespace.
pub const XSLT_NAMESPACE : String = "http://www.w3.org/1999/XSL/Transform"

///|
/// A stylesheet compile or transformation error.
pub suberror XsltError {
  Failure(String)
}

///|
/// One `xsl:template` rule.
pub struct Template {
  element : Int32
  pattern : String?
  name : String?
  mode : String
  priority : Double
  order : Int32
}

///|
/// The `match` attribute of the template, if it has one.
pub fn Template::match_pattern(self : Template) -> String? {
  self.pattern
}

///|
/// The `name` attribute of the template, if it has one.
pub fn Template::template_name(self : Template) -> String? {
  self.name
}

///|
/// The mode the template applies to; the empty string is the default mode.
pub fn Template::mode(self : Template) -> String {
  self.mode
}

///|
/// The effective priority of the template.
pub fn Template::priority(self : Template) -> Double {
  self.priority
}

///|
/// A compiled stylesheet.
pub struct Stylesheet {
  doc : @xml.Document
  root_element : Int32
  templates : Array[Template]
  named : Array[(String, Int32)]
  version : String
  serialization_method : String
  omit_xml_declaration : Bool
  indent : Bool
  strip_whitespace : Bool
  strip_names : Array[String]
  preserve_names : Array[String]
}

///|
/// The stylesheet document the rules were compiled from.
pub fn Stylesheet::document(self : Stylesheet) -> @xml.Document {
  self.doc
}

///|
/// Number of template rules, including named templates without a pattern.
pub fn Stylesheet::template_count(self : Stylesheet) -> Int32 {
  self.templates.length()
}

///|
/// The `version` attribute of the stylesheet.
pub fn Stylesheet::version(self : Stylesheet) -> String {
  self.version
}

///|
/// The output method declared by `xsl:output`, defaulting to `xml`.
pub fn Stylesheet::output_method(self : Stylesheet) -> String {
  self.serialization_method
}

///|
/// Whether the XML declaration should be omitted.
pub fn Stylesheet::omits_xml_declaration(self : Stylesheet) -> Bool {
  self.omit_xml_declaration
}

///|
/// Whether the result should be indented.
pub fn Stylesheet::indents(self : Stylesheet) -> Bool {
  self.indent
}

///|
/// Whether whitespace-only text nodes should be stripped from the source.
pub fn Stylesheet::strips_whitespace(self : Stylesheet) -> Bool {
  self.strip_whitespace
}

///|
/// Whether the whitespace-only text children of an element are stripped.
///
/// An xsl:preserve-space declaration wins over xsl:strip-space, as the
/// specification requires.
pub fn Stylesheet::strips_element(self : Stylesheet, name : String) -> Bool {
  for preserved in self.preserve_names {
    if preserved == name {
      return false
    }
  }
  if self.strip_whitespace {
    return true
  }
  for stripped in self.strip_names {
    if stripped == name {
      return true
    }
  }
  false
}

///|
/// Compile a stylesheet document.
pub fn compile(stylesheet : @xml.Document) -> Result[Stylesheet, String] {
  let root = match stylesheet.root() {
    Some(root) => root
    None => return Err("the stylesheet has no document element")
  }
  if stylesheet.namespace_uri(root) != XSLT_NAMESPACE {
    return Err(
      "the document element is not in the XSLT namespace: {" +
      stylesheet.namespace_uri(root) +
      "}" +
      stylesheet.local_name(root),
    )
  }
  let root_local = stylesheet.local_name(root)
  if root_local != "stylesheet" && root_local != "transform" {
    return Err(
      "expected xsl:stylesheet or xsl:transform, found xsl:" + root_local,
    )
  }
  let version = match stylesheet.attribute_value(root, "version") {
    Some(version) => version
    None => "1.0"
  }
  let templates : Array[Template] = []
  let named : Array[(String, Int32)] = []
  let mut serialization_method = "xml"
  let mut omit_declaration = false
  let mut indent = false
  let mut strip_whitespace = false
  let strip_names : Array[String] = []
  let preserve_names : Array[String] = []
  for node in stylesheet.descendants(root) {
    if !stylesheet.is_element(node) ||
      stylesheet.namespace_uri(node) != XSLT_NAMESPACE {
      continue
    }
    let name = stylesheet.local_name(node)
    if name == "template" {
      let pattern = stylesheet.attribute_value(node, "match")
      let template_name = stylesheet.attribute_value(node, "name")
      if pattern is None && template_name is None {
        return Err("xsl:template needs a match or a name attribute")
      }
      let mode = match stylesheet.attribute_value(node, "mode") {
        Some(mode) => mode
        None => ""
      }
      let priority = match stylesheet.attribute_value(node, "priority") {
        Some(text) =>
          match parse_double(text) {
            Some(value) => value
            None => return Err("invalid priority \"" + text + "\"")
          }
        None =>
          match pattern {
            Some(pattern) => default_priority(pattern)
            None => 0.0
          }
      }
      let index = templates.length()
      templates.push({
        element: node,
        pattern,
        name: template_name,
        mode,
        priority,
        order: index,
      })
      match template_name {
        Some(template_name) => named.push((template_name, index))
        None => ()
      }
    } else if name == "output" {
      match stylesheet.attribute_value(node, "method") {
        Some(value) => serialization_method = value
        None => ()
      }
      match stylesheet.attribute_value(node, "omit-xml-declaration") {
        Some(value) => omit_declaration = value == "yes"
        None => ()
      }
      match stylesheet.attribute_value(node, "indent") {
        Some(value) => indent = value == "yes"
        None => ()
      }
    } else if name == "strip-space" || name == "preserve-space" {
      let elements = match stylesheet.attribute_value(node, "elements") {
        Some(value) => value
        None => "*"
      }
      for element in split_on_whitespace(elements) {
        let trimmed = element.trim().to_owned()
        if trimmed == "" {
          continue
        }
        if name == "strip-space" {
          if trimmed == "*" {
            strip_whitespace = true
          } else {
            strip_names.push(trimmed)
          }
        } else {
          preserve_names.push(trimmed)
        }
      }
    }
  }
  Ok({
    doc: stylesheet,
    root_element: root,
    templates,
    named,
    version,
    serialization_method,
    omit_xml_declaration: omit_declaration,
    indent,
    strip_whitespace,
    strip_names,
    preserve_names,
  })
}

///|
/// Look up a named template by name.
pub fn Stylesheet::named_template(
  self : Stylesheet,
  name : String,
) -> Template? {
  for entry in self.named {
    if entry.0 == name {
      return Some(self.templates[entry.1])
    }
  }
  None
}

///|
/// All template rules in stylesheet order.
pub fn Stylesheet::template_rules(self : Stylesheet) -> ArrayView[Template] {
  self.templates[:]
}

///|
/// The default priority of a `match` pattern, per the XSLT 1.0 specification.
pub fn default_priority(pattern : String) -> Double {
  let alternatives = split_pattern_alternatives(pattern)
  let mut best = -1.0e300
  for alternative in alternatives {
    let priority = single_default_priority(alternative.trim().to_owned())
    if priority > best {
      best = priority
    }
  }
  if best == -1.0e300 {
    0.0
  } else {
    best
  }
}

///|
fn single_default_priority(pattern : String) -> Double {
  if pattern == "" {
    return 0.5
  }
  // A location path with more than one step has the default priority 0.5.
  if has_top_level_step_separator(pattern) {
    return 0.5
  }
  if pattern == "node()" ||
    pattern == "text()" ||
    pattern == "comment()" ||
    pattern == "processing-instruction()" ||
    pattern.has_prefix("processing-instruction(") {
    return -0.5
  }
  if pattern == "*" || pattern == "@*" {
    return -0.5
  }
  if pattern.has_prefix("*[") || pattern.has_prefix("@*[") {
    return 0.5
  }
  if pattern.contains(":*") {
    return -0.25
  }
  if pattern.contains("[") {
    return 0.5
  }
  0.0
}

///|
/// Whether a pattern contains a `/` outside brackets and quotes.
fn has_top_level_step_separator(pattern : String) -> Bool {
  let chars = pattern.to_array()
  let mut depth = 0
  let mut quote = Int32::unsafe_to_char(0)
  for c in chars {
    if quote != Int32::unsafe_to_char(0) {
      if c == quote {
        quote = Int32::unsafe_to_char(0)
      }
    } else if c == '"' || c == '\'' {
      quote = c
    } else if c == '[' {
      depth = depth + 1
    } else if c == ']' {
      depth = depth - 1
    } else if c == '/' && depth == 0 {
      return true
    }
  }
  false
}

///|
/// Split a pattern on top-level `|` alternatives.
pub fn split_pattern_alternatives(pattern : String) -> Array[String] {
  let parts : Array[String] = []
  let chars = pattern.to_array()
  let sb = StringBuilder::StringBuilder()
  let mut depth = 0
  let mut quote = Int32::unsafe_to_char(0)
  for c in chars {
    if quote != Int32::unsafe_to_char(0) {
      sb.write_char(c)
      if c == quote {
        quote = Int32::unsafe_to_char(0)
      }
      continue
    }
    if c == '"' || c == '\'' {
      quote = c
      sb.write_char(c)
      continue
    }
    if c == '[' || c == '(' {
      depth = depth + 1
    } else if c == ']' || c == ')' {
      depth = depth - 1
    }
    if c == '|' && depth == 0 {
      parts.push(sb.to_string())
      sb.reset()
    } else {
      sb.write_char(c)
    }
  }
  parts.push(sb.to_string())
  parts
}

///|
/// The namespace declarations in scope at an element, nearest declaration
/// first.
pub fn in_scope_namespaces(
  doc : @xml.Document,
  element : Int32,
) -> Array[(String, String)] {
  let result : Array[(String, String)] = []
  let mut current : Int32? = Some(element)
  while current is Some(id) {
    for declaration in doc.namespace_declarations(id) {
      let prefix = declaration.0
      let mut seen = false
      for existing in result {
        if existing.0 == prefix {
          seen = true
        }
      }
      if !seen {
        result.push(declaration)
      }
    }
    current = doc.parent(id)
  }
  result
}

///|
/// Parse a floating point number written in the stylesheet.
pub fn parse_double(text : String) -> Double? {
  let trimmed = text.trim()
  if trimmed == "" {
    return None
  }
  let value = @xpath.parse_number(trimmed.to_owned())
  if value.is_nan() {
    None
  } else {
    Some(value)
  }
}

///|
/// Split a list-valued attribute such as `elements="a b  c"` on whitespace.
fn split_on_whitespace(text : String) -> Array[String] {
  let parts : Array[String] = []
  let sb = StringBuilder::StringBuilder()
  let mut started = false
  for c in text {
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      if started {
        parts.push(sb.to_string())
        sb.reset()
        started = false
      }
    } else {
      sb.write_char(c)
      started = true
    }
  }
  if started {
    parts.push(sb.to_string())
  }
  parts
}
