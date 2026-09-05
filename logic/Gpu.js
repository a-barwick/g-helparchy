.pragma library

// ============================================================
// GPU mode and Linux runtime state
// ============================================================
// These values follow asus-linux's GpuMode conversion exactly:
//   Eco / Integrated  gpu_mux_mode=1, dgpu_disable=1
//   Standard / Hybrid gpu_mux_mode=1, dgpu_disable=0
//   Ultimate          gpu_mux_mode=0, dgpu_disable=0
// GPU attributes are queued by asusd and applied at shutdown. They describe
// firmware intent, not which GPU owns a connector or whether NVIDIA is awake,
// so the UI reports those independently from Linux sysfs below.
var gpuModes = [
    { id: "eco",      name: "Integrated", icon: "\u{F06C0}", desc: "Integrated display, discrete GPU disabled", mux: 1, dgpuDisable: 1,
      tip: "Uses integrated graphics and disables the discrete GPU after a normal shutdown/reboot." },
    { id: "standard", name: "Hybrid",     icon: "\u{F035B}", desc: "Integrated display, discrete GPU available on demand", mux: 1, dgpuDisable: 0,
      tip: "The integrated GPU drives the panel; the discrete GPU remains available for render offload." },
    { id: "ultimate", name: "dGPU direct", icon: "\u{F04C5}", desc: "Discrete GPU owns the internal display", mux: 0, dgpuDisable: 0,
      tip: "The discrete GPU drives the internal panel after a normal shutdown/reboot." }
]

function gpuModeId(mux, dgpuDisabled, supportsMux, supportsDgpu) {
    if (supportsMux === false && supportsDgpu === false) return "unknown"
    mux = parseGpuInteger(mux)
    dgpuDisabled = parseGpuInteger(dgpuDisabled)
    if (mux === 0) return "ultimate"
    if (mux !== 1 && supportsMux !== false) return "unknown"
    if (dgpuDisabled === 1) return "eco"
    if (dgpuDisabled === 0 || supportsDgpu === false) return "standard"
    return "unknown"
}

function gpuModeDef(id) {
    for (var i = 0; i < gpuModes.length; i++) if (gpuModes[i].id === id) return gpuModes[i]
    return { id: "unknown", name: "Unknown", desc: "GPU mode is unavailable" }
}

// Return the minimal ordered set of writes needed for a target. In the common
// Hybrid <-> Integrated transition gpu_mux_mode is already 1, so only
// dgpu_disable is touched. Values may be queued values rather than current
// values, which lets a second click safely replace a pending choice.
function gpuModeCommands(currentMux, currentDgpu, id, supportsMux, supportsDgpu) {
    var def = gpuModeDef(id)
    var commands = []
    if (!gpuModeAvailable(id, supportsMux, supportsDgpu)) return commands
    if (supportsDgpu && Number(currentDgpu) !== def.dgpuDisable)
        commands.push(["asusctl", "armoury", "set", "dgpu_disable", String(def.dgpuDisable)])
    if (supportsMux && Number(currentMux) !== def.mux)
        commands.push(["asusctl", "armoury", "set", "gpu_mux_mode", String(def.mux)])
    return commands
}

function gpuModeAvailable(id, supportsMux, supportsDgpu) {
    if (id === "eco") return !!supportsDgpu
    if (id === "ultimate") return !!supportsMux
    return id === "standard" && (!!supportsMux || !!supportsDgpu)
}

function effectiveGpuValue(currentValue, queuedValue) {
    return Number(queuedValue) >= 0 ? Number(queuedValue) : Number(currentValue)
}

function gpuDisableNeedsConfirmation(targetId, currentDgpu, status) {
    if (targetId !== "eco" || Number(currentDgpu) === 1) return false
    return !status.usersKnown || status.users.length > 0
}

