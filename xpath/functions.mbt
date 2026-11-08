// Extended XPath 1.0 function library.
//
// The core functions that location paths and the XSLT engine depend on live in
// `eval.mbt`; this module holds the rest of the XPath 1.0 function library.

///|
/// Dispatch to the extended function library.
///
/// The full string, number and node-set function library is implemented in the
/// next milestone; unknown names are reported as errors so that a stylesheet
/// using an unimplemented function fails loudly instead of silently returning
/// an empty value.
fn call_library_function(
  name : String,
  arguments : Array[Expr],
  context : EvalContext,
) -> Value raise EvaluationError {
  let _ = arguments
  let _ = context
  raise EvaluationError::Message("unknown function " + name + "()")
}
