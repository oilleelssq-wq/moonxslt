// Package `oilleelssq-wq/moonxslt/xml` provides the namespace-aware XML data
// model that the XPath and XSLT engines operate on.
//
// The model is arena based: every node lives in `Document.nodes` and is
// addressed by its integer id. Node ids are assigned in document order, which
// makes document-order comparisons cheap and keeps the tree free of parent
// cycles for garbage collection.

///|
/// The six node kinds of the XPath 1.0 data model.
///
/// `Namespace` nodes are not materialised: the namespace axis is derived from
/// the declarations stored on element nodes.
pub(all) enum NodeKind {
  Document
  Element
  Attribute
  Text
  Comment
  ProcessingInstruction
}

///|
/// A namespace-aware qualified name.
///
/// `uri` is the empty string when the name has no namespace.
pub struct QName {
  prefix : String
  local_part : String
  uri : String
}

///|
pub fn QName::new(prefix : String, local_part : String, uri : String) -> QName {
  { prefix, local_part, uri, }
}

///|
pub fn QName::prefix(self : QName) -> String {
  self.prefix
}

///|
pub fn QName::local_part(self : QName) -> String {
  self.local_part
}

///|
pub fn QName::uri(self : QName) -> String {
  self.uri
}

///|
/// The expanded name, used for matching in XPath and XSLT.
pub fn QName::expanded(self : QName) -> String {
  "{" + self.uri + "}" + self.local_part
}

///|
/// The lexical form of the name, i.e. `prefix:local_part` or `local_part`.
pub fn QName::qualified(self : QName) -> String {
  if self.prefix == "" {
    self.local_part
  } else {
    self.prefix + ":" + self.local_part
  }
}

