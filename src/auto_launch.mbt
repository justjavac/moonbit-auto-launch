///|
fn new_with(
  platform : Platform,
  name : String,
  path : String?,
  launch_in_background : Bool,
  background_arg : String,
  extra_arguments : Array[String],
  identifier : String?,
  get_current_executable_path~ : () -> Result[String, AutoLaunchError],
) -> Result[AutoLaunch, AutoLaunchError] {
  if backend_for_platform(platform) == BackendKind::UnsupportedBackend {
    return Err(AutoLaunchError::UnsupportedPlatform(platform))
  }

  let trimmed_name = trim_text(name)
  if trimmed_name.is_empty() {
    return Err(AutoLaunchError::EmptyName)
  }

  if launch_in_background && trim_text(background_arg).is_empty() {
    return Err(AutoLaunchError::EmptyBackgroundArgument)
  }

  let resolved_path = match path {
    Some(explicit_path) => {
      let trimmed_path = trim_text(explicit_path)
      if trimmed_path.is_empty() {
        return Err(AutoLaunchError::EmptyExecutablePath)
      }
      trimmed_path
    }
    None =>
      match get_current_executable_path() {
        Ok(executable_path) => executable_path
        Err(error) => return Err(error)
      }
  }

  if !is_absolute_path(platform, resolved_path) {
    return Err(AutoLaunchError::RelativeExecutablePath(resolved_path))
  }

  Ok(AutoLaunch::{
    config: {
      name: trimmed_name,
      app_path: resolved_path,
      identifier: default_identifier(trimmed_name, identifier),
      launch_in_background,
      background_arg,
      extra_arguments,
    },
  })
}

///|
/// Create an auto-launch configuration for the current platform.
///
/// `name` is the human-readable application name shown in generated desktop
/// entries. `path` defaults to the current executable path when omitted.
///
/// When `launch_in_background` is `true`, the package appends
/// `background_arg` before any `extra_arguments`. This mirrors the common
/// `--hidden` startup convention used by desktop applications.
///
/// `identifier` controls the stable registry value or file name used by the
/// backend. When omitted, it is derived from `name`.
pub fn new(
  name : String,
  path? : String,
  launch_in_background? : Bool = false,
  background_arg? : String = "--hidden",
  extra_arguments? : Array[String] = [],
  identifier? : String,
) -> Result[AutoLaunch, AutoLaunchError] {
  new_with(
    current_platform(),
    name,
    path,
    launch_in_background,
    background_arg,
    extra_arguments,
    identifier,
    get_current_executable_path=current_executable_path_result,
  )
}

///|
/// Returns the configured human-readable application name.
pub fn AutoLaunch::name(self : AutoLaunch) -> String {
  self.config.name
}

///|
/// Returns the resolved absolute executable path that will be launched.
pub fn AutoLaunch::path(self : AutoLaunch) -> String {
  self.config.app_path
}

///|
/// Returns the stable backend identifier used for the registry value or file
/// name.
pub fn AutoLaunch::identifier(self : AutoLaunch) -> String {
  self.config.identifier
}

///|
/// Enable auto-launch for this configuration on the current platform.
pub fn AutoLaunch::enable(self : AutoLaunch) -> Result[Unit, AutoLaunchError] {
  enable_with(
    self,
    current_platform(),
    home_directory_result,
    windows_set_run_entry_result,
    write_text_file_result,
  )
}

///|
/// Disable auto-launch for this configuration on the current platform.
pub fn AutoLaunch::disable(self : AutoLaunch) -> Result[Unit, AutoLaunchError] {
  disable_with(
    self,
    current_platform(),
    home_directory_result,
    windows_delete_run_entry_result,
    remove_file_result,
  )
}

///|
/// Check whether the auto-launch entry currently exists for this configuration.
pub fn AutoLaunch::is_enabled(
  self : AutoLaunch,
) -> Result[Bool, AutoLaunchError] {
  is_enabled_with(
    self,
    current_platform(),
    home_directory_result,
    windows_run_entry_exists_result,
    file_exists_result,
  )
}
