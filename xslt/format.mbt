// `format-number()` and the `xsl:decimal-format` declarations it uses.

///|
/// The characters and strings that control number formatting.
pub struct DecimalFormat {
  decimal_separator : String
  grouping_separator : String
  infinity : String
  minus_sign : String
  nan : String
  percent : String
  per_mille : String
  zero_digit : Char
  digit : Char
  pattern_separator : String
}

///|
/// The default decimal format of XSLT 1.0.
pub fn DecimalFormat::default() -> DecimalFormat {
  {
    decimal_separator: ".",
    grouping_separator: ",",
    infinity: "Infinity",
    minus_sign: "-",
    nan: "NaN",
    percent: "%",
    per_mille: "‰",
    zero_digit: '0',
    digit: '#',
    pattern_separator: ";",
  }
}

///|
/// Build a decimal format from an `xsl:decimal-format` element.
pub fn decimal_format_from_element(
  doc : @xml.Document,
  element : Int32,
) -> DecimalFormat {
  let format = DecimalFormat::default()
  let value = fn(name : String) -> String? {
    doc.attribute_value(element, name)
  }
  {
    decimal_separator: match value("decimal-separator") {
      Some(text) => text
      None => format.decimal_separator
    },
    grouping_separator: match value("grouping-separator") {
      Some(text) => text
      None => format.grouping_separator
    },
    infinity: match value("infinity") {
      Some(text) => text
      None => format.infinity
    },
    minus_sign: match value("minus-sign") {
      Some(text) => text
      None => format.minus_sign
    },
    nan: match value("NaN") {
      Some(text) => text
      None => format.nan
    },
    percent: match value("percent") {
      Some(text) => text
      None => format.percent
    },
    per_mille: match value("per-mille") {
      Some(text) => text
      None => format.per_mille
    },
    zero_digit: match value("zero-digit") {
      Some(text) =>
        match text.to_array() {
          [c, ..] => c
          [] => format.zero_digit
        }
      None => format.zero_digit
    },
    digit: match value("digit") {
      Some(text) =>
        match text.to_array() {
          [c, ..] => c
          [] => format.digit
        }
      None => format.digit
    },
    pattern_separator: match value("pattern-separator") {
      Some(text) => text
      None => format.pattern_separator
    },
  }
}

