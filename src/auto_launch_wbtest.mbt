///|
test "platform mapping and backend selection" {
  assert_eq(platform_from_code(0), Platform::Unsupported)
  assert_eq(platform_from_code(1), Platform::Windows)
  assert_eq(platform_from_code(2), Platform::Macos)
  assert_eq(platform_from_code(3), Platform::Linux)
  assert_eq(
    backend_for_platform(Platform::Windows),
    BackendKind::WindowsRegistry,
  )
  assert_eq(backend_for_platform(Platform::Macos), BackendKind::MacLaunchAgent)
  assert_eq(
    backend_for_platform(Platform::Linux),
    BackendKind::LinuxDesktopEntry,
  )
  assert_eq(
    backend_for_platform(Platform::Unsupported),
    BackendKind::UnsupportedBackend,
  )
}

///|
test "identifier sanitization is stable" {
  assert_eq(sanitize_identifier("MoonBit Auto Launch"), "moonbit-auto-launch")
  assert_eq(sanitize_identifier("  Hello__World  "), "hello__world")
  assert_eq(sanitize_identifier("%%%"), "")
  assert_eq(default_identifier("MoonBit App", None), "moonbit-app")
  assert_eq(default_identifier("MoonBit App", Some("Custom ID")), "custom-id")
  assert_eq(default_identifier("%%%", None), "auto-launch")
}

///|
test "absolute path detection covers windows and unix styles" {
  assert_true(is_absolute_path(Platform::Windows, "C:\\Windows\\notepad.exe"))
  assert_true(is_absolute_path(Platform::Windows, "C:/Windows/notepad.exe"))
  assert_true(is_absolute_path(Platform::Windows, "\\\\server\\share\\app.exe"))
  assert_false(is_absolute_path(Platform::Windows, "app.exe"))
  assert_true(is_absolute_path(Platform::Linux, "/usr/bin/app"))
  assert_true(is_absolute_path(Platform::Macos, "/Applications/App"))
  assert_false(is_absolute_path(Platform::Unsupported, "/unsupported"))
  assert_false(is_absolute_path(Platform::Linux, "./app"))
}

///|
test "program arguments include background switch when requested" {
  let visible = {
    name: "Visible App",
    app_path: "/usr/bin/app",
    identifier: "visible-app",
    launch_in_background: false,
    background_arg: "--hidden",
    extra_arguments: ["--flag"],
  }
  let hidden = {
    name: "Hidden App",
    app_path: "/usr/bin/app",
    identifier: "hidden-app",
    launch_in_background: true,
    background_arg: "--background",
    extra_arguments: ["--flag", "value"],
  }

  assert_eq(build_program_arguments(visible), ["/usr/bin/app", "--flag"])
  assert_eq(build_program_arguments(hidden), [
    "/usr/bin/app", "--background", "--flag", "value",
  ])
}

///|
test "windows quoting escapes spaces quotes and trailing backslashes" {
  assert_eq(
    windows_quote_argument("C:\\Program Files\\App\\app.exe"),
    "\"C:\\Program Files\\App\\app.exe\"",
  )
  assert_eq(windows_quote_argument("say \"hello\""), "\"say \\\"hello\\\"\"")
  assert_eq(windows_quote_argument("C:\\temp\\"), "\"C:\\temp\\\\\"")
}

///|
test "desktop quoting and xml escaping are deterministic" {
  assert_eq(
    desktop_quote_argument("/opt/My App/app \"$HOME\""),
    "\"/opt/My App/app \\\"\\$HOME\\\"\"",
  )
  assert_eq(
    xml_escape("MoonBit & <Launch> \"App\""),
    "MoonBit &amp; &lt;Launch&gt; &quot;App&quot;",
  )
}

