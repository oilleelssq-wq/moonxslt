// Black-box tests for xsl:include and xsl:import.

///|
const SHARED_STYLESHEET : String = "<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'><xsl:template match='item'><i><xsl:value-of select='.'/></i></xsl:template></xsl:stylesheet>"

///|
const MAIN_WITH_INCLUDE : String = "<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'><xsl:include href='shared.xsl'/><xsl:template match='/'><out><xsl:apply-templates select='//item'/></out></xsl:template></xsl:stylesheet>"

///|
const MAIN_WITH_IMPORT : String = "<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'><xsl:import href='shared.xsl'/><xsl:template match='/'><out><xsl:apply-templates select='//item'/></out></xsl:template></xsl:stylesheet>"

///|
fn shared_loader(uri : String) -> Result[String, String] {
  if uri == "shared.xsl" {
    Ok(SHARED_STYLESHEET)
  } else {
    Err("unexpected " + uri)
  }
}

///|
test "xsl:include pulls in templates" {
  let result = @xslt.transform_with_loader(
    "<r><item>7</item></r>",
    MAIN_WITH_INCLUDE,
    shared_loader,
  )
  assert_eq(
    result.unwrap(),
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?><out><i>7</i></out>",
  )
}

///|
test "xsl:import pulls in templates" {
  let result = @xslt.transform_with_loader(
    "<r><item>8</item></r>",
    MAIN_WITH_IMPORT,
    shared_loader,
  )
  assert_eq(
    result.unwrap(),
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?><out><i>8</i></out>",
  )
}

///|
test "included declarations keep their namespace prefixes" {
  let shared = "<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform' xmlns:out='urn:out'><xsl:template match='item'><out:i><xsl:value-of select='.'/></out:i></xsl:template></xsl:stylesheet>"
  let loader = fn(uri) {
    if uri == "shared.xsl" {
      Ok(shared)
    } else {
      Err("unexpected " + uri)
    }
  }
  let result = @xslt.transform_with_loader(
    "<r><item>9</item></r>",
    MAIN_WITH_INCLUDE,
    loader,
  )
  assert_eq(
    result.unwrap(),
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?><out><out:i xmlns:out=\"urn:out\">9</out:i></out>",
  )
}

///|
test "compiling without a loader reports the include" {
  let result = @xslt.transform("<r/>", MAIN_WITH_INCLUDE)
  match result {
    Err(message) => assert_true(message.contains("loader"))
    Ok(_) => abort("expected an error for xsl:include without a loader")
  }
}

///|
test "loader failures are reported" {
  let failing_loader = fn(_uri) { Err("disk on fire") }
  let result = @xslt.transform_with_loader(
    "<r/>",
    MAIN_WITH_INCLUDE,
    failing_loader,
  )
  match result {
    Err(message) => assert_true(message.contains("disk on fire"))
    Ok(_) => abort("expected the loader error")
  }
}

///|
test "circular includes are rejected" {
  let circular = "<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'><xsl:include href='a.xsl'/></xsl:stylesheet>"
  let loader = fn(_uri) { Ok(circular) }
  let result = @xslt.transform_with_loader("<r/>", circular, loader)
  match result {
    Err(message) => assert_true(message.contains("circular"))
    Ok(_) => abort("expected a circular include error")
  }
}
