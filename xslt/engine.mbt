// The XSLT 1.0 transformation engine.
//
// The engine walks the stylesheet's sequence constructors, evaluates XPath
// expressions against the source document and builds a result tree in a second
// arena document. Template rules are selected by mode and priority; patterns are
// compiled to absolute XPath expressions and cached per template.
//
// Variables are kept on a stack that mirrors lexical scope: every sequence
// constructor records the stack height on entry and truncates back to it on
// exit, so `xsl:variable` bindings are visible to the following siblings and to
// their descendants only.

///|
/// The transformer state for one transformation.
priv struct Transformer {
  style : Stylesheet
  source : @xml.Document
  result : @xml.Document
  cache : Array[@xpath.NodeSet]
  cache_ready : Array[Bool]
  variables : Array[(String, @xpath.Value)]
  mut current_node : Int32
  mut current_position : Int32
  mut current_size : Int32
}

///|
/// Apply a compiled stylesheet to a source document and return the result tree.
pub fn run(
  style : Stylesheet,
  source : @xml.Document,
) -> Result[@xml.Document, String] {
  try {
    let transformer = Transformer::new(style, source)
    transformer.apply_templates(0, "", 0)
    Ok(transformer.result)
  } catch {
    XsltError::Failure(message) => Err(message)
  }
}

///|
fn Transformer::new(style : Stylesheet, source : @xml.Document) -> Transformer {
  let cache : Array[@xpath.NodeSet] = []
  let ready : Array[Bool] = []
  for _ in 0..<style.templates.length() {
    cache.push(@xpath.NodeSet::empty())
    ready.push(false)
  }
  {
    style,
    source,
    result: @xml.Document::empty(),
    cache,
    cache_ready: ready,
    variables: [],
    current_node: 0,
    current_position: 1,
    current_size: 1,
  }
}

// ---------------------------------------------------------------------------
// Context and variable stack
// ---------------------------------------------------------------------------

///|
/// Mark the current variable scope.
fn Transformer::save_scope(self : Transformer) -> Int32 {
  self.variables.length()
}

///|
/// Discard the bindings introduced since a mark.
fn Transformer::restore_scope(self : Transformer, mark : Int32) -> Unit {
  self.variables.truncate(mark)
}

///|
/// Look up a variable binding, innermost first.
fn Transformer::lookup_variable(
  self : Transformer,
  name : String,
) -> @xpath.Value? {
  let mut index = self.variables.length() - 1
  while index >= 0 {
    let binding = self.variables[index]
    if binding.0 == name {
      return Some(binding.1)
    }
    index = index - 1
  }
  None
}

///|
/// Evaluate an expression in the current context.
fn Transformer::context(
  self : Transformer,
  style_element : Int32,
) -> @xpath.EvalContext {
  @xpath.EvalContext::new(self.source, self.current_node)
  .with_position(self.current_position, self.current_size)
  .with_variables(self.variables)
  .with_namespaces(in_scope_namespaces(self.style.doc, style_element))
}

// ---------------------------------------------------------------------------
// Template rule selection
// ---------------------------------------------------------------------------

///|
/// Process a node by applying the matching template rule, or the built-in rule
/// when no template matches.
fn Transformer::apply_templates(
  self : Transformer,
  node : Int32,
  mode : String,
  output_parent : Int32,
) -> Unit raise XsltError {
  let saved_node = self.current_node
  let saved_position = self.current_position
  let saved_size = self.current_size
  self.current_node = node
  self.current_position = 1
  self.current_size = 1
  match self.find_template(node, mode) {
    Some(index) => {
      let template = self.style.templates[index]
      self.instantiate(template.element, output_parent)
    }
    None => self.apply_builtin(node, mode, output_parent)
  }
  self.current_node = saved_node
  self.current_position = saved_position
  self.current_size = saved_size
}

///|
/// The highest priority template rule for a node in a mode.
fn Transformer::find_template(
  self : Transformer,
  node : Int32,
  mode : String,
) -> Int32? raise XsltError {
  let mut best : Int32? = None
  let mut best_priority = -1.0e300
  for index in 0..<self.style.templates.length() {
    let template = self.style.templates[index]
    if template.mode != mode {
      continue
    }
    match template.pattern {
      Some(_) =>
        if self.matches_pattern(index, node) {
          // Later rules win ties, which is what the specification requires.
          if template.priority >= best_priority {
            best = Some(index)
            best_priority = template.priority
          }
        }
      None => ()
    }
  }
  best
}

