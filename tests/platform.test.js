const assert = require("node:assert")
const loadModule = require("./load-module")
const Aura = loadModule("logic/Aura.js")
const Platform = loadModule("logic/Platform.js")


// ---------------------------------------------------------------- armoury
const ARMOURY = `Multiple asusd interfaces devices found
charge_mode:
  current: [0,1,2]

dgpu_disable:
  current: [(0),1]

gpu_mux_mode:
  current: [(0),1]

nv_dynamic_boost:
  current: 5..[25]..25
  default: 25

nv_temp_target:
  current: 75..[87]..87
  default: 87

panel_overdrive:
  current: [(0),1]

ppt_pl1_spl:
  current: 28..[133]..135
  default: 115

ppt_pl2_sppt:
  current: 28..[135]..135
  default: 135
`

const a = Platform.parseArmoury(ARMOURY)
assert.equal(a.supported.pptPl1, true)
assert.equal(a.supported.nvTempTarget, true)
assert.equal(a.supported.panelOverdrive, true)
assert.equal(a.values.ppt_pl1_spl, 133)
assert.deepEqual(a.ranges.ppt_pl1_spl, { min: 28, max: 135 })
assert.equal(a.defaults.ppt_pl1_spl, 115)
assert.equal(a.values.gpu_mux_mode, 0)
// "Multiple asusd interfaces devices found" must not be read as an attribute.
assert.equal(a.supported["Multiple asusd interfaces devices found"], undefined)

// The current option is whichever one is parenthesised — matching only the
// first entry made every toggle read as "off" no matter its real state.
assert.equal(Platform.parseArmouryValue("[(0),1]").value, 0)
assert.equal(Platform.parseArmouryValue("[0,(1)]").value, 1)
assert.equal(Platform.parseArmouryValue("[0,1,2]"), null)

// ---------------------------------------------------------------- features
// asusctl 6.x names the charge limit ChargeControlEndThreshold; matching only
// on the word "battery" hid the limit slider on models that support it.
const INFO = `Supported Platform Properties:
[
    ChargeControlEndThreshold,
    ThrottlePolicy,
]
Supported Aura Modes:
[
    Static,
    Breathe,
]
`
const f = Platform.parseSupportedFeatures(INFO)
assert.equal(f.hasBattery, true)
assert.deepEqual(f.auraModes, ["Static", "Breathe"])
assert.equal(Aura.supportedEffects(f.auraModes).length, 2)
console.log("ok - platform checks passed")
