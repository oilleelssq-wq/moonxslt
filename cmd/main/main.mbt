// Command line front end for the processor.
//
// Usage: moonxslt <stylesheet.xsl> <source.xml> [output]
//
// The stylesheet and source are read as UTF-8, the transformation result is
// written to standard output, or to the file named by the third argument.

///|
/// Read a file referenced by xsl:include or xsl:import.
fn load_external(uri : String) -> Result[String, String] {
  let mut outcome : Result[String, String] = Err("cannot read " + uri)
  try {
    outcome = Ok(@fs.read_file_to_string(uri))
  } catch {
    _ => ()
  }
  outcome
}

///|
fn main {
  let args = @env.args()
  if args.length() < 3 {
    println("usage: moonxslt <stylesheet.xsl> <source.xml> [output]")
    println("")
    println("  stylesheet.xsl  the XSLT 1.0 stylesheet to apply")
    println("  source.xml      the XML document to transform")
    println("  output          optional file for the result")
    return
  }
  let stylesheet_path = args[1]
  let source_path = args[2]
  try {
    let stylesheet_text = @fs.read_file_to_string(stylesheet_path)
    let source_text = @fs.read_file_to_string(source_path)
    match
      @xslt.transform_with_loader(source_text, stylesheet_text, load_external) {
      Ok(result) =>
        if args.length() >= 4 {
          @fs.write_string_to_file(args[3], result)
          println("written " + args[3])
        } else {
          println(result)
        }
      Err(message) => println("error: " + message)
    }
  } catch {
    _ => println("error: cannot read the input files")
  }
}
