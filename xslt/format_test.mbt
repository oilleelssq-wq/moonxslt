// Black-box tests for format-number() and xsl:decimal-format.

///|
test "formats with grouping and fixed decimals" {
  let body = "<xsl:template match='/'><out><xsl:value-of select='format-number(1234.567, \"#,##0.00\")'/></out></xsl:template>"
  assert_eq(transform("<r/>", body), "<out>1,234.57</out>")
}

///|
test "pads integer digits with zeroes" {
  let body = "<xsl:template match='/'><out><xsl:value-of select='format-number(3, \"000\")'/></out></xsl:template>"
  assert_eq(transform("<r/>", body), "<out>003</out>")
}

///|
test "formats percentages" {
  let body = "<xsl:template match='/'><out><xsl:value-of select='format-number(0.5, \"0%\")'/></out></xsl:template>"
  assert_eq(transform("<r/>", body), "<out>50%</out>")
}

///|
test "uses a negative subpattern" {
  let body = "<xsl:template match='/'><out><xsl:value-of select='format-number(-12.3, \"0.0;(0.0)\")'/></out></xsl:template>"
  assert_eq(transform("<r/>", body), "<out>(12.3)</out>")
}

///|
test "trims optional fraction digits" {
  let body = "<xsl:template match='/'><out><xsl:value-of select='format-number(12.3, \"#,##0.00\")'/></out></xsl:template>"
  assert_eq(transform("<r/>", body), "<out>12.30</out>")
  let body2 = "<xsl:template match='/'><out><xsl:value-of select='format-number(12.0, \"#,##0.##\")'/></out></xsl:template>"
  assert_eq(transform("<r/>", body2), "<out>12</out>")
}

///|
test "honours a named decimal format" {
  let body = "<xsl:decimal-format name='europe' decimal-separator=',' grouping-separator='.'/><xsl:template match='/'><out><xsl:value-of select='format-number(1234.5, \"#.##0,00\", \"europe\")'/></out></xsl:template>"
  assert_eq(transform("<r/>", body), "<out>1.234,50</out>")
}

///|
test "formats infinities" {
  let body = "<xsl:template match='/'><out><xsl:value-of select='format-number(1 div 0, \"0\")'/></out></xsl:template>"
  assert_eq(transform("<r/>", body), "<out>Infinity</out>")
}