///|
test "join paths and render linux desktop entries" {
  let config = {
    name: "MoonBit App",
    app_path: "/usr/bin/moonbit",
    identifier: "moonbit-app",
    launch_in_background: true,
    background_arg: "--hidden",
    extra_arguments: ["--profile", "work"],
  }
  assert_eq(
    linux_desktop_path("/home/moonbit", "moonbit-app"),
    "/home/moonbit/.config/autostart/moonbit-app.desktop",
  )
  assert_eq(join_unix_path("/home/moonbit/", "child"), "/home/moonbit/child")
  let contents = linux_desktop_contents(config)
  assert_true(contents.contains("Name=MoonBit App"))
  assert_true(
    contents.contains(
      "Exec=\"/usr/bin/moonbit\" \"--hidden\" \"--profile\" \"work\"",
    ),
  )

  let simple_contents = linux_desktop_contents({
    name: "Simple App",
    app_path: "/usr/bin/simple",
    identifier: "simple-app",
    launch_in_background: false,
    background_arg: "--hidden",
    extra_arguments: [],
  })
  assert_true(simple_contents.contains("Exec=\"/usr/bin/simple\""))
}

///|
test "render mac launch agents" {
  let config = {
    name: "MoonBit App",
    app_path: "/Applications/MoonBit.app/Contents/MacOS/MoonBit",
    identifier: "moonbit-app",
    launch_in_background: false,
    background_arg: "--hidden",
    extra_arguments: ["--agent"],
  }
  assert_eq(
    launch_agent_path("/Users/moonbit", "moonbit-app"),
    "/Users/moonbit/Library/LaunchAgents/moonbit-app.plist",
  )
  let contents = mac_launch_agent_contents(config)
  assert_true(contents.contains("<string>moonbit-app</string>"))
  assert_true(
    contents.contains(
      "<string>/Applications/MoonBit.app/Contents/MacOS/MoonBit</string>",
    ),
  )
  assert_true(contents.contains("<string>--agent</string>"))

  match file_entry_result(config, Platform::Macos, "/Users/moonbit") {
    Ok(entry) => {
      assert_eq(
        entry.file_path,
        "/Users/moonbit/Library/LaunchAgents/moonbit-app.plist",
      )
      assert_true(entry.contents.contains("<key>RunAtLoad</key>"))
    }
    _ => fail("expected macOS file entry")
  }
}

///|
test "entry specs cover supported and unsupported branches" {
  let windows_config = {
    name: "MoonBit App",
    app_path: "C:\\Program Files\\MoonBit\\moonbit.exe",
    identifier: "moonbit-app",
    launch_in_background: true,
    background_arg: "--hidden",
    extra_arguments: ["--trace"],
  }

  let command = windows_command(windows_config)
  assert_true(command.contains("\"C:\\Program Files\\MoonBit\\moonbit.exe\""))
  assert_true(command.contains("\"--hidden\""))
  assert_true(command.contains("\"--trace\""))

  match file_entry_result(windows_config, Platform::Unsupported, "/tmp") {
    Err(UnsupportedPlatform(Unsupported)) => ()
    _ => fail("expected UnsupportedPlatform")
  }
}

