///|
/// Returns the per-user LaunchAgent plist path for `identifier`.
///
/// The package intentionally targets `~/Library/LaunchAgents` so it behaves as
/// a user-scoped auto-launch entry and does not require elevated privileges.
fn launch_agent_path(home_directory : String, identifier : String) -> String {
  join_unix_path(
    join_unix_path(home_directory, "Library"),
    "LaunchAgents/" + identifier + ".plist",
  )
}

///|
/// Returns the XDG autostart desktop-entry path for `identifier`.
///
/// This matches the common freedesktop.org convention used by desktop
/// environments such as GNOME, KDE, XFCE, and others.
fn linux_desktop_path(home_directory : String, identifier : String) -> String {
  join_unix_path(
    join_unix_path(join_unix_path(home_directory, ".config"), "autostart"),
    identifier + ".desktop",
  )
}

///|
/// Renders the command string stored in the Windows `Run` registry value.
///
/// Windows expects a single command-line string rather than a structured array,
/// so each argument is individually escaped and then joined with spaces.
fn windows_command(config : AutoLaunchConfig) -> String {
  let quoted : Array[String] = []
  for argument in build_program_arguments(config) {
    quoted.push(windows_quote_argument(argument))
  }
  quoted.join(" ")
}

///|
/// Renders a freedesktop.org desktop-entry file for Linux auto-start.
///
/// The generated file is intentionally minimal and only includes the fields
/// required for a regular background-less application launch on login.
fn linux_desktop_contents(config : AutoLaunchConfig) -> String {
  let quoted : Array[String] = []
  for argument in build_program_arguments(config) {
    quoted.push(desktop_quote_argument(argument))
  }
  let exec_line = quoted.join(" ")
  (
    $|[Desktop Entry]
    $|Type=Application
    $|Version=1.0
    $|Name=\{config.name}
    $|Comment=Launch \{config.name} automatically at login
    $|Exec=\{exec_line}
    $|Terminal=false
    $|StartupNotify=false
    $|
  )
}

///|
/// Renders the `<string>` entries for a LaunchAgent `ProgramArguments` array.
///
/// Each argument is XML-escaped independently so special characters in paths or
/// flags never break the plist structure.
fn plist_program_arguments(arguments : Array[String]) -> String {
  let builder = StringBuilder::new()
  for argument in arguments {
    builder.write_string("    <string>")
    builder.write_string(xml_escape(argument))
    builder.write_string("</string>\n")
  }
  builder.to_string()
}

///|
/// Renders a macOS LaunchAgent plist.
///
/// The generated plist uses `RunAtLoad=true`, which mirrors the behavior users
/// generally expect from an "auto-launch on login" feature.
fn mac_launch_agent_contents(config : AutoLaunchConfig) -> String {
  let arguments = build_program_arguments(config)
  let argument_items = plist_program_arguments(arguments)
  (
    $|<?xml version="1.0" encoding="UTF-8"?>
    $|<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    $|<plist version="1.0">
    $|<dict>
    $|  <key>Label</key>
    $|  <string>\{xml_escape(config.identifier)}</string>
    $|  <key>ProgramArguments</key>
    $|  <array>
    $|\{argument_items}  </array>
    $|  <key>RunAtLoad</key>
    $|  <true/>
    $|</dict>
    $|</plist>
    $|
  )
}

///|
/// Produces the file-backed entry for the requested platform.
///
/// Only macOS and Linux are handled here because Windows stores its entry in
/// the registry instead of a file.
fn file_entry_result(
  config : AutoLaunchConfig,
  platform : Platform,
  home_directory : String,
) -> Result[FileEntry, AutoLaunchError] {
  match platform {
    Platform::Macos =>
      Ok(FileEntry::{
        file_path: launch_agent_path(home_directory, config.identifier),
        contents: mac_launch_agent_contents(config),
      })
    Platform::Linux =>
      Ok(FileEntry::{
        file_path: linux_desktop_path(home_directory, config.identifier),
        contents: linux_desktop_contents(config),
      })
    _ => Err(AutoLaunchError::UnsupportedPlatform(platform))
  }
}

