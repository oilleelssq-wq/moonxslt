// The module facade.
//
// The processor is split into three packages that can be used on their own:
// `xml` parses and serialises documents, `xpath` evaluates XPath 1.0 expressions
// and `xslt` runs stylesheets. This package re-exports the common entry points so
// that applications can depend on a single import.

///|
/// Transform an XML document with an XSLT stylesheet.
///
/// Both arguments are XML text; the result is the serialised result tree,
/// serialised with the method declared by `xsl:output`.
pub fn transform(
  source_xml : String,
  stylesheet_xml : String,
) -> Result[String, String] {
  @xslt.transform(source_xml, stylesheet_xml)
}

///|
/// Parse an XML document.
pub fn parse_xml(text : String) -> Result[@xml.Document, String] {
  match @xml.parse(text) {
    Ok(document) => Ok(document)
    Err(info) => Err(info.message)
  }
}

///|
/// Evaluate an XPath 1.0 expression against a document and return the matching
/// nodes as a node-set.
pub fn select(
  document : @xml.Document,
  expression : String,
) -> Result[@xpath.NodeSet, String] {
  let root = match document.root() {
    Some(root) => root
    None => return Err("the document has no document element")
  }
  @xpath.select(document, root, expression)
}

///|
/// Evaluate an XPath 1.0 expression against a document and return its string
/// value.
pub fn select_string(
  document : @xml.Document,
  expression : String,
) -> Result[String, String] {
  let root = match document.root() {
    Some(root) => root
    None => return Err("the document has no document element")
  }
  @xpath.select_string(document, root, expression)
}