///|
/// Whether a node matches the pattern of a template rule.
fn Transformer::matches_pattern(
  self : Transformer,
  index : Int32,
  node : Int32,
) -> Bool raise XsltError {
  if !self.cache_ready[index] {
    self.cache[index] = self.compute_pattern(index)
    self.cache_ready[index] = true
  }
  self.cache[index].contains(node)
}

///|
/// Compile a template pattern into the node-set it matches.
///
/// A pattern is an XPath expression with a restricted grammar; prefixing a
/// relative pattern with `//` and evaluating the result from the document node
/// is equivalent to matching it against every node of the document, which is
/// exactly what the specification defines.
fn Transformer::compute_pattern(
  self : Transformer,
  index : Int32,
) -> @xpath.NodeSet raise XsltError {
  let template = self.style.templates[index]
  let pattern = match template.pattern {
    Some(pattern) => pattern
    None => return @xpath.NodeSet::empty()
  }
  let namespaces = in_scope_namespaces(self.style.doc, template.element)
  let context = @xpath.EvalContext::new(self.source, 0).with_namespaces(
    namespaces,
  )
  let matched : Array[Int32] = []
  for alternative in split_pattern_alternatives(pattern) {
    let text = alternative.trim().to_owned()
    if text == "" {
      continue
    }
    let expression_text = if text == "/" {
      text
    } else if text.has_prefix("/") {
      text
    } else {
      "//" + text
    }
    let expression = match @xpath.parse(expression_text) {
      Ok(expression) => expression
      Err(info) =>
        return self.fail("invalid pattern \"" + pattern + "\": " + info.message)
    }
    match @xpath.select_nodes(context, expression) {
      Ok(set) =>
        for id in set.nodes() {
          matched.push(id)
        }
      Err(message) =>
        return self.fail(
          "cannot evaluate pattern \"" + pattern + "\": " + message,
        )
    }
  }
  @xpath.NodeSet::new(self.source, matched)
}

///|
/// The built-in template rules: elements and the root recurse into their
/// children, text is copied, and everything else is ignored.
fn Transformer::apply_builtin(
  self : Transformer,
  node : Int32,
  mode : String,
  output_parent : Int32,
) -> Unit raise XsltError {
  if self.source.is_element(node) || self.source.is_document_node(node) {
    for child in self.source.children(node) {
      self.apply_templates(child, mode, output_parent)
    }
  } else if self.source.is_text(node) {
    let _ = self.result.add_text(output_parent, self.source.value(node))
  }
}

// ---------------------------------------------------------------------------
// Sequence constructors
// ---------------------------------------------------------------------------

///|
/// Instantiate the children of a stylesheet element.
fn Transformer::instantiate(
  self : Transformer,
  style_element : Int32,
  output_parent : Int32,
) -> Unit raise XsltError {
  let mark = self.save_scope()
  for child in self.style.doc.children(style_element) {
    self.instantiate_node(child, output_parent)
  }
  self.restore_scope(mark)
}

///|
/// Instantiate a single stylesheet node.
fn Transformer::instantiate_node(
  self : Transformer,
  child : Int32,
  output_parent : Int32,
) -> Unit raise XsltError {
  if self.style.doc.is_text(child) {
    let text = self.style.doc.value(child)
    if is_whitespace_only(text) {
      return
    }
    let _ = self.result.add_text(output_parent, text)
    return
  }
  if self.style.doc.is_comment(child) {
    let _ = self.result.add_comment(output_parent, self.style.doc.value(child))
    return
  }
  if self.style.doc.is_processing_instruction(child) {
    let target = self.style.doc.qualified_name(child)
    let _ = self.result.add_processing_instruction(
      output_parent,
      target,
      self.style.doc.value(child),
    )
    return
  }
  if !self.style.doc.is_element(child) {
    return
  }
  if self.style.doc.namespace_uri(child) == XSLT_NAMESPACE {
    self.instruction(self.style.doc.local_name(child), child, output_parent)
  } else {
    self.literal_element(child, output_parent)
  }
}

