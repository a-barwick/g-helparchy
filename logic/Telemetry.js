.pragma library
.import "Numbers.js" as Numbers

// ============================================================
// Live sensors
// ============================================================
// One shell round-trip per tick instead of a Process per reading. hwmon
// indices are not stable across boots, so chips are matched by their `name`
// file rather than a hardcoded hwmonN path. NVIDIA telemetry is read only
// from sysfs, and only while the PCI device is already active. In particular,
// this must never poll nvidia-smi: doing so can wake a runtime-suspended dGPU.
var sensorScript =
    'read _ cpu_user cpu_nice cpu_system cpu_idle cpu_iowait cpu_irq cpu_softirq cpu_steal _ < /proc/stat; ' +
    'cpu_total=$((cpu_user + cpu_nice + cpu_system + cpu_idle + cpu_iowait + cpu_irq + cpu_softirq + cpu_steal)); ' +
    'echo "cpu_total=$cpu_total"; echo "cpu_idle=$((cpu_idle + cpu_iowait))"; ' +
    'for h in /sys/class/hwmon/*; do n=$(cat "$h/name" 2>/dev/null); case "$n" in ' +
    'coretemp|k10temp|zenpower) echo "cpu_temp=$(cat "$h/temp1_input" 2>/dev/null)";; ' +
    'asus) echo "fan_cpu=$(cat "$h/fan1_input" 2>/dev/null)"; echo "fan_gpu=$(cat "$h/fan2_input" 2>/dev/null)";; ' +
    'esac; done; ' +
    'for b in /sys/class/power_supply/BAT*; do [ -d "$b" ] || continue; ' +
    'echo "bat_pct=$(cat "$b/capacity" 2>/dev/null)"; ' +
    'echo "bat_status=$(cat "$b/status" 2>/dev/null)"; ' +
    'echo "bat_power=$(cat "$b/power_now" 2>/dev/null)"; break; done; ' +
    'for d in /sys/class/drm/card[0-9]*; do base=${d##*/}; ' +
    'case "$base" in card*[!0-9]*) continue;; esac; ' +
    '[ "$(cat "$d/device/vendor" 2>/dev/null)" = 0x10de ] || continue; ' +
    '[ "$(cat "$d/device/power/runtime_status" 2>/dev/null)" = active ] || continue; ' +
    'for h in "$d/device"/hwmon/hwmon*; do [ -d "$h" ] || continue; ' +
    '[ -r "$h/temp1_input" ] && echo "gpu_temp_milli=$(cat "$h/temp1_input" 2>/dev/null)"; ' +
    '[ -r "$h/power1_average" ] && echo "gpu_power_uw=$(cat "$h/power1_average" 2>/dev/null)"; done; ' +
    '[ -r "$d/device/gpu_busy_percent" ] && echo "gpu_util=$(cat "$d/device/gpu_busy_percent" 2>/dev/null)"; done'

function sensorCommand() { return ["sh", "-c", sensorScript] }

// -1 means "not reported" throughout; callers hide the tile rather than
// printing a bogus zero.
function parseSensors(raw) {
    var r = { cpuTemp: -1, cpuTotal: -1, cpuIdle: -1, gpuTemp: -1, gpuPower: -1, gpuUtil: -1, fanCpu: -1, fanGpu: -1, batPct: -1, batStatus: "", batPower: -1 }
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var eq = lines[i].indexOf("=")
        if (eq < 0) continue
        var k = lines[i].substring(0, eq).trim(), v = lines[i].substring(eq + 1).trim()
        if (v === "") continue
        var n = parseFloat(v)
        if (k === "cpu_temp" && !isNaN(n)) r.cpuTemp = Math.round(n / 1000)
        else if (k === "cpu_total" && !isNaN(n)) r.cpuTotal = n
        else if (k === "cpu_idle" && !isNaN(n)) r.cpuIdle = n
        else if (k === "gpu_temp_milli" && !isNaN(n)) r.gpuTemp = Math.round(n / 1000)
        else if (k === "gpu_power_uw" && !isNaN(n)) r.gpuPower = n / 1000000
        else if (k === "gpu_util" && !isNaN(n)) r.gpuUtil = Math.round(n)
        else if (k === "fan_cpu" && !isNaN(n)) r.fanCpu = Math.round(n)
        else if (k === "fan_gpu" && !isNaN(n)) r.fanGpu = Math.round(n)
        else if (k === "bat_pct" && !isNaN(n)) r.batPct = Math.round(n)
        else if (k === "bat_power" && !isNaN(n)) r.batPower = n / 1000000
        else if (k === "bat_status") r.batStatus = v
    }
    return r
}

// Aggregate CPU utilization between two /proc/stat snapshots. Reading the
// counters is effectively free and includes the probe's own work, which gives
// the efficiency detector a conservative (busier) result rather than a false
// idle result.
function cpuUtilization(previousTotal, previousIdle, currentTotal, currentIdle) {
    var oldTotal = Number(previousTotal), oldIdle = Number(previousIdle)
    var nextTotal = Number(currentTotal), nextIdle = Number(currentIdle)
    var total = nextTotal - oldTotal
    var idle = nextIdle - oldIdle
    if (isNaN(oldTotal) || isNaN(oldIdle) || isNaN(nextTotal) || isNaN(nextIdle) ||
            oldTotal < 0 || oldIdle < 0 || nextTotal < 0 || nextIdle < 0 || total <= 0 || idle < 0) return -1
    return Math.round(Numbers.clamp((total - idle) / total * 100, 0, 100))
}
