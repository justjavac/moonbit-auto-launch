///|
struct AutoLaunchConfig {
  name : String
  app_path : String
  identifier : String
  launch_in_background : Bool
  background_arg : String
  extra_arguments : Array[String]
}

///|
struct FileEntry {
  file_path : String
  contents : String
} derive(Eq, Show)

///|
/// Stores the normalized auto-launch configuration for one application.
pub struct AutoLaunch {
  config : AutoLaunchConfig
}

///|
fn trim_text(text : String) -> String {
  text.trim().to_string()
}

///|
fn is_ascii_lower_letter(ch : Char) -> Bool {
  ch >= 'a' && ch <= 'z'
}

///|
fn is_ascii_upper_letter(ch : Char) -> Bool {
  ch >= 'A' && ch <= 'Z'
}

///|
fn is_ascii_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_ascii_letter(ch : Char) -> Bool {
  is_ascii_lower_letter(ch) || is_ascii_upper_letter(ch)
}

///|
fn is_identifier_punctuation(ch : Char) -> Bool {
  ch == '-' || ch == '_' || ch == '.'
}

///|
fn sanitize_identifier(text : String) -> String {
  let lowered = text.to_lower()
  let builder = StringBuilder::new()
  let mut last_was_separator = true
  for ch in lowered {
    if is_ascii_letter(ch) ||
      is_ascii_digit(ch) ||
      is_identifier_punctuation(ch) {
      builder.write_char(ch)
      last_was_separator = false
    } else if !last_was_separator {
      builder.write_char('-')
      last_was_separator = true
    }
  }
  builder.to_string().trim(chars="-._").to_string()
}

///|
fn default_identifier(name : String, explicit_identifier : String?) -> String {
  let source = match explicit_identifier {
    Some(identifier) => trim_text(identifier)
    None => trim_text(name)
  }
  let sanitized = sanitize_identifier(source)
  if sanitized.is_empty() {
    "auto-launch"
  } else {
    sanitized
  }
}

///|
fn is_windows_drive_path(path : String) -> Bool {
  match (path.get_char(0), path.get_char(1), path.get_char(2)) {
    (Some(drive), Some(':'), Some('\\')) if is_ascii_letter(drive) => true
    (Some(drive), Some(':'), Some('/')) if is_ascii_letter(drive) => true
    _ => false
  }
}

///|
fn is_windows_unc_path(path : String) -> Bool {
  path.has_prefix("\\\\") || path.has_prefix("//")
}

///|
fn is_absolute_path(platform : Platform, path : String) -> Bool {
  match platform {
    Platform::Windows =>
      is_windows_drive_path(path) || is_windows_unc_path(path)
    Platform::Macos => path.has_prefix("/")
    Platform::Linux => path.has_prefix("/")
    Platform::Unsupported => false
  }
}

///|
fn build_program_arguments(config : AutoLaunchConfig) -> Array[String] {
  let arguments : Array[String] = [config.app_path]
  if config.launch_in_background {
    arguments.push(config.background_arg)
  }
  for argument in config.extra_arguments {
    arguments.push(argument)
  }
  arguments
}

///|
fn write_repeated_char(builder : StringBuilder, ch : Char, count : Int) -> Unit {
  for _ in 0..<count {
    builder.write_char(ch)
  }
}

///|
fn windows_quote_argument(argument : String) -> String {
  let builder = StringBuilder::new()
  builder.write_char('"')
  let mut backslash_count = 0
  for ch in argument {
    if ch == '\\' {
      backslash_count += 1
    } else if ch == '"' {
      write_repeated_char(builder, '\\', backslash_count * 2 + 1)
      builder.write_char('"')
      backslash_count = 0
    } else {
      write_repeated_char(builder, '\\', backslash_count)
      builder.write_char(ch)
      backslash_count = 0
    }
  }
  write_repeated_char(builder, '\\', backslash_count * 2)
  builder.write_char('"')
  builder.to_string()
}

///|
fn desktop_quote_argument(argument : String) -> String {
  let escaped = argument
    .replace_all(old="\\", new="\\\\")
    .replace_all(old="\"", new="\\\"")
    .replace_all(old="$", new="\\$")
    .replace_all(old="`", new="\\`")
  "\"" + escaped + "\""
}

///|
fn xml_escape(text : String) -> String {
  text
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&apos;")
}

///|
fn join_unix_path(base : String, child : String) -> String {
  if base.has_suffix("/") {
    base + child
  } else {
    base + "/" + child
  }
}
