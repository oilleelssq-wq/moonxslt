// Black-box tests for the XPath 1.0 engine.

///|
fn load(xml : String) -> @xml.Document {
  match @xml.parse(xml) {
    Ok(doc) => doc
    Err(info) => abort(info.message)
  }
}

///|
fn root_of(doc : @xml.Document) -> Int32 {
  match doc.root() {
    Some(root) => root
    None => abort("document has no root element")
  }
}

///|
fn describe(doc : @xml.Document, ids : Array[Int32]) -> Array[String] {
  ids.map(fn(id) { doc.qualified_name(id) })
}

///|
fn texts(doc : @xml.Document, ids : Array[Int32]) -> Array[String] {
  ids.map(fn(id) { doc.text_content(id) })
}

///|
test "selects children and descendants" {
  let doc = load("<a><b>1</b><b>2</b><c><b>3</b></c></a>")
  let selected = match @xpath.select(doc, root_of(doc), "/a/b") {
    Ok(set) => set.nodes().to_owned()
    Err(message) => abort(message)
  }
  assert_eq(selected.length(), 2)
  assert_eq(texts(doc, selected), ["1", "2"])
  let descendants = match @xpath.select(doc, root_of(doc), "//b") {
    Ok(set) => set.nodes().to_owned()
    Err(message) => abort(message)
  }
  assert_eq(texts(doc, descendants), ["1", "2", "3"])
}

///|
test "selects wildcards and attributes" {
  let doc = load("<a><b id='x'>1</b><b id='y'>2</b></a>")
  let wildcard = match @xpath.select(doc, root_of(doc), "/a/*") {
    Ok(set) => set.nodes().to_owned()
    Err(message) => abort(message)
  }
  assert_eq(wildcard.length(), 2)
  let attributes = match @xpath.select(doc, root_of(doc), "//b/@id") {
    Ok(set) => set.nodes().to_owned()
    Err(message) => abort(message)
  }
  assert_eq(attributes.length(), 2)
  assert_eq(doc.value(attributes[0]), "x")
  assert_eq(doc.value(attributes[1]), "y")
}

///|
test "applies numeric and boolean predicates" {
  let doc = load("<a><b id='x'>1</b><b id='y'>2</b><b id='z'>3</b></a>")
  let first = match @xpath.select(doc, root_of(doc), "/a/b[1]") {
    Ok(set) => set.nodes().to_owned()
    Err(message) => abort(message)
  }
  assert_eq(texts(doc, first), ["1"])
  let last = match @xpath.select(doc, root_of(doc), "/a/b[last()]") {
    Ok(set) => set.nodes().to_owned()
    Err(message) => abort(message)
  }
  assert_eq(texts(doc, last), ["3"])
  let filtered = match @xpath.select(doc, root_of(doc), "/a/b[@id='y']") {
    Ok(set) => set.nodes().to_owned()
    Err(message) => abort(message)
  }
  assert_eq(texts(doc, filtered), ["2"])
  let second = match @xpath.select(doc, root_of(doc), "/a/b[position()=2]") {
    Ok(set) => set.nodes().to_owned()
    Err(message) => abort(message)
  }
  assert_eq(texts(doc, second), ["2"])
}

///|
test "selects text nodes" {
  let doc = load("<a><b>hello</b><b>world</b></a>")
  let selected = match @xpath.select(doc, root_of(doc), "/a/b/text()") {
    Ok(set) => set.nodes().to_owned()
    Err(message) => abort(message)
  }
  assert_eq(selected.length(), 2)
  assert_eq(doc.value(selected[0]), "hello")
  assert_eq(doc.value(selected[1]), "world")
}

///|
test "unions node-sets and removes duplicates" {
  let doc = load("<a><b>1</b><c>2</c></a>")
  let selected = match @xpath.select(doc, root_of(doc), "/a/b | /a/c | /a/b") {
    Ok(set) => set.nodes().to_owned()
    Err(message) => abort(message)
  }
  assert_eq(describe(doc, selected), ["b", "c"])
}

///|
test "navigates with reverse and sibling axes" {
  let doc = load("<a><b>1</b><b>2</b><b>3</b></a>")
  let parent = match @xpath.select(doc, root_of(doc), "/a/b[1]/..") {
    Ok(set) => set.nodes().to_owned()
    Err(message) => abort(message)
  }
  assert_eq(describe(doc, parent), ["a"])
  let following_result = @xpath.select(
    doc,
    root_of(doc),
    "/a/b[1]/following-sibling::*[1]",
  )
  let following = match following_result {
    Ok(set) => set.nodes().to_owned()
    Err(message) => abort(message)
  }
  assert_eq(texts(doc, following), ["2"])
  let preceding_result = @xpath.select(
    doc,
    root_of(doc),
    "/a/b[3]/preceding-sibling::*",
  )
  let preceding = match preceding_result {
    Ok(set) => set.nodes().to_owned()
    Err(message) => abort(message)
  }
  assert_eq(texts(doc, preceding), ["1", "2"])
  let ancestor = match @xpath.select(doc, root_of(doc), "//b/ancestor::a") {
    Ok(set) => set.nodes().to_owned()
    Err(message) => abort(message)
  }
  assert_eq(describe(doc, ancestor), ["a"])
}

