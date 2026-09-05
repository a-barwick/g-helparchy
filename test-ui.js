// Exercise actual QML imports and bindings using packaged Omarchy components.
// Runs offscreen; the fixture controller disables timers and startup probes.
const fs = require("node:fs")
const os = require("node:os")
const path = require("node:path")
const { spawnSync } = require("node:child_process")
const assert = require("node:assert/strict")

const shellRoot = process.env.OMARCHY_SHELL_PATH || "/usr/share/omarchy/shell"
const scratch = fs.mkdtempSync(path.join(os.tmpdir(), "g-helparchy-ui-"))
try {
    for (const dir of ["Commons", "Ui"])
        fs.symlinkSync(path.join(shellRoot, dir), path.join(scratch, dir), "dir")
    fs.symlinkSync(__dirname, path.join(scratch, "Plugin"), "dir")
    fs.copyFileSync(path.join(__dirname, "tests/ui-smoke.qml"), path.join(scratch, "shell.qml"))
    // Wayland adds entry-point compilation because PanelWindow needs a backend.
    // The fixture stays hidden in that pass and never opens the actual popup.
    for (const platform of process.env.WAYLAND_DISPLAY ? ["offscreen", "wayland"] : ["offscreen"]) {
        const env = { ...process.env, QT_QPA_PLATFORM: platform, QT_QUICK_BACKEND: "software", QT_QPA_PLATFORMTHEME: "" }
        if (platform === "offscreen") delete env.WAYLAND_DISPLAY
        const result = spawnSync("qs", ["--no-color", "-p", path.join(scratch, "shell.qml")], {
            env,
            encoding: "utf8", timeout: 15000
        })
        const log = (result.stdout || "") + (result.stderr || "")
        process.stdout.write(log)
        assert.ifError(result.error)
        assert.equal(result.status, 0)
        assert.match(log, /SMOKE_OK/)
        assert.doesNotMatch(log, /SMOKE_FAIL|ReferenceError|TypeError|Binding loop|Unable to assign|Cannot assign|is not a type/)
    }
} finally {
    // Only this test's mkdtemp directory; symlinks are unlinked, never followed.
    fs.rmSync(scratch, { recursive: true, force: true })
}
