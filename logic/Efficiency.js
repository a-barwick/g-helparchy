.pragma library

// ============================================================
// Context-aware efficiency suggestion
// ============================================================
function isDischarging(status) {
    return String(status || "").toLowerCase() === "discharging"
}

function isPerformanceProfile(profile) {
    var p = String(profile || "").toLowerCase()
    return p.indexOf("performance") >= 0 || p.indexOf("turbo") >= 0
}

function isHighPowerConfiguration(gpuMode, profile, refreshRate, customFanCurve) {
    var direct = gpuMode === "ultimate"
    var performance = isPerformanceProfile(profile)
    var highRefresh = Number(refreshRate) > 60
    var customFans = customFanCurve === true
    return (direct && (performance || highRefresh || customFans)) ||
           (performance && highRefresh && customFans)
}

function isLightWorkload(cpuUtil, gpuUtil, gpuPower) {
    var cpu = Number(cpuUtil), gpu = Number(gpuUtil), power = Number(gpuPower)
    if (isNaN(cpu) || cpu < 0 || cpu >= 20) return false
    if (!isNaN(gpu) && gpu >= 0 && gpu >= 15) return false
    if (!isNaN(power) && power >= 0 && power >= 15) return false
    return true
}

// Pure transition function so timing behaviour can be exercised without QML.
// A short busy spike leaves lightSinceMs intact; thirty seconds of sustained
// work clears the suggestion. All countdowns use timestamps, not sample counts,
// so opening the panel and increasing the sensor rate cannot accelerate them.
function nextEfficiencyState(previous, input, nowMs) {
    var old = previous || {}
    var now = Number(nowMs)
    var contextActive = input.enabled === true && Number(input.batteryPct) >= 0 &&
        Number(input.batteryPct) <= 30 && isDischarging(input.batteryStatus) &&
        isHighPowerConfiguration(input.gpuMode, input.profile, input.refreshRate, input.customFanCurve)
    if (!contextActive) return { lightSinceMs: 0, busySinceMs: 0, suggested: false, contextActive: false }

    var lightSince = Number(old.lightSinceMs) || 0
    var busySince = Number(old.busySinceMs) || 0
    var suggested = old.suggested === true
    if (isLightWorkload(input.cpuUtil, input.gpuUtil, input.gpuPower)) {
        busySince = 0
        if (lightSince <= 0) lightSince = now
        if (input.suppressed !== true && now - lightSince >= 300000) suggested = true
    } else {
        if (busySince <= 0) busySince = now
        if (now - busySince >= 30000) {
            lightSince = 0
            suggested = false
        }
    }
    if (input.suppressed === true) suggested = false
    return { lightSinceMs: lightSince, busySinceMs: busySince, suggested: suggested, contextActive: true }
}