///|
test "evaluates arithmetic expressions" {
  let doc = load("<a/>")
  let root = root_of(doc)
  assert_eq(
    match @xpath.select_number(doc, root, "1 + 2 * 3") {
      Ok(value) => value
      Err(message) => abort(message)
    },
    7.0,
  )
  assert_eq(
    match @xpath.select_number(doc, root, "10 div 4") {
      Ok(value) => value
      Err(message) => abort(message)
    },
    2.5,
  )
  assert_eq(
    match @xpath.select_number(doc, root, "5 mod 2") {
      Ok(value) => value
      Err(message) => abort(message)
    },
    1.0,
  )
  assert_eq(
    match @xpath.select_number(doc, root, "-3 + 1") {
      Ok(value) => value
      Err(message) => abort(message)
    },
    -2.0,
  )
}

///|
test "evaluates comparisons and boolean operators" {
  let doc = load("<a><b>1</b><b>2</b></a>")
  let root = root_of(doc)
  assert_eq(
    match @xpath.select_boolean(doc, root, "count(//b) = 2") {
      Ok(value) => value
      Err(message) => abort(message)
    },
    true,
  )
  assert_eq(
    match @xpath.select_boolean(doc, root, "count(//b) > 5") {
      Ok(value) => value
      Err(message) => abort(message)
    },
    false,
  )
  assert_eq(
    match @xpath.select_boolean(doc, root, "//b = 2") {
      Ok(value) => value
      Err(message) => abort(message)
    },
    true,
  )
  assert_eq(
    match @xpath.select_boolean(doc, root, "true() and not(false())") {
      Ok(value) => value
      Err(message) => abort(message)
    },
    true,
  )
}

///|
test "converts values with the core functions" {
  let doc = load("<a><b> 42 </b></a>")
  let root = root_of(doc)
  assert_eq(
    match @xpath.select_string(doc, root, "string(//b)") {
      Ok(value) => value
      Err(message) => abort(message)
    },
    " 42 ",
  )
  assert_eq(
    match @xpath.select_number(doc, root, "number(//b)") {
      Ok(value) => value
      Err(message) => abort(message)
    },
    42.0,
  )
  assert_eq(
    match @xpath.select_string(doc, root, "name(//b)") {
      Ok(value) => value
      Err(message) => abort(message)
    },
    "b",
  )
}

///|
test "resolves namespaced name tests" {
  let doc = load("<r xmlns:p=\"urn:p\"><p:c>1</p:c><c>2</c></r>")
  let context = @xpath.EvalContext::new(doc, root_of(doc)).with_namespaces([
    ("p", "urn:p"),
  ])
  let expression = match @xpath.parse("//p:c") {
    Ok(expression) => expression
    Err(info) => abort(info.message)
  }
  let selected = match @xpath.select_nodes(context, expression) {
    Ok(set) => set.nodes().to_owned()
    Err(message) => abort(message)
  }
  assert_eq(selected.length(), 1)
  assert_eq(doc.namespace_uri(selected[0]), "urn:p")
}

///|
test "reads variables from the context" {
  let doc = load("<a/>")
  let context = @xpath.EvalContext::new(doc, root_of(doc)).with_variables([
    ("x", @xpath.of_number(41.0)),
  ])
  let expression = match @xpath.parse("$x + 1") {
    Ok(expression) => expression
    Err(info) => abort(info.message)
  }
  let value = match @xpath.evaluate_with(context, expression) {
    Ok(value) => value.number_value(doc)
    Err(message) => abort(message)
  }
  assert_eq(value, 42.0)
}

///|
test "treats an unbound variable as an error" {
  let doc = load("<a/>")
  let result = @xpath.evaluate_path(doc, root_of(doc), "$missing")
  assert_true(result is Err(_))
}

///|
test "reports syntax errors" {
  assert_true(@xpath.parse("//[") is Err(_))
  assert_true(@xpath.parse("1 +") is Err(_))
  assert_true(@xpath.parse("child::") is Err(_))
  match @xpath.parse("1 +") {
    Ok(_) => abort("expected a syntax error")
    Err(info) => assert_true(info.position >= 0)
  }
}

///|
test "formats numbers like XPath" {
  assert_eq(@xpath.format_number(1.0), "1")
  assert_eq(@xpath.format_number(1.5), "1.5")
  assert_eq(@xpath.format_number(0.0), "0")
  assert_eq(@xpath.format_number(-0.0), "0")
  assert_true(@xpath.format_number(@xpath.nan()) == "NaN")
}

///|
test "applies location steps after a filter expression" {
  let doc = load(
    "<catalog><book><title>A</title></book><book><title>B</title></book></catalog>",
  )
  let context = @xpath.EvalContext::new(doc, 0)
  let title = @xpath.select_string(doc, 0, "(//book)[1]/title").unwrap()
  assert_eq(title, "A")
  let titles = @xpath.select_nodes(
    context,
    @xpath.parse("(//book)[2]/title").unwrap(),
  ).unwrap()
  assert_eq(texts(doc, titles.nodes().to_array()), ["B"])
}
