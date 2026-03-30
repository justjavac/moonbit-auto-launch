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
      identifier="moonbit-auto-launch-example",
    ) {
    Ok(launcher) =>
      match launcher.disable() {
        Ok(_) => println("Auto-launch disabled")
        Err(error) => println("Disable failed: \{error}")
      }
    Err(error) => println("Launcher creation failed: \{error}")
  }
}
