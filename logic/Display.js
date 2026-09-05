.pragma library

// ============================================================
// Display (G-Helper's 60Hz / max-Hz screen toggle)
// ============================================================
// Picks the built-in panel (eDP-*) when present — the refresh toggle is a
// laptop-screen feature, and on a docked machine the focused monitor is
// usually the external one. Falls back to the focused monitor otherwise.
function parseMonitors(rawJson) {
    var list
    try { list = JSON.parse(String(rawJson || "[]")) } catch (e) { return null }
    if (!Array.isArray(list) || list.length === 0) return null
    var m = null
    for (var i = 0; i < list.length; i++) if (String(list[i].name || "").indexOf("eDP") === 0) { m = list[i]; break }
    if (!m) for (var j = 0; j < list.length; j++) if (list[j].focused) { m = list[j]; break }
    if (!m) m = list[0]

    // availableModes entries look like "1920x1080@144.00Hz"; keep only the
    // rates offered at the resolution currently in use, deduped and sorted.
    var res = m.width + "x" + m.height
    var rates = [], seen = {}
    var modes = Array.isArray(m.availableModes) ? m.availableModes : []
    for (var k = 0; k < modes.length; k++) {
        var parts = String(modes[k]).split("@")
        if (parts.length !== 2 || parts[0] !== res) continue
        var hz = Math.round(parseFloat(parts[1]))
        if (isNaN(hz) || seen[hz]) continue
        seen[hz] = true
        rates.push(hz)
    }
    rates.sort(function(a, b) { return a - b })
    return {
        name: m.name, width: m.width, height: m.height,
        x: m.x, y: m.y, scale: m.scale,
        rate: Math.round(m.refreshRate), rates: rates
    }
}

// hyprmoncfg (a third-party monitor-profile daemon, not part of Omarchy) takes
// ownership of monitor config where it is installed: its daemon re-applies the
// active saved profile a few seconds after any runtime change, so a plain
// hl.monitor call silently snaps back. Where it is running, the new mode has to
// be saved into that profile as well — see setRefreshRate in AsusController.qml.
function parseHyprmoncfgStatus(raw) {
    var r = { managed: false, profile: "" }
    var d
    try { d = JSON.parse(String(raw || "{}")) } catch (e) { return r }
    r.managed = !!(d && d.daemon && d.daemon.running)
    if (d && d.active_profile && d.active_profile.name) r.profile = String(d.active_profile.name)
    // A running daemon with no active profile has nothing to save back into,
    // so treat that as unmanaged rather than issuing a `save ""`.
    if (r.profile === "") r.managed = false
    return r
}

// Hyprland 0.56 parses its config as Lua, and `hyprctl keyword monitor`
// against it fails outright with "keyword can't work with non-legacy parsers.
// Use eval." — so the mode change goes through the Lua monitor API instead,
// the same call omarchy-hyprland-monitor-scaling uses.
//
// Position and scale are repeated explicitly: hl.monitor replaces the whole
// rule, so omitting them would reset the monitor's placement and scaling while
// changing only the rate.
function monitorCommand(mon, hz) {
    return ["hyprctl", "eval",
            'hl.monitor({ output = "' + mon.name + '"' +
            ', mode = "' + mon.width + "x" + mon.height + "@" + hz + '"' +
            ', position = "' + mon.x + "x" + mon.y + '"' +
            ", scale = " + mon.scale + " })"]
}