///|
/// Execute one XSLT instruction.
fn Transformer::instruction(
  self : Transformer,
  name : String,
  element : Int32,
  output_parent : Int32,
) -> Unit raise XsltError {
  match name {
    "value-of" => {
      let select = self.required_attribute(element, "select")
      let text = self.evaluate_string(select, element)
      let _ = self.result.add_text(output_parent, text)
    }
    "apply-templates" => {
      let select = match self.style.doc.attribute_value(element, "select") {
        Some(select) => select
        None => "child::node()"
      }
      let mode = match self.style.doc.attribute_value(element, "mode") {
        Some(mode) => mode
        None => ""
      }
      let selected = self.evaluate_nodes(select, element)
      for id in self.sort_nodes(selected, element) {
        self.apply_templates(id, mode, output_parent)
      }
    }
    "call-template" => {
      let template_name = self.required_attribute(element, "name")
      let target = match self.style.named_template(template_name) {
        Some(template) => template
        None => return self.fail("no template named \"" + template_name + "\"")
      }
      let mark = self.save_scope()
      for child in self.style.doc.children(element) {
        if self.style.doc.is_element(child) &&
          self.style.doc.namespace_uri(child) == XSLT_NAMESPACE &&
          self.style.doc.local_name(child) == "with-param" {
          self.bind_parameter(child)
        }
      }
      self.instantiate(target.element, output_parent)
      self.restore_scope(mark)
    }
    "for-each" => {
      let select = self.required_attribute(element, "select")
      let selected = self.evaluate_nodes(select, element)
      let nodes = self.sort_nodes(selected, element)
      let size = nodes.length()
      let saved_node = self.current_node
      let saved_position = self.current_position
      let saved_size = self.current_size
      for index in 0..<size {
        self.current_node = nodes[index]
        self.current_position = index + 1
        self.current_size = size
        self.instantiate(element, output_parent)
      }
      self.current_node = saved_node
      self.current_position = saved_position
      self.current_size = saved_size
    }
    "if" => {
      let condition = self.required_attribute(element, "test")
      if self.evaluate_boolean(condition, element) {
        self.instantiate(element, output_parent)
      }
    }
    "choose" =>
      for child in self.style.doc.children(element) {
        if !self.style.doc.is_element(child) ||
          self.style.doc.namespace_uri(child) != XSLT_NAMESPACE {
          continue
        }
        let child_name = self.style.doc.local_name(child)
        if child_name == "when" {
          let condition = self.required_attribute(child, "test")
          if self.evaluate_boolean(condition, child) {
            self.instantiate(child, output_parent)
            return
          }
        } else if child_name == "otherwise" {
          self.instantiate(child, output_parent)
          return
        }
      }
    "variable" => self.bind_variable(element)
    "param" => {
      let parameter_name = self.required_attribute(element, "name")
      match self.lookup_variable(parameter_name) {
        Some(_) => ()
        None => self.bind_variable(element)
      }
    }
    "text" => {
      let sb = StringBuilder::StringBuilder()
      for child in self.style.doc.children(element) {
        if self.style.doc.is_text(child) {
          sb.write_string(self.style.doc.value(child))
        }
      }
      let _ = self.result.add_text(output_parent, sb.to_string())
    }
    "comment" => {
      let text = self.instantiate_text(element)
      let _ = self.result.add_comment(output_parent, text)
    }
    "processing-instruction" => {
      let target = match self.style.doc.attribute_value(element, "name") {
        Some(target) => target
        None => "pi"
      }
      let text = self.instantiate_text(element)
      let _ = self.result.add_processing_instruction(
        output_parent, target, text,
      )
    }
    "element" => {
      let name_text = self.evaluate_avt(
        self.required_attribute(element, "name"),
        element,
      )
      let namespace_uri = match
        self.style.doc.attribute_value(element, "namespace") {
        Some(uri) => Some(self.evaluate_avt(uri, element))
        None => None
      }
      let qname = self.resolve_qname(name_text, namespace_uri, element)
      let result_element = self.result.add_element(output_parent, qname)
      self.note_root(result_element)
      self.ensure_namespace_declared(
        result_element,
        qname.prefix(),
        qname.uri(),
      )
      self.instantiate(element, result_element)
    }
    "attribute" => {
      let name_text = self.evaluate_avt(
        self.required_attribute(element, "name"),
        element,
      )
      let namespace_uri = match
        self.style.doc.attribute_value(element, "namespace") {
        Some(uri) => Some(self.evaluate_avt(uri, element))
        None => None
      }
      let qname = self.resolve_qname(name_text, namespace_uri, element)
      let value = self.instantiate_text(element)
      let _ = self.result.add_attribute(output_parent, qname, value)
    }
    "copy" => self.copy_current(element, output_parent)
    "copy-of" => {
      let select = self.required_attribute(element, "select")
      match self.evaluate_value(select, element).node_set() {
        Some(set) =>
          for id in set.nodes() {
            self.copy_subtree(id, output_parent)
          }
        None => {
          let value = self.evaluate_value(select, element)
          let text = value.string_value(self.source)
          let _ = self.result.add_text(output_parent, text)
        }
      }
    }
    "sort" => ()
    "message" => {
      let text = self.instantiate_text(element)
      let _ = text
    }
    _ =>
      self.fail(
        "unsupported instruction xsl:" +
        name +
        "; it is not implemented in this milestone",
      )
  }
}

