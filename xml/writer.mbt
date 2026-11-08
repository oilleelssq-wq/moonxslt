// Serialisation of the document model back to XML text.

///|
/// Serialise the document to XML.
///
/// With `indent = true` the output is pretty printed: element children are put
/// on their own lines, while text-only content stays inline.
pub fn Document::to_xml(
  self : Document,
  indent~ : Bool = false,
  declaration~ : Bool = true,
) -> String {
  let sb = StringBuilder::StringBuilder()
  if declaration {
    sb.write_string("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
    if indent {
      sb.write_char('\n')
    }
  }
  match self.root() {
    Some(root) => self.write_node(root, sb, indent, 0)
    None => ()
  }
  sb.to_string()
}

///|
/// Serialise a single node subtree.
pub fn Document::write_node(
  self : Document,
  id : Int32,
  sb : StringBuilder,
  indent : Bool,
  depth : Int32,
) -> Unit {
  match self.kind(id) {
    Some(Element) => self.write_element(id, sb, indent, depth)
    Some(Text) => sb.write_string(escape_text(self.value(id)))
    Some(Comment) => {
      sb.write_string("<!--")
      sb.write_string(self.value(id))
      sb.write_string("-->")
    }
    Some(ProcessingInstruction) => {
      sb.write_string("<?")
      sb.write_string(self.qualified_name(id))
      let data = self.value(id)
      if data != "" {
        sb.write_char(' ')
        sb.write_string(data)
      }
      sb.write_string("?>")
    }
    Some(Document) =>
      for child in self.children(id) {
        self.write_node(child, sb, indent, depth)
      }
    Some(Attribute) => ()
    None => ()
  }
}

///|
fn Document::write_element(
  self : Document,
  id : Int32,
  sb : StringBuilder,
  indent : Bool,
  depth : Int32,
) -> Unit {
  sb.write_char('<')
  sb.write_string(self.qualified_name(id))
  for declaration in self.namespace_declarations(id) {
    let prefix = declaration.0
    let uri = declaration.1
    sb.write_string(" xmlns")
    if prefix != "" {
      sb.write_char(':')
      sb.write_string(prefix)
    }
    sb.write_string("=\"")
    sb.write_string(escape_attribute(uri))
    sb.write_char('"')
  }
  for attribute in self.attributes(id) {
    sb.write_char(' ')
    sb.write_string(self.qualified_name(attribute))
    sb.write_string("=\"")
    sb.write_string(escape_attribute(self.value(attribute)))
    sb.write_char('"')
  }
  let children = self.children(id)
  if children.length() == 0 {
    sb.write_string("/>")
    return
  }
  sb.write_char('>')
  let block = indent && self.has_element_like_child(id)
  if block {
    for child in children {
      sb.write_char('\n')
      write_indent(sb, depth + 1)
      self.write_node(child, sb, indent, depth + 1)
    }
    sb.write_char('\n')
    write_indent(sb, depth)
  } else {
    for child in children {
      self.write_node(child, sb, indent, depth + 1)
    }
  }
  sb.write_string("</")
  sb.write_string(self.qualified_name(id))
  sb.write_char('>')
}

///|
fn Document::has_element_like_child(self : Document, id : Int32) -> Bool {
  for child in self.children(id) {
    match self.kind(child) {
      Some(Element) | Some(Comment) | Some(ProcessingInstruction) => return true
      _ => ()
    }
  }
  false
}

///|
fn write_indent(sb : StringBuilder, depth : Int32) -> Unit {
  for _ in 0..<depth {
    sb.write_string("  ")
  }
}

///|
/// Escape character data.
pub fn escape_text(text : String) -> String {
  let sb = StringBuilder::StringBuilder()
  for c in text {
    if c == '&' {
      sb.write_string("&amp;")
    } else if c == '<' {
      sb.write_string("&lt;")
    } else if c == '>' {
      sb.write_string("&gt;")
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// Escape an attribute value, including the whitespace characters that a parser
/// would otherwise normalise.
pub fn escape_attribute(text : String) -> String {
  let sb = StringBuilder::StringBuilder()
  for c in text {
    if c == '&' {
      sb.write_string("&amp;")
    } else if c == '<' {
      sb.write_string("&lt;")
    } else if c == '"' {
      sb.write_string("&quot;")
    } else if c == '\t' {
      sb.write_string("&#9;")
    } else if c == '\n' {
      sb.write_string("&#10;")
    } else if c == '\r' {
      sb.write_string("&#13;")
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}
