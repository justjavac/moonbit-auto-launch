///|
/// Disables the shared example auto-launch entry for the current user.
fn main {
  match @support.new_example_launcher() {
    Ok(launcher) =>
      match launcher.disable() {
        Ok(_) => println("Auto-launch disabled")
        Err(error) => println("Disable failed: \{error}")
      }
    Err(error) => println("Launcher creation failed: \{error}")
  }
}
