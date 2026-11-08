// Black-box tests for the XML data model and parser.

///|
test "parses a simple document" {
  let result = @xml.parse("<greeting>hello</greeting>")
  let doc = match result {
    Ok(doc) => doc
    Err(info) => abort(info.message)
  }
  let root = match doc.root() {
    Some(root) => root
    None => abort("missing root")
  }
  assert_true(doc.kind(root) is Some(Element))
  assert_eq(doc.local_name(root), "greeting")
  assert_eq(doc.namespace_uri(root), "")
  assert_eq(doc.text_content(root), "hello")
  assert_eq(doc.children(root).length(), 1)
}

///|
test "decodes entities and character references" {
  let result = @xml.parse("<a>&lt;x&gt; &amp; &#65;&#x42;</a>")
  let doc = match result {
    Ok(doc) => doc
    Err(info) => abort(info.message)
  }
  let root = match doc.root() {
    Some(root) => root
    None => abort("missing root")
  }
  assert_eq(doc.text_content(root), "<x> & AB")
}

///|
test "keeps comments between text nodes" {
  let result = @xml.parse("<a>one<!--c-->two</a>")
  let doc = match result {
    Ok(doc) => doc
    Err(info) => abort(info.message)
  }
  let root = match doc.root() {
    Some(root) => root
    None => abort("missing root")
  }
  let children = doc.children(root)
  assert_eq(children.length(), 3)
  assert_eq(doc.value(children[0]), "one")
  assert_true(doc.kind(children[1]) is Some(Comment))
  assert_eq(doc.value(children[2]), "two")
}

///|
test "parses attributes and normalises whitespace" {
  let result = @xml.parse("<a id = '1' note=\"x\ty\nz\"/>")
  let doc = match result {
    Ok(doc) => doc
    Err(info) => abort(info.message)
  }
  let root = match doc.root() {
    Some(root) => root
    None => abort("missing root")
  }
  assert_eq(doc.attribute_value(root, "id"), Some("1"))
  assert_eq(doc.attribute_value(root, "note"), Some("x y z"))
  assert_eq(doc.attributes(root).length(), 2)
}

///|
test "resolves default and prefixed namespaces" {
  let source = "<root xmlns=\"urn:d\" xmlns:p=\"urn:p\"><p:child p:attr=\"v\"/></root>"
  let result = @xml.parse(source)
  let doc = match result {
    Ok(doc) => doc
    Err(info) => abort(info.message)
  }
  let root = match doc.root() {
    Some(root) => root
    None => abort("missing root")
  }
  assert_eq(doc.namespace_uri(root), "urn:d")
  let child = doc.children(root)[0]
  assert_eq(doc.local_name(child), "child")
  assert_eq(doc.namespace_uri(child), "urn:p")
  let attribute = doc.attributes(child)[0]
  assert_eq(doc.local_name(attribute), "attr")
  assert_eq(doc.namespace_uri(attribute), "urn:p")
  assert_eq(doc.namespace_declarations(root).length(), 2)
}

///|
test "default namespace does not apply to attributes" {
  let result = @xml.parse("<root xmlns=\"urn:d\" plain=\"v\"/>")
  let doc = match result {
    Ok(doc) => doc
    Err(info) => abort(info.message)
  }
  let root = match doc.root() {
    Some(root) => root
    None => abort("missing root")
  }
  assert_eq(doc.namespace_uri(root), "urn:d")
  assert_eq(doc.namespace_uri(doc.attributes(root)[0]), "")
}

///|
test "parses CDATA as text" {
  let result = @xml.parse("<a><![CDATA[<not markup> & raw]]></a>")
  let doc = match result {
    Ok(doc) => doc
    Err(info) => abort(info.message)
  }
  let root = match doc.root() {
    Some(root) => root
    None => abort("missing root")
  }
  assert_eq(doc.text_content(root), "<not markup> & raw")
}

///|
test "parses comments and processing instructions" {
  let source = "<?xml version=\"1.0\"?><!--before--><a><?pi data?></a><!--after-->"
  let result = @xml.parse(source)
  let doc = match result {
    Ok(doc) => doc
    Err(info) => abort(info.message)
  }
  let document_children = doc.children(0)
  assert_eq(document_children.length(), 3)
  assert_true(doc.kind(document_children[0]) is Some(Comment))
  assert_eq(doc.value(document_children[0]), "before")
  assert_true(doc.kind(document_children[2]) is Some(Comment))
  assert_eq(doc.value(document_children[2]), "after")
  let root = document_children[1]
  let instruction = doc.children(root)[0]
  assert_true(doc.kind(instruction) is Some(ProcessingInstruction))
  assert_eq(doc.qualified_name(instruction), "pi")
  assert_eq(doc.value(instruction), "data")
}

