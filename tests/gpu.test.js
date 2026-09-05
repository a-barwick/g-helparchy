const assert = require("node:assert")
const loadModule = require("./load-module")
const Telemetry = loadModule("logic/Telemetry.js")
const Gpu = loadModule("logic/Gpu.js")


// ---------------------------------------------------------------- gpu mode
// asus-linux's authoritative mapping is mux 0 = Ultimate and mux 1 =
// Optimus/Hybrid. Integrated/Integrated adds dgpu_disable=1 without moving
// the MUX away from the integrated GPU.
assert.equal(Gpu.gpuModeId(1, 0), "standard")
assert.equal(Gpu.gpuModeId(1, 1), "eco")
assert.equal(Gpu.gpuModeId(0, 0), "ultimate")
assert.equal(Gpu.gpuModeDef("eco").mux, 1)
assert.equal(Gpu.gpuModeDef("standard").mux, 1)
assert.equal(Gpu.gpuModeDef("ultimate").mux, 0)

// Hybrid <-> Integrated changes only dgpu_disable. A MUX write is introduced
// only when entering or leaving dGPU-direct, and writes are serialized in the
// same dgpu-then-mux order as upstream rog-control-center.
assert.deepEqual(Gpu.gpuModeCommands(1, 0, "eco", true, true), [
    ["asusctl", "armoury", "set", "dgpu_disable", "1"]
])
assert.deepEqual(Gpu.gpuModeCommands(1, 1, "standard", true, true), [
    ["asusctl", "armoury", "set", "dgpu_disable", "0"]
])
assert.deepEqual(Gpu.gpuModeCommands(0, 0, "eco", true, true), [
    ["asusctl", "armoury", "set", "dgpu_disable", "1"],
    ["asusctl", "armoury", "set", "gpu_mux_mode", "1"]
])
assert.deepEqual(Gpu.gpuModeCommands(1, 0, "ultimate", true, true), [
    ["asusctl", "armoury", "set", "gpu_mux_mode", "0"]
])
assert.deepEqual(Gpu.gpuModeCommands(0, 0, "standard", true, true), [
    ["asusctl", "armoury", "set", "gpu_mux_mode", "1"]
])
assert.deepEqual(Gpu.gpuModeCommands(-1, 0, "eco", false, true), [
    ["asusctl", "armoury", "set", "dgpu_disable", "1"]
])
assert.deepEqual(Gpu.gpuModeCommands(1, 0, "ultimate", false, true), [])
assert.deepEqual(Gpu.gpuModeCommands(0, 0, "eco", true, false), [])
assert.equal(Gpu.gpuModeAvailable("eco", true, false), false)
assert.equal(Gpu.gpuModeAvailable("eco", false, true), true)
assert.equal(Gpu.gpuModeAvailable("ultimate", true, false), true)
assert.equal(Gpu.gpuModeAvailable("ultimate", false, true), false)
assert.equal(Gpu.effectiveGpuValue(1, -1), 1)
assert.equal(Gpu.effectiveGpuValue(1, 0), 0)

const GPU_STATUS = `display_connector=eDP-2
display_driver=i915
dgpu_present=1
dgpu_runtime=active
gpu_mux_mode_current=1
gpu_mux_mode_queued=0
dgpu_disable_current=0
dgpu_disable_queued=-1
users_known=1
gpu_user=1403|Hyprland
gpu_user=3999|ChatGPT
`
const gs = Gpu.parseGpuStatus(GPU_STATUS)
assert.equal(gs.displayConnector, "eDP-2")
assert.equal(Gpu.displayOwnerLabel(gs.displayDriver), "Intel (i915)")
assert.equal(gs.muxCurrent, 1)
assert.equal(gs.muxQueued, 0)
assert.equal(gs.dgpuCurrent, 0)
assert.equal(gs.users.length, 2)
assert.equal(Gpu.dgpuStateLabel(gs, 0), "busy — 2 visible processes")
assert.equal(Gpu.gpuUsersText(gs.users), "Hyprland (1403), ChatGPT (3999)")
assert.equal(Gpu.gpuDisableNeedsConfirmation("eco", 0, gs), true)
assert.equal(Gpu.gpuDisableNeedsConfirmation("standard", 0, gs), false)
assert.equal(Gpu.gpuDisableNeedsConfirmation("eco", 1, gs), false)
assert.equal(Gpu.gpuDisableNeedsConfirmation("eco", 0, { usersKnown: false, users: [] }), true)
assert.equal(Gpu.dgpuStateLabel({ dgpuPresent: true, users: [], runtimeStatus: "suspended" }, 0), "runtime suspended")
assert.equal(Gpu.dgpuStateLabel({ dgpuPresent: true, users: [], runtimeStatus: "active", usersKnown: true }, 0), "awake — no visible processes")
assert.equal(Gpu.dgpuStateLabel({ dgpuPresent: true, users: [], runtimeStatus: "active", usersKnown: false }, 0), "awake — process detection unavailable")
assert.equal(Gpu.dgpuStateLabel({ dgpuPresent: true, users: [], runtimeStatus: "active" }, 1), "disabled by firmware")

// Opening the panel must not wake a suspended NVIDIA GPU.
assert.equal(Telemetry.sensorCommand().join(" ").indexOf("nvidia-smi"), -1)
assert.equal(Gpu.gpuStatusCommand().join(" ").indexOf("nvidia-smi"), -1)

// Missing supported attributes must not look like a confirmed Hybrid mode.
assert.equal(Gpu.gpuModeId(-1, -1), "unknown")
assert.equal(Gpu.gpuModeId(1, -1, true, true), "unknown")
assert.equal(Gpu.gpuModeId(-1, 0, true, true), "unknown")
assert.equal(Gpu.gpuModeId(-1, 0, false, true), "standard")
assert.equal(Gpu.gpuModeId(1, -1, true, false), "standard")
assert.equal(Gpu.gpuModeId(-1, -1, false, false), "unknown")
assert.equal(Gpu.gpuModeDef("unknown").name, "Unknown")
assert.deepEqual(Gpu.gpuModeCommands(1, 0, "unknown", true, true), [])
assert.equal(Gpu.parseGpuInteger(0), 0)
assert.equal(Gpu.parseGpuInteger("1oops"), -1)
assert.equal(Gpu.parseGpuInteger(""), -1)



// Run the process-detection shell fragment with controlled fuser responses.
// The rest of the hardware probe is excluded; no GPU device is opened.
const { execFileSync } = require("child_process")
const probe = Gpu.gpuStatusScript.slice(Gpu.gpuStatusScript.indexOf("users_known=0;"))
function processProbe(definition, nodes = "/dev/mock-gpu") {
    return Gpu.parseGpuStatus(execFileSync("sh", ["-c", definition + "; gpu_nodes='" + nodes + "'; " + probe], { encoding: "utf8" }))
}
assert.equal(processProbe('fuser() { return 1; }').usersKnown, true)
assert.equal(processProbe('fuser() { echo "Permission denied" >&2; return 1; }').usersKnown, false)
assert.equal(processProbe('fuser() { return 2; }').usersKnown, false)
assert.equal(processProbe('command() { return 1; }').usersKnown, false)
assert.equal(processProbe('fuser() { return 0; }', "").usersKnown, false)
const busy = processProbe('fuser() { echo $$; echo "/dev/mock-gpu:" >&2; return 0; }')
assert.equal(busy.usersKnown, true)
assert.equal(busy.users.length, 1)
assert.equal(Gpu.gpuDisableNeedsConfirmation("eco", 0, busy), true)
console.log("ok - GPU process probe checks passed")
console.log("ok - gpu checks passed")
