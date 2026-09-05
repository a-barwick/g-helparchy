# Architecture

The plugin uses QML views, one observable controller, and pure JavaScript feature
modules. Dependencies flow from the views into the controller and feature logic;
the JavaScript modules never import QML or execute processes.

```text
Panel.qml                       Bar, popup lifecycle, tab selection and IPC
AsusController.qml              Live state, timers, processes and action queues
ui/
  MainTab.qml                   Sensors, efficiency suggestion, core controls
  RgbTab.qml                    Keyboard lighting controls
  FanTab.qml                    Fan profile selection and curve controls
  AdvancedTab.qml               Firmware power limits
  SensorTile.qml                Reusable sensor readout
  FanCurveEditor.qml            Reusable curve editor
  Format.js                     Temperature, fan-speed and power display helpers
logic/
  Aura.js                       Effects, lighting commands, colours and LED parsing
  Platform.js                   Capabilities, profiles, battery limit, Armoury data
  FanCurves.js                  Fan data parsing, serialization and point editing
  Telemetry.js                  Passive sensor probe and CPU counter deltas
  Efficiency.js                 Pure efficiency suggestion state transitions
  Gpu.js                        GPU modes, probes, transition planning and safety
  Display.js                    Monitor parsing and refresh-rate command building
  Numbers.js                    Shared bounds and index helpers
```

## Ownership

Each tab takes a typed `AsusController` and a bar appearance object. Views bind
to state and call named actions such as `setEffectChannel`, `commitFanCurve`, or
`switchToEfficiency`. Process IDs and write queues remain inside the controller.
The plugin entry point retains the host's popup controller and IPC contract.

`AsusController.qml` owns the two existing polling timers and all `Process`
objects. Extracting the tabs does not create independent pollers. Sensors retain
the two-second open / twenty-second closed cadence; the heavier refresh remains
limited to the open panel. Startup probes and timers can be disabled with
`active: false` for tests and previews.

JavaScript modules contain catalogs, parsers, command builders and policy. QML
imports them as library namespaces. Their shell probes are strings returned to
the controller, which executes them. Telemetry stays separate from firmware
configuration; GPU current values remain separate from queued intent.

The efficiency module receives a snapshot, the previous timer state and a
timestamp, and returns the next state. It has no dependency on the UI or on a
particular process API. The controller applies the resulting suggestion and
coordinates the preset action with the existing GPU confirmation flow.

## Tests

- `node test-model.js` runs the feature tests in `tests/*.test.js`. The loader
  gives each module an isolated namespace and resolves explicit QML imports,
  catching dependencies that a single shared VM would conceal.
- `node test-panel.js` exercises the real controller methods against fake
  processes, including serialized firmware writes and partial efficiency failure.
- `node test-ui.js` constructs the real controller and all four tab components
  against packaged Omarchy UI types with startup probes and timers disabled. It
  checks reactive state with dark and light foreground/background pairs. With a
  Wayland session available, it also constructs the plugin entry point while
  keeping its popup closed. Set `OMARCHY_SHELL_PATH` for an alternative shell tree.
- `omarchy plugin validate .` validates the plugin package manifest.

Add feature rules to the relevant logic module, put execution and asynchronous
state changes in the controller, and keep layout changes in the corresponding
tab or reusable view component.