///|
/// Bind an `xsl:variable` or `xsl:param` in the current scope.
fn Transformer::bind_variable(
  self : Transformer,
  element : Int32,
) -> Unit raise XsltError {
  let variable_name = self.required_attribute(element, "name")
  let value = match self.style.doc.attribute_value(element, "select") {
    Some(select) => self.evaluate_value(select, element)
    None => @xpath.Value::of_string(self.instantiate_text(element))
  }
  self.variables.push((variable_name, value))
}

///|
/// Bind an `xsl:with-param` in the current scope.
fn Transformer::bind_parameter(
  self : Transformer,
  element : Int32,
) -> Unit raise XsltError {
  let parameter_name = self.required_attribute(element, "name")
  let value = match self.style.doc.attribute_value(element, "select") {
    Some(select) => self.evaluate_value(select, element)
    None => @xpath.Value::of_string(self.instantiate_text(element))
  }
  self.variables.push((parameter_name, value))
}

///|
/// Instantiate the children of an instruction into a string, which is how
/// `xsl:variable`, `xsl:comment` and `xsl:processing-instruction` build their
/// content when there is no `select` attribute.
fn Transformer::instantiate_text(
  self : Transformer,
  element : Int32,
) -> String raise XsltError {
  let temporary = Transformer::new(self.style, self.source)
  temporary.current_node = self.current_node
  temporary.current_position = self.current_position
  temporary.current_size = self.current_size
  for binding in self.variables {
    temporary.variables.push(binding)
  }
  temporary.instantiate(element, 0)
  temporary.result.text_content(0)
}

// ---------------------------------------------------------------------------
// Result tree construction
// ---------------------------------------------------------------------------

///|
/// Create a literal result element, evaluating its attribute value templates.
fn Transformer::literal_element(
  self : Transformer,
  element : Int32,
  output_parent : Int32,
) -> Unit raise XsltError {
  let name = match self.style.doc.name(element) {
    Some(name) => name
    None => return self.fail("literal result element without a name")
  }
  let result_element = self.result.add_element(
    output_parent,
    @xml.QName::new(name.prefix(), name.local_part(), name.uri()),
  )
  self.note_root(result_element)
  for declaration in self.style.doc.namespace_declarations(element) {
    if declaration.1 != XSLT_NAMESPACE {
      self.result.declare_namespace(
        result_element,
        declaration.0,
        declaration.1,
      )
    }
  }
  self.ensure_namespace_declared(result_element, name.prefix(), name.uri())
  for attribute in self.style.doc.attributes(element) {
    let attribute_name = match self.style.doc.name(attribute) {
      Some(attribute_name) => attribute_name
      None => continue
    }
    let attribute_prefix = attribute_name.prefix()
    let attribute_local = attribute_name.local_part()
    if attribute_local == "xmlns" || attribute_prefix == "xmlns" {
      continue
    }
    if attribute_name.uri() == XSLT_NAMESPACE {
      continue
    }
    let value = self.evaluate_avt(self.style.doc.value(attribute), element)
    let _ = self.result.add_attribute(
      result_element,
      @xml.QName::new(attribute_prefix, attribute_local, attribute_name.uri()),
      value,
    )
  }
  self.instantiate(element, result_element)
}

