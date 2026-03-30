///|
/// Errors returned by `auto_launch` operations.
pub enum AutoLaunchError {
  EmptyName
  EmptyExecutablePath
  EmptyBackgroundArgument
  ExecutablePathUnavailable
  HomeDirectoryUnavailable
  RelativeExecutablePath(String)
  UnsupportedPlatform(Platform)
  NativeFailure(action~ : String, message~ : String)
} derive(Eq, Show)
