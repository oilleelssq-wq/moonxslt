// Black-box tests for xsl:attribute-set and use-attribute-sets.

///|
test "literal result elements use attribute sets" {
  let body = "<xsl:attribute-set name='box'><xsl:attribute name='class'>box</xsl:attribute></xsl:attribute-set><xsl:template match='/'><out xsl:use-attribute-sets='box'/></xsl:template>"
  assert_eq(transform("<r/>", body), "<out class=\"box\"/>")
}

///|
test "xsl:attribute overrides an attribute set value" {
  let body = "<xsl:attribute-set name='box'><xsl:attribute name='class'>box</xsl:attribute></xsl:attribute-set><xsl:template match='/'><out xsl:use-attribute-sets='box'><xsl:attribute name='class'>big</xsl:attribute></out></xsl:template>"
  assert_eq(transform("<r/>", body), "<out class=\"big\"/>")
}

///|
test "literal attributes override attribute set values" {
  let body = "<xsl:attribute-set name='box'><xsl:attribute name='class'>box</xsl:attribute></xsl:attribute-set><xsl:template match='/'><out class='literal' xsl:use-attribute-sets='box'/></xsl:template>"
  assert_eq(transform("<r/>", body), "<out class=\"literal\"/>")
}

///|
test "attribute sets can use other attribute sets" {
  let body = "<xsl:attribute-set name='base'><xsl:attribute name='lang'>en</xsl:attribute></xsl:attribute-set><xsl:attribute-set name='box' use-attribute-sets='base'><xsl:attribute name='class'>box</xsl:attribute></xsl:attribute-set><xsl:template match='/'><out xsl:use-attribute-sets='box'/></xsl:template>"
  assert_eq(transform("<r/>", body), "<out lang=\"en\" class=\"box\"/>")
}

///|
test "xsl:element honours use-attribute-sets" {
  let body = "<xsl:attribute-set name='base'><xsl:attribute name='lang'>en</xsl:attribute></xsl:attribute-set><xsl:template match='/'><xsl:element name='out' use-attribute-sets='base'/></xsl:template>"
  assert_eq(transform("<r/>", body), "<out lang=\"en\"/>")
}
