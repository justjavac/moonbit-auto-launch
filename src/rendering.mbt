///|
fn launch_agent_path(home_directory : String, identifier : String) -> String {
  join_unix_path(
    join_unix_path(home_directory, "Library"),
    "LaunchAgents/" + identifier + ".plist",
  )
}

///|
fn linux_desktop_path(home_directory : String, identifier : String) -> String {
  join_unix_path(
    join_unix_path(join_unix_path(home_directory, ".config"), "autostart"),
    identifier + ".desktop",
  )
}

///|
fn windows_command(config : AutoLaunchConfig) -> String {
  let quoted : Array[String] = []
  for argument in build_program_arguments(config) {
    quoted.push(windows_quote_argument(argument))
  }
  quoted.join(" ")
}

///|
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
