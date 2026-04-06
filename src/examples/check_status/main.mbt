///|
/// Prints the current platform and whether the shared example launcher is enabled.
fn main {
  let platform = @auto_launch.current_platform()
  println("Platform: \{platform}")
  println("Supported: \{@auto_launch.is_supported()}")

  let launcher = @support.new_example_launcher()

  match launcher {
    Ok(value) =>
      match value.is_enabled() {
        Ok(enabled) => println("Enabled: \{enabled}")
        Err(error) => println("State check failed: \{error}")
      }
    Err(error) => println("Launcher creation failed: \{error}")
  }
}
