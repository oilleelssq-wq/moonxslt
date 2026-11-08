// Extended XPath 1.0 function library.
//
// The core functions that location paths and the XSLT engine depend on live in
// `eval.mbt`; this module holds the remaining string, number and node-set
// functions of the XPath 1.0 core library.

///|
/// Dispatch to the extended function library.
fn call_library_function(
  name : String,
  arguments : Array[Expr],
  context : EvalContext,
) -> Value raise EvaluationError {
  match name {
    "concat" => {
      if arguments.length() < 2 {
        raise EvaluationError::Message(
          "concat() expects at least two arguments",
        )
      }
      let sb = StringBuilder::StringBuilder()
      for argument in arguments {
        sb.write_string(evaluate(argument, context).string_value(context.doc))
      }
      String(sb.to_string())
    }
    "contains" => {
      expect_arity(name, arguments, 2)
      let haystack = string_argument(name, arguments, 0, context)
      let needle = string_argument(name, arguments, 1, context)
      Boolean(contains_text(haystack, needle))
    }
    "starts-with" => {
      expect_arity(name, arguments, 2)
      let text = string_argument(name, arguments, 0, context)
      let prefix = string_argument(name, arguments, 1, context)
      Boolean(text.has_prefix(prefix))
    }
    "substring" => {
      if arguments.length() < 2 || arguments.length() > 3 {
        raise EvaluationError::Message(
          "substring() expects two or three arguments",
        )
      }
      let text = string_argument(name, arguments, 0, context)
      let start = number_argument(name, arguments, 1, context)
      let length = if arguments.length() == 3 {
        Some(number_argument(name, arguments, 2, context))
      } else {
        None
      }
      String(substring_text(text, start, length))
    }
    "substring-before" => {
      expect_arity(name, arguments, 2)
      let text = string_argument(name, arguments, 0, context)
      let search = string_argument(name, arguments, 1, context)
      String(substring_before(text, search))
    }
    "substring-after" => {
      expect_arity(name, arguments, 2)
      let text = string_argument(name, arguments, 0, context)
      let search = string_argument(name, arguments, 1, context)
      String(substring_after(text, search))
    }
    "string-length" => {
      let text = if arguments.length() == 0 {
        string_of_node(context.doc, context.node)
      } else {
        string_argument(name, arguments, 0, context)
      }
      Number(text.to_array().length().to_double())
    }
    "normalize-space" => {
      let text = if arguments.length() == 0 {
        string_of_node(context.doc, context.node)
      } else {
        string_argument(name, arguments, 0, context)
      }
      String(normalize_space(text))
    }
    "translate" => {
      expect_arity(name, arguments, 3)
      let text = string_argument(name, arguments, 0, context)
      let from = string_argument(name, arguments, 1, context)
      let to = string_argument(name, arguments, 2, context)
      String(translate_text(text, from, to))
    }
    "sum" => {
      expect_arity(name, arguments, 1)
      match evaluate(arguments[0], context) {
        Nodes(set) => {
          let mut total = 0.0
          for node in set.nodes() {
            total = total + parse_number(string_of_node(context.doc, node))
          }
          Number(total)
        }
        _ => raise EvaluationError::Message("sum() requires a node-set")
      }
    }
    "floor" => Number(number_argument(name, arguments, 0, context).floor())
    "ceiling" => Number(number_argument(name, arguments, 0, context).ceil())
    "round" =>
      Number(round_number(number_argument(name, arguments, 0, context)))
    "id" => {
      expect_arity(name, arguments, 1)
      let ids = string_argument(name, arguments, 0, context)
      Nodes(NodeSet::new(context.doc, elements_by_id(context.doc, ids)))
    }
    "lang" => {
      expect_arity(name, arguments, 1)
      let language = string_argument(name, arguments, 0, context).to_lower()
      Boolean(matches_language(context.doc, context.node, language))
    }
    _ => raise EvaluationError::Message("unknown function " + name + "()")
  }
}

///|
fn string_argument(
  name : String,
  arguments : Array[Expr],
  index : Int32,
  context : EvalContext,
) -> String raise EvaluationError {
  if index >= arguments.length() {
    raise EvaluationError::Message(
      name + "() expects an argument at position " + (index + 1).to_string(),
    )
  }
  evaluate(arguments[index], context).string_value(context.doc)
}

///|
fn number_argument(
  name : String,
  arguments : Array[Expr],
  index : Int32,
  context : EvalContext,
) -> Double raise EvaluationError {
  if index >= arguments.length() {
    raise EvaluationError::Message(
      name + "() expects an argument at position " + (index + 1).to_string(),
    )
  }
  evaluate(arguments[index], context).number_value(context.doc)
}

///|
fn is_space_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\r' || c == '\n'
}

