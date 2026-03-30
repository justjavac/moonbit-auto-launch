///|
fn main {
  let platform = @auto_launch.current_platform()
  println("Platform: \{platform}")
  println("Supported: \{@auto_launch.is_supported()}")

  let launcher = @auto_launch.new(
    "MoonBit Auto Launch Example",
    path=match platform {
      Windows => "C:\\Program Files\\MoonBit\\moonbit.exe"
      Macos => "/Applications/MoonBit.app/Contents/MacOS/MoonBit"
      Linux => "/usr/bin/moonbit"
      Unsupported => "/unsupported"
    },
    identifier="moonbit-auto-launch-example",
  )

  match launcher {
    Ok(value) =>
      match value.is_enabled() {
        Ok(enabled) => println("Enabled: \{enabled}")
        Err(error) => println("State check failed: \{error}")
      }
    Err(error) => println("Launcher creation failed: \{error}")
  }
}
