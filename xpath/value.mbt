// Values of the XPath 1.0 data model and the conversions between them.
//
// XPath has exactly four types: node-set, boolean, number and string. Every
// operation is defined in terms of the conversions implemented here, so this
// module is the semantic foundation of both the XPath and the XSLT engine.

///|
/// The four XPath value types.
pub(all) enum Value {
  Nodes(NodeSet)
  Boolean(Bool)
  Number(Double)
  String(String)
}

///|
/// An unordered set of nodes, held in document order.
///
/// Nodes are identified by their id in the arena; the document is supplied by
/// the evaluation context so that node-sets do not need to carry it around.
pub struct NodeSet {
  nodes : Array[Int32]
}

///|
/// Create a node-set from arbitrary ids, sorting them into document order and
/// removing duplicates.
pub fn NodeSet::new(doc : @xml.Document, ids : Array[Int32]) -> NodeSet {
  { nodes: doc.sort_document_order(ids), }
}

///|
/// The empty node-set.
pub fn NodeSet::empty() -> NodeSet {
  { nodes: [], }
}

///|
/// Number of nodes in the set.
pub fn NodeSet::length(self : NodeSet) -> Int32 {
  self.nodes.length()
}

///|
/// Whether the set is empty.
pub fn NodeSet::is_empty(self : NodeSet) -> Bool {
  self.nodes.length() == 0
}

///|
/// The nodes, in document order.
pub fn NodeSet::nodes(self : NodeSet) -> ArrayView[Int32] {
  self.nodes[:]
}

///|
/// The first node in document order, if any.
pub fn NodeSet::first(self : NodeSet) -> Int32? {
  if self.nodes.length() == 0 {
    None
  } else {
    Some(self.nodes[0])
  }
}

///|
/// Whether a node belongs to the set.
pub fn NodeSet::contains(self : NodeSet, id : Int32) -> Bool {
  for node in self.nodes {
    if node == id {
      return true
    }
  }
  false
}

///|
/// Union of two node-sets.
pub fn NodeSet::union(
  self : NodeSet,
  doc : @xml.Document,
  other : NodeSet,
) -> NodeSet {
  let merged : Array[Int32] = []
  for node in self.nodes {
    merged.push(node)
  }
  for node in other.nodes {
    merged.push(node)
  }
  NodeSet::new(doc, merged)
}

///|
/// The string-value of a single node.
///
/// Elements and the document node yield the concatenation of their descendant
/// text, attributes and text nodes yield their character data, and comments and
/// processing instructions yield their content.
pub fn string_of_node(doc : @xml.Document, id : Int32) -> String {
  if doc.is_element(id) || doc.is_document_node(id) {
    doc.text_content(id)
  } else {
    doc.value(id)
  }
}

///|
/// Wrap a boolean as an XPath value.
pub fn of_boolean(value : Bool) -> Value {
  Boolean(value)
}

///|
/// Wrap a number as an XPath value.
pub fn of_number(value : Double) -> Value {
  Number(value)
}

///|
/// Wrap a string as an XPath value.
pub fn of_string(value : String) -> Value {
  String(value)
}

///|
/// XPath boolean conversion.
pub fn Value::boolean_value(self : Value) -> Bool {
  match self {
    Boolean(value) => value
    Number(value) => !(value.is_nan() || value == 0.0)
    String(value) => value != ""
    Nodes(set) => !set.is_empty()
  }
}

///|
/// XPath string conversion.
pub fn Value::string_value(self : Value, doc : @xml.Document) -> String {
  match self {
    Boolean(value) => if value { "true" } else { "false" }
    Number(value) => format_number(value)
    String(value) => value
    Nodes(set) =>
      match set.first() {
        Some(node) => string_of_node(doc, node)
        None => ""
      }
  }
}

///|
/// XPath number conversion.
pub fn Value::number_value(self : Value, doc : @xml.Document) -> Double {
  match self {
    Boolean(value) => if value { 1.0 } else { 0.0 }
    Number(value) => value
    String(value) => parse_number(value)
    Nodes(set) =>
      match set.first() {
        Some(node) => parse_number(string_of_node(doc, node))
        None => nan()
      }
  }
}

///|
/// The IEEE NaN value, which XPath uses for numbers that cannot be represented.
pub fn nan() -> Double {
  @double.infinity - @double.infinity
}

///|
/// Format a number the way XPath's `string()` does.
///
/// Whole numbers are printed without a fractional part and infinities and NaN
/// use their XPath spellings.
pub fn format_number(value : Double) -> String {
  if value.is_nan() {
    "NaN"
  } else if value.is_pos_inf() {
    "Infinity"
  } else if value.is_neg_inf() {
    "-Infinity"
  } else if value == 0.0 {
    "0"
  } else if value == value.floor() && value.abs() < 1.0e15 {
    value.to_int().to_string()
  } else {
    trim_trailing_zeros(value.to_string())
  }
}

///|
/// Remove a trailing `.0` or trailing zeros from a decimal representation.
fn trim_trailing_zeros(text : String) -> String {
  if !text.contains(".") {
    return text
  }
  let chars = text.to_array()
  let mut end = chars.length()
  while end > 0 && chars[end - 1] == '0' {
    end = end - 1
  }
  if end > 0 && chars[end - 1] == '.' {
    end = end - 1
  }
  String::from_array(chars[0:end])
}

///|
/// Parse an XPath number: optional surrounding whitespace, an optional minus
/// sign, digits with an optional fractional part. Anything else is NaN.
pub fn parse_number(text : String) -> Double {
  let chars = text.trim().to_array()
  if chars.length() == 0 {
    return nan()
  }
  let mut index = 0
  let mut negative = false
  if chars[0] == '-' {
    negative = true
    index = 1
  }
  let start = index
  let mut value = 0.0
  let mut digits = 0
  while index < chars.length() && chars[index] >= '0' && chars[index] <= '9' {
    value = value * 10.0 + (chars[index].to_int() - '0'.to_int()).to_double()
    index = index + 1
    digits = digits + 1
  }
  if index < chars.length() && chars[index] == '.' {
    index = index + 1
    let mut scale = 0.1
    while index < chars.length() && chars[index] >= '0' && chars[index] <= '9' {
      value = value + (chars[index].to_int() - '0'.to_int()).to_double() * scale
      scale = scale / 10.0
      index = index + 1
      digits = digits + 1
    }
  }
  if digits == 0 || index != chars.length() {
    return nan()
  }
  let _ = start
  if negative {
    -value
  } else {
    value
  }
}