///|
fn contains_text(haystack : String, needle : String) -> Bool {
  find_substring(haystack.to_array(), needle.to_array()) >= 0
}

///|
fn find_substring(haystack : Array[Char], needle : Array[Char]) -> Int32 {
  if needle.length() == 0 {
    return 0
  }
  let mut i = 0
  while i + needle.length() <= haystack.length() {
    let mut matched = true
    for j in 0..<needle.length() {
      if haystack[i + j] != needle[j] {
        matched = false
      }
    }
    if matched {
      return i
    }
    i = i + 1
  }
  -1
}

///|
fn substring_before(text : String, search : String) -> String {
  let haystack = text.to_array()
  let index = find_substring(haystack, search.to_array())
  if index < 0 {
    ""
  } else {
    String::from_array(haystack[0:index])
  }
}

///|
fn substring_after(text : String, search : String) -> String {
  let haystack = text.to_array()
  let needle = search.to_array()
  let index = find_substring(haystack, needle)
  if index < 0 {
    ""
  } else {
    String::from_array(haystack[index + needle.length():])
  }
}

///|
/// XPath `substring()`: positions are one based and are rounded before use, and
/// a negative length yields the empty string.
fn substring_text(text : String, start : Double, length : Double?) -> String {
  let chars = text.to_array()
  let first = round_number(start)
  let limit = match length {
    Some(value) => first + round_number(value)
    None => 1.0e300
  }
  let sb = StringBuilder::StringBuilder()
  for i in 0..<chars.length() {
    let position = (i + 1).to_double()
    if position >= first && position < limit {
      sb.write_char(chars[i])
    }
  }
  sb.to_string()
}

///|
/// XPath `round()`: round half up, preserving NaN and infinities.
fn round_number(value : Double) -> Double {
  if value.is_nan() || value.is_inf() {
    return value
  }
  if value >= -0.5 && value < 0.0 {
    return -0.0
  }
  (value + 0.5).floor()
}

///|
/// XPath `normalize-space()`: trim and collapse whitespace runs.
fn normalize_space(text : String) -> String {
  let sb = StringBuilder::StringBuilder()
  let mut pending_space = false
  let mut started = false
  for c in text.to_array() {
    if is_space_char(c) {
      if started {
        pending_space = true
      }
    } else {
      if pending_space {
        sb.write_char(' ')
        pending_space = false
      }
      sb.write_char(c)
      started = true
    }
  }
  sb.to_string()
}

///|
/// XPath `translate()`: map characters from `from` to `to` and delete the rest.
fn translate_text(text : String, from : String, to : String) -> String {
  let source = text.to_array()
  let from_chars = from.to_array()
  let to_chars = to.to_array()
  let sb = StringBuilder::StringBuilder()
  for c in source {
    let mut index = -1
    let mut i = 0
    while i < from_chars.length() {
      if from_chars[i] == c {
        index = i
        break
      }
      i = i + 1
    }
    if index < 0 {
      sb.write_char(c)
    } else if index < to_chars.length() {
      sb.write_char(to_chars[index])
    }
  }
  sb.to_string()
}

///|
/// Split a string on XPath whitespace.
fn split_whitespace(text : String) -> Array[String] {
  let result : Array[String] = []
  let sb = StringBuilder::StringBuilder()
  let mut started = false
  for c in text.to_array() {
    if is_space_char(c) {
      if started {
        result.push(sb.to_string())
        sb.reset()
        started = false
      }
    } else {
      sb.write_char(c)
      started = true
    }
  }
  if started {
    result.push(sb.to_string())
  }
  result
}

///|
/// The XPath `id()` function: select elements whose `id` attribute matches one
/// of the whitespace separated identifiers.
fn elements_by_id(doc : @xml.Document, ids : String) -> Array[Int32] {
  let wanted = split_whitespace(ids)
  let result : Array[Int32] = []
  for node in doc.nodes_in_document_order() {
    if doc.is_element(node) {
      match doc.attribute_value(node, "id") {
        Some(value) =>
          for id in wanted {
            if value == id {
              result.push(node)
            }
          }
        None => ()
      }
    }
  }
  result
}

///|
/// The XPath `lang()` function: match the `xml:lang` attribute of the node or of
/// its nearest ancestor that carries one.
fn matches_language(
  doc : @xml.Document,
  node : Int32,
  language : String,
) -> Bool {
  let mut current : Int32? = Some(node)
  while current is Some(id) {
    match
      doc.attribute_by_expanded(
        id, "http://www.w3.org/XML/1998/namespace", "lang",
      ) {
      Some(attribute) => {
        let declared = doc.value(attribute).to_lower()
        if declared == language {
          return true
        }
        if declared.has_prefix(language + "-") {
          return true
        }
        return false
      }
      None => current = doc.parent(id)
    }
  }
  false
}
