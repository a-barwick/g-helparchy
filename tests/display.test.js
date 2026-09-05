const assert = require("node:assert")
const loadModule = require("./load-module")
const Display = loadModule("logic/Display.js")


// ---------------------------------------------------------------- display
const MONITORS = JSON.stringify([
    { name: "HDMI-A-1", focused: true, width: 1920, height: 1080, refreshRate: 74.973, x: 0, y: 0, scale: 1.25,
      availableModes: ["1920x1080@74.97Hz", "1920x1080@60.00Hz", "1280x720@60.00Hz"] },
    { name: "eDP-1", focused: false, width: 1920, height: 1080, refreshRate: 60.004, x: -1536, y: 0, scale: 1.25,
      availableModes: ["1920x1080@60.00Hz", "1920x1080@144.00Hz"] }
])
const mon = Display.parseMonitors(MONITORS)
// The built-in panel wins even when an external monitor has focus.
assert.equal(mon.name, "eDP-1")
assert.deepEqual(mon.rates, [60, 144])
assert.equal(mon.rate, 60)
// Must be the Lua eval form: `hyprctl keyword monitor` is rejected by
// Hyprland's non-legacy (Lua) config parser. Position and scale are repeated
// because hl.monitor replaces the whole rule.
assert.deepEqual(Display.monitorCommand(mon, 144), ["hyprctl", "eval",
    'hl.monitor({ output = "eDP-1", mode = "1920x1080@144", position = "-1536x0", scale = 1.25 })'])
assert.equal(Display.parseMonitors("not json"), null)
assert.equal(Display.parseMonitors("[]"), null)

// ------------------------------------------------------------ hyprmoncfg
// Where the daemon runs, a refresh change must also be saved into its active
// profile or it reverts; where it does not, the runtime change stands alone.
const MONCFG_RUNNING = JSON.stringify({
    schema_version: 1, version: "1.15.0",
    daemon: { running: true },
    active_profile: { name: "MonLeft" }
})
assert.deepEqual(Display.parseHyprmoncfgStatus(MONCFG_RUNNING), { managed: true, profile: "MonLeft" })
assert.deepEqual(Display.parseHyprmoncfgStatus(JSON.stringify({ daemon: { running: false }, active_profile: { name: "MonLeft" } })),
    { managed: false, profile: "MonLeft" })
// A running daemon with no active profile has nothing to save into — saving
// would be `hyprmoncfg save ""`, so this must not count as managed.
assert.deepEqual(Display.parseHyprmoncfgStatus(JSON.stringify({ daemon: { running: true } })),
    { managed: false, profile: "" })
// Binary missing entirely: the status call produces nothing parseable.
assert.deepEqual(Display.parseHyprmoncfgStatus(""), { managed: false, profile: "" })
assert.deepEqual(Display.parseHyprmoncfgStatus("command not found"), { managed: false, profile: "" })
console.log("ok - display checks passed")
