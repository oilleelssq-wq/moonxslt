// Numbering: `xsl:number` and the formatting of the resulting number.

///|
/// Compute the text `xsl:number` inserts for the current node.
fn Transformer::number_text(
  self : Transformer,
  element : Int32,
) -> String raise XsltError {
  let format = match self.style.doc.attribute_value(element, "format") {
    Some(format) => format
    None => "1"
  }
  match self.style.doc.attribute_value(element, "value") {
    Some(value) => {
      let number = self.evaluate_number(value, element)
      format_number_value(round_to_int(number), format)
    }
    None => {
      let level = match self.style.doc.attribute_value(element, "level") {
        Some(level) => level
        None => "single"
      }
      let pattern = match self.style.doc.attribute_value(element, "count") {
        Some(pattern) => pattern
        None =>
          match self.source.name(self.current_node) {
            Some(name) => name.qualified()
            None => "*"
          }
      }
      if level == "multiple" {
        let parts : Array[String] = []
        let ancestors = self.source.ancestors_or_self(self.current_node)
        let mut index = ancestors.length() - 1
        while index >= 0 {
          let ancestor = ancestors[index]
          if self.matches_count(pattern, ancestor) {
            let count = self.preceding_matching(ancestor, pattern) + 1
            parts.push(format_number_value(count, format))
          }
          index = index - 1
        }
        join_strings(parts, ".")
      } else if level == "any" {
        let mut count = 0
        for node in self.source.nodes_in_document_order() {
          if self.matches_count(pattern, node) {
            count = count + 1
          }
          if node == self.current_node {
            break
          }
        }
        format_number_value(count, format)
      } else {
        let mut current : Int32? = Some(self.current_node)
        while current is Some(node) {
          if self.matches_count(pattern, node) {
            let count = self.preceding_matching(node, pattern) + 1
            return format_number_value(count, format)
          }
          current = self.source.parent(node)
        }
        format_number_value(1, format)
      }
    }
  }
}

///|
/// Whether a node counts for an `xsl:number` `count` pattern.
///
/// Only name tests and `*` are supported; the namespace of a prefixed name is
/// ignored, which is enough for the numbering patterns stylesheets normally use.
fn Transformer::matches_count(
  self : Transformer,
  pattern : String,
  node : Int32,
) -> Bool {
  if pattern == "*" || pattern == "node()" {
    return true
  }
  if pattern == "text()" {
    return self.source.is_text(node)
  }
  if pattern == "comment()" {
    return self.source.is_comment(node)
  }
  if !self.source.is_element(node) {
    return false
  }
  let local_name = self.source.local_name(node)
  match @xml.split_qname(pattern) {
    Some(pair) => pair.1 == local_name
    None => false
  }
}

///|
/// How many preceding siblings of a node match a numbering pattern.
fn Transformer::preceding_matching(
  self : Transformer,
  node : Int32,
  pattern : String,
) -> Int32 {
  let parent = match self.source.parent(node) {
    Some(parent) => parent
    None => return 0
  }
  let mut count = 0
  for sibling in self.source.children(parent) {
    if sibling == node {
      break
    }
    if self.matches_count(pattern, sibling) {
      count = count + 1
    }
  }
  count
}

///|
/// Format a number with an `xsl:number` format token.
pub fn format_number_value(number : Int32, format : String) -> String {
  if format == "" {
    return number.to_string()
  }
  let chars = format.to_array()
  let first = chars[0]
  if first == 'a' || first == 'A' {
    return alpha_number(number, first == 'A')
  }
  if first == 'i' || first == 'I' {
    return roman_number(number, first == 'I')
  }
  let mut width = 0
  for c in chars {
    if c == '0' || c == '1' {
      width = width + 1
    } else {
      break
    }
  }
  pad_number(number, width)
}

///|
fn pad_number(number : Int32, width : Int32) -> String {
  let digits = number.to_string()
  if digits.length() >= width {
    return digits
  }
  let sb = StringBuilder::StringBuilder()
  for _ in 0..<(width - digits.length()) {
    sb.write_char('0')
  }
  sb.write_string(digits)
  sb.to_string()
}

///|
fn alpha_number(number : Int32, upper : Bool) -> String {
  if number <= 0 {
    return number.to_string()
  }
  let base = if upper { 'A'.to_int() } else { 'a'.to_int() }
  let digits : Array[Char] = []
  let mut remaining = number
  while remaining > 0 {
    let index = (remaining - 1) % 26
    digits.push(Int32::unsafe_to_char(base + index))
    remaining = (remaining - 1) / 26
  }
  let sb = StringBuilder::StringBuilder()
  let mut index = digits.length() - 1
  while index >= 0 {
    sb.write_char(digits[index])
    index = index - 1
  }
  sb.to_string()
}

///|
fn roman_number(number : Int32, upper : Bool) -> String {
  if number <= 0 || number >= 4000 {
    return number.to_string()
  }
  let values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
  let symbols = [
    "m", "cm", "d", "cd", "c", "xc", "l", "xl", "x", "ix", "v", "iv", "i",
  ]
  let sb = StringBuilder::StringBuilder()
  let mut remaining = number
  for index in 0..<values.length() {
    while remaining >= values[index] {
      sb.write_string(symbols[index])
      remaining = remaining - values[index]
    }
  }
  let text = sb.to_string()
  if upper {
    text.to_upper()
  } else {
    text
  }
}

///|
fn round_to_int(number : Double) -> Int32 {
  if number.is_nan() {
    return 0
  }
  (number + 0.5).floor().to_int()
}

///|
fn join_strings(parts : Array[String], separator : String) -> String {
  let sb = StringBuilder::StringBuilder()
  for index in 0..<parts.length() {
    if index > 0 {
      sb.write_string(separator)
    }
    sb.write_string(parts[index])
  }
  sb.to_string()
}
