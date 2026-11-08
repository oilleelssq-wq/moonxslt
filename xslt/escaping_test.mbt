// Black-box tests for disable-output-escaping.

///|
test "value-of writes markup verbatim when escaping is disabled" {
  let body = "<xsl:template match='/'><out><xsl:value-of select='//s' disable-output-escaping='yes'/></out></xsl:template>"
  assert_eq(
    transform("<r><s>&lt;b&gt;bold&lt;/b&gt;</s></r>", body),
    "<out><b>bold</b></out>",
  )
}

///|
test "value-of escapes markup by default" {
  let body = "<xsl:template match='/'><out><xsl:value-of select='//s'/></out></xsl:template>"
  assert_eq(transform("<r><s>&lt;b&gt;</s></r>", body), "<out>&lt;b&gt;</out>")
}

///|
test "xsl:text honours disable-output-escaping" {
  let body = "<xsl:template match='/'><out><xsl:text disable-output-escaping='yes'>&lt;hr/&gt;</xsl:text></out></xsl:template>"
  assert_eq(transform("<r/>", body), "<out><hr/></out>")
}

///|
test "html output honours disable-output-escaping" {
  let body = "<xsl:output method='html' omit-xml-declaration='yes'/><xsl:template match='/'><out><xsl:value-of select='//s' disable-output-escaping='yes'/></out></xsl:template>"
  assert_eq(transform("<r><s>&lt;br&gt;</s></r>", body), "<out><br></out>")
}
