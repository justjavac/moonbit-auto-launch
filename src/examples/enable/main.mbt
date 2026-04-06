///|
/// Enables the shared example auto-launch entry with a background launch flag.
fn main {
  match
    @support.new_example_launcher(launch_in_background=true, extra_arguments=[
      "--serve",
    ]) {
    Ok(launcher) =>
      match launcher.enable() {
        Ok(_) => println("Auto-launch enabled")
        Err(error) => println("Enable failed: \{error}")
      }
    Err(error) => println("Launcher creation failed: \{error}")
  }
}
