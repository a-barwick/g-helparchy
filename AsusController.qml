import QtQuick
import Quickshell.Io
import "logic/Aura.js" as Aura
import "logic/Platform.js" as Platform
import "logic/FanCurves.js" as FanCurves
import "logic/Telemetry.js" as Telemetry
import "logic/Efficiency.js" as Efficiency
import "logic/Gpu.js" as Gpu
import "logic/Display.js" as Display
import "logic/Numbers.js" as Numbers

// Observable state and the single execution boundary for the ASUS panel.
QtObject {
    id: root
    property list<QtObject> resources
    property bool active: true
    property bool panelOpen: false

    // Views receive state and actions rather than private Process objects.
    readonly property bool canRequestGpuMode: !gpuActionProc.running && !armouryActionProc.running && armouryActionQueue.length === 0 && !actionProc.running && gpuActionQueue.length === 0 && pendingGpuRequest === ""

    onPanelOpenChanged: {
        if (panelOpen)
            Qt.callLater(refresh);
        else if (!efficiencyActionRunning && !efficiencyWaitingForGpu)
            efficiencyActionMessage = "";
    }

    function setEffectChannel(channel, value, secondary) {
        var n = Math.max(0, Math.min(255, Math.round(value)));
        if (secondary) {
            if (channel === "r")
                color2R = n;
            else if (channel === "g")
                color2G = n;
            else if (channel === "b")
                color2B = n;
        } else {
            if (channel === "r")
                colorR = n;
            else if (channel === "g")
                colorG = n;
            else if (channel === "b")
                colorB = n;
        }
    }
    function setEffectSpeed(speed) {
        currentSpeed = speed;
        applyEffect();
    }
    function setEffectDirection(direction) {
        currentDirection = direction;
        applyEffect();
    }
    function commitFanCurve(fan, points) {
        if (fan === "cpu")
            cpuFanPoints = points;
        else if (fan === "gpu")
            gpuFanPoints = points;
        else if (fan === "mid")
            midFanPoints = points;
        applyFanCurve(fan, points);
    }
    property string currentProfile: ""
    property bool profileLoaded: false
    property bool infoLoaded: false
    property var profiles: ["Quiet", "Balanced", "Performance"]
    property int profileIndex: 1
    property var acProfile: ({
            ac: "",
            battery: ""
        })
    property var supported: ({
            hasAura: false,
            hasFanCurve: false,
            hasBattery: false,
            hasProfile: false,
            auraModes: []
        })
    property bool fanCurveEnabled: false
    property int batteryLimit: 100
    property bool asusctlAvailable: false

    // Live sensors — refreshed on a faster tick than the asusctl state, since
    // temps and fan speeds are the numbers you actually watch move.
    property var sensors: ({
            cpuTemp: -1,
            cpuTotal: -1,
            cpuIdle: -1,
            gpuTemp: -1,
            gpuPower: -1,
            gpuUtil: -1,
            fanCpu: -1,
            fanGpu: -1,
            batPct: -1,
            batStatus: "",
            batPower: -1
        })
    property real previousCpuTotal: -1
    property real previousCpuIdle: -1
    property int cpuUtil: -1
    readonly property bool hasNvidia: sensors.gpuTemp >= 0

    // Low-battery efficiency suggestion. The state machine is timestamp-based,
    // so the faster sensor cadence while this panel is open cannot make the
    // five-minute threshold arrive sooner.
    property var efficiencyMonitorState: ({
            lightSinceMs: 0,
            busySinceMs: 0,
            suggested: false,
            contextActive: false
        })
    property bool efficiencySuppressed: false
    property bool efficiencyActionRunning: false
    property bool efficiencyProfilePending: false
    property bool efficiencyDisplayPending: false
    property bool efficiencyGpuPending: false
    property bool efficiencyWaitingForGpu: false
    property bool efficiencyGpuRequested: false
    property var efficiencyErrors: []
    property string efficiencyActionMessage: ""
    readonly property bool efficiencySuggested: efficiencyMonitorState.suggested === true
    readonly property bool efficiencyBannerVisible: efficiencySuggested || efficiencyActionMessage !== ""

    // Display — the built-in panel's current/available refresh rates, read
    // from Hyprland rather than asusctl (which has no display controls).
    property var monitor: null

    // Whether hyprmoncfg is installed, and whether its daemon is actively
    // managing displays. When it is, a runtime mode change has to be saved
    // back into the active profile or the daemon reverts it seconds later.
    property bool hyprmoncfgAvailable: false
    property bool hyprmoncfgManaged: false
    property string hyprmoncfgProfile: ""

    // RGB
    property string currentEffect: "static"
    property int colorR: 255
    property int colorG: 0
    property int colorB: 0
    property int color2R: 0
    property int color2G: 0
    property int color2B: 255
    property string currentSpeed: "med"
    property string currentDirection: "left"
    property bool ledAwake: true
    property bool ledBoot: true
    property bool ledSleep: true
    property string ledBrightness: "med"
    readonly property string colorHex: Aura.rgbToHex(colorR, colorG, colorB)
    readonly property string color2Hex: Aura.rgbToHex(color2R, color2G, color2B)
    readonly property color liveColor: Qt.rgba(colorR / 255, colorG / 255, colorB / 255, 1)
    readonly property color liveColor2: Qt.rgba(color2R / 255, color2G / 255, color2B / 255, 1)

    readonly property var auraSupportedEffects: Aura.supportedEffects(root.supported.auraModes)
    readonly property var effectDef: {
        for (var i = 0; i < Aura.effects.length; i++) {
            if (Aura.effects[i].id === currentEffect)
                return Aura.effects[i];
        }
        return Aura.effects[0];
    }
    readonly property bool needsColor: effectDef.params.indexOf("color") >= 0
    readonly property bool needsColor2: effectDef.params.indexOf("color2") >= 0
    readonly property bool needsSpeed: effectDef.params.indexOf("speed") >= 0
    readonly property bool needsDirection: effectDef.params.indexOf("direction") >= 0

    // Fan curves
    property bool cpuFanEnabled: false
    property bool gpuFanEnabled: false
    property bool midFanEnabled: false
    property bool hasMidFan: false
    property var cpuFanPoints: []
    property var gpuFanPoints: []
    property var midFanPoints: []
    // Which profile's curves the Fan tab is editing. asusctl stores one curve
    // set per power profile, so — like G-Helper — the editor targets a chosen
    // profile rather than silently always writing the active one.
    property string fanEditProfile: ""
    readonly property string fanProfile: fanEditProfile || currentProfile || "Balanced"

    // Armoury — armourySupported gates each Advanced control per-model, since
    // `asusctl armoury list` only reports attributes the running laptop
    // actually exposes (no dGPU / no panel overdrive on some models).
    property var armourySupported: ({
            panelOverdrive: false,
            gpuMux: false,
            dgpuDisable: false,
            pptPl1: false,
            pptPl2: false,
            nvDynBoost: false,
            nvTempTarget: false
        })
    property var armouryDefaults: ({})
    property var armouryActionQueue: []
    property string armouryActionError: ""
    property bool panelOverdrive: false
    property int gpuMuxValue: -1
    property int dgpuDisableValue: -1
    property int gpuMuxQueued: -1
    property int dgpuDisableQueued: -1
    property var gpuStatus: ({
            displayConnector: "none",
            displayDriver: "unknown",
            dgpuPresent: false,
            runtimeStatus: "unavailable",
            usersKnown: false,
            users: [],
            muxCurrent: -1,
            muxQueued: -1,
            dgpuCurrent: -1,
            dgpuQueued: -1
        })
    property string pendingGpuRequest: ""
    property string gpuConfirmMode: ""
    property string gpuActionTarget: ""
    property string gpuActionError: ""
    property var gpuActionQueue: []
    property int pptPl1: 115
    property int pptPl1Min: 25
    property int pptPl1Max: 45
    property int pptPl2: 135
    property int pptPl2Min: 35
    property int pptPl2Max: 60
    property int nvDynBoost: 25
    property int nvDynBoostMin: 0
    property int nvDynBoostMax: 25
    property int nvTempTarget: 87
    property int nvTempTargetMin: 75
    property int nvTempTargetMax: 87

    // Current firmware state and queued shutdown intent are separate. asusd
    // deliberately keeps queued values out of CurrentValue, so presenting one
    // as the other would make a pending MUX change look as though it were live.
    readonly property string currentGpuMode: Gpu.gpuModeId(gpuMuxValue, dgpuDisableValue, armourySupported.gpuMux, armourySupported.dgpuDisable)
    readonly property int effectiveGpuMux: Gpu.effectiveGpuValue(gpuMuxValue, gpuMuxQueued)
    readonly property int effectiveDgpuDisable: Gpu.effectiveGpuValue(dgpuDisableValue, dgpuDisableQueued)
    readonly property string gpuMode: Gpu.gpuModeId(effectiveGpuMux, effectiveDgpuDisable, armourySupported.gpuMux, armourySupported.dgpuDisable)
    readonly property bool gpuHasPending: gpuMuxQueued >= 0 || dgpuDisableQueued >= 0
    readonly property bool hasGpuMode: armourySupported.gpuMux || armourySupported.dgpuDisable

    property bool suggestEfficiency: true
    property int refreshInterval: 10000

    function refresh() {
        if (!active)
            return;
        if (!asusctlAvailable) {
            checkAsusctl.running = true;
            return;
        }
        if (!profileProc.running)
            profileProc.running = true;
        if (!infoProc.running)
            infoProc.running = true;
        if (supported.hasBattery && !batteryProc.running)
            batteryProc.running = true;
        if (!ledProc.running)
            ledProc.running = true;
        if (!armouryProc.running)
            armouryProc.running = true;
        if (!gpuStatusProc.running)
            gpuStatusProc.running = true;
        if (!monitorProc.running)
            monitorProc.running = true;
        if (hyprmoncfgAvailable && !hyprmoncfgProc.running)
            hyprmoncfgProc.running = true;
        if (supported.hasFanCurve) {
            if (!fanDetailProc.running)
                fanDetailProc.running = true;
        }
    }

    function setProfile(p) {
        if (!p || actionProc.running)
            return;
        actionProc.command = ["asusctl", "profile", "set", p];
        actionProc.running = true;
    }
    function cycleProfile(d) {
        profileIndex = Numbers.selectProfileIndex(profileIndex, d, profiles);
        setProfile(profiles[profileIndex]);
    }

    function applyEffect() {
        if (!supported.hasAura)
            return;
        var params = {};
        if (needsColor)
            params.color = colorHex;
        if (needsColor2)
            params.color2 = color2Hex;
        if (needsSpeed)
            params.speed = currentSpeed;
        if (needsDirection)
            params.direction = currentDirection;
        actionProc.command = Aura.buildAuraCommand(currentEffect, params);
        actionProc.running = true;
    }
    function selectEffect(id) {
        currentEffect = id;
        applyEffect();
    }
    function setPresetColor(hex) {
        var r = Aura.hexToRgb(hex);
        colorR = r.r;
        colorG = r.g;
        colorB = r.b;
        applyEffect();
    }
    function setPresetColor2(hex) {
        var r = Aura.hexToRgb(hex);
        color2R = r.r;
        color2G = r.g;
        color2B = r.b;
        applyEffect();
    }

    // power-tuf takes all three states in one call, so each toggle resends the
    // full triple — sending only the changed flag makes asusctl default the
    // omitted ones back to false.
    function applyLedPower() {
        actionProc.command = ["asusctl", "aura", "power-tuf", "--awake", ledAwake ? "true" : "false", "--keyboard", "--boot", ledBoot ? "true" : "false", "--sleep", ledSleep ? "true" : "false"];
        actionProc.running = true;
    }
    function setLedPower(on) {
        ledAwake = on;
        applyLedPower();
    }
    function setLedBoot(on) {
        ledBoot = on;
        applyLedPower();
    }
    function setLedSleep(on) {
        ledSleep = on;
        applyLedPower();
    }
    function setLedBrightness(level) {
        ledBrightness = level;
        actionProc.command = ["asusctl", "leds", "set", level];
        actionProc.running = true;
    }
    function setBatteryLimit(l) {
        if (!supported.hasBattery)
            return;
        var c = Math.max(20, Math.min(100, Math.round(l)));
        actionProc.command = ["asusctl", "battery", "limit", String(c)];
        actionProc.running = true;
    }

    // Fan curves — every write is gated on profileLoaded so an action never
    // silently lands on the wrong (hardcoded "Balanced") profile because the
    // real active profile hadn't loaded yet. This was the root cause of fan
    // controls appearing to "not work sometimes".
    function toggleFanCurves() {
        if (!supported.hasFanCurve || !profileLoaded)
            return;
        var n = !fanCurveEnabled;
        actionProc.command = ["asusctl", "fan-curve", "--mod-profile", fanProfile, "--enable-fan-curves", n ? "true" : "false"];
        actionProc.running = true;
    }
    function toggleCpuFan() {
        if (!profileLoaded)
            return;
        var n = !cpuFanEnabled;
        actionProc.command = ["asusctl", "fan-curve", "--mod-profile", fanProfile, "--enable-fan-curve", n ? "true" : "false", "--fan", "cpu"];
        actionProc.running = true;
    }
    function toggleGpuFan() {
        if (!profileLoaded)
            return;
        var n = !gpuFanEnabled;
        actionProc.command = ["asusctl", "fan-curve", "--mod-profile", fanProfile, "--enable-fan-curve", n ? "true" : "false", "--fan", "gpu"];
        actionProc.running = true;
    }
    function toggleMidFan() {
        if (!profileLoaded || !hasMidFan)
            return;
        var n = !midFanEnabled;
        actionProc.command = ["asusctl", "fan-curve", "--mod-profile", fanProfile, "--enable-fan-curve", n ? "true" : "false", "--fan", "mid"];
        actionProc.running = true;
    }
    function resetFanCurves() {
        if (!profileLoaded)
            return;
        actionProc.command = ["asusctl", "fan-curve", "--mod-profile", fanProfile, "--default"];
        actionProc.running = true;
    }
    function applyFanCurve(fan, points) {
        if (!profileLoaded || actionProc.running)
            return;
        actionProc.command = ["asusctl", "fan-curve", "--mod-profile", fanProfile, "--fan", fan, "--data", FanCurves.serializeFanPoints(points)];
        actionProc.running = true;
    }
    function selectFanProfile(p) {
        if (!p || p === fanProfile)
            return;
        fanEditProfile = p;
        if (!fanModProc.running)
            fanModProc.running = true;
    }

    function setArmouryAttr(a, v) {
        armouryActionError = "";
        armouryActionQueue = armouryActionQueue.concat([["asusctl", "armoury", "set", a, String(v)]]);
        runNextArmouryAction();
    }
    function runNextArmouryAction() {
        if (armouryActionProc.running || gpuActionProc.running || gpuActionQueue.length > 0)
            return;
        if (armouryActionQueue.length === 0) {
            if (!armouryProc.running)
                armouryProc.running = true;
            return;
        }
        var queue = armouryActionQueue.slice(0);
        armouryActionProc.command = queue.shift();
        armouryActionQueue = queue;
        armouryActionProc.running = true;
    }
    function finishArmouryAction(ec) {
        if (ec !== 0)
            armouryActionError = "Could not apply a firmware setting (asusctl exit " + ec + ").";
        Qt.callLater(root.runNextArmouryAction);
    }
    function togglePanelOverdrive() {
        panelOverdrive = !panelOverdrive;
        setArmouryAttr("panel_overdrive", panelOverdrive ? 1 : 0);
    }
    function setPptPl1(v) {
        pptPl1 = Math.round(v);
        setArmouryAttr("ppt_pl1_spl", pptPl1);
    }
    function setPptPl2(v) {
        pptPl2 = Math.round(v);
        setArmouryAttr("ppt_pl2_sppt", pptPl2);
    }
    function setNvDynBoost(v) {
        nvDynBoost = Math.round(v);
        setArmouryAttr("nv_dynamic_boost", nvDynBoost);
    }
    function setNvTempTarget(v) {
        nvTempTarget = Math.round(v);
        setArmouryAttr("nv_temp_target", nvTempTarget);
    }
    // Firmware ships a sane default per attribute; `asusctl armoury list`
    // reports it, so "Defaults" is just replaying those values.
    function restorePowerDefaults() {
        var d = root.armouryDefaults;
        if (d.ppt_pl1_spl !== undefined)
            setPptPl1(d.ppt_pl1_spl);
        if (d.ppt_pl2_sppt !== undefined)
            setPptPl2(d.ppt_pl2_sppt);
        if (d.nv_dynamic_boost !== undefined)
            setNvDynBoost(d.nv_dynamic_boost);
        if (d.nv_temp_target !== undefined)
            setNvTempTarget(d.nv_temp_target);
    }

    // GPU writes are serialized because a mode can require two attributes.
    // Integrated is preflighted against real device users immediately before
    // queueing; a busy or uninspectable dGPU requires a second explicit click.
    function requestGpuMode(id) {
        if (!id || gpuActionProc.running || gpuActionQueue.length > 0 || armouryActionProc.running || armouryActionQueue.length > 0 || actionProc.running)
            return;
        gpuActionError = "";
        gpuConfirmMode = "";
        if (id === "eco" && effectiveDgpuDisable !== 1) {
            pendingGpuRequest = id;
            if (!gpuStatusProc.running)
                gpuStatusProc.running = true;
            return;
        }
        queueGpuMode(id);
    }

    function finishGpuPreflight() {
        if (pendingGpuRequest === "")
            return;
        var id = pendingGpuRequest;
        pendingGpuRequest = "";
        if (Gpu.gpuDisableNeedsConfirmation(id, effectiveDgpuDisable, gpuStatus)) {
            gpuConfirmMode = id;
            if (efficiencyWaitingForGpu) {
                efficiencyActionRunning = false;
                efficiencyActionMessage = "Quiet and display savings applied. Review NVIDIA use below to finish switching.";
            }
            return;
        }
        queueGpuMode(id);
    }

    function confirmGpuMode() {
        var id = gpuConfirmMode;
        gpuConfirmMode = "";
        if (id && efficiencyWaitingForGpu) {
            efficiencyActionRunning = true;
            efficiencyActionMessage = "Finishing efficiency settings…";
        }
        if (id)
            queueGpuMode(id);
    }

    function queueGpuMode(id) {
        if (gpuActionProc.running || gpuActionQueue.length > 0 || armouryActionProc.running || armouryActionQueue.length > 0 || actionProc.running)
            return;
        var commands = Gpu.gpuModeCommands(effectiveGpuMux, effectiveDgpuDisable, id, armourySupported.gpuMux, armourySupported.dgpuDisable);
        if (commands.length === 0) {
            if (efficiencyWaitingForGpu) {
                addEfficiencyError("Integrated graphics could not be queued.");
                finishEfficiencyAction(false);
            }
            return;
        }
        gpuActionTarget = id;
        gpuActionQueue = commands;
        runNextGpuAction();
    }

    function runNextGpuAction() {
        if (gpuActionProc.running)
            return;
        if (gpuActionQueue.length === 0) {
            gpuActionTarget = "";
            runNextArmouryAction();
            if (!gpuStatusProc.running)
                gpuStatusProc.running = true;
            if (!armouryProc.running)
                armouryProc.running = true;
            if (efficiencyWaitingForGpu)
                finishEfficiencyAction(true);
            return;
        }
        var queue = gpuActionQueue.slice(0);
        gpuActionProc.command = queue.shift();
        gpuActionQueue = queue;
        gpuActionProc.running = true;
    }

    function keepCurrentGpuMode() {
        gpuConfirmMode = "";
        queueGpuMode(currentGpuMode);
    }

    // Applying a refresh rate is two steps where hyprmoncfg is managing
    // displays: change it live, then persist it into the daemon's active
    // profile. Without that second step hyprmoncfgd re-applies its saved
    // profile a few seconds later and the change silently reverts. On a
    // machine without the daemon the first step alone is the whole job.
    function setRefreshRate(hz) {
        if (!monitor || displayProc.running || hyprmoncfgSaveProc.running)
            return;
        displayProc.command = Display.monitorCommand(monitor, hz);
        displayProc.running = true;
    }

    function updateEfficiencyMonitor(nextSensors, nextCpuUtil, nowMs) {
        var state = Efficiency.nextEfficiencyState(efficiencyMonitorState, {
            enabled: suggestEfficiency,
            suppressed: efficiencySuppressed,
            batteryPct: nextSensors.batPct,
            batteryStatus: nextSensors.batStatus,
            cpuUtil: nextCpuUtil,
            gpuUtil: nextSensors.gpuUtil,
            gpuPower: nextSensors.gpuPower,
            gpuMode: currentGpuMode,
            profile: currentProfile,
            refreshRate: monitor ? monitor.rate : -1,
            customFanCurve: fanCurveEnabled
        }, nowMs);
        efficiencyMonitorState = state;
        if (!state.contextActive) {
            efficiencySuppressed = false;
            if (!efficiencyActionRunning)
                efficiencyActionMessage = "";
        }
    }

    function efficiencyQuietProfile() {
        for (var i = 0; i < profiles.length; i++)
            if (Platform.profileLabel(profiles[i]) === "Quiet")
                return profiles[i];
        return "Quiet";
    }

    function efficiencyRefreshRate() {
        if (!monitor || !monitor.rates || monitor.rates.length === 0)
            return -1;
        for (var i = 0; i < monitor.rates.length; i++)
            if (Number(monitor.rates[i]) === 60)
                return 60;
        return Number(monitor.rates[0]);
    }

    function addEfficiencyError(message) {
        var next = efficiencyErrors.slice(0);
        next.push(message);
        efficiencyErrors = next;
    }

    function switchToEfficiency() {
        if (efficiencyActionRunning || actionProc.running || efficiencyProfileProc.running || displayProc.running || hyprmoncfgSaveProc.running || gpuActionProc.running || gpuActionQueue.length > 0 || pendingGpuRequest !== "" || armouryActionProc.running || armouryActionQueue.length > 0)
            return;
        efficiencyErrors = [];
        efficiencySuppressed = true;
        efficiencyActionRunning = true;
        efficiencyActionMessage = "Applying efficiency settings…";
        efficiencyProfilePending = Platform.profileLabel(currentProfile) !== "Quiet";

        var targetRate = efficiencyRefreshRate();
        efficiencyDisplayPending = targetRate > 0 && monitor && Number(monitor.rate) !== targetRate;
        if (monitor && targetRate > 60)
            addEfficiencyError("60 Hz is unavailable.");

        efficiencyGpuPending = Gpu.gpuModeAvailable("eco", armourySupported.gpuMux, armourySupported.dgpuDisable) && gpuMode !== "eco";
        efficiencyGpuRequested = efficiencyGpuPending || (currentGpuMode !== "eco" && gpuMode === "eco");
        if (hasGpuMode && !Gpu.gpuModeAvailable("eco", armourySupported.gpuMux, armourySupported.dgpuDisable))
            addEfficiencyError("Integrated-only mode is unavailable.");

        if (efficiencyProfilePending) {
            efficiencyProfileProc.command = ["asusctl", "profile", "set", efficiencyQuietProfile()];
            efficiencyProfileProc.running = true;
        }
        if (efficiencyDisplayPending) {
            displayProc.command = Display.monitorCommand(monitor, targetRate);
            displayProc.running = true;
        }
        maybeContinueEfficiencyAction();
    }

    function maybeContinueEfficiencyAction() {
        if (!efficiencyActionRunning || efficiencyProfilePending || efficiencyDisplayPending)
            return;
        if (efficiencyGpuPending) {
            efficiencyGpuPending = false;
            efficiencyWaitingForGpu = true;
            requestGpuMode("eco");
            return;
        }
        finishEfficiencyAction(false);
    }

    function finishEfficiencyAction(gpuQueued) {
        efficiencyActionRunning = false;
        efficiencyProfilePending = false;
        efficiencyDisplayPending = false;
        efficiencyGpuPending = false;
        efficiencyWaitingForGpu = false;
        efficiencyMonitorState = ({
                lightSinceMs: 0,
                busySinceMs: 0,
                suggested: false,
                contextActive: true
            });
        if (efficiencyErrors.length > 0) {
            efficiencyActionMessage = "Efficiency partly applied. " + efficiencyErrors.join(" ");
        } else if (gpuQueued || efficiencyGpuRequested) {
            efficiencyActionMessage = "Efficiency applied. Integrated graphics will take effect after restart.";
        } else {
            efficiencyActionMessage = "Efficiency applied.";
        }
    }

    function cancelGpuMode() {
        gpuConfirmMode = "";
        if (efficiencyWaitingForGpu) {
            efficiencyWaitingForGpu = false;
            efficiencyActionRunning = false;
            efficiencyActionMessage = "Quiet and display savings applied. Integrated graphics was not queued.";
        }
    }

    Component.onCompleted: {
        if (active) {
            checkAsusctl.running = true;
            checkHyprmoncfg.running = true;
        }
    }

    resources: [
        Process {
            id: checkAsusctl
            command: ["which", "asusctl"]
            onExited: function (ec) {
                root.asusctlAvailable = ec === 0;
                if (root.asusctlAvailable)
                    refresh();
            }
        },
        Process {
            id: profileProc
            command: ["asusctl", "profile", "get"]
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    var p = Platform.parseCurrentProfile(text);
                    if (p) {
                        root.currentProfile = p;
                        var i = root.profiles.indexOf(p);
                        if (i >= 0)
                            root.profileIndex = i;
                    }
                    root.acProfile = Platform.parseProfiles(text);
                    root.profileLoaded = true;
                }
            }
        },
        Process {
            id: infoProc
            command: ["asusctl", "info", "--show-supported"]
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    root.supported = Platform.parseSupportedFeatures(text);
                    root.infoLoaded = true;
                }
            }
        },
        Process {
            id: batteryProc
            command: ["asusctl", "battery", "info"]
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    root.batteryLimit = Platform.parseBatteryInfo(text).limit;
                }
            }
        },
        Process {
            id: ledProc
            command: ["asusctl", "leds", "get"]
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    root.ledBrightness = Aura.parseLedBrightness(text);
                }
            }
        },
        Process {
            id: fanDetailProc
            command: ["asusctl", "fan-curve", "--get-enabled"]
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    var info = FanCurves.parseFanCurves(text);
                    root.cpuFanEnabled = info.cpuEnabled;
                    root.gpuFanEnabled = info.gpuEnabled;
                    root.hasMidFan = info.hasMid;
                    root.midFanEnabled = info.midEnabled;
                    root.cpuFanPoints = info.cpuPoints;
                    root.gpuFanPoints = info.gpuPoints;
                    root.midFanPoints = info.midPoints;
                    root.fanCurveEnabled = info.cpuEnabled || info.gpuEnabled || (info.hasMid && info.midEnabled);
                    // Also fetch detailed curve data
                    if (!fanModProc.running)
                        fanModProc.running = true;
                }
            }
        },
        Process {
            id: fanModProc
            command: ["asusctl", "fan-curve", "--mod-profile", root.fanProfile]
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    var info = FanCurves.parseFanCurves(text);
                    if (info.cpuPoints.length > 0)
                        root.cpuFanPoints = info.cpuPoints;
                    if (info.gpuPoints.length > 0)
                        root.gpuFanPoints = info.gpuPoints;
                    if (info.midPoints.length > 0) {
                        root.midFanPoints = info.midPoints;
                        root.hasMidFan = true;
                    }
                }
            }
        },
        Process {
            id: armouryProc
            command: ["asusctl", "armoury", "list"]
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    var a = Platform.parseArmoury(text);
                    root.armourySupported = a.supported;
                    root.armouryDefaults = a.defaults;
                    var v = a.values, r = a.ranges;
                    if (v.panel_overdrive !== undefined)
                        root.panelOverdrive = v.panel_overdrive === 1;
                    if (v.gpu_mux_mode !== undefined)
                        root.gpuMuxValue = v.gpu_mux_mode;
                    if (v.dgpu_disable !== undefined)
                        root.dgpuDisableValue = v.dgpu_disable;
                    if (v.ppt_pl1_spl !== undefined)
                        root.pptPl1 = v.ppt_pl1_spl;
                    if (r.ppt_pl1_spl) {
                        root.pptPl1Min = r.ppt_pl1_spl.min;
                        root.pptPl1Max = r.ppt_pl1_spl.max;
                    }
                    if (v.ppt_pl2_sppt !== undefined)
                        root.pptPl2 = v.ppt_pl2_sppt;
                    if (r.ppt_pl2_sppt) {
                        root.pptPl2Min = r.ppt_pl2_sppt.min;
                        root.pptPl2Max = r.ppt_pl2_sppt.max;
                    }
                    if (v.nv_dynamic_boost !== undefined)
                        root.nvDynBoost = v.nv_dynamic_boost;
                    if (r.nv_dynamic_boost) {
                        root.nvDynBoostMin = r.nv_dynamic_boost.min;
                        root.nvDynBoostMax = r.nv_dynamic_boost.max;
                    }
                    if (v.nv_temp_target !== undefined)
                        root.nvTempTarget = v.nv_temp_target;
                    if (r.nv_temp_target) {
                        root.nvTempTargetMin = r.nv_temp_target.min;
                        root.nvTempTargetMax = r.nv_temp_target.max;
                    }
                }
            }
        },
        Process {
            id: gpuStatusProc
            command: Gpu.gpuStatusCommand()
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    var state = Gpu.parseGpuStatus(text);
                    root.gpuStatus = state;
                    if (state.muxCurrent >= 0)
                        root.gpuMuxValue = state.muxCurrent;
                    if (state.dgpuCurrent >= 0)
                        root.dgpuDisableValue = state.dgpuCurrent;
                    root.gpuMuxQueued = state.muxQueued;
                    root.dgpuDisableQueued = state.dgpuQueued;
                }
            }
            onExited: function () {
                Qt.callLater(root.finishGpuPreflight);
            }
        },
        Process {
            id: monitorProc
            command: ["hyprctl", "-j", "monitors"]
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    var m = Display.parseMonitors(text);
                    if (m)
                        root.monitor = m;
                }
            }
        },
        Process {
            id: checkHyprmoncfg
            command: ["which", "hyprmoncfg"]
            onExited: function (ec) {
                root.hyprmoncfgAvailable = ec === 0;
                if (root.hyprmoncfgAvailable && !hyprmoncfgProc.running)
                    hyprmoncfgProc.running = true;
            }
        },
        // Re-read on every refresh: the active profile changes when monitors are
        // plugged or unplugged, and saving into a stale profile name would either
        // fail or overwrite the wrong one.
        Process {
            id: hyprmoncfgProc
            command: ["hyprmoncfg", "status", "--json"]
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    var s = Display.parseHyprmoncfgStatus(text);
                    root.hyprmoncfgManaged = s.managed;
                    root.hyprmoncfgProfile = s.profile;
                }
            }
        },
        Process {
            id: displayProc
            onExited: function (ec) {
                if (ec !== 0 && root.efficiencyDisplayPending) {
                    root.addEfficiencyError("The display refresh rate could not be changed.");
                    root.efficiencyDisplayPending = false;
                    root.maybeContinueEfficiencyAction();
                }
                if (ec === 0 && root.hyprmoncfgManaged && root.hyprmoncfgProfile !== "" && !hyprmoncfgSaveProc.running) {
                    hyprmoncfgSaveProc.command = ["hyprmoncfg", "save", root.hyprmoncfgProfile];
                    hyprmoncfgSaveProc.running = true;
                    return;
                }
                if (root.efficiencyDisplayPending) {
                    root.efficiencyDisplayPending = false;
                    root.maybeContinueEfficiencyAction();
                }
                if (!monitorProc.running)
                    monitorProc.running = true;
            }
        },
        Process {
            id: hyprmoncfgSaveProc
            onExited: function (ec) {
                if (root.efficiencyDisplayPending) {
                    if (ec !== 0)
                        root.addEfficiencyError("The 60 Hz monitor profile could not be saved.");
                    root.efficiencyDisplayPending = false;
                    root.maybeContinueEfficiencyAction();
                }
                if (!monitorProc.running)
                    monitorProc.running = true;
            }
        },
        Process {
            id: sensorProc
            command: Telemetry.sensorCommand()
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    var next = Telemetry.parseSensors(text);
                    var util = Telemetry.cpuUtilization(root.previousCpuTotal, root.previousCpuIdle, next.cpuTotal, next.cpuIdle);
                    root.previousCpuTotal = next.cpuTotal;
                    root.previousCpuIdle = next.cpuIdle;
                    root.cpuUtil = util;
                    root.sensors = next;
                    root.updateEfficiencyMonitor(next, util, Date.now());
                }
            }
        },
        Process {
            id: efficiencyProfileProc
            onExited: function (ec) {
                if (ec !== 0)
                    root.addEfficiencyError("Quiet mode could not be applied.");
                root.efficiencyProfilePending = false;
                if (!profileProc.running)
                    profileProc.running = true;
                root.maybeContinueEfficiencyAction();
            }
        },
        Process {
            id: gpuActionProc
            onExited: function (ec) {
                if (ec !== 0) {
                    root.gpuActionError = "Could not schedule the GPU change (asusctl exit " + ec + ").";
                    root.gpuActionQueue = [];
                    root.gpuActionTarget = "";
                    if (root.efficiencyWaitingForGpu) {
                        root.addEfficiencyError("Integrated graphics could not be queued.");
                        root.finishEfficiencyAction(false);
                    }
                    root.runNextArmouryAction();
                    if (!gpuStatusProc.running)
                        gpuStatusProc.running = true;
                    return;
                }
                Qt.callLater(root.runNextGpuAction);
            }
        },
        Process {
            id: armouryActionProc
            onExited: function (ec) {
                root.finishArmouryAction(ec);
            }
        },
        Process {
            id: actionProc
            onExited: function () {
                if (!profileProc.running)
                    profileProc.running = true;
                if (!batteryProc.running)
                    batteryProc.running = true;
                if (!ledProc.running)
                    ledProc.running = true;
                if (!armouryProc.running)
                    armouryProc.running = true;
                if (!monitorProc.running)
                    monitorProc.running = true;
                if (!fanDetailProc.running)
                    fanDetailProc.running = true;
            }
        },
        Timer {
            interval: root.refreshInterval
            running: root.active && root.panelOpen && root.asusctlAvailable
            repeat: true
            onTriggered: root.refresh()
        },

        // Sensors run on their own, faster tick — the asusctl round-trip is much
        // heavier and its values barely move. Backs off while the panel is closed,
        // where the readings only feed the bar tooltip.
        Timer {
            interval: root.panelOpen ? 2000 : 20000
            running: root.active && root.asusctlAvailable
            repeat: true
            triggeredOnStart: true
            onTriggered: if (!sensorProc.running)
                sensorProc.running = true
        }
    ]
}