///|
test "enable disable and is_enabled cover platform dispatch" {
  let launcher = AutoLaunch::{
    config: {
      name: "MoonBit App",
      app_path: "/usr/bin/moonbit",
      identifier: "moonbit-app",
      launch_in_background: false,
      background_arg: "--hidden",
      extra_arguments: [],
    },
  }

  let mut observed_path = ""
  let mut observed_windows_name = ""
  let mut observed_windows_command = ""

  let enable_linux = enable_with(
    launcher,
    Platform::Linux,
    fn() { Ok("/home/moonbit") },
    fn(name, _command) {
      observed_windows_name = name
      Ok(())
    },
    fn(path, _contents) {
      observed_path = path
      Ok(())
    },
  )
  assert_eq(enable_linux, Ok(()))
  assert_eq(
    observed_path, "/home/moonbit/.config/autostart/moonbit-app.desktop",
  )
  assert_eq(observed_windows_name, "")

  let disable_linux = disable_with(
    launcher,
    Platform::Linux,
    fn() { Ok("/home/moonbit") },
    fn(name) {
      observed_windows_name = name
      Ok(())
    },
    fn(path) {
      observed_path = path
      Ok(())
    },
  )
  assert_eq(disable_linux, Ok(()))
  assert_eq(
    observed_path, "/home/moonbit/.config/autostart/moonbit-app.desktop",
  )

  let enabled_windows = is_enabled_with(
    launcher,
    Platform::Windows,
    fn() { Ok("/ignored") },
    fn(name) {
      observed_windows_name = name
      Ok(true)
    },
    fn(_path) { Ok(false) },
  )
  assert_eq(enabled_windows, Ok(true))
  assert_eq(observed_windows_name, "moonbit-app")

  let enable_windows = enable_with(
    launcher,
    Platform::Windows,
    fn() { Ok("/ignored") },
    fn(name, command) {
      observed_windows_name = name
      observed_windows_command = command
      Ok(())
    },
    fn(_path, _contents) { Ok(()) },
  )
  assert_eq(enable_windows, Ok(()))
  assert_eq(observed_windows_name, "moonbit-app")
  assert_true(observed_windows_command.contains("/usr/bin/moonbit"))

  let disable_windows = disable_with(
    launcher,
    Platform::Windows,
    fn() { Ok("/ignored") },
    fn(name) {
      observed_windows_name = name
      Ok(())
    },
    fn(_path) { Ok(()) },
  )
  assert_eq(disable_windows, Ok(()))
  assert_eq(observed_windows_name, "moonbit-app")

  let disable_macos = disable_with(
    launcher,
    Platform::Macos,
    fn() { Ok("/Users/moonbit") },
    fn(_name) { Ok(()) },
    fn(path) {
      observed_path = path
      Ok(())
    },
  )
  assert_eq(disable_macos, Ok(()))
  assert_eq(
    observed_path, "/Users/moonbit/Library/LaunchAgents/moonbit-app.plist",
  )

  let enable_macos = enable_with(
    launcher,
    Platform::Macos,
    fn() { Ok("/Users/moonbit") },
    fn(_name, _command) { Ok(()) },
    fn(path, _contents) {
      observed_path = path
      Ok(())
    },
  )
  assert_eq(enable_macos, Ok(()))
  assert_eq(
    observed_path, "/Users/moonbit/Library/LaunchAgents/moonbit-app.plist",
  )

  match
    enable_with(
      launcher,
      Platform::Unsupported,
      fn() { Ok("/ignored") },
      fn(_name, _command) { Ok(()) },
      fn(_path, _contents) { Ok(()) },
    ) {
    Err(UnsupportedPlatform(Unsupported)) => ()
    _ => fail("expected unsupported enable result")
  }

  match
    disable_with(
      launcher,
      Platform::Macos,
      fn() { Err(HomeDirectoryUnavailable) },
      fn(_name) { Ok(()) },
      fn(_path) { Ok(()) },
    ) {
    Err(HomeDirectoryUnavailable) => ()
    _ => fail("expected home directory failure")
  }

  match
    is_enabled_with(
      launcher,
      Platform::Linux,
      fn() { Err(HomeDirectoryUnavailable) },
      fn(_name) { Ok(false) },
      fn(_path) { Ok(false) },
    ) {
    Err(HomeDirectoryUnavailable) => ()
    _ => fail("expected home directory failure")
  }

  let enabled_linux = is_enabled_with(
    launcher,
    Platform::Linux,
    fn() { Ok("/home/moonbit") },
    fn(_name) { Ok(false) },
    fn(path) {
      observed_path = path
      Ok(true)
    },
  )
  assert_eq(enabled_linux, Ok(true))
  assert_eq(
    observed_path, "/home/moonbit/.config/autostart/moonbit-app.desktop",
  )

  let enabled_macos = is_enabled_with(
    launcher,
    Platform::Macos,
    fn() { Ok("/Users/moonbit") },
    fn(_name) { Ok(false) },
    fn(path) {
      observed_path = path
      Ok(true)
    },
  )
  assert_eq(enabled_macos, Ok(true))
  assert_eq(
    observed_path, "/Users/moonbit/Library/LaunchAgents/moonbit-app.plist",
  )

  match
    disable_with(
      launcher,
      Platform::Unsupported,
      fn() { Ok("/ignored") },
      fn(_name) { Ok(()) },
      fn(_path) { Ok(()) },
    ) {
    Err(UnsupportedPlatform(Unsupported)) => ()
    _ => fail("expected unsupported disable result")
  }

  match
    is_enabled_with(
      launcher,
      Platform::Unsupported,
      fn() { Ok("/ignored") },
      fn(_name) { Ok(false) },
      fn(_path) { Ok(false) },
    ) {
    Err(UnsupportedPlatform(Unsupported)) => ()
    _ => fail("expected unsupported is_enabled result")
  }
}