// The status probe uses only sysfs, busctl, fuser, and /proc metadata. It never
// invokes a GPU management client, so merely opening the panel does not wake a
// runtime-suspended NVIDIA device. fuser is optional; without it the UI marks
// process detection unavailable and requires confirmation before disabling.
var gpuStatusScript =
    'display_connector=none; display_driver=unknown; ' +
    'for c in /sys/class/drm/card*-eDP-*; do [ -e "$c" ] || continue; ' +
    '[ "$(cat "$c/status" 2>/dev/null)" = connected ] || continue; ' +
    'base=${c##*/}; card=${base%%-*}; display_connector=${base#*-}; ' +
    'display_driver=$(basename "$(readlink -f "/sys/class/drm/$card/device/driver" 2>/dev/null)"); break; done; ' +
    'echo "display_connector=$display_connector"; echo "display_driver=$display_driver"; ' +
    'dgpu_present=0; dgpu_runtime=unavailable; gpu_nodes=""; ' +
    'for d in /sys/class/drm/card[0-9]*; do base=${d##*/}; case "$base" in card*[!0-9]*) continue;; esac; ' +
    '[ "$(cat "$d/device/vendor" 2>/dev/null)" = 0x10de ] || continue; ' +
    'dgpu_present=1; dgpu_runtime=$(cat "$d/device/power/runtime_status" 2>/dev/null); ' +
    'gpu_nodes="$gpu_nodes /dev/dri/$base"; dev=$(readlink -f "$d/device"); ' +
    'for r in /sys/class/drm/renderD*; do [ -e "$r" ] || continue; ' +
    '[ "$(readlink -f "$r/device")" = "$dev" ] && gpu_nodes="$gpu_nodes /dev/dri/${r##*/}"; done; done; ' +
    'for n in /dev/nvidia*; do [ -e "$n" ] && gpu_nodes="$gpu_nodes $n"; done; ' +
    'echo "dgpu_present=$dgpu_present"; echo "dgpu_runtime=$dgpu_runtime"; ' +
    'for a in gpu_mux_mode dgpu_disable; do path=/xyz/ljones/asus_armoury/$a; ' +
    'v=$(busctl get-property xyz.ljones.Asusd "$path" xyz.ljones.AsusArmoury CurrentValue 2>/dev/null); ' +
    'echo "${a}_current=${v##* }"; ' +
    'v=$(busctl get-property xyz.ljones.Asusd "$path" xyz.ljones.AsusArmoury QueuedGpuValue 2>/dev/null); ' +
    'echo "${a}_queued=${v##* }"; done; ' +
    'users_known=0; ' +
    'if [ -n "$gpu_nodes" ] && command -v fuser >/dev/null 2>&1; then ' +
    'err=$(mktemp) || exit 1; trap \'rm -f "$err"\' EXIT; ' +
    'pids=$(fuser $gpu_nodes 2>"$err"); rc=$?; ' +
    // fuser writes file labels to stderr on success. With no matches it
    // returns 1 and no output; diagnostics on that path mean detection failed.
    'if [ "$rc" = 0 ] || { [ "$rc" = 1 ] && [ ! -s "$err" ]; }; then users_known=1; fi; ' +
    'for pid in $(printf "%s" "$pids" | tr " " "\\n" | sed "/^$/d" | sort -nu); do ' +
    'comm=$(cat "/proc/$pid/comm" 2>/dev/null | tr "|=" "__"); ' +
    '[ -n "$comm" ] && echo "gpu_user=$pid|$comm"; done; fi; ' +
    'echo "users_known=$users_known"'

function gpuStatusCommand() { return ["sh", "-c", gpuStatusScript] }

function parseGpuStatus(raw) {
    var r = {
        displayConnector: "none", displayDriver: "unknown",
        dgpuPresent: false, runtimeStatus: "unavailable", usersKnown: false,
        users: [], muxCurrent: -1, muxQueued: -1, dgpuCurrent: -1, dgpuQueued: -1
    }
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var eq = lines[i].indexOf("=")
        if (eq < 0) continue
        var k = lines[i].substring(0, eq), v = lines[i].substring(eq + 1)
        if (k === "display_connector") r.displayConnector = v || "none"
        else if (k === "display_driver") r.displayDriver = v || "unknown"
        else if (k === "dgpu_present") r.dgpuPresent = Number(v) === 1
        else if (k === "dgpu_runtime") r.runtimeStatus = v || "unavailable"
        else if (k === "users_known") r.usersKnown = Number(v) === 1
        else if (k === "gpu_mux_mode_current") r.muxCurrent = parseGpuInteger(v)
        else if (k === "gpu_mux_mode_queued") r.muxQueued = parseGpuInteger(v)
        else if (k === "dgpu_disable_current") r.dgpuCurrent = parseGpuInteger(v)
        else if (k === "dgpu_disable_queued") r.dgpuQueued = parseGpuInteger(v)
        else if (k === "gpu_user") {
            var split = v.indexOf("|")
            if (split > 0) r.users.push({ pid: parseInt(v.substring(0, split)), name: v.substring(split + 1) })
        }
    }
    return r
}

function parseGpuInteger(value) {
    var text = String(value === undefined || value === null ? "" : value).trim()
    return /^-?\d+$/.test(text) ? Number(text) : -1
}

function displayOwnerLabel(driver) {
    var d = String(driver || "").toLowerCase()
    if (d === "i915" || d === "xe") return "Intel (" + d + ")"
    if (d === "nvidia") return "NVIDIA"
    if (d === "amdgpu") return "AMD (amdgpu)"
    return d && d !== "unknown" ? d : "Unknown"
}

function dgpuStateLabel(status, dgpuDisabled) {
    if (Number(dgpuDisabled) === 1) return "disabled by firmware"
    if (!status.dgpuPresent) return "not detected"
    if (status.users.length > 0) return "busy — " + status.users.length + " visible process" + (status.users.length === 1 ? "" : "es")
    if (status.runtimeStatus === "suspended") return "runtime suspended"
    if (status.runtimeStatus === "active") return status.usersKnown ? "awake — no visible processes" : "awake — process detection unavailable"
    return status.runtimeStatus || "state unknown"
}

function gpuUsersText(users) {
    var items = []
    var list = users || []
    for (var i = 0; i < list.length; i++) items.push(list[i].name + " (" + list[i].pid + ")")
    return items.join(", ")
}
