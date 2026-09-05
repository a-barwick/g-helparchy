.pragma library

// ============================================================
// Profile
// ============================================================
function profileIcon(name) {
    var n = String(name || "").toLowerCase()
    if (n.indexOf("quiet") >= 0 || n.indexOf("silent") >= 0) return "\u{F032A}"
    if (n.indexOf("balanced") >= 0) return "\u{F029A}"
    if (n.indexOf("performance") >= 0 || n.indexOf("turbo") >= 0) return "\u{F04C5}"
    return "\u{F0244}"
}

// G-Helper tints each performance mode; the same three-colour language is
// reused here so the active profile reads at a glance from the bar icon
// and the mode buttons.
// Tooltip copy for the three throttle policies. Says what each one does to
// fans and power rather than restating its name.
function profileDescription(name) {
    var n = String(name || "").toLowerCase()
    if (n.indexOf("quiet") >= 0 || n.indexOf("silent") >= 0)
        return "Lowest power limits and fan speeds.\nQuietest and coolest, longest battery, slowest under load."
    if (n.indexOf("balanced") >= 0)
        return "Default policy. Power and fans scale with load.\nWhat you want for everyday use."
    if (n.indexOf("performance") >= 0 || n.indexOf("turbo") >= 0)
        return "Highest power limits and fan speeds.\nLoud and hot, but the best sustained performance."
    return "Set the platform throttle policy to " + name + "."
}

function profileColor(name) {
    var n = String(name || "").toLowerCase()
    if (n.indexOf("quiet") >= 0 || n.indexOf("silent") >= 0) return "#44aaff"
    if (n.indexOf("balanced") >= 0) return "#44cc66"
    if (n.indexOf("performance") >= 0 || n.indexOf("turbo") >= 0) return "#ff6644"
    return "#888888"
}

function profileLabel(name) {
    var n = String(name || "").toLowerCase()
    if (n.indexOf("quiet") >= 0 || n.indexOf("silent") >= 0) return "Quiet"
    if (n.indexOf("balanced") >= 0) return "Balanced"
    if (n.indexOf("performance") >= 0 || n.indexOf("turbo") >= 0) return "Performance"
    return name || "\u2014"
}

function parseCurrentProfile(raw) {
    var text = String(raw || "").trim()
    var idx = text.indexOf("Active profile:")
    if (idx >= 0) { var fl = text.substring(idx + 16).trim().split("\n")[0].trim(); if (fl) return fl }
    var lines = text.split("\n")
    if (lines.length > 0) { var parts = lines[0].trim().split(/\s+/); if (parts.length > 0) return parts[0] }
    return ""
}

function parseProfiles(raw) {
    var text = String(raw || "").trim()
    var r = { ac: "", battery: "" }
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i].trim()
        if (l.indexOf("AC profile") >= 0) r.ac = l.replace("AC profile", "").trim()
        if (l.indexOf("Battery profile") >= 0) r.battery = l.replace("Battery profile", "").trim()
    }
    return r
}

// ============================================================
// Feature detection
// ============================================================
function parseSupportedFeatures(raw) {
    var text = String(raw || "")
    return {
        hasAura: text.indexOf("Aura") >= 0,
        hasFanCurve: text.indexOf("FanCurves") >= 0,
        // asusctl 6.x reports the charge limit as a platform property named
        // ChargeControlEndThreshold rather than anything containing "battery",
        // so matching only on the word hid the limit slider on models that do
        // support it.
        hasBattery: text.indexOf("ChargeControlEndThreshold") >= 0 || text.indexOf("battery") >= 0 || text.indexOf("Battery") >= 0,
        hasProfile: text.indexOf("Platform") >= 0,
        hasAniMe: text.indexOf("anime") >= 0,
        auraModes: parseListSection(text, "Supported Aura Modes:")
    }
}

// Pulls a bracketed list section out of `asusctl info --show-supported`, e.g.
//   Supported Aura Modes:
//   [
//       Static,
//       Breathe,
//   ]
// -> ["Static", "Breathe"]
function parseListSection(text, header) {
    var idx = text.indexOf(header)
    if (idx < 0) return []
    var rest = text.substring(idx + header.length)
    var open = rest.indexOf("[")
    var close = rest.indexOf("]")
    if (open < 0 || close < 0 || close < open) return []
    return rest.substring(open + 1, close).split(",")
        .map(function(s) { return s.trim() })
        .filter(function(s) { return s.length > 0 })
}