///|
test "new covers additional validation branches" {
  guard is_supported() else { return }

  match new("MoonBit", path="", launch_in_background=false) {
    Err(EmptyExecutablePath) => ()
    _ => fail("expected EmptyExecutablePath")
  }

  match
    new(
      "MoonBit",
      path=match current_platform() {
        Windows => "C:\\Windows\\System32\\notepad.exe"
        Macos => "/usr/bin/true"
        Linux => "/bin/true"
        Unsupported => "/unsupported"
      },
      launch_in_background=true,
      background_arg="",
    ) {
    Err(EmptyBackgroundArgument) => ()
    _ => fail("expected EmptyBackgroundArgument")
  }

  match new("MoonBit Current Executable") {
    Ok(launcher) => assert_true(!launcher.path().is_empty())
    Err(error) =>
      fail("expected current executable path to be detected: \{error}")
  }
}

///|
test "new_with covers unsupported and executable path failures" {
  match
    new_with(
      Platform::Unsupported,
      "MoonBit",
      None,
      false,
      "--hidden",
      [],
      None,
      get_current_executable_path=fn() { Ok("/bin/true") },
    ) {
    Err(UnsupportedPlatform(Unsupported)) => ()
    _ => fail("expected UnsupportedPlatform")
  }

  match
    new_with(Platform::Linux, "MoonBit", None, false, "--hidden", [], None, get_current_executable_path=fn() {
      Err(ExecutablePathUnavailable)
    }) {
    Err(ExecutablePathUnavailable) => ()
    _ => fail("expected ExecutablePathUnavailable")
  }
}

///|
fn temp_file_path() -> String {
  match current_platform() {
    Windows => "C:\\Users\\Public\\moonbit-auto-launch-ffi-test.txt"
    Macos => "/tmp/moonbit-auto-launch-ffi-test.txt"
    Linux => "/tmp/moonbit-auto-launch-ffi-test.txt"
    Unsupported => "/tmp/moonbit-auto-launch-ffi-test.txt"
  }
}

///|
fn invalid_remove_path() -> String {
  match current_platform() {
    Windows => "C:\\Windows"
    Macos => "/tmp"
    Linux => "/tmp"
    Unsupported => "/tmp"
  }
}

///|
test "ffi helpers cover success paths" {
  match current_executable_path_result() {
    Ok(path) => assert_true(!path.is_empty())
    Err(error) => fail("expected executable path: \{error}")
  }

  match home_directory_result() {
    Ok(path) => assert_true(!path.is_empty())
    Err(error) => fail("expected home directory: \{error}")
  }

  let file_path = temp_file_path()
  assert_eq(remove_file_result(file_path), Ok(()))
  assert_eq(file_exists_result(file_path), Ok(false))
  assert_eq(write_text_file_result(file_path, "MoonBit"), Ok(()))
  assert_eq(file_exists_result(file_path), Ok(true))
  assert_eq(remove_file_result(file_path), Ok(()))
  assert_eq(file_exists_result(file_path), Ok(false))
}