///|
/// Format a number with an XSLT 1.0 picture string.
pub fn format_number(
  number : Double,
  pattern : String,
  format : DecimalFormat,
) -> String {
  if number.is_nan() {
    return format.nan
  }
  let subpatterns = split_on(pattern, format.pattern_separator)
  let positive = if subpatterns.length() > 0 { subpatterns[0] } else { "" }
  let negative = if subpatterns.length() > 1 {
    Some(subpatterns[1])
  } else {
    None
  }
  let is_negative = number < 0.0
  let subpattern = if is_negative {
    match negative {
      Some(text) => text
      None => positive
    }
  } else {
    positive
  }
  let mut multiplier = 1.0
  if subpattern.contains(format.percent) {
    multiplier = 100.0
  }
  if subpattern.contains(format.per_mille) {
    multiplier = 1000.0
  }
  let value = (if is_negative { -number } else { number }) * multiplier
  if number.is_inf() {
    if is_negative {
      return format.minus_sign + format.infinity
    }
    return format.infinity
  }
  let chars = subpattern.to_array()
  let decimal_char = format.decimal_separator.to_array()
  let grouping_char = format.grouping_separator.to_array()
  let is_decimal = fn(c : Char) -> Bool {
    decimal_char.length() > 0 && c == decimal_char[0]
  }
  let is_grouping = fn(c : Char) -> Bool {
    grouping_char.length() > 0 && c == grouping_char[0]
  }
  let is_digit = fn(c : Char) -> Bool {
    c == format.zero_digit || c == format.digit
  }
  let mut first_digit = -1
  let mut last_digit = -1
  for index in 0..<chars.length() {
    if is_digit(chars[index]) {
      if first_digit < 0 {
        first_digit = index
      }
      last_digit = index
    } else if is_decimal(chars[index]) || is_grouping(chars[index]) {
      if first_digit >= 0 {
        last_digit = index
      }
    }
  }
  if first_digit < 0 {
    return subpattern
  }
  let prefix = String::from_array(chars[0:first_digit])
  let suffix = String::from_array(chars[last_digit + 1:])
  let mantissa = chars[first_digit:last_digit + 1]
  let mut decimal_position = -1
  for index in 0..<mantissa.length() {
    if is_decimal(mantissa[index]) {
      decimal_position = index
      break
    }
  }
  let integer_end = if decimal_position >= 0 {
    decimal_position
  } else {
    mantissa.length()
  }
  let mut min_integer_digits = 0
  for index in 0..<integer_end {
    if mantissa[index] == format.zero_digit {
      min_integer_digits = min_integer_digits + 1
    }
  }
  let mut grouping_size = 0
  for index in 0..<integer_end {
    if is_grouping(mantissa[index]) {
      grouping_size = integer_end - index - 1
    }
  }
  let mut max_fraction_digits = 0
  let mut min_fraction_digits = 0
  if decimal_position >= 0 {
    for index in (decimal_position + 1)..<mantissa.length() {
      if is_digit(mantissa[index]) {
        max_fraction_digits = max_fraction_digits + 1
        if mantissa[index] == format.zero_digit {
          min_fraction_digits = min_fraction_digits + 1
        }
      }
    }
  }
  let scale = power_of_ten(max_fraction_digits)
  let scaled = (value * scale.to_double() + 0.5).floor().to_int()
  let integer_part = scaled / scale
  let fraction_part = scaled % scale
  let mut integer_text = integer_part.to_string()
  while integer_text.length() < min_integer_digits {
    integer_text = "0" + integer_text
  }
  if grouping_size > 0 {
    integer_text = group_digits(
      integer_text,
      grouping_size,
      format.grouping_separator,
    )
  }
  let mut fraction_text = fraction_part.to_string()
  while fraction_text.length() < max_fraction_digits {
    fraction_text = "0" + fraction_text
  }
  while fraction_text.length() > min_fraction_digits &&
        fraction_text.has_suffix("0") {
    fraction_text = fraction_text[0:fraction_text.length() - 1].to_owned()
  }
  let sb = StringBuilder::StringBuilder()
  if is_negative && negative is None {
    sb.write_string(format.minus_sign)
  }
  sb.write_string(prefix)
  sb.write_string(integer_text)
  if fraction_text != "" {
    sb.write_string(format.decimal_separator)
    sb.write_string(fraction_text)
  }
  sb.write_string(suffix)
  sb.to_string()
}

///|
fn power_of_ten(exponent : Int32) -> Int32 {
  let mut result = 1
  for _ in 0..<exponent {
    result = result * 10
  }
  result
}

///|
fn group_digits(text : String, size : Int32, separator : String) -> String {
  if size <= 0 || text.length() <= size {
    return text
  }
  let sb = StringBuilder::StringBuilder()
  let chars = text.to_array()
  let length = chars.length()
  for index in 0..<length {
    if index > 0 && (length - index) % size == 0 {
      sb.write_string(separator)
    }
    sb.write_char(chars[index])
  }
  sb.to_string()
}

///|
fn split_on(text : String, separator : String) -> Array[String] {
  let parts : Array[String] = []
  if separator == "" {
    parts.push(text)
    return parts
  }
  let chars = text.to_array()
  let separator_chars = separator.to_array()
  let sb = StringBuilder::StringBuilder()
  let mut index = 0
  while index < chars.length() {
    let mut matches = index + separator_chars.length() <= chars.length()
    if matches {
      for offset in 0..<separator_chars.length() {
        if chars[index + offset] != separator_chars[offset] {
          matches = false
        }
      }
    }
    if matches {
      parts.push(sb.to_string())
      sb.reset()
      index = index + separator_chars.length()
    } else {
      sb.write_char(chars[index])
      index = index + 1
    }
  }
  parts.push(sb.to_string())
  parts
}
