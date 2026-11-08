// Tests for the module facade.

///|
test "transforms through the package facade" {
  let source = "<r><item>a</item></r>"
  let stylesheet = "<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'><xsl:output omit-xml-declaration='yes'/><xsl:template match='/'><out><xsl:value-of select='//item'/></out></xsl:template></xsl:stylesheet>"
  let result = match @moonxslt.transform(source, stylesheet) {
    Ok(text) => text
    Err(message) => abort(message)
  }
  assert_eq(result, "<out>a</out>")
}

///|
test "parses and selects through the package facade" {
  let document = match @moonxslt.parse_xml("<r><a>1</a><a>2</a></r>") {
    Ok(document) => document
    Err(message) => abort(message)
  }
  let count = match @moonxslt.select_string(document, "count(//a)") {
    Ok(value) => value
    Err(message) => abort(message)
  }
  assert_eq(count, "2")
  let nodes = match @moonxslt.select(document, "//a") {
    Ok(nodes) => nodes
    Err(message) => abort(message)
  }
  assert_eq(nodes.length(), 2)
}
