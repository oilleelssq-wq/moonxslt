// Black-box tests for the extended XPath 1.0 function library.

///|
test "string functions" {
  let doc = load("<a/>")
  let root = root_of(doc)
  let evaluate_string = fn(path : String) -> String {
    match @xpath.select_string(doc, root, path) {
      Ok(value) => value
      Err(message) => abort(message)
    }
  }
  assert_eq(evaluate_string("concat('a', 'b', 'c')"), "abc")
  assert_eq(evaluate_string("concat('x', 1 + 1)"), "x2")
  assert_eq(evaluate_string("contains('hello world', 'lo w')"), "true")
  assert_eq(evaluate_string("starts-with('hello', 'he')"), "true")
  assert_eq(evaluate_string("substring('12345', 2, 3)"), "234")
  assert_eq(evaluate_string("substring('12345', 1.5, 2.6)"), "234")
  assert_eq(evaluate_string("substring('12345', 0, 3)"), "12")
  assert_eq(evaluate_string("substring('12345', 2)"), "2345")
  assert_eq(evaluate_string("substring-before('a-b-c', '-')"), "a")
  assert_eq(evaluate_string("substring-after('a-b-c', '-')"), "b-c")
  assert_eq(evaluate_string("string-length('abcd')"), "4")
  assert_eq(evaluate_string("normalize-space('  a   b  ')"), "a b")
  assert_eq(evaluate_string("translate('abcabc', 'ac', 'xy')"), "xbyxby")
  assert_eq(evaluate_string("translate('abc', 'ab', 'x')"), "xc")
}

///|
test "number functions" {
  let doc = load("<a><b>1</b><b>2</b><b>3</b></a>")
  let root = root_of(doc)
  let evaluate_number = fn(path : String) -> Double {
    match @xpath.select_number(doc, root, path) {
      Ok(value) => value
      Err(message) => abort(message)
    }
  }
  assert_eq(evaluate_number("sum(//b)"), 6.0)
  assert_eq(evaluate_number("floor(1.9)"), 1.0)
  assert_eq(evaluate_number("ceiling(1.1)"), 2.0)
  assert_eq(evaluate_number("round(1.5)"), 2.0)
  assert_eq(evaluate_number("round(-1.5)"), -1.0)
}

///|
test "node-set functions" {
  let doc = load("<a><item id='x'>1</item><item id='y'>2</item></a>")
  let root = root_of(doc)
  let selected = match @xpath.select(doc, root, "id('y x')") {
    Ok(set) => set.nodes().to_owned()
    Err(message) => abort(message)
  }
  assert_eq(selected.length(), 2)
  assert_eq(doc.local_name(selected[0]), "item")
  assert_eq(doc.value(doc.attributes(selected[0])[0]), "x")
}

///|
test "matches xml:lang values" {
  let doc = load("<a xml:lang='en-GB'><b/></a>")
  let root = root_of(doc)
  let context = @xpath.EvalContext::new(doc, doc.children(root)[0])
  let expression = match @xpath.parse("lang('en')") {
    Ok(expression) => expression
    Err(info) => abort(info.message)
  }
  let value = match @xpath.evaluate_with(context, expression) {
    Ok(value) => value.boolean_value()
    Err(message) => abort(message)
  }
  assert_eq(value, true)
}
