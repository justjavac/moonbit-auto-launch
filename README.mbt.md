# justjavac/auto_launch

[![CI](https://github.com/justjavac/moonbit-auto-launch/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/justjavac/moonbit-auto-launch/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/justjavac/moonbit-auto-launch/graph/badge.svg?branch=main)](https://codecov.io/gh/justjavac/moonbit-auto-launch)

Cross-platform auto-launch helpers for MoonBit.

This project is inspired by and references [Teamwork/node-auto-launch](https://github.com/Teamwork/node-auto-launch). The API shape, platform choices, and overall package direction in this repository were designed with that project as the main reference and source of inspiration.

## Example

```mbt check
///|
test "public api can be called" {
  ignore(@auto_launch.current_platform())
  ignore(@auto_launch.is_supported())

  let launcher = @auto_launch.new(
    "MoonBit Demo",
    path=match @auto_launch.current_platform() {
      Windows => "C:\\Program Files\\MoonBit\\moonbit.exe"
      Macos => "/Applications/MoonBit.app/Contents/MacOS/MoonBit"
      Linux => "/usr/bin/moonbit"
      Unsupported => "/unsupported"
    },
    launch_in_background=true,
    extra_arguments=["--serve"],
  )

  match launcher {
    Ok(value) => {
      ignore(value.name())
      ignore(value.path())
      ignore(value.identifier())
    }
    Err(_) => ()
  }
}
```

## Example Programs

```mbt nocheck
moon run src/examples/check_status --target native
moon run src/examples/enable --target native
moon run src/examples/disable --target native
```
