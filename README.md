# omarchy-asus

ASUS laptop controls for the [Omarchy](https://omarchy.org) bar, using
[`asusctl`](https://asus-linux.org/). Includes power profiles, GPU modes,
keyboard lighting, fan curves, and firmware power limits.

Maintained by [a-barwick](https://github.com/a-barwick), based on
[moneytosms/omarchy-asus](https://github.com/moneytosms/omarchy-asus).
Thanks to moneytosms for building the original panel and sharing it.
This fork fixes GPU mode selection, shows pending firmware changes, and
avoids waking NVIDIA GPUs with sensor polling.

Used on a ROG Zephyrus G16 (GU605CW). Other models and shutdown transitions
need more testing. Bug reports should include the laptop model and asusctl
version.

The screenshots below are from upstream. The GPU section has since changed.

| Main | RGB |
|---|---|
| ![Main tab](docs/screenshots/main.png) | ![RGB tab](docs/screenshots/rgb.png) |

| Fan | Advanced |
|---|---|
| ![Fan tab](docs/screenshots/fan.png) | ![Advanced tab](docs/screenshots/advanced.png) |

## Features

- **Live sensors** — CPU temperature, both fan speeds, battery charge and charge
  rate, plus GPU telemetry when the NVIDIA driver exposes it through sysfs.
  The plugin never polls `nvidia-smi`, because polling it can wake a suspended
  dGPU. The same available readings appear in the bar icon's tooltip.
- **Main** — performance mode (Quiet/Balanced/Performance, tinted by mode),
  GPU mode (Integrated/Hybrid/dGPU direct), actual display
  ownership and dGPU runtime/process state, screen refresh rate and panel
  overdrive, battery charge limit.
- **RGB** — keyboard lighting, filtered to the aura effects your laptop
  actually reports (`asusctl info --show-supported`), not a fixed list of
  twelve, plus brightness and the awake/boot/sleep power states.
- **Fan** — a master "Custom Fan Curves" switch, a per-profile curve editor
  (curves are stored per power profile, so you pick which profile you are
  tuning), draggable curves per fan (CPU/GPU, plus Mid on laptops with a third
  fan) with the live RPM and temperature for that fan alongside, and a
  one-click reset.
- **Advanced** — firmware power limits (PL1/PL2, GPU dynamic boost, GPU temp
  target) with ranges read from the firmware and a "Defaults" button that
  replays the values `asusctl` reports as default. Each control appears only
  if `asusctl armoury list` says your laptop exposes it.
- **Bar icon** — scroll over it to cycle performance modes without opening the
  panel.

### G-Helper parity

This mirrors [G-Helper](https://github.com/seerge/g-helper)'s layout and
feature set where Linux tooling allows it. What is deliberately absent:

| G-Helper feature | Status here |
|---|---|
| Anime Matrix / Slash display | Not implemented (no such hardware to test against) |
| CPU boost toggle | Needs root writes to `intel_pstate`/`cpufreq`; `asusctl` exposes no equivalent |
| AutoTDP, FPS limiter, overlay | Windows-only mechanisms |
| Per-key / per-zone RGB | `asusctl` exposes zones only on some models; single-colour effects only for now |
| Automatic AC/battery profile switching | `asusctl` applies its own AC/battery profiles; not duplicated here |

### GPU modes

The selector follows the mappings in upstream
[`asusctl` 6.3.8](https://gitlab.com/asus-linux/asusctl/-/blob/6.3.8/rog-platform/src/platform.rs),
not the apparent truthiness of the firmware value:

| UI mode | `gpu_mux_mode` | `dgpu_disable` | Linux behavior after shutdown/reboot |
|---|---:|---:|---|
| Integrated | 1 | 1 | The integrated GPU owns the panel; the discrete GPU is disabled |
| Hybrid | 1 | 0 | The integrated GPU owns the panel; the discrete GPU is available on demand |
| dGPU direct | 0 | 0 | The discrete GPU owns the internal panel |

`asusd` queues these GPU attributes in memory and `asus-shutdown` applies them
during a normal shutdown. The UI therefore keeps three different facts
separate: current firmware values, queued values, and observed Linux state. It
finds the connected internal panel's DRM driver, reads the NVIDIA PCI runtime
status, and uses `fuser` to list visible processes holding NVIDIA or NVIDIA DRM
device nodes. It can report disabled, runtime suspended, awake, or busy
without running `nvidia-smi`.

Process detection is limited to what the current user can inspect. An empty
list does not prove that no other user or system process is using the GPU.
Missing tools, missing device nodes, and failed checks are shown as unavailable.

Moving between Hybrid and Integrated changes `dgpu_disable`; the MUX is left at
1. Selecting Integrated runs a fresh process check and refuses the first click
when NVIDIA is busy (or process detection is unavailable). Close the listed
programs and try again, or use the explicit **Disable anyway** confirmation.

Changes are only scheduled: the plugin does not shut down or restart the
laptop. **Keep current mode** replaces pending values with the currently active
firmware mode; because `asusd` has no queue-clear API, no-op values may remain
queued until shutdown. There is deliberately no automatic "restore on next
boot" action: these are persistent ASUS firmware attributes, so their effect
can carry into Windows even though the plugin never changes Windows files.

GPU selection does not touch monitor configuration or refresh rate. Use the
separate Screen control to change the refresh rate.

### Screen refresh rate

`asusctl` has no display controls, so the refresh buttons drive Hyprland
directly. The built-in `eDP-*` panel is preferred over external monitors, since
this is a laptop-screen feature.

Two details worth knowing:

- Hyprland 0.56 parses its config as Lua, and `hyprctl keyword monitor` is
  rejected against a non-legacy parser. The mode change goes through
  `hyprctl eval "hl.monitor({ ... })"` instead — the same call
  `omarchy-hyprland-monitor-scaling` uses. Position and scale are always
  repeated, because `hl.monitor` replaces the whole rule.
- If [hyprmoncfg](https://github.com/crmne/hyprmoncfg) is installed and its
  daemon is running, it owns monitor configuration and re-applies its active
  saved profile a few seconds after any runtime change — a plain `hl.monitor`
  call silently reverts. The plugin detects this (`hyprmoncfg status --json`)
  and follows the mode change with `hyprmoncfg save <active profile>` so it
  sticks and survives a reboot. The Screen header shows the profile name when
  this is in effect.

  Note that `hyprmoncfg save` snapshots the *whole* current monitor state, not
  just the refresh rate, so it also refreshes that profile's workspace-to-output
  assignments. Without the daemon, the runtime change stands on its own and
  lasts until the Hyprland config is reloaded.

## Development

```bash
node test-model.js
node test-panel.js
omarchy plugin validate .
```

The tests cover parsing, GPU mode commands, process-detection failures, and
the firmware write queue. They do not change firmware settings.

## Prerequisites

Runs in the Omarchy Quattro shell. Requires `asusctl` and its `asusd` service.
Screen controls use Hyprland's `hyprctl`; GPU status uses `busctl` from systemd.
`fuser` from `psmisc` is optional and enables the GPU process list. If you use
`hyprmoncfg`, screen changes are also saved to its active profile.

```bash
# From AUR
yay -S asusctl

# Or from the OGC Arch repo — see https://asus-linux.org for setup
sudo pacman -S asusctl

sudo systemctl enable --now asusd.service
```

## Install

If the upstream plugin is enabled, disable it first:

```bash
omarchy plugin disable io.github.moneytosms.asus
```

Install this fork:

```bash
omarchy plugin add https://github.com/a-barwick/omarchy-asus.git --enable
```

Or clone manually into `~/.config/omarchy/plugins/io.github.a-barwick.asus`
and enable it via the Omarchy plugin menu.

## Remove

```bash
omarchy plugin remove io.github.a-barwick.asus
```

Removal deletes the plugin folder and its settings block in
`~/.config/omarchy/shell.json`. It does not revert settings previously sent to
`asusctl`; persistent ASUS firmware values, including GPU mode, remain as set.

## Configuration

`~/.config/omarchy/shell.json`, under the plugin's settings:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `showBatteryLimit` | boolean | `true` | Show the battery charge limit section on Main |
| `refreshIntervalSec` | integer | `10` | Poll interval while the panel is open (5–60s) |

## Compatibility

Requires a laptop supported by `asusctl`. Controls depend on the features
reported by the laptop. This fork has been used on the ROG Zephyrus G16
(GU605CW); support for other models is not yet verified. GPU runtime and
process detection currently cover NVIDIA devices.

## Troubleshooting

```bash
# Verify the plugin is detected
omarchy plugin validate ~/.config/omarchy/plugins/io.github.a-barwick.asus

# Check asusd is running
systemctl status asusd

# Check what your model supports
asusctl info --show-supported
asusctl armoury list

# Compare live and queued GPU firmware values
busctl get-property xyz.ljones.Asusd /xyz/ljones/asus_armoury/gpu_mux_mode xyz.ljones.AsusArmoury CurrentValue
busctl get-property xyz.ljones.Asusd /xyz/ljones/asus_armoury/gpu_mux_mode xyz.ljones.AsusArmoury QueuedGpuValue
busctl get-property xyz.ljones.Asusd /xyz/ljones/asus_armoury/dgpu_disable xyz.ljones.AsusArmoury CurrentValue
busctl get-property xyz.ljones.Asusd /xyz/ljones/asus_armoury/dgpu_disable xyz.ljones.AsusArmoury QueuedGpuValue
```

## License

MIT
