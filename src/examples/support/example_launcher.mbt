///|
/// Returns a stable example executable path for the requested platform.
///
/// The returned value is intentionally deterministic so that all example
/// programs render the same launcher configuration in documentation, local
/// runs, and tests. Supported platforms receive a representative absolute path,
/// while `Unsupported` falls back to a placeholder path that will still fail
/// cleanly during real launcher construction.
pub fn example_app_path(platform : @auto_launch.Platform) -> String {
  match platform {
    Windows => "C:\\Program Files\\MoonBit\\moonbit.exe"
    Macos => "/Applications/MoonBit.app/Contents/MacOS/MoonBit"
    Linux => "/usr/bin/moonbit"
    Unsupported => "/unsupported"
  }
}

///|
/// Builds the shared launcher configuration used by the example binaries.
///
/// `launch_in_background` controls whether the example launcher prepends the
/// package's background argument, and `extra_arguments` are appended after that.
/// The function always uses the same application name and identifier so that
/// `enable`, `disable`, and `check_status` all operate on the same startup
/// entry across runs.
///
/// Returns `Err(AutoLaunchError)` when the current platform is unsupported or
/// when the example executable path cannot be validated by the library.
pub fn new_example_launcher(
  launch_in_background? : Bool = false,
  extra_arguments? : Array[String] = [],
) -> Result[@auto_launch.AutoLaunch, @auto_launch.AutoLaunchError] {
  let platform = @auto_launch.current_platform()
  @auto_launch.new(
    "MoonBit Auto Launch Example",
    path=example_app_path(platform),
    launch_in_background~,
    extra_arguments~,
    identifier="moonbit-auto-launch-example",
  )
}
