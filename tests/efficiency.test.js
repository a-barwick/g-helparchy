const assert = require("node:assert")
const loadModule = require("./load-module")
const Efficiency = loadModule("logic/Efficiency.js")


// ------------------------------------------------ efficiency suggestion
assert.equal(Efficiency.isHighPowerConfiguration("ultimate", "Performance", 240, true), true)
assert.equal(Efficiency.isHighPowerConfiguration("ultimate", "Quiet", 240, false), true)
assert.equal(Efficiency.isHighPowerConfiguration("standard", "Performance", 240, true), true)
assert.equal(Efficiency.isHighPowerConfiguration("standard", "Performance", 240, false), false)
assert.equal(Efficiency.isHighPowerConfiguration("standard", "Quiet", 240, false), false)
assert.equal(Efficiency.isLightWorkload(10, 5, 8), true)
assert.equal(Efficiency.isLightWorkload(20, 5, 8), false)
assert.equal(Efficiency.isLightWorkload(10, -1, -1), true)
assert.equal(Efficiency.isLightWorkload(undefined, -1, -1), false)

const efficiencyInput = {
    enabled: true, suppressed: false, batteryPct: 25, batteryStatus: "Discharging",
    cpuUtil: 10, gpuUtil: 5, gpuPower: 8, gpuMode: "ultimate",
    profile: "Performance", refreshRate: 240, customFanCurve: true
}
let efficiency = Efficiency.nextEfficiencyState(null, efficiencyInput, 1000)
assert.equal(efficiency.suggested, false)
efficiency = Efficiency.nextEfficiencyState(efficiency, efficiencyInput, 300999)
assert.equal(efficiency.suggested, false)
efficiency = Efficiency.nextEfficiencyState(efficiency, efficiencyInput, 301000)
assert.equal(efficiency.suggested, true)
// A short spike neither clears the suggestion nor restarts its light timer.
const busyInput = Object.assign({}, efficiencyInput, { cpuUtil: 80 })
efficiency = Efficiency.nextEfficiencyState(efficiency, busyInput, 310000)
assert.equal(efficiency.suggested, true)
assert.equal(efficiency.lightSinceMs, 1000)
// Thirty seconds of real work clears it.
efficiency = Efficiency.nextEfficiencyState(efficiency, busyInput, 340000)
assert.equal(efficiency.suggested, false)
assert.equal(efficiency.lightSinceMs, 0)
// Charging, a healthy battery, opt-out, or an efficiency action suppresses it.
assert.equal(Efficiency.nextEfficiencyState(null, Object.assign({}, efficiencyInput, { batteryStatus: "Charging" }), 1000).contextActive, false)
assert.equal(Efficiency.nextEfficiencyState(null, Object.assign({}, efficiencyInput, { batteryPct: 31 }), 1000).contextActive, false)
assert.equal(Efficiency.nextEfficiencyState(null, Object.assign({}, efficiencyInput, { enabled: false }), 1000).contextActive, false)
efficiency = Efficiency.nextEfficiencyState({ lightSinceMs: 1000, busySinceMs: 0, suggested: true }, Object.assign({}, efficiencyInput, { suppressed: true }), 400000)
assert.equal(efficiency.suggested, false)
console.log("ok - efficiency checks passed")
