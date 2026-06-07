///|
/// Errors returned by `auto_launch` operations.
///
/// The error model is intentionally small and stable:
///
/// - validation errors describe incorrect input supplied by the caller
/// - discovery errors describe missing runtime information such as the current
///   executable path or home directory
/// - `NativeFailure` reports a backend-specific failure message produced by the
///   underlying platform API
///
/// This enum derives `Eq` and `Debug`, and implements `Show` for user-facing
/// diagnostics.
pub enum AutoLaunchError {
  EmptyName
  EmptyExecutablePath
  EmptyBackgroundArgument
  ExecutablePathUnavailable
  HomeDirectoryUnavailable
  RelativeExecutablePath(String)
  UnsupportedPlatform(Platform)
  NativeFailure(action~ : String, message~ : String)
} derive(Eq, Debug)

///|
pub impl Show for AutoLaunchError with fn to_string(self) {
  match self {
    EmptyName => "EmptyName"
    EmptyExecutablePath => "EmptyExecutablePath"
    EmptyBackgroundArgument => "EmptyBackgroundArgument"
    ExecutablePathUnavailable => "ExecutablePathUnavailable"
    HomeDirectoryUnavailable => "HomeDirectoryUnavailable"
    RelativeExecutablePath(path) => "RelativeExecutablePath(\{path})"
    UnsupportedPlatform(platform) => "UnsupportedPlatform(\{platform})"
    NativeFailure(action~, message~) =>
      "NativeFailure(action=\{action}, message=\{message})"
  }
}
