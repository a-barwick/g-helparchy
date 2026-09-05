// Exercise the panel's actual write queue without starting QML or touching firmware.
// Run with node test-panel.js.
const assert = require("assert")
const fs = require("fs")
const path = require("path")
const vm = require("vm")
const source = fs.readFileSync(path.join(__dirname, "Panel.qml"), "utf8")
const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, "manifest.json"), "utf8"))

// The suggestion stays in the Main tab's visual flow: sensors, calm banner,
// then the existing performance controls. It has one direct action and is
// enabled by default without exposing threshold tuning.
const sensorGridAt = source.indexOf("id: sensorGrid")
const efficiencyBannerAt = source.indexOf("id: efficiencyBanner")
const performanceModeAt = source.indexOf('text: "PERFORMANCE MODE"')
assert.ok(sensorGridAt >= 0 && sensorGridAt < efficiencyBannerAt && efficiencyBannerAt < performanceModeAt)
assert.match(source, /text: "Switch to Efficiency"/)
assert.match(source, /\["asusctl", "profile", "set", efficiencyQuietProfile\(\)\]/)
assert.match(source, /requestGpuMode\("eco"\)/)
assert.equal(manifest.barWidget.defaults.suggestEfficiency, true)
assert.equal(manifest.barWidget.schema.find(s => s.key === "suggestEfficiency").type, "boolean")

const modelContext = {}
vm.createContext(modelContext)
vm.runInContext(fs.readFileSync(path.join(__dirname, "Model.js"), "utf8"), modelContext)
const efficiencyWrites = { profile: [], display: [], gpu: [] }
const efficiencyContext = {
    Model: modelContext,
    profiles: ["Quiet", "Balanced", "Performance"], currentProfile: "Performance",
    monitor: { name: "eDP-1", width: 2560, height: 1600, x: 0, y: 0, scale: 1, rate: 240, rates: [60, 240] },
    armourySupported: { gpuMux: true, dgpuDisable: true }, hasGpuMode: true,
    gpuMode: "ultimate", currentGpuMode: "ultimate",
    efficiencyActionRunning: false, efficiencyProfilePending: false,
    efficiencyDisplayPending: false, efficiencyGpuPending: false,
    efficiencyWaitingForGpu: false, efficiencyGpuRequested: false,
    efficiencySuppressed: false, efficiencyErrors: [], efficiencyActionMessage: "",
    efficiencyMonitorState: {}, gpuActionQueue: [], armouryActionQueue: [], pendingGpuRequest: "",
    actionProc: { running: false }, efficiencyProfileProc: { running: false },
    displayProc: { running: false }, hyprmoncfgSaveProc: { running: false },
    gpuActionProc: { running: false }, armouryActionProc: { running: false },
    requestGpuMode: id => efficiencyWrites.gpu.push(id)
}
efficiencyContext.root = efficiencyContext
Object.defineProperty(efficiencyContext.efficiencyProfileProc, "command", { set: cmd => efficiencyWrites.profile.push(Array.from(cmd)) })
Object.defineProperty(efficiencyContext.displayProc, "command", { set: cmd => efficiencyWrites.display.push(Array.from(cmd)) })
vm.createContext(efficiencyContext)
for (const name of ["efficiencyQuietProfile", "efficiencyRefreshRate", "addEfficiencyError", "switchToEfficiency", "maybeContinueEfficiencyAction", "finishEfficiencyAction"]) {
    const start = source.indexOf("    function " + name + "(")
    assert.ok(start >= 0, name)
    const end = source.indexOf("\n    }", start)
    vm.runInContext(source.slice(start, end + 6), efficiencyContext)
}
efficiencyContext.switchToEfficiency()
assert.deepStrictEqual(efficiencyWrites.profile, [["asusctl", "profile", "set", "Quiet"]])
assert.equal(efficiencyWrites.display.length, 1)
assert.equal(efficiencyWrites.display[0].at(-1).includes("@60"), true)
assert.equal(efficiencyWrites.gpu.length, 0)
efficiencyContext.efficiencyProfilePending = false
efficiencyContext.efficiencyDisplayPending = false
efficiencyContext.maybeContinueEfficiencyAction()
assert.deepStrictEqual(efficiencyWrites.gpu, ["eco"])
assert.equal(efficiencyContext.efficiencyWaitingForGpu, true)
efficiencyContext.finishEfficiencyAction(true)
assert.match(efficiencyContext.efficiencyActionMessage, /after restart/)
efficiencyContext.addEfficiencyError("Quiet mode could not be applied.")
efficiencyContext.finishEfficiencyAction(false)
assert.match(efficiencyContext.efficiencyActionMessage, /partly applied/)

const writes = [], deferred = []
const context = {
    armouryActionQueue: [], armouryActionError: "", gpuActionQueue: [],
    armouryActionProc: { running: false }, gpuActionProc: { running: false },
    armouryProc: { running: false },
    armouryDefaults: { ppt_pl1_spl: 30, ppt_pl2_sppt: 60, nv_dynamic_boost: 15, nv_temp_target: 80 },
    Qt: { callLater: fn => deferred.push(fn) }
}
context.root = context
Object.defineProperty(context.armouryActionProc, "command", { set: cmd => writes.push(Array.from(cmd)) })
vm.createContext(context)
for (const name of ["setArmouryAttr", "runNextArmouryAction", "finishArmouryAction", "setPptPl1", "setPptPl2", "setNvDynBoost", "setNvTempTarget", "restorePowerDefaults"]) {
    const start = source.indexOf("    function " + name + "(")
    assert.ok(start >= 0, name)
    const end = source.indexOf("\n    }", start)
    const lineEnd = source.indexOf("\n", start)
    vm.runInContext(source.slice(start, source.slice(start, lineEnd).endsWith("}") ? lineEnd : end + 6), context)
}
function complete(code = 0) {
    context.armouryActionProc.running = false
    context.finishArmouryAction(code)
    while (deferred.length) deferred.shift()()
}
context.restorePowerDefaults()
assert.equal(writes.length, 1)
assert.equal(context.armouryActionQueue.length, 3)
complete(); complete(); complete(); complete()
assert.deepStrictEqual(writes.map(cmd => cmd.slice(3)), [
    ["ppt_pl1_spl", "30"], ["ppt_pl2_sppt", "60"],
    ["nv_dynamic_boost", "15"], ["nv_temp_target", "80"]
])
assert.equal(context.armouryProc.running, true)
// Firmware controls wait for a GPU transition, then resume without lost writes.
context.gpuActionProc.running = true
context.setPptPl1(35)
assert.equal(writes.length, 4)
context.gpuActionProc.running = false
context.runNextArmouryAction()
context.setPptPl2(65)
complete(1)
assert.match(context.armouryActionError, /exit 1/)
assert.deepStrictEqual(writes.at(-1).slice(3), ["ppt_pl2_sppt", "65"])
complete()
assert.equal(context.armouryActionQueue.length, 0)
console.log("ok - panel write queue checks passed")