///|
/// Make sure the namespace a result element's name lives in is declared, so
/// that serialisation produces a well-formed document.
fn Transformer::ensure_namespace_declared(
  self : Transformer,
  element : Int32,
  prefix : String,
  uri : String,
) -> Unit {
  if uri == "" {
    return
  }
  for declaration in self.result.namespace_declarations(element) {
    if declaration.0 == prefix && declaration.1 == uri {
      return
    }
  }
  self.result.declare_namespace(element, prefix, uri)
}

///|
/// Remember the document element of the result tree.
fn Transformer::note_root(self : Transformer, element : Int32) -> Unit {
  match self.result.root() {
    Some(_) => ()
    None => self.result.set_root(element)
  }
}

// ---------------------------------------------------------------------------
// Sorting (xsl:sort)
// ---------------------------------------------------------------------------

///|
/// Apply the `xsl:sort` children of an instruction to a node-set.
fn Transformer::sort_nodes(
  self : Transformer,
  selected : @xpath.NodeSet,
  element : Int32,
) -> Array[Int32] raise XsltError {
  let nodes = selected.nodes().to_owned()
  let sorts : Array[(String, String, String, Int32)] = []
  for child in self.style.doc.children(element) {
    if self.style.doc.is_element(child) &&
      self.style.doc.namespace_uri(child) == XSLT_NAMESPACE &&
      self.style.doc.local_name(child) == "sort" {
      let select = match self.style.doc.attribute_value(child, "select") {
        Some(select) => select
        None => "."
      }
      let data_type = match self.style.doc.attribute_value(child, "data-type") {
        Some(value) => value
        None => "text"
      }
      let order = match self.style.doc.attribute_value(child, "order") {
        Some(value) => value
        None => "ascending"
      }
      sorts.push((select, data_type, order, child))
    }
  }
  if sorts.length() == 0 {
    return nodes
  }
  // Insertion sort keeps the document order of equal keys.
  let mut index = 1
  while index < nodes.length() {
    let current = nodes[index]
    let mut position = index
    while position > 0 &&
          self.compare_nodes(nodes[position - 1], current, sorts) > 0 {
      nodes[position] = nodes[position - 1]
      position = position - 1
    }
    nodes[position] = current
    index = index + 1
  }
  nodes
}

///|
/// Compare two nodes by every sort key, in order.
fn Transformer::compare_nodes(
  self : Transformer,
  left : Int32,
  right : Int32,
  sorts : Array[(String, String, String, Int32)],
) -> Int32 raise XsltError {
  for key in sorts {
    let comparison = self.compare_by_key(left, right, key)
    if comparison != 0 {
      return comparison
    }
  }
  0
}

///|
/// Compare two nodes with one sort key.
fn Transformer::compare_by_key(
  self : Transformer,
  left : Int32,
  right : Int32,
  key : (String, String, String, Int32),
) -> Int32 raise XsltError {
  let (select, data_type, order, sort_element) = key
  let saved_node = self.current_node
  self.current_node = left
  let left_text = self.evaluate_string(select, sort_element)
  self.current_node = right
  let right_text = self.evaluate_string(select, sort_element)
  self.current_node = saved_node
  let mut result = 0
  if data_type == "number" {
    let left_number = @xpath.parse_number(left_text)
    let right_number = @xpath.parse_number(right_text)
    if left_number < right_number {
      result = -1
    } else if left_number > right_number {
      result = 1
    }
  } else {
    result = compare_text(left_text, right_text)
  }
  if order == "descending" {
    -result
  } else {
    result
  }
}

