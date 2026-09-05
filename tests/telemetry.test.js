const assert = require("node:assert")
const loadModule = require("./load-module")
const Telemetry = loadModule("logic/Telemetry.js")
const Format = loadModule("ui/Format.js")


// ---------------------------------------------------------------- sensors
const SENSORS = `cpu_temp=63000
cpu_total=10000
cpu_idle=8000
fan_cpu=3000
fan_gpu=3100
bat_pct=99
bat_status=Charging
bat_power=8627000
gpu_temp_milli=51000
gpu_power_uw=6660000
gpu_util=15
`
const s = Telemetry.parseSensors(SENSORS)
assert.equal(s.cpuTemp, 63)      // millidegrees -> C
assert.equal(s.cpuTotal, 10000)
assert.equal(s.cpuIdle, 8000)
assert.equal(s.fanCpu, 3000)
assert.equal(s.gpuTemp, 51)
assert.ok(Math.abs(s.gpuPower - 6.66) < 0.001)
assert.equal(s.batPct, 99)
assert.equal(s.batStatus, "Charging")
assert.ok(Math.abs(s.batPower - 8.627) < 0.001)  // microwatts -> W

// Missing hardware reports nothing rather than a misleading zero.
const empty = Telemetry.parseSensors("")
assert.equal(empty.cpuTemp, -1)
assert.equal(empty.gpuTemp, -1)
assert.equal(Format.fmtTemp(-1), "—")
assert.equal(Format.fmtRpm(0), "off")
assert.equal(Telemetry.cpuUtilization(10000, 8000, 11000, 8750), 25)
assert.equal(Telemetry.cpuUtilization(-1, -1, 11000, 8750), -1)
assert.equal(Telemetry.cpuUtilization(undefined, undefined, 11000, 8750), -1)
console.log("ok - telemetry checks passed")
