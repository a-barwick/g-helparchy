.pragma library

// Cool -> hot ramp shared by every temperature readout.
function tempColor(c) {
    if (c < 0) return "#888888"
    if (c >= 90) return "#ff4444"
    if (c >= 80) return "#ff8844"
    if (c >= 65) return "#ffcc44"
    return "#44cc66"
}

function fmtTemp(c) { return c < 0 ? "—" : c + "°C" }
function fmtRpm(r) { return r < 0 ? "—" : (r === 0 ? "off" : r + " rpm") }
function fmtWatts(w) { return w < 0 ? "—" : (Math.round(w * 10) / 10) + " W" }
