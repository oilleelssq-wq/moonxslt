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
/// An xsl:key declaration.
pub struct KeyDeclaration {
  name : String
  match_pattern : String
  use_expression : String
  element : Int32
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
  decimal_formats : Array[(String, DecimalFormat)]
  keys : Array[KeyDeclaration]
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
  let decimal_formats : Array[(String, DecimalFormat)] = []
  let keys : Array[KeyDeclaration] = []
  for node in stylesheet.descendants(root) {
    if !stylesheet.is_element(node) ||
      stylesheet.namespace_uri(node) != XSLT_NAMESPACE {
      continue
    }
    let name = stylesheet.local_name(node)
    if name == "include" || name == "import" {
      return Err(
        "xsl:" +
        name +
        " requires an external stylesheet loader; use compile_with_loader",
      )
    }
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
    } else if name == "key" {
      let key_name = match stylesheet.attribute_value(node, "name") {
        Some(key_name) => key_name
        None => return Err("xsl:key requires a name attribute")
      }
      let match_pattern = match stylesheet.attribute_value(node, "match") {
        Some(match_pattern) => match_pattern
        None => return Err("xsl:key requires a match attribute")
      }
      let use_expression = match stylesheet.attribute_value(node, "use") {
        Some(text) => text
        None => return Err("xsl:key requires a use attribute")
      }
      keys.push({
        name: key_name,
        match_pattern,
        use_expression,
        element: node,
      })
    } else if name == "decimal-format" {
      let format_name = match stylesheet.attribute_value(node, "name") {
        Some(format_name) => format_name
        None => ""
      }
      decimal_formats.push(
        (format_name, decimal_format_from_element(stylesheet, node)),
      )
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
    decimal_formats,
    keys,
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

///|
/// The decimal format with the given name, or the default format.
pub fn Stylesheet::decimal_format(
  self : Stylesheet,
  name : String,
) -> DecimalFormat {
  for entry in self.decimal_formats {
    if entry.0 == name {
      return entry.1
    }
  }
  DecimalFormat::default()
}

///|
/// Loads an external stylesheet by the URI written in an `href` attribute.
///
/// Returning `Err` makes the compiler report the message and stop.
pub type Loader = (String) -> Result[String, String]

///|
/// Compile a stylesheet after expanding `xsl:include` and `xsl:import`.
///
/// The included stylesheets are parsed with the same parser and their
/// top-level declarations are copied into the including document, so the rest
/// of the engine keeps working with a single document arena.
pub fn compile_with_loader(
  stylesheet : @xml.Document,
  loader : Loader,
) -> Result[Stylesheet, String] {
  match expand_includes(stylesheet, loader, []) {
    Ok(_) => compile(stylesheet)
    Err(message) => Err(message)
  }
}

///|
fn expand_includes(
  stylesheet : @xml.Document,
  loader : Loader,
  seen : Array[String],
) -> Result[Unit, String] {
  let root = match stylesheet.root() {
    Some(root) => root
    None => return Err("stylesheet has no root element")
  }
  let children : Array[Int32] = []
  for child in stylesheet.children(root) {
    children.push(child)
  }
  for child in children {
    if !stylesheet.is_element(child) ||
      stylesheet.namespace_uri(child) != XSLT_NAMESPACE {
      continue
    }
    let name = stylesheet.local_name(child)
    if name != "include" && name != "import" {
      continue
    }
    let href = match stylesheet.attribute_value(child, "href") {
      Some(href) => href
      None => return Err("xsl:" + name + " requires an href attribute")
    }
    let mut already_seen = false
    for entry in seen {
      if entry == href {
        already_seen = true
      }
    }
    if already_seen {
      return Err("circular xsl:" + name + " of " + href)
    }
    let text = match loader(href) {
      Ok(text) => text
      Err(message) => return Err("cannot load " + href + ": " + message)
    }
    let document = match @xml.parse(text) {
      Ok(document) => document
      Err(info) =>
        return Err("included stylesheet " + href + ": " + info.message)
    }
    let next_seen : Array[String] = []
    for entry in seen {
      next_seen.push(entry)
    }
    next_seen.push(href)
    match expand_includes(document, loader, next_seen) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    let included_root = match document.root() {
      Some(included_root) => included_root
      None => return Err("included stylesheet " + href + " has no root element")
    }
    let declarations : Array[(String, String)] = []
    for declaration in document.namespace_declarations(included_root) {
      declarations.push(declaration)
    }
    let imported_children : Array[Int32] = []
    for grandchild in document.children(included_root) {
      imported_children.push(
        stylesheet.import_subtree(root, document, grandchild),
      )
    }
    for imported in imported_children {
      if stylesheet.is_element(imported) {
        for declaration in declarations {
          stylesheet.declare_namespace(imported, declaration.0, declaration.1)
        }
      }
    }
    stylesheet.remove_child(root, child)
  }
  Ok(())
}
