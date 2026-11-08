// Black-box tests for xsl:key and key().

///|
const KEY_CATALOG : String = "<catalog><book><title>A</title><author>Li Wei</author></book><book><title>B</title><author>Chen Yu</author></book><book><title>C</title><author>Li Wei</author></book></catalog>"

///|
test "selects nodes by key value" {
  let body = "<xsl:key name='by-author' match='book' use='author'/><xsl:template match='/'><out><xsl:for-each select='key(\"by-author\", \"Chen Yu\")'><t><xsl:value-of select='title'/></t></xsl:for-each></out></xsl:template>"
  assert_eq(transform(KEY_CATALOG, body), "<out><t>B</t></out>")
}

///|
test "returns every node registered for a key" {
  let body = "<xsl:key name='by-author' match='book' use='author'/><xsl:template match='/'><out><xsl:for-each select='key(\"by-author\", \"Li Wei\")'><t><xsl:value-of select='title'/></t></xsl:for-each></out></xsl:template>"
  assert_eq(transform(KEY_CATALOG, body), "<out><t>A</t><t>C</t></out>")
}

///|
test "treats the key argument as a single string" {
  let body = "<xsl:key name='by-author' match='book' use='author'/><xsl:template match='/'><out><xsl:value-of select='count(key(\"by-author\", \"Li Wei Chen Yu\"))'/></out></xsl:template>"
  assert_eq(transform(KEY_CATALOG, body), "<out>0</out>")
}

///|
test "returns an empty node-set for unknown keys" {
  let body = "<xsl:key name='by-author' match='book' use='author'/><xsl:template match='/'><out><xsl:value-of select='count(key(\"by-author\", \"Nobody\"))'/></out></xsl:template>"
  assert_eq(transform(KEY_CATALOG, body), "<out>0</out>")
}
