// Error reporting for the XML parser.

///|
/// A well-formedness error with the position where it was detected.
pub(all) struct XmlErrorInfo {
  message : String
  line : Int32
  column : Int32
}

///|
/// Internal parser error carrying the source position.
pub suberror XmlError {
  Parse(String, Int32, Int32)
}