///|
test "ffi helpers cover fallback error messages" {
  assert_eq(decode_optional_text(@utf8.encode("")), None)
  assert_eq(decode_optional_text(@utf8.encode("MoonBit")), Some("MoonBit"))
  assert_eq(decode_error_message(@utf8.encode(""), "fallback"), "fallback")
  assert_eq(
    decode_error_message(@utf8.encode("native error"), "fallback"),
    "native error",
  )
  assert_eq(last_error_message_or("fallback"), "fallback")
  match native_failure("probe", "fallback") {
    NativeFailure(action="probe", message="fallback") => ()
    _ => fail("expected NativeFailure")
  }

  match write_text_file_result("", "MoonBit") {
    Err(NativeFailure(action="write file", ..)) => ()
    _ => fail("expected write file failure")
  }

  match remove_file_result("") {
    Ok(_) =>
      match remove_file_result(invalid_remove_path()) {
        Err(NativeFailure(action="remove file", ..)) => ()
        _ => fail("expected remove file failure")
      }
    Err(NativeFailure(action="remove file", ..)) => ()
    _ => fail("expected remove file failure")
  }

  match file_exists_result("") {
    Err(NativeFailure(action="file exists", ..)) => ()
    _ => fail("expected file exists failure")
  }
}

///|
test "pure ffi result helpers cover success and error mappings" {
  assert_eq(
    optional_path_result(Some("/bin/true"), ExecutablePathUnavailable),
    Ok("/bin/true"),
  )
  match optional_path_result(None, HomeDirectoryUnavailable) {
    Err(HomeDirectoryUnavailable) => ()
    _ => fail("expected HomeDirectoryUnavailable")
  }

  assert_eq(unit_result_from_status(0, "action", "fallback"), Ok(()))
  match unit_result_from_status(1, "action", "fallback") {
    Err(NativeFailure(action="action", ..)) => ()
    _ => fail("expected NativeFailure")
  }

  assert_eq(bool_result_from_status(0, "action", "fallback"), Ok(false))
  assert_eq(bool_result_from_status(1, "action", "fallback"), Ok(true))
  match bool_result_from_status(2, "action", "fallback") {
    Err(NativeFailure(action="action", ..)) => ()
    _ => fail("expected NativeFailure")
  }
}

///|
test "resolve_file_entry forwards home lookup failures" {
  let launcher = AutoLaunch::{
    config: {
      name: "MoonBit App",
      app_path: "/usr/bin/moonbit",
      identifier: "moonbit-app",
      launch_in_background: false,
      background_arg: "--hidden",
      extra_arguments: [],
    },
  }

  match
    resolve_file_entry(launcher, Platform::Linux, fn() {
      Err(HomeDirectoryUnavailable)
    }) {
    Err(HomeDirectoryUnavailable) => ()
    _ => fail("expected HomeDirectoryUnavailable")
  }

  match
    resolve_file_entry(launcher, Platform::Macos, fn() { Ok("/Users/moonbit") }) {
    Ok(entry) =>
      assert_eq(
        entry.file_path,
        "/Users/moonbit/Library/LaunchAgents/moonbit-app.plist",
      )
    _ => fail("expected macOS file entry")
  }

  match
    resolve_file_entry(launcher, Platform::Unsupported, fn() { Ok("/tmp") }) {
    Err(UnsupportedPlatform(Unsupported)) => ()
    _ => fail("expected UnsupportedPlatform")
  }

  match
    resolve_file_entry(launcher, Platform::Linux, fn() { Ok("/home/moonbit") }) {
    Ok(entry) =>
      assert_eq(
        entry.file_path,
        "/home/moonbit/.config/autostart/moonbit-app.desktop",
      )
    _ => fail("expected Linux file entry")
  }
}

///|
test "windows registry ffi wrappers work on windows" {
  guard current_platform() == Platform::Windows else { return }

  let name = "moonbit-auto-launch-whitebox-registry-test"
  assert_eq(windows_delete_run_entry_result(name), Ok(()))
  assert_eq(windows_run_entry_exists_result(name), Ok(false))
  assert_eq(
    windows_set_run_entry_result(name, "\"C:\\Windows\\System32\\notepad.exe\""),
    Ok(()),
  )
  assert_eq(windows_run_entry_exists_result(name), Ok(true))
  assert_eq(windows_delete_run_entry_result(name), Ok(()))
  assert_eq(windows_run_entry_exists_result(name), Ok(false))
}