// ============================================================
// Battery
// ============================================================
function parseBatteryInfo(raw) {
    var text = String(raw || "").trim()
    var r = { limit: 100 }
    var m = text.match(/(\d+)%/)
    if (m) r.limit = parseInt(m[1])
    return r
}

// ============================================================
// Armoury / Firmware
// ============================================================
// Walks the whole `asusctl armoury list` output once and returns everything
// the panel needs about every attribute:
//
//   attr_name:
//     current: 28..[133]..135
//     default: 115
//
// -> supported.attr_name = true, values.attr_name = 133,
//    ranges.attr_name = {min:28,max:135}, defaults.attr_name = 115
//
// Toggles ("[(0),1]") land in values as 0/1 with no range. Doing this in one
// pass here keeps the controller free of format-specific parsing it used to
// carry, so adding an attribute is a one-line change at the call site.
function parseArmoury(raw) {
    var lines = String(raw || "").split("\n")
    var out = { supported: {}, values: {}, ranges: {}, defaults: {} }
    var cur = ""
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i].trim()
        if (l.length === 0 || l.indexOf(":") < 0) continue
        if (l.indexOf("Multiple") >= 0 || l.indexOf("devices") >= 0) continue

        if (l.indexOf("current:") === 0) {
            if (!cur) continue
            var p = parseArmouryValue(l.substring(8).trim())
            if (p) {
                out.values[cur] = p.value
                if (p.type === "range") out.ranges[cur] = { min: p.min, max: p.max }
            }
            continue
        }
        if (l.indexOf("default:") === 0) {
            if (!cur) continue
            var d = parseInt(l.substring(8).trim())
            if (!isNaN(d)) out.defaults[cur] = d
            continue
        }
        cur = l.replace(":", "").trim()
        out.supported[cur] = true
    }
    // Keep the legacy camelCase flags the panel's `visible:` bindings read.
    out.supported.panelOverdrive = !!out.supported["panel_overdrive"]
    out.supported.gpuMux         = !!out.supported["gpu_mux_mode"]
    out.supported.dgpuDisable    = !!out.supported["dgpu_disable"]
    out.supported.pptPl1         = !!out.supported["ppt_pl1_spl"]
    out.supported.pptPl2         = !!out.supported["ppt_pl2_sppt"]
    out.supported.nvDynBoost     = !!out.supported["nv_dynamic_boost"]
    out.supported.nvTempTarget   = !!out.supported["nv_temp_target"]
    return out
}

function parseArmouryValue(raw) {
    var text = String(raw || "").trim()
    // Range: "25..[115]..45" — checked first, since it also uses brackets.
    var rm = text.match(/(\d+)\.\.\[(\d+)\]\.\.(\d+)/)
    if (rm) return { type: "range", value: parseInt(rm[2]), min: parseInt(rm[1]), max: parseInt(rm[3]) }
    // Enum/toggle: "[(0),1]" or "[0,(1)]" — parentheses mark the *current*
    // option, and they can sit on any entry, so scan rather than assuming the
    // first one is selected (assuming that made every toggle read as "off").
    var tm = text.match(/^\[(.+)\]$/)
    if (tm) {
        var opts = tm[1].split(",").map(function(s) { return s.trim() })
        for (var i = 0; i < opts.length; i++) {
            var pm = opts[i].match(/^\((\d+)\)$/)
            if (pm) return { type: "toggle", value: parseInt(pm[1]) }
        }
    }
    return null
}

// Tooltip copy for the firmware attributes on the Advanced tab. Keyed by the
// asusctl armoury attribute name.
var armouryTips = {
    ppt_pl1_spl: "Sustained CPU power limit (PL1).\nThe wattage the CPU settles at under a long load.",
    ppt_pl2_sppt: "Short-burst CPU power limit (PL2).\nThe wattage the CPU may pull briefly before dropping to PL1.",
    nv_dynamic_boost: "NVIDIA Dynamic Boost.\nExtra watts the GPU may borrow from the CPU's budget when the CPU is idle.",
    nv_temp_target: "GPU temperature target.\nThe GPU throttles itself to stay at or below this. Lower is cooler and quieter, and slower.",
    panel_overdrive: "Speeds up pixel transitions to cut ghosting at high refresh rates.\nCan cause slight overshoot artefacts on some panels."
}
