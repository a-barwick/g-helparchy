.pragma library

// ============================================================
// Effect definitions
// ============================================================
// `auraName` matches the strings asusctl reports under "Supported Aura
// Modes:" (from `asusctl info --show-supported`) — used to hide effects the
// current hardware doesn't actually support, instead of listing all twelve
// regardless of model.
var effects = [
    { id: "static",        name: "Static",        auraName: "Static",       icon: "\u{F05A8}", params: ["color"],
      tip: "One steady colour across the keyboard." },
    { id: "breathe",       name: "Breathe",       auraName: "Breathe",      icon: "\u{F01C8}", params: ["color", "color2", "speed"],
      tip: "Fades slowly between two colours." },
    { id: "pulse",         name: "Pulse",         auraName: "Pulse",        icon: "\u{F04DA}", params: ["color"],
      tip: "Sharp on/off throb in one colour." },
    { id: "rainbow-cycle", name: "Rainbow Cycle", auraName: "RainbowCycle", icon: "\u{F0764}", params: ["speed"],
      tip: "Whole keyboard shifts through the spectrum together." },
    { id: "rainbow-wave",  name: "Rainbow Wave",  auraName: "RainbowWave",  icon: "\u{F053E}", params: ["speed", "direction"],
      tip: "Rainbow sweeps across the keys in one direction." },
    { id: "stars",         name: "Stars",         auraName: "Stars",        icon: "\u{F0165}", params: ["color", "color2", "speed"],
      tip: "Random keys twinkle between two colours." },
    { id: "rain",          name: "Rain",          auraName: "Rain",         icon: "\u{F0276}", params: ["speed"],
      tip: "Streaks fall down the keyboard." },
    { id: "highlight",     name: "Highlight",     auraName: "Highlight",    icon: "\u{F030D}", params: ["color", "speed"],
      tip: "Only the key you press lights up." },
    { id: "laser",         name: "Laser",         auraName: "Laser",        icon: "\u{F0330}", params: ["color", "speed"],
      tip: "A pressed key fires a beam across the row." },
    { id: "ripple",        name: "Ripple",        auraName: "Ripple",       icon: "\u{F053E}", params: ["color", "speed"],
      tip: "A pressed key sends rings outward." },
    { id: "comet",         name: "Comet",         auraName: "Comet",        icon: "\u{F0361}", params: ["color"],
      tip: "A lit streak runs across the keyboard and fades." },
    { id: "flash",         name: "Flash",         auraName: "Flash",        icon: "\u{F0192}", params: ["color"],
      tip: "Brief full-keyboard flashes." }
]

function supportedEffects(auraModes) {
    if (!auraModes || auraModes.length === 0) return effects
    return effects.filter(function(e) { return auraModes.indexOf(e.auraName) >= 0 })
}

var speeds = ["low", "med", "high"]
var speedLabels = { low: "Slow", med: "Medium", high: "Fast" }
var directions = ["up", "down", "left", "right"]

function buildAuraCommand(effectId, params) {
    var cmd = ["asusctl", "aura", "effect", effectId]
    var effect = null
    for (var i = 0; i < effects.length; i++) { if (effects[i].id === effectId) { effect = effects[i]; break } }
    if (!effect) return cmd
    for (var j = 0; j < effect.params.length; j++) {
        var p = effect.params[j], val = params[p]
        if (val === undefined || val === null || val === "") continue
        if (p === "color")  { cmd.push("--colour"); cmd.push(String(val)) }
        if (p === "color2") { cmd.push("--colour2"); cmd.push(String(val)) }
        if (p === "speed")  { cmd.push("--speed"); cmd.push(String(val)) }
        if (p === "direction") { cmd.push("--direction"); cmd.push(String(val)) }
    }
    return cmd
}

// ============================================================
// LED brightness
// ============================================================
function parseLedBrightness(raw) {
    var text = String(raw || "").trim().toLowerCase()
    if (text.indexOf("off") >= 0) return "off"
    if (text.indexOf("high") >= 0) return "high"
    if (text.indexOf("med") >= 0) return "med"
    if (text.indexOf("low") >= 0) return "low"
    return "off"
}

// ============================================================
// Color helpers
// ============================================================
function rgbToHex(r, g, b) {
    var rh = Math.max(0, Math.min(255, Math.round(r))).toString(16)
    var gh = Math.max(0, Math.min(255, Math.round(g))).toString(16)
    var bh = Math.max(0, Math.min(255, Math.round(b))).toString(16)
    if (rh.length < 2) rh = "0" + rh
    if (gh.length < 2) gh = "0" + gh
    if (bh.length < 2) bh = "0" + bh
    return rh + gh + bh
}

function hexToRgb(hex) {
    var h = String(hex).replace("#", "")
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2]
    if (h.length !== 6) return { r: 255, g: 255, b: 255 }
    return { r: parseInt(h.substring(0, 2), 16) || 0, g: parseInt(h.substring(2, 4), 16) || 0, b: parseInt(h.substring(4, 6), 16) || 0 }
}

var presetColors = [
    { name: "Red",    hex: "ff0000" }, { name: "Orange", hex: "ff8800" },
    { name: "Yellow", hex: "ffff00" }, { name: "Green",  hex: "00ff00" },
    { name: "Cyan",   hex: "00ffff" }, { name: "Blue",   hex: "0088ff" },
    { name: "Purple", hex: "aa00ff" }, { name: "Pink",   hex: "ff00ff" },
    { name: "White",  hex: "ffffff" }, { name: "Warm",   hex: "ffaa44" },
    { name: "Ice",    hex: "44ccff" }, { name: "Lime",   hex: "88ff00" }
]
