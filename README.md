# Omarchy Framework Fan Control

A native Omarchy bar widget for Framework laptops whose Linux kernel exposes a controllable `cros_ec` hwmon fan. It shows current RPM, offers ten manual steps from 10% through 100%, and restores the firmware's automatic fan control with one toggle.

The slider is deliberately staged while Automatic mode is active. Moving it does not change the fan until Manual control is explicitly enabled. Manual 0% is not offered.

## Requirements

- Omarchy 4.x with the manifest-based Quickshell plugin API
- One hwmon device named `cros_ec` exposing `fan1_input`, `pwm1`, and `pwm1_enable`
- `sudo`, `visudo`, and `jq`
- No `ectool`, `fw-fanctrl`, or `framework_tool` dependency

Do not run another fan-control service at the same time; two controllers will race.

## Install

Install from Git once this repository is published:

```bash
omarchy plugin add https://github.com/OWNER/omarchy-framework-fan-control.git --yes
cd ~/.config/omarchy/plugins/nate.framework.fan-control
sudo ./setup install
omarchy plugin enable nate.framework.fan-control --before omarchy.power
```

The setup copies a small, root-owned helper to `/usr/local/libexec` and installs a sudoers rule for only `auto` and the ten valid manual values. The QML plugin itself stays unprivileged. The initial placement is directly left of Power; afterward it remains a normal Omarchy widget that can be dragged or moved with `omarchy bar move`.

For a local checkout already placed under `~/.config/omarchy/plugins`, run the final three commands above.

## Update

```bash
omarchy plugin update nate.framework.fan-control
cd ~/.config/omarchy/plugins/nate.framework.fan-control
sudo ./setup install
```

Rerunning setup keeps the installed helper protocol synchronized with the plugin.

## Uninstall

Restore Automatic mode and remove the privileged integration before removing the plugin:

```bash
cd ~/.config/omarchy/plugins/nate.framework.fan-control
sudo ./setup uninstall
omarchy plugin remove nate.framework.fan-control --yes
```

Setup refuses to uninstall if it cannot request Automatic control.

## Development

```bash
tests/run
```

The helper tests use a temporary fake hwmon tree. The real-hardware smoke test is opt-in, accepts a manual percentage, and uses an exit trap to request Automatic control:

```bash
tests/hardware-smoke 50
```

Plugin ID: `nate.framework.fan-control`. License: MIT.