///|
test "parses nested elements and text content" {
  let result = @xml.parse("<a><b>one</b><b>two</b></a>")
  let doc = match result {
    Ok(doc) => doc
    Err(info) => abort(info.message)
  }
  let root = match doc.root() {
    Some(root) => root
    None => abort("missing root")
  }
  assert_eq(doc.children(root).length(), 2)
  assert_eq(doc.text_content(root), "onetwo")
  let first = doc.children(root)[0]
  let second = doc.children(root)[1]
  assert_true(doc.compare_order(first, second) < 0)
  assert_eq(doc.parent(first), Some(root))
}

///|
test "rejects mismatched end tags" {
  let result = @xml.parse("<a></b>")
  assert_true(result is Err(_))
  match result {
    Err(info) => {
      assert_eq(info.line, 1)
      assert_true(info.message.contains("does not match"))
    }
    Ok(_) => abort("expected an error")
  }
}

///|
test "rejects unclosed elements" {
  let result = @xml.parse("<a><b></a>")
  assert_true(result is Err(_))
}

///|
test "rejects unknown entities" {
  let result = @xml.parse("<a>&nbsp;</a>")
  assert_true(result is Err(_))
  match result {
    Err(info) => assert_true(info.message.contains("unknown entity"))
    Ok(_) => abort("expected an error")
  }
}

///|
test "rejects undeclared namespace prefixes" {
  let result = @xml.parse("<p:a/>")
  assert_true(result is Err(_))
  match result {
    Err(info) =>
      assert_true(info.message.contains("undeclared namespace prefix"))
    Ok(_) => abort("expected an error")
  }
}

///|
test "rejects duplicate attributes" {
  let result = @xml.parse("<a x=\"1\" x=\"2\"/>")
  assert_true(result is Err(_))
  match result {
    Err(info) => assert_true(info.message.contains("duplicate attribute"))
    Ok(_) => abort("expected an error")
  }
}

///|
test "reports the line of an error" {
  let result = @xml.parse("<a>\n  <b>\n</a>")
  match result {
    Err(info) => assert_eq(info.line, 3)
    Ok(_) => abort("expected an error")
  }
}

///|
test "serialises a document" {
  let result = @xml.parse("<a x='1'><b>t</b></a>")
  let doc = match result {
    Ok(doc) => doc
    Err(info) => abort(info.message)
  }
  assert_eq(
    doc.to_xml(),
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?><a x=\"1\"><b>t</b></a>",
  )
}

///|
test "serialises empty elements and escapes text" {
  let result = @xml.parse("<a><b/><c>1 &lt; 2</c></a>")
  let doc = match result {
    Ok(doc) => doc
    Err(info) => abort(info.message)
  }
  assert_eq(
    doc.to_xml(),
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?><a><b/><c>1 &lt; 2</c></a>",
  )
}

///|
test "pretty printing indents element children" {
  let result = @xml.parse("<a><b>t</b><c/></a>")
  let doc = match result {
    Ok(doc) => doc
    Err(info) => abort(info.message)
  }
  assert_eq(
    doc.to_xml(indent=true),
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<a>\n  <b>t</b>\n  <c/>\n</a>",
  )
}

///|
test "round trips through serialisation" {
  let source = "<r xmlns:p=\"urn:p\"><p:x a=\"1\">text</p:x><!--c--><![CDATA[raw]]></r>"
  let first = match @xml.parse(source) {
    Ok(doc) => doc
    Err(info) => abort(info.message)
  }
  let serialised = first.to_xml()
  let second = match @xml.parse(serialised) {
    Ok(doc) => doc
    Err(info) => abort(info.message)
  }
  assert_eq(second.to_xml(), serialised)
}

///|
test "keeps non-ASCII text intact" {
  let result = @xml.parse("<标题>你好，世界</标题>")
  let doc = match result {
    Ok(doc) => doc
    Err(info) => abort(info.message)
  }
  let root = match doc.root() {
    Some(root) => root
    None => abort("missing root")
  }
  assert_eq(doc.local_name(root), "标题")
  assert_eq(doc.text_content(root), "你好，世界")
}

///|
test "keeps whitespace-only text nodes" {
  let result = @xml.parse("<a> <b/> </a>")
  let doc = match result {
    Ok(doc) => doc
    Err(info) => abort(info.message)
  }
  let root = match doc.root() {
    Some(root) => root
    None => abort("missing root")
  }
  let children = doc.children(root)
  assert_eq(children.length(), 3)
  assert_true(doc.is_whitespace_text(children[0]))
  assert_eq(doc.is_whitespace_text(children[1]), false)
}