///|
/// Split a lexical name into `(prefix, local_part)`.
///
/// Returns `None` when the name contains more than one colon, which XML does
/// not allow.
pub fn split_qname(name : String) -> (String, String)? {
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
/// A single node of the document arena.
///
/// Only `name`, `value` and `parent` are ever reassigned after creation, so the
/// remaining fields are immutable.
struct Node {
  kind : NodeKind
  mut name : QName?
  mut value : String
  attrs : Array[Int32]
  children : Array[Int32]
  parent : Int32
  ns_decls : Array[(String, String)]
  order : Int32
}

///|
/// A parsed XML document.
pub struct Document {
  nodes : Array[Node]
  mut root_id : Int32?
}

///|
/// Create an empty document containing only the document node.
pub fn Document::empty() -> Document {
  let document_node : Node = {
    kind: Document,
    name: None,
    value: "",
    attrs: [],
    children: [],
    parent: -1,
    ns_decls: [],
    order: 0,
  }
  { nodes: [document_node], root_id: None, }
}

///|
/// Number of nodes in the arena, including the document node.
pub fn Document::node_count(self : Document) -> Int32 {
  self.nodes.length()
}

///|
/// Id of the document element, if the document has one.
pub fn Document::root(self : Document) -> Int32? {
  self.root_id
}

///|
/// Kind of the node with the given id.
///
/// `None` means the id is out of range.
pub fn Document::kind(self : Document, id : Int32) -> NodeKind? {
  if id < 0 || id >= self.nodes.length() {
    None
  } else {
    Some(self.nodes[id].kind)
  }
}

///|
/// Parent id of a node, or `None` for the document node.
pub fn Document::parent(self : Document, id : Int32) -> Int32? {
  if id <= 0 || id >= self.nodes.length() {
    None
  } else {
    let parent = self.nodes[id].parent
    if parent < 0 {
      None
    } else {
      Some(parent)
    }
  }
}

///|
/// Child node ids of a document or element node, in document order.
pub fn Document::children(self : Document, id : Int32) -> ArrayView[Int32] {
  if id < 0 || id >= self.nodes.length() {
    []
  } else {
    self.nodes[id].children[:]
  }
}

///|
/// Whether the node has children.
pub fn Document::has_children(self : Document, id : Int32) -> Bool {
  self.children(id).length() > 0
}

///|
/// Attribute node ids of an element, in declaration order.
pub fn Document::attributes(self : Document, id : Int32) -> ArrayView[Int32] {
  if id < 0 || id >= self.nodes.length() {
    []
  } else {
    self.nodes[id].attrs[:]
  }
}

///|
/// The expanded name of an element or attribute node.
pub fn Document::name(self : Document, id : Int32) -> QName? {
  if id < 0 || id >= self.nodes.length() {
    None
  } else {
    self.nodes[id].name
  }
}

///|
/// The lexical name of an element or attribute node.
pub fn Document::qualified_name(self : Document, id : Int32) -> String {
  match self.name(id) {
    Some(name) => name.qualified()
    None => ""
  }
}

///|
/// The local_part part of an element or attribute name.
pub fn Document::local_name(self : Document, id : Int32) -> String {
  match self.name(id) {
    Some(name) => name.local_part()
    None => ""
  }
}

///|
/// The namespace URI of an element or attribute name, `""` when unqualified.
pub fn Document::namespace_uri(self : Document, id : Int32) -> String {
  match self.name(id) {
    Some(name) => name.uri()
    None => ""
  }
}

///|
/// Character data of a text, comment or processing-instruction node.
pub fn Document::value(self : Document, id : Int32) -> String {
  if id < 0 || id >= self.nodes.length() {
    ""
  } else {
    self.nodes[id].value
  }
}

///|
/// Namespace declarations attached to an element, as `(prefix, uri)` pairs.
///
/// The empty prefix denotes the default namespace.
pub fn Document::namespace_declarations(
  self : Document,
  id : Int32,
) -> ArrayView[(String, String)] {
  if id < 0 || id >= self.nodes.length() {
    []
  } else {
    self.nodes[id].ns_decls[:]
  }
}

///|
/// Document-order key of a node.
///
/// Nodes are numbered in document order, except that attributes reuse the
/// order key of their owning element so that a sort on `(order, id)` yields
/// element, then its attributes, then its children.
pub fn Document::document_order(self : Document, id : Int32) -> Int32 {
  if id < 0 || id >= self.nodes.length() {
    -1
  } else {
    self.nodes[id].order
  }
}

///|
/// Compare two node ids in document order.
///
/// Returns a negative number when `a` precedes `b`, zero when they are the
/// same node, and a positive number otherwise.
pub fn Document::compare_order(self : Document, a : Int32, b : Int32) -> Int32 {
  if a == b {
    return 0
  }
  let order_a = self.document_order(a)
  let order_b = self.document_order(b)
  if order_a != order_b {
    order_a - order_b
  } else {
    a - b
  }
}

///|
/// Look up an attribute by local_part name, ignoring the namespace.
pub fn Document::attribute_by_local(
  self : Document,
  element : Int32,
  local_part : String,
) -> Int32? {
  for attr in self.attributes(element) {
    if self.local_name(attr) == local_part {
      return Some(attr)
    }
  }
  None
}

///|
/// Look up an attribute by expanded `(uri, local_part)` name.
pub fn Document::attribute_by_expanded(
  self : Document,
  element : Int32,
  uri : String,
  local_part : String,
) -> Int32? {
  for attr in self.attributes(element) {
    if self.local_name(attr) == local_part && self.namespace_uri(attr) == uri {
      return Some(attr)
    }
  }
  None
}

///|
/// Look up an attribute value by local_part name.
pub fn Document::attribute_value(
  self : Document,
  element : Int32,
  local_part : String,
) -> String? {
  match self.attribute_by_local(element, local_part) {
    Some(attr) => Some(self.value(attr))
    None => None
  }
}

///|
/// Concatenated character data of the node and all its descendants, which is
/// the XPath `string()` of an element.
pub fn Document::text_content(self : Document, id : Int32) -> String {
  let sb = StringBuilder::StringBuilder()
  self.collect_text(id, sb)
  sb.to_string()
}

///|
fn Document::collect_text(
  self : Document,
  id : Int32,
  sb : StringBuilder,
) -> Unit {
  match self.kind(id) {
    Some(Text) => sb.write_string(self.value(id))
    Some(Comment) | Some(ProcessingInstruction) => ()
    _ =>
      for child in self.children(id) {
        self.collect_text(child, sb)
      }
  }
}

///|
/// Whether a text node consists only of XML whitespace.
pub fn Document::is_whitespace_text(self : Document, id : Int32) -> Bool {
  match self.kind(id) {
    Some(Text) => ()
    _ => return false
  }
  for c in self.value(id) {
    if !is_xml_whitespace(c) {
      return false
    }
  }
  true
}

///|
/// XML whitespace characters.
pub fn is_xml_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
/// Append a new element node under `parent` and return its id.
///
/// Used by the parser and by result-tree construction in the XSLT engine.
pub fn Document::add_element(
  self : Document,
  parent : Int32,
  name : QName,
) -> Int32 {
  self.append(parent, {
    kind: Element,
    name: Some(name),
    value: "",
    attrs: [],
    children: [],
    parent,
    ns_decls: [],
    order: self.nodes.length(),
  })
}

///|
/// Append a text node under `parent`.
///
/// Adjacent text nodes are merged, as required by the XPath data model; in that
/// case the existing node id is returned.
pub fn Document::add_text(
  self : Document,
  parent : Int32,
  text : String,
) -> Int32 {
  let children = self.nodes[parent].children
  if children.length() > 0 {
    let last = children[children.length() - 1]
    match self.nodes[last].kind {
      Text => {
        self.nodes[last].value = self.nodes[last].value + text
        return last
      }
      _ => ()
    }
  }
  self.append(parent, {
    kind: Text,
    name: None,
    value: text,
    attrs: [],
    children: [],
    parent,
    ns_decls: [],
    order: self.nodes.length(),
  })
}

///|
/// Append a comment node under `parent`.
pub fn Document::add_comment(
  self : Document,
  parent : Int32,
  text : String,
) -> Int32 {
  self.append(parent, {
    kind: Comment,
    name: None,
    value: text,
    attrs: [],
    children: [],
    parent,
    ns_decls: [],
    order: self.nodes.length(),
  })
}

///|
/// Append a processing-instruction node under `parent`.
pub fn Document::add_processing_instruction(
  self : Document,
  parent : Int32,
  target : String,
  data : String,
) -> Int32 {
  self.append(parent, {
    kind: ProcessingInstruction,
    name: Some({ prefix: "", local_part: target, uri: "", }),
    value: data,
    attrs: [],
    children: [],
    parent,
    ns_decls: [],
    order: self.nodes.length(),
  })
}

///|
/// Append an attribute node to an element.
///
/// Attribute ids are ordered by declaration and share the document-order key of
/// their element.
pub fn Document::add_attribute(
  self : Document,
  element : Int32,
  name : QName,
  value : String,
) -> Int32 {
  let id = self.nodes.length()
  let order = self.nodes[element].order
  self.nodes.push({
    kind: Attribute,
    name: Some(name),
    value,
    attrs: [],
    children: [],
    parent: element,
    ns_decls: [],
    order,
  })
  self.nodes[element].attrs.push(id)
  id
}

///|
/// Record a namespace declaration on an element.
pub fn Document::declare_namespace(
  self : Document,
  element : Int32,
  prefix : String,
  uri : String,
) -> Unit {
  self.nodes[element].ns_decls.push((prefix, uri))
}

///|
/// Mark the document element.
pub fn Document::set_root(self : Document, id : Int32) -> Unit {
  self.root_id = Some(id)
}

///|
/// Set the resolved name of an element once its namespace scope is known.
pub fn Document::set_element_name(
  self : Document,
  element : Int32,
  prefix : String,
  local_part : String,
  uri : String,
) -> Unit {
  self.nodes[element].name = Some(QName::new(prefix, local_part, uri))
}

///|
fn Document::append(self : Document, parent : Int32, node : Node) -> Int32 {
  let id = self.nodes.length()
  self.nodes.push(node)
  if parent >= 0 && parent < id {
    self.nodes[parent].children.push(id)
  }
  id
}

///|
/// Resolve a namespace prefix for the given node by walking up the tree.
///
/// Returns `None` for an undeclared prefix.
pub fn Document::resolve_prefix(
  self : Document,
  node : Int32,
  prefix : String,
) -> String? {
  let mut current = node
  while current >= 0 {
    for decl in self.namespace_declarations(current) {
      let declared_prefix = decl.0
      let declared_uri = decl.1
      if declared_prefix == prefix {
        return Some(declared_uri)
      }
    }
    match self.parent(current) {
      Some(parent) => current = parent
      None => break
    }
  }
  if prefix == "xml" {
    Some("http://www.w3.org/XML/1998/namespace")
  } else if prefix == "" {
    Some("")
  } else {
    None
  }
}