///|
/// Resolves the concrete file entry for a launcher, including the caller's home
/// directory lookup.
///
/// Separating this step keeps platform-specific path rendering pure and makes
/// the enable/disable/status code easy to unit test with injected functions.
fn resolve_file_entry(
  launcher : AutoLaunch,
  platform : Platform,
  get_home_directory : () -> Result[String, AutoLaunchError],
) -> Result[FileEntry, AutoLaunchError] {
  match get_home_directory() {
    Ok(home_directory) =>
      file_entry_result(launcher.config, platform, home_directory)
    Err(error) => Err(error)
  }
}

///|
/// Enables auto-launch using injected side-effect functions.
///
/// This is the behavior core behind [`AutoLaunch::enable`](../auto_launch.mbt):
/// it selects the correct backend for the platform and delegates I/O to the
/// provided callbacks so tests can exercise the branching logic without touching
/// the real system.
fn enable_with(
  launcher : AutoLaunch,
  platform : Platform,
  get_home_directory : () -> Result[String, AutoLaunchError],
  set_windows_entry : (String, String) -> Result[Unit, AutoLaunchError],
  write_file : (String, String) -> Result[Unit, AutoLaunchError],
) -> Result[Unit, AutoLaunchError] {
  match platform {
    Platform::Windows =>
      set_windows_entry(
        launcher.config.identifier,
        windows_command(launcher.config),
      )
    Platform::Macos | Platform::Linux =>
      match resolve_file_entry(launcher, platform, get_home_directory) {
        Ok(entry) => write_file(entry.file_path, entry.contents)
        Err(error) => Err(error)
      }
    Platform::Unsupported => Err(AutoLaunchError::UnsupportedPlatform(platform))
  }
}

///|
/// Disables auto-launch using injected side-effect functions.
///
/// File-backed platforms resolve the expected entry path first and then remove
/// it. Windows delegates directly to the registry callback.
fn disable_with(
  launcher : AutoLaunch,
  platform : Platform,
  get_home_directory : () -> Result[String, AutoLaunchError],
  delete_windows_entry : (String) -> Result[Unit, AutoLaunchError],
  remove_file : (String) -> Result[Unit, AutoLaunchError],
) -> Result[Unit, AutoLaunchError] {
  match platform {
    Platform::Windows => delete_windows_entry(launcher.config.identifier)
    Platform::Macos | Platform::Linux =>
      match resolve_file_entry(launcher, platform, get_home_directory) {
        Ok(entry) => remove_file(entry.file_path)
        Err(error) => Err(error)
      }
    Platform::Unsupported => Err(AutoLaunchError::UnsupportedPlatform(platform))
  }
}

///|
/// Checks whether auto-launch is currently enabled using injected lookup
/// functions.
///
/// The check is backend-specific: Windows asks for the registry value to exist,
/// while macOS and Linux ask for the rendered file path to exist.
fn is_enabled_with(
  launcher : AutoLaunch,
  platform : Platform,
  get_home_directory : () -> Result[String, AutoLaunchError],
  windows_entry_exists : (String) -> Result[Bool, AutoLaunchError],
  file_exists : (String) -> Result[Bool, AutoLaunchError],
) -> Result[Bool, AutoLaunchError] {
  match platform {
    Platform::Windows => windows_entry_exists(launcher.config.identifier)
    Platform::Macos | Platform::Linux =>
      match resolve_file_entry(launcher, platform, get_home_directory) {
        Ok(entry) => file_exists(entry.file_path)
        Err(error) => Err(error)
      }
    Platform::Unsupported => Err(AutoLaunchError::UnsupportedPlatform(platform))
  }
}
