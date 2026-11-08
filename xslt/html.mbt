// Serialisation for the HTML output method.
//
// The HTML method differs from XML in three ways that matter for the documents
// this processor produces: there is no XML declaration, void elements are not
// self-closed, and namespace declarations are not needed.

///|
/// Serialise a result tree with the HTML output method.
pub fn serialise_html(result : @xml.Document) -> String {
  let sb = StringBuilder::StringBuilder()
  match result.root() {
    Some(root) => write_html_node(result, root, sb)
    None => ()
  }
  sb.to_string()
}

///|
fn write_html_node(
  doc : @xml.Document,
  node : Int32,
  sb : StringBuilder,
) -> Unit {
  if doc.is_text(node) {
    write_escaped_text(doc.value(node), sb)
  } else if doc.is_comment(node) {
    sb.write_string("<!--")
    sb.write_string(doc.value(node))
    sb.write_string("-->")
  } else if doc.is_element(node) {
    let qualified = match doc.name(node) {
      Some(name) => name.qualified()
      None => ""
    }
    sb.write_char('<')
    sb.write_string(qualified)
    for attribute in doc.attributes(node) {
      match doc.name(attribute) {
        Some(attribute_name) =>
          if attribute_name.prefix() != "xmlns" &&
            attribute_name.local_part() != "xmlns" {
            sb.write_char(' ')
            sb.write_string(attribute_name.qualified())
            sb.write_string("=\"")
            write_escaped_attribute(doc.value(attribute), sb)
            sb.write_char('"')
          }
        None => ()
      }
    }
    sb.write_char('>')
    if !is_void_element(doc.local_name(node)) {
      for child in doc.children(node) {
        write_html_node(doc, child, sb)
      }
      sb.write_string("</")
      sb.write_string(qualified)
      sb.write_char('>')
    }
  } else if doc.is_document_node(node) {
    for child in doc.children(node) {
      write_html_node(doc, child, sb)
    }
  }
}

///|
fn is_void_element(local_name : String) -> Bool {
  match local_name {
    "area"
    | "base"
    | "br"
    | "col"
    | "embed"
    | "hr"
    | "img"
    | "input"
    | "link"
    | "meta"
    | "param"
    | "source"
    | "track"
    | "wbr" => true
    _ => false
  }
}

///|
fn write_escaped_text(text : String, sb : StringBuilder) -> Unit {
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
}

///|
fn write_escaped_attribute(text : String, sb : StringBuilder) -> Unit {
  for c in text {
    if c == '&' {
      sb.write_string("&amp;")
    } else if c == '<' {
      sb.write_string("&lt;")
    } else if c == '>' {
      sb.write_string("&gt;")
    } else if c == '"' {
      sb.write_string("&quot;")
    } else {
      sb.write_char(c)
    }
  }
}
