// Black-box tests for the XSLT 1.0 engine.

///|
const XSL_HEAD : String = "<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'><xsl:output method='xml' omit-xml-declaration='yes'/>"

///|
fn transform(source : String, body : String) -> String {
  let stylesheet = XSL_HEAD + body + "</xsl:stylesheet>"
  match @xslt.transform(source, stylesheet) {
    Ok(text) => text
    Err(message) => abort(message)
  }
}

///|
fn transform_error(source : String, body : String) -> String {
  let stylesheet = XSL_HEAD + body + "</xsl:stylesheet>"
  match @xslt.transform(source, stylesheet) {
    Ok(_) => abort("expected a transformation error")
    Err(message) => message
  }
}

///|
test "evaluates value-of inside literal result elements" {
  let result = transform(
    "<r><item>a</item><item>b</item></r>", "<xsl:template match='/'><doc><xsl:value-of select='count(//item)'/></doc></xsl:template>",
  )
  assert_eq(result, "<doc>2</doc>")
}

///|
test "applies templates to selected nodes" {
  let body = "<xsl:template match='/'><ul><xsl:apply-templates select='//item'/></ul></xsl:template><xsl:template match='item'><li><xsl:value-of select='.'/></li></xsl:template>"
  let result = transform("<r><item>a</item><item>b</item></r>", body)
  assert_eq(result, "<ul><li>a</li><li>b</li></ul>")
}

///|
test "falls back to the built-in template rules" {
  let body = "<xsl:template match='/'><out><xsl:apply-templates/></out></xsl:template>"
  let result = transform("<r>text<b>x</b></r>", body)
  assert_eq(result, "<out>textx</out>")
}

///|
test "expands attribute value templates and brace escapes" {
  let body = "<xsl:template match='/'><a href='{//link/@href}' title='x{{y}}'/></xsl:template>"
  let result = transform("<r><link href='u'/></r>", body)
  assert_eq(result, "<a href=\"u\" title=\"x{y}\"/>")
}

///|
test "prefers higher priority templates" {
  let body = "<xsl:template match='/'><out><xsl:apply-templates/></out></xsl:template><xsl:template match='item' priority='2'><high/></xsl:template><xsl:template match='item' priority='1'><low/></xsl:template>"
  let result = transform("<r><item/></r>", body)
  assert_eq(result, "<out><high/></out>")
}

///|
test "separates templates by mode" {
  let body = "<xsl:template match='/'><out><xsl:apply-templates select='//item' mode='m'/></out></xsl:template><xsl:template match='item' mode='m'><m/></xsl:template><xsl:template match='item'><d/></xsl:template>"
  let result = transform("<r><item/></r>", body)
  assert_eq(result, "<out><m/></out>")
}

///|
test "strips whitespace-only text from the stylesheet" {
  let body = "\n  <xsl:template match='/'>\n    <out/>\n  </xsl:template>\n"
  let result = transform("<r/>", body)
  assert_eq(result, "<out/>")
}

///|
test "reports unimplemented instructions" {
  let message = transform_error(
    "<r><item/></r>", "<xsl:template match='/'><xsl:number value='1'/></xsl:template>",
  )
  assert_true(message.contains("unsupported instruction"))
}

///|
test "rejects documents that are not stylesheets" {
  let result = @xslt.transform("<r/>", "<r/>")
  assert_true(result is Err(_))
}

///|
test "reports invalid patterns" {
  let message = transform_error(
    "<r/>", "<xsl:template match='child::'><out/></xsl:template>",
  )
  assert_true(message.contains("invalid pattern"))
}

///|
test "includes the XML declaration by default" {
  let stylesheet = "<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'><xsl:template match='/'><out/></xsl:template></xsl:stylesheet>"
  let result = match @xslt.transform("<r/>", stylesheet) {
    Ok(text) => text
    Err(message) => abort(message)
  }
  assert_true(result.has_prefix("<?xml"))
}

///|
test "iterates with for-each and exposes position()" {
  let body = "<xsl:template match='/'><out><xsl:for-each select='//item'><i><xsl:value-of select='position()'/></i></xsl:for-each></out></xsl:template>"
  let result = transform("<r><item/><item/></r>", body)
  assert_eq(result, "<out><i>1</i><i>2</i></out>")
}

///|
test "evaluates if" {
  let body = "<xsl:template match='/'><out><xsl:if test='count(//item) &gt; 1'><many/></xsl:if></out></xsl:template>"
  let result = transform("<r><item/><item/></r>", body)
  assert_eq(result, "<out><many/></out>")
}

///|
test "evaluates choose" {
  let body = "<xsl:template match='/'><out><xsl:choose><xsl:when test='//item'>present</xsl:when><xsl:otherwise>missing</xsl:otherwise></xsl:choose></out></xsl:template>"
  assert_eq(transform("<r><item/></r>", body), "<out>present</out>")
  assert_eq(transform("<r/>", body), "<out>missing</out>")
}

///|
test "binds variables" {
  let body = "<xsl:template match='/'><xsl:variable name='total' select='count(//item)'/><out><xsl:value-of select='$total'/></out></xsl:template>"
  let result = transform("<r><item/><item/><item/></r>", body)
  assert_eq(result, "<out>3</out>")
}

///|
test "passes parameters to named templates" {
  let body = "<xsl:template match='/'><out><xsl:call-template name='greet'><xsl:with-param name='who' select='&quot;world&quot;'/></xsl:call-template></out></xsl:template><xsl:template name='greet'><p><xsl:value-of select='$who'/></p></xsl:template>"
  let result = transform("<r/>", body)
  assert_eq(result, "<out><p>world</p></out>")
}

///|
test "sorts by numeric keys in descending order" {
  let body = "<xsl:template match='/'><out><xsl:for-each select='//n'><xsl:sort select='.' data-type='number' order='descending'/><xsl:value-of select='.'/>,</xsl:for-each></out></xsl:template>"
  let result = transform("<r><n>2</n><n>10</n><n>1</n></r>", body)
  assert_eq(result, "<out>10,2,1,</out>")
}
