///|
fn main {
  match
    @auto_launch.new(
      "MoonBit Auto Launch Example",
      path=match @auto_launch.current_platform() {
        Windows => "C:\\Program Files\\MoonBit\\moonbit.exe"
        Macos => "/Applications/MoonBit.app/Contents/MacOS/MoonBit"
        Linux => "/usr/bin/moonbit"
        Unsupported => "/unsupported"
      },
      launch_in_background=true,
      extra_arguments=["--serve"],
      identifier="moonbit-auto-launch-example",
    ) {
    Ok(launcher) =>
      match launcher.enable() {
        Ok(_) => println("Auto-launch enabled")
        Err(error) => println("Enable failed: \{error}")
      }
    Err(error) => println("Launcher creation failed: \{error}")
  }
}
