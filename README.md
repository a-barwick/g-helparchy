# g-helparchy

ASUS laptop controls for the [Omarchy](https://omarchy.org) bar, built on
[asusctl](https://asus-linux.org/).

## Install

Requires Omarchy Quattro and asusctl. Follow the
[ASUS Linux Arch setup guide](https://asus-linux.org/guides/arch-guide/)
first if asusctl is not already working.

Disable any other ASUS control widget, then install:

```bash
omarchy plugin add https://github.com/a-barwick/g-helparchy.git --enable
```

| Main (Last Horizon) | RGB (Catppuccin Latte) |
|---|---|
| ![Main tab](docs/screenshots/main.png) | ![RGB tab](docs/screenshots/rgb.png) |

| Fan (Tokyo Night) | Advanced (Flexoki Light) |
|---|---|
| ![Fan tab](docs/screenshots/fan.png) | ![Advanced tab](docs/screenshots/advanced.png) |

## G-Helper features

- Performance profiles
- GPU modes
- Display refresh rate and panel overdrive
- Keyboard lighting
- Custom fan curves
- Battery charge limits
- CPU and GPU power limits
- Live temperatures, fan speeds, and battery status

Controls are shown based on what your laptop supports.

## Enhanced for Omarchy

- GPU labels that match the actual ASUS modes
- Current and queued GPU modes shown separately
- Display GPU and dGPU status
- Warnings when an app is using the dGPU
- GPU checks that leave a sleeping dGPU asleep
- Better power limit defaults and battery detection
- A gentle low-battery suggestion with one-click Quiet, 60 Hz, and Integrated
  graphics when high-power settings outlive the work that needed them

GPU mode changes apply after a shutdown or reboot.

## Development

```bash
node test-model.js
node test-panel.js
node test-ui.js
omarchy plugin validate .
```

The UI smoke test requires Quickshell and Omarchy's shell components. It renders
the tabs offscreen and checks the entry point in a hidden Wayland pass when a
session is available. Hardware probes are disabled in the fixture.

See [Architecture](docs/architecture.md) for module ownership and test locations.

## Credits and license

Based on [moneytosms' original ASUS panel](https://github.com/moneytosms/omarchy-asus).
Released under the [MIT license](LICENSE).
