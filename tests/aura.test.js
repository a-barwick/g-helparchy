const assert = require("node:assert")
const loadModule = require("./load-module")
const Aura = loadModule("logic/Aura.js")

assert.deepEqual(Aura.supportedEffects(["Static", "Breathe"]).map(e => e.id), ["static", "breathe"])
assert.deepEqual(Aura.buildAuraCommand("static", { color: "123456", speed: "high", color2: "ffffff" }),
    ["asusctl", "aura", "effect", "static", "--colour", "123456"])
assert.deepEqual(Aura.buildAuraCommand("breathe", { color: "123456", color2: "abcdef", speed: "low" }),
    ["asusctl", "aura", "effect", "breathe", "--colour", "123456", "--colour2", "abcdef", "--speed", "low"])
assert.equal(Aura.parseLedBrightness("Current brightness: Med"), "med")
assert.equal(Aura.rgbToHex(300, -10, 127.6), "ff0080")
assert.deepEqual(Aura.hexToRgb("#abc"), { r: 170, g: 187, b: 204 })
console.log("ok - aura checks passed")
