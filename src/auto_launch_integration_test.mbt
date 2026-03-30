///|
fn integration_tests_enabled() -> Bool {
  match @env.get_env_var("MOONBIT_AUTO_LAUNCH_RUN_INTEGRATION_TESTS") {
    Some("1") => true
    Some("true") => true
    Some("yes") => true
    Some("on") => true
    _ => false
  }
}

///|
fn stable_test_path(platform : Platform) -> String {
  match platform {
    Platform::Windows => "C:\\Windows\\System32\\notepad.exe"
    Platform::Macos => "/usr/bin/true"
    Platform::Linux => "/bin/true"
    Platform::Unsupported => "/unsupported"
  }
}

///|
test "integration enable disable roundtrip" {
  guard integration_tests_enabled() else { return }
  guard @auto_launch.is_supported() else {
    fail("integration tests were enabled on an unsupported platform")
  }

  let platform = @auto_launch.current_platform()
  let launcher = match
    @auto_launch.new(
      "MoonBit Auto Launch Integration Test",
      path=stable_test_path(platform),
      identifier="moonbit-auto-launch-integration-test",
    ) {
    Ok(value) => value
    Err(error) => fail("failed to build launcher: \{error}")
  }

  ignore(launcher.disable())

  match launcher.is_enabled() {
    Ok(false) => ()
    Ok(true) => fail("launcher should be disabled after cleanup")
    Err(error) => fail("failed to query initial auto-launch state: \{error}")
  }

  match launcher.enable() {
    Ok(_) => ()
    Err(error) => fail("failed to enable auto-launch: \{error}")
  }

  match launcher.is_enabled() {
    Ok(true) => ()
    Ok(false) => fail("launcher should be enabled after enable()")
    Err(error) => fail("failed to query enabled auto-launch state: \{error}")
  }

  match launcher.disable() {
    Ok(_) => ()
    Err(error) => fail("failed to disable auto-launch: \{error}")
  }

  match launcher.is_enabled() {
    Ok(false) => ()
    Ok(true) => fail("launcher should be disabled after disable()")
    Err(error) => fail("failed to query disabled auto-launch state: \{error}")
  }
}
