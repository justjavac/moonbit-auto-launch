///|
/// Enumerates the operating systems that this package can detect at runtime.
pub enum Platform {
  Windows
  Macos
  Linux
  Unsupported
} derive(Eq, Show)

///|
enum BackendKind {
  WindowsRegistry
  MacLaunchAgent
  LinuxDesktopEntry
  UnsupportedBackend
} derive(Eq, Show)

///|
fn platform_from_code(code : Int) -> Platform {
  match code {
    1 => Platform::Windows
    2 => Platform::Macos
    3 => Platform::Linux
    _ => Platform::Unsupported
  }
}

///|
fn backend_for_platform(platform : Platform) -> BackendKind {
  match platform {
    Platform::Windows => BackendKind::WindowsRegistry
    Platform::Macos => BackendKind::MacLaunchAgent
    Platform::Linux => BackendKind::LinuxDesktopEntry
    Platform::Unsupported => BackendKind::UnsupportedBackend
  }
}

///|
/// Detects the current runtime platform for the active native build.
pub fn current_platform() -> Platform {
  platform_from_code(platform_code_ffi())
}

///|
/// Returns `true` when the current runtime platform has a supported auto-launch
/// backend in this package.
pub fn is_supported() -> Bool {
  backend_for_platform(current_platform()) != BackendKind::UnsupportedBackend
}