///|
fn compare_text(left : String, right : String) -> Int32 {
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

// ---------------------------------------------------------------------------
// Expression evaluation
// ---------------------------------------------------------------------------

///|
/// Evaluate an XPath expression to a node-set.
fn Transformer::evaluate_nodes(
  self : Transformer,
  text : String,
  style_element : Int32,
) -> @xpath.NodeSet raise XsltError {
  let expression = match @xpath.parse(text) {
    Ok(expression) => expression
    Err(info) =>
      self.fail("invalid XPath expression \"" + text + "\": " + info.message)
  }
  match @xpath.select_nodes(self.context(style_element), expression) {
    Ok(set) => set
    Err(message) => self.fail(message)
  }
}

///|
/// Evaluate an XPath expression to a value.
fn Transformer::evaluate_value(
  self : Transformer,
  text : String,
  style_element : Int32,
) -> @xpath.Value raise XsltError {
  let expression = match @xpath.parse(text) {
    Ok(expression) => expression
    Err(info) =>
      self.fail("invalid XPath expression \"" + text + "\": " + info.message)
  }
  match @xpath.evaluate_with(self.context(style_element), expression) {
    Ok(value) => value
    Err(message) => self.fail(message)
  }
}

///|
/// Evaluate an XPath expression and convert the result to a string.
fn Transformer::evaluate_string(
  self : Transformer,
  text : String,
  style_element : Int32,
) -> String raise XsltError {
  let expression = match @xpath.parse(text) {
    Ok(expression) => expression
    Err(info) =>
      self.fail("invalid XPath expression \"" + text + "\": " + info.message)
  }
  match @xpath.string_of(self.context(style_element), expression) {
    Ok(value) => value
    Err(message) => self.fail(message)
  }
}

///|
/// Evaluate an XPath expression and convert the result to a boolean.
fn Transformer::evaluate_boolean(
  self : Transformer,
  text : String,
  style_element : Int32,
) -> Bool raise XsltError {
  let expression = match @xpath.parse(text) {
    Ok(expression) => expression
    Err(info) =>
      self.fail("invalid XPath expression \"" + text + "\": " + info.message)
  }
  match @xpath.boolean_of(self.context(style_element), expression) {
    Ok(value) => value
    Err(message) => self.fail(message)
  }
}

///|
/// Expand an attribute value template: literal text is copied, `{expression}`
/// is replaced by its string value and `{{`/`}}` are unescaped.
fn Transformer::evaluate_avt(
  self : Transformer,
  text : String,
  style_element : Int32,
) -> String raise XsltError {
  let chars = text.to_array()
  let sb = StringBuilder::StringBuilder()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '{' {
      if i + 1 < chars.length() && chars[i + 1] == '{' {
        sb.write_char('{')
        i = i + 2
        continue
      }
      let expression = StringBuilder::StringBuilder()
      let mut j = i + 1
      while j < chars.length() && chars[j] != '}' {
        expression.write_char(chars[j])
        j = j + 1
      }
      if j >= chars.length() {
        return self.fail("unterminated expression in attribute value template")
      }
      let value = self.evaluate_string(expression.to_string(), style_element)
      sb.write_string(value)
      i = j + 1
    } else if c == '}' {
      if i + 1 < chars.length() && chars[i + 1] == '}' {
        sb.write_char('}')
        i = i + 2
      } else {
        return self.fail("unescaped \"}\" in attribute value template")
      }
    } else {
      sb.write_char(c)
      i = i + 1
    }
  }
  sb.to_string()
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

///|
/// The value of a required attribute of a stylesheet element.
fn Transformer::required_attribute(
  self : Transformer,
  element : Int32,
  name : String,
) -> String raise XsltError {
  match self.style.doc.attribute_value(element, name) {
    Some(value) => value
    None =>
      self.fail(
        "xsl:" +
        self.style.doc.local_name(element) +
        " requires a " +
        name +
        " attribute",
      )
  }
}

///|
/// Resolve a QName written in the stylesheet against its in-scope namespaces,
/// or against an explicit `namespace` attribute.
fn Transformer::resolve_qname(
  self : Transformer,
  text : String,
  namespace_uri : String?,
  style_element : Int32,
) -> @xml.QName raise XsltError {
  let (prefix, local_name) = match @xml.split_qname(text) {
    Some(pair) => pair
    None => return self.fail("invalid QName \"" + text + "\"")
  }
  let uri = match namespace_uri {
    Some(uri) => uri
    None =>
      if prefix == "" {
        ""
      } else if prefix == "xml" {
        "http://www.w3.org/XML/1998/namespace"
      } else {
        let mut declared : String? = None
        for declaration in in_scope_namespaces(self.style.doc, style_element) {
          if declaration.0 == prefix && declared is None {
            declared = Some(declaration.1)
          }
        }
        match declared {
          Some(uri) => uri
          None =>
            return self.fail("undeclared namespace prefix \"" + prefix + "\"")
        }
      }
  }
  @xml.QName::new(prefix, local_name, uri)
}

///|
/// Shallow-copy the current node, then instantiate the instruction's children.
fn Transformer::copy_current(
  self : Transformer,
  element : Int32,
  output_parent : Int32,
) -> Unit raise XsltError {
  let node = self.current_node
  if self.source.is_element(node) {
    let name = match self.source.name(node) {
      Some(name) => name
      None => return self.fail("cannot copy an element without a name")
    }
    let copy = self.result.add_element(
      output_parent,
      @xml.QName::new(name.prefix(), name.local_part(), name.uri()),
    )
    self.note_root(copy)
    for declaration in self.source.namespace_declarations(node) {
      self.result.declare_namespace(copy, declaration.0, declaration.1)
    }
    self.ensure_namespace_declared(copy, name.prefix(), name.uri())
    self.instantiate(element, copy)
    return
  }
  if self.source.is_text(node) {
    let _ = self.result.add_text(output_parent, self.source.value(node))
    return
  }
  if self.source.is_comment(node) {
    let _ = self.result.add_comment(output_parent, self.source.value(node))
    return
  }
  if self.source.is_processing_instruction(node) {
    let _ = self.result.add_processing_instruction(
      output_parent,
      self.source.qualified_name(node),
      self.source.value(node),
    )
    return
  }
  if self.source.is_attribute(node) {
    self.copy_attribute(node, output_parent)
    return
  }
  self.instantiate(element, output_parent)
}

///|
/// Copy one attribute node onto a result element.
fn Transformer::copy_attribute(
  self : Transformer,
  attribute : Int32,
  output_parent : Int32,
) -> Unit {
  match self.source.name(attribute) {
    Some(name) =>
      if self.result.is_element(output_parent) {
        let _ = self.result.add_attribute(
          output_parent,
          @xml.QName::new(name.prefix(), name.local_part(), name.uri()),
          self.source.value(attribute),
        )
      }
    None => ()
  }
}

///|
/// Deep-copy a source subtree into the result tree.
fn Transformer::copy_subtree(
  self : Transformer,
  node : Int32,
  output_parent : Int32,
) -> Unit raise XsltError {
  if self.source.is_element(node) {
    let name = match self.source.name(node) {
      Some(name) => name
      None => return self.fail("cannot copy an element without a name")
    }
    let copy = self.result.add_element(
      output_parent,
      @xml.QName::new(name.prefix(), name.local_part(), name.uri()),
    )
    self.note_root(copy)
    for declaration in self.source.namespace_declarations(node) {
      self.result.declare_namespace(copy, declaration.0, declaration.1)
    }
    self.ensure_namespace_declared(copy, name.prefix(), name.uri())
    for attribute in self.source.attributes(node) {
      self.copy_attribute(attribute, copy)
    }
    for child in self.source.children(node) {
      self.copy_subtree(child, copy)
    }
    return
  }
  if self.source.is_text(node) {
    let _ = self.result.add_text(output_parent, self.source.value(node))
  } else if self.source.is_comment(node) {
    let _ = self.result.add_comment(output_parent, self.source.value(node))
  } else if self.source.is_processing_instruction(node) {
    let _ = self.result.add_processing_instruction(
      output_parent,
      self.source.qualified_name(node),
      self.source.value(node),
    )
  } else if self.source.is_attribute(node) {
    self.copy_attribute(node, output_parent)
  }
}

///|
/// Report a transformation error.
fn[T] Transformer::fail(
  self : Transformer,
  message : String,
) -> T raise XsltError {
  let _ = self
  raise XsltError::Failure(message)
}

///|
fn is_whitespace_only(text : String) -> Bool {
  for c in text {
    if !@xml.is_xml_whitespace(c) {
      return false
    }
  }
  true
}
