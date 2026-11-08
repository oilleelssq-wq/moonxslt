// Public entry points for applying stylesheets.

///|
/// Transform an XML document with an XSLT stylesheet.
///
/// Both arguments are XML text; the result is the serialised result tree.
pub fn transform(
  source_xml : String,
  stylesheet_xml : String,
) -> Result[String, String] {
  let source = match @xml.parse(source_xml) {
    Ok(doc) => doc
    Err(info) => return Err("source document: " + info.message)
  }
  let stylesheet_document = match @xml.parse(stylesheet_xml) {
    Ok(doc) => doc
    Err(info) => return Err("stylesheet: " + info.message)
  }
  let stylesheet = match compile(stylesheet_document) {
    Ok(stylesheet) => stylesheet
    Err(message) => return Err(message)
  }
  let result = match run(stylesheet, source) {
    Ok(doc) => doc
    Err(message) => return Err(message)
  }
  Ok(
    result.to_xml(
      indent=stylesheet.indents(),
      declaration=!stylesheet.omits_xml_declaration(),
    ),
  )
}

///|
/// Transform already parsed documents.
pub fn transform_documents(
  source : @xml.Document,
  stylesheet : Stylesheet,
) -> Result[@xml.Document, String] {
  run(stylesheet, source)
}

///|
/// Compile a stylesheet from XML text.
pub fn compile_stylesheet(
  stylesheet_xml : String,
) -> Result[Stylesheet, String] {
  let document = match @xml.parse(stylesheet_xml) {
    Ok(doc) => doc
    Err(info) => return Err("stylesheet: " + info.message)
  }
  compile(document)
}

///|
/// Serialise a result tree with the settings of a compiled stylesheet.
pub fn serialise(result : @xml.Document, stylesheet : Stylesheet) -> String {
  result.to_xml(
    indent=stylesheet.indents(),
    declaration=!stylesheet.omits_xml_declaration(),
  )
}
