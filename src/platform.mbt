///|
/// Enumerates the operating systems that this package can detect at runtime.
///
/// The value is derived from the active native backend rather than from
/// build-time configuration alone, so it reflects the platform that the
/// current executable is actually running on.
pub enum Platform {
  Windows
  Macos
  Linux
  Unsupported
} derive(Eq, Debug)

///|
pub impl Show for Platform with fn to_string(self) {
  match self {
    Windows => "Windows"
    Macos => "Macos"
    Linux => "Linux"
    Unsupported => "Unsupported"
  }
}

///|
/// Internal backend categories for supported startup mechanisms.
enum BackendKind {
  WindowsRegistry
  MacLaunchAgent
  LinuxDesktopEntry
  UnsupportedBackend
} derive(Eq, Debug)

///|
/// Decodes the numeric platform code returned by the native layer.
fn platform_from_code(code : Int) -> Platform {
  match code {
    1 => Windows
    2 => Macos
    3 => Linux
    _ => Unsupported
  }
}

///|
/// Returns the auto-launch backend used for `platform`.
fn backend_for_platform(platform : Platform) -> BackendKind {
  match platform {
    Windows => WindowsRegistry
    Macos => MacLaunchAgent
    Linux => LinuxDesktopEntry
    Unsupported => UnsupportedBackend
  }
}

///|
/// Detects the current runtime platform for the active native build.
///
/// This function is a lightweight probe over the native FFI layer. It is safe
/// to call repeatedly and is primarily useful for platform-specific setup,
/// conditional logging, or selecting example paths in applications and tests.
pub fn current_platform() -> Platform {
  platform_from_code(platform_code_ffi())
}

///|
/// Returns `true` when the current runtime platform has a supported auto-launch
/// backend in this package.
///
/// Supported platforms currently map to these backends:
///
/// - `Windows`: current-user `Run` registry value
/// - `Macos`: per-user LaunchAgent plist
/// - `Linux`: XDG autostart desktop entry
///
/// `Unsupported` means the package was compiled or executed in an environment
/// for which no native backend is implemented.
pub fn is_supported() -> Bool {
  backend_for_platform(current_platform()) != UnsupportedBackend
}
