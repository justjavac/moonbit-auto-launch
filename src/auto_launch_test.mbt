///|
test "public api symbols are exported" {
  ignore(@auto_launch.current_platform)
  ignore(@auto_launch.is_supported)
  ignore(@auto_launch.AutoLaunch::name)
  ignore(@auto_launch.AutoLaunch::path)
  ignore(@auto_launch.AutoLaunch::identifier)
  ignore(@auto_launch.AutoLaunch::enable)
  ignore(@auto_launch.AutoLaunch::disable)
  ignore(@auto_launch.AutoLaunch::is_enabled)
}

///|
test "new validates empty names" {
  match @auto_launch.new("") {
    Err(EmptyName) => ()
    _ => fail("expected EmptyName")
  }
  match @auto_launch.new("   ") {
    Err(EmptyName) => ()
    _ => fail("expected EmptyName")
  }
}

///|
test "new validates relative explicit paths" {
  match @auto_launch.new("Auto Launch", path="relative/path") {
    Err(RelativeExecutablePath(path)) => assert_eq(path, "relative/path")
    _ => fail("expected RelativeExecutablePath")
  }
}

///|
test "new creates a launcher on supported platforms" {
  guard @auto_launch.is_supported() else { return }

  let launcher = match
    @auto_launch.new(
      "MoonBit Auto Launch",
      path=match @auto_launch.current_platform() {
        Windows => "C:\\Program Files\\MoonBit\\moonbit.exe"
        Macos => "/Applications/MoonBit.app/Contents/MacOS/MoonBit"
        Linux => "/usr/bin/moonbit"
        Unsupported => "/unsupported"
      },
      launch_in_background=true,
      extra_arguments=["--verbose"],
      identifier="moonbit-auto-launch",
    ) {
    Ok(value) => value
    Err(error) => fail("expected launcher creation to succeed: \{error}")
  }

  assert_eq(launcher.name(), "MoonBit Auto Launch")
  assert_eq(launcher.identifier(), "moonbit-auto-launch")
}

///|
test "current platform and support flag stay in sync" {
  match (@auto_launch.current_platform(), @auto_launch.is_supported()) {
    (Unsupported, false) => ()
    (Windows, true) => ()
    (Macos, true) => ()
    (Linux, true) => ()
    _ => fail("platform support detection should stay consistent")
  }
}

///|
fn public_roundtrip_test_path(platform : Platform) -> String {
  match platform {
    Windows => "C:\\Windows\\System32\\notepad.exe"
    Macos => "/usr/bin/true"
    Linux => "/bin/true"
    Unsupported => "/unsupported"
  }
}

///|
test "public methods can roundtrip a windows startup entry" {
  guard @auto_launch.current_platform() is Windows else { return }

  let launcher = match
    @auto_launch.new(
      "MoonBit Auto Launch Public Roundtrip Test",
      path=public_roundtrip_test_path(@auto_launch.current_platform()),
      identifier="moonbit-auto-launch-public-roundtrip-test",
    ) {
    Ok(value) => value
    Err(error) => fail("expected launcher creation to succeed: \{error}")
  }

  ignore(launcher.disable())

  match launcher.enable() {
    Ok(_) => ()
    Err(error) => fail("failed to enable auto-launch: \{error}")
  }

  match launcher.is_enabled() {
    Ok(true) => ()
    Ok(false) => fail("launcher should be enabled after enable()")
    Err(error) => fail("failed to query enabled state: \{error}")
  }

  match launcher.disable() {
    Ok(_) => ()
    Err(error) => fail("failed to disable auto-launch: \{error}")
  }

  match launcher.is_enabled() {
    Ok(false) => ()
    Ok(true) => fail("launcher should be disabled after disable()")
    Err(error) => fail("failed to query disabled state: \{error}")
  }
}
