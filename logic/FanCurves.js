.pragma library
.import "Numbers.js" as Numbers

// ============================================================
// Fan curves — parse per-fan data from `asusctl fan-curve --get-enabled`
// and `asusctl fan-curve --mod-profile <name>`
// ============================================================
function parseFanCurves(raw) {
    var text = String(raw || "")
    var result = { cpuEnabled: false, gpuEnabled: false, midEnabled: false, hasMid: false, cpuPoints: [], gpuPoints: [], midPoints: [] }

    // Parse enabled state: "CPU: enabled: false, 40c:6%,..."
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (line.indexOf("CPU:") >= 0) {
            result.cpuEnabled = line.indexOf("enabled: true") >= 0
            // Extract curve points after the comma
            var idx = line.indexOf(",")
            if (idx >= 0) {
                var curveStr = line.substring(idx + 1).trim()
                result.cpuPoints = parseFanPoints(curveStr)
            }
        }
        if (line.indexOf("GPU:") >= 0) {
            result.gpuEnabled = line.indexOf("enabled: true") >= 0
            var idx2 = line.indexOf(",")
            if (idx2 >= 0) {
                var curveStr2 = line.substring(idx2 + 1).trim()
                result.gpuPoints = parseFanPoints(curveStr2)
            }
        }
        if (line.indexOf("MID:") >= 0) {
            result.hasMid = true
            result.midEnabled = line.indexOf("enabled: true") >= 0
            var idx3 = line.indexOf(",")
            if (idx3 >= 0) {
                var curveStr3 = line.substring(idx3 + 1).trim()
                result.midPoints = parseFanPoints(curveStr3)
            }
        }
    }

    // Also parse detailed curve from `fan-curve --mod-profile` output
    // Format: pwm: (2, 17, 30, ...), temp: (50, 65, 69, ...)
    for (var j = 0; j < lines.length; j++) {
        var ln = lines[j].trim()
        if (ln.indexOf("fan: CPU") >= 0) {
            // Look ahead for pwm and temp lines
            for (var k = j + 1; k < Math.min(j + 5, lines.length); k++) {
                var pline = lines[k].trim()
                if (pline.indexOf("pwm:") >= 0) {
                    var pwms = pline.replace("pwm:", "").replace(/[()]/g, "").split(",").map(function(s) { return parseInt(s.trim()) }).filter(function(n) { return !isNaN(n) })
                    // Find matching temp line
                    for (var t = k + 1; t < Math.min(k + 3, lines.length); t++) {
                        var tline = lines[t].trim()
                        if (tline.indexOf("temp:") >= 0) {
                            var temps = tline.replace("temp:", "").replace(/[()]/g, "").split(",").map(function(s) { return parseInt(s.trim()) }).filter(function(n) { return !isNaN(n) })
                            result.cpuPoints = []
                            for (var m = 0; m < Math.min(pwms.length, temps.length); m++) {
                                result.cpuPoints.push({ temp: temps[m], speed: Math.round(pwms[m] / 255 * 100) })
                            }
                            break
                        }
                    }
                    break
                }
            }
        }
        if (ln.indexOf("fan: GPU") >= 0) {
            for (var k2 = j + 1; k2 < Math.min(j + 5, lines.length); k2++) {
                var pline2 = lines[k2].trim()
                if (pline2.indexOf("pwm:") >= 0) {
                    var pwms2 = pline2.replace("pwm:", "").replace(/[()]/g, "").split(",").map(function(s) { return parseInt(s.trim()) }).filter(function(n) { return !isNaN(n) })
                    for (var t2 = k2 + 1; t2 < Math.min(k2 + 3, lines.length); t2++) {
                        var tline2 = lines[t2].trim()
                        if (tline2.indexOf("temp:") >= 0) {
                            var temps2 = tline2.replace("temp:", "").replace(/[()]/g, "").split(",").map(function(s) { return parseInt(s.trim()) }).filter(function(n) { return !isNaN(n) })
                            result.gpuPoints = []
                            for (var m2 = 0; m2 < Math.min(pwms2.length, temps2.length); m2++) {
                                result.gpuPoints.push({ temp: temps2[m2], speed: Math.round(pwms2[m2] / 255 * 100) })
                            }
                            break
                        }
                    }
                    break
                }
            }
        }
        if (ln.indexOf("fan: MID") >= 0) {
            result.hasMid = true
            for (var k3 = j + 1; k3 < Math.min(j + 5, lines.length); k3++) {
                var pline3 = lines[k3].trim()
                if (pline3.indexOf("pwm:") >= 0) {
                    var pwms3 = pline3.replace("pwm:", "").replace(/[()]/g, "").split(",").map(function(s) { return parseInt(s.trim()) }).filter(function(n) { return !isNaN(n) })
                    for (var t3 = k3 + 1; t3 < Math.min(k3 + 3, lines.length); t3++) {
                        var tline3 = lines[t3].trim()
                        if (tline3.indexOf("temp:") >= 0) {
                            var temps3 = tline3.replace("temp:", "").replace(/[()]/g, "").split(",").map(function(s) { return parseInt(s.trim()) }).filter(function(n) { return !isNaN(n) })
                            result.midPoints = []
                            for (var m3 = 0; m3 < Math.min(pwms3.length, temps3.length); m3++) {
                                result.midPoints.push({ temp: temps3[m3], speed: Math.round(pwms3[m3] / 255 * 100) })
                            }
                            break
                        }
                    }
                    break
                }
            }
        }
    }

    return result
}

// Serializes curve points back into asusctl's --data format: "30c:1%,49c:2%,...".
function serializeFanPoints(points) {
    return points.map(function(p) { return Math.round(p.temp) + "c:" + Math.round(p.speed) + "%" }).join(",")
}

// Moves point[index] to a new temp/speed, clamped to bounds and kept sorted
// by temp (dragging past a neighbor swaps order rather than crossing it).
function moveFanPoint(points, index, temp, speed) {
    var pts = points.map(function(p) { return { temp: p.temp, speed: p.speed } })
    if (index < 0 || index >= pts.length) return pts
    pts[index].temp = Numbers.clamp(Math.round(temp), 30, 100)
    pts[index].speed = Numbers.clamp(Math.round(speed), 0, 100)
    pts.sort(function(a, b) { return a.temp - b.temp })
    return pts
}

function parseFanPoints(str) {
    var points = []
    var parts = str.split(/[,;\s]+/)
    for (var i = 0; i < parts.length; i++) {
        var p = parts[i].replace(/[c%]/g, "").trim()
        var kv = p.split(/[:\s]+/)
        if (kv.length >= 2) {
            var temp = parseInt(kv[0]), speed = parseInt(kv[1])
            if (!isNaN(temp) && !isNaN(speed)) points.push({ temp: temp, speed: speed })
        }
    }
    return points
}
