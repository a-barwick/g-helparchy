// Exercise the panel's actual write queue without starting QML or touching firmware.
// Run with node test-panel.js.
const assert = require("assert")
const fs = require("fs")
const path = require("path")
const vm = require("vm")
const source = fs.readFileSync(path.join(__dirname, "Panel.qml"), "utf8")
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
