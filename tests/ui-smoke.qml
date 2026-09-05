import QtQuick
import QtQuick.Window
import Quickshell
import "Plugin" as Plugin
import "Plugin/ui" as Views

ShellRoot {
    id: test
    property int stage: 0
    property var tabs: [main, rgb, fan, advanced]
    property var pluginPanel: null

    Plugin.AsusController {
        id: backend
        active: false
        asusctlAvailable: true
        currentProfile: "Performance"
        profileLoaded: true
        infoLoaded: true
        supported: ({
                hasAura: true,
                hasFanCurve: true,
                hasBattery: true,
                hasProfile: true,
                auraModes: ["Static", "Breathe"]
            })
        armourySupported: ({
                gpuMux: true,
                dgpuDisable: true,
                panelOverdrive: true,
                pptPl1: true,
                pptPl2: true,
                nvDynBoost: true,
                nvTempTarget: true
            })
        gpuMuxValue: 0
        dgpuDisableValue: 0
        monitor: ({
                name: "eDP-1",
                width: 2560,
                height: 1600,
                x: 0,
                y: 0,
                scale: 1,
                rate: 240,
                rates: [60, 240]
            })
        sensors: ({
                cpuTemp: 55,
                cpuTotal: 10000,
                cpuIdle: 9000,
                gpuTemp: 45,
                gpuUtil: 3,
                gpuPower: 8,
                fanCpu: 2400,
                fanGpu: 2500,
                batPct: 25,
                batStatus: "Discharging",
                batPower: 18
            })
        cpuFanPoints: [
            {
                temp: 30,
                speed: 0
            },
            {
                temp: 60,
                speed: 30
            },
            {
                temp: 90,
                speed: 100
            }
        ]
        gpuFanPoints: cpuFanPoints
        midFanPoints: cpuFanPoints
        cpuFanEnabled: true
        gpuFanEnabled: true
        midFanEnabled: true
        hasMidFan: true
        fanCurveEnabled: true
        ledAwake: false
    }

    QtObject {
        id: bar
        property color foreground: "#cacccc"
        property color background: "#101315"
        property string fontFamily: "monospace"
        property color barForeground: foreground
        property color urgent: "#a55555"
        property bool vertical: false
        property int barSize: 28
        property string position: "top"
        property bool foregroundAnimationEnabled: false
        function hideTooltip(item) {
        }
    }

    Window {
        id: window
        visible: Quickshell.env("QT_QPA_PLATFORM") === "offscreen"
        width: 420
        height: 1100
        color: bar.background
        Views.MainTab {
            id: main
            width: parent.width - 24
            x: 12
            y: 12
            controller: backend
            bar: bar
        }
        Views.RgbTab {
            id: rgb
            visible: false
            width: main.width
            x: 12
            y: 12
            controller: backend
            bar: bar
        }
        Views.FanTab {
            id: fan
            visible: false
            width: main.width
            x: 12
            y: 12
            controller: backend
            bar: bar
        }
        Views.AdvancedTab {
            id: advanced
            visible: false
            width: main.width
            x: 12
            y: 12
            controller: backend
            bar: bar
        }
    }

    function verify(condition, message) {
        if (!condition) {
            console.error("SMOKE_FAIL: " + message);
            Qt.quit();
        }
        return condition;
    }

    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            if (test.stage === 0) {
                backend.updateEfficiencyMonitor(backend.sensors, 5, 1000);
                backend.updateEfficiencyMonitor(backend.sensors, 5, 301000);
                if (!test.verify(backend.efficiencySuggested, "efficiency state binding"))
                    return;
                backend.setEffectChannel("r", 17, false);
                if (!test.verify(backend.colorHex === "110000", "RGB channel action"))
                    return;
                // Compile the entry point too, without instantiating its live controller.
                if (Quickshell.env("QT_QPA_PLATFORM") === "wayland") {
                    var component = Qt.createComponent("Plugin/Panel.qml");
                    if (!test.verify(component.status === Component.Ready, component.errorString()))
                        return;
                    test.pluginPanel = component.createObject(window.contentItem, {
                        active: false,
                        bar: bar
                    });
                    if (!test.verify(test.pluginPanel !== null, "entry point construction"))
                        return;
                }
            }
            if (test.stage < 8) {
                var index = test.stage % 4;
                for (var i = 0; i < test.tabs.length; i++)
                    test.tabs[i].visible = i === index;
                if (test.stage === 4) {
                    bar.foreground = "#202020";
                    bar.background = "#fafafa";
                }
                if (test.pluginPanel)
                    test.pluginPanel.tabKey = ["main", "rgb", "fan", "advanced"][index];
                if (!test.verify(test.tabs[index].implicitHeight > 0, "empty tab " + index))
                    return;
                // Queue and confirmation views must remain reactive after extraction.
                backend.gpuMuxQueued = 1;
                backend.dgpuDisableQueued = 1;
                backend.gpuConfirmMode = "eco";
                test.stage++;
            } else {
                if (!test.verify(backend.gpuMode === "eco" && backend.currentGpuMode === "ultimate", "current vs queued GPU mode"))
                    return;
                for (var j = 0; j < backend.resources.length; j++)
                    if (!test.verify(backend.resources[j].running !== true, "disabled controller started I/O"))
                        return;
                console.log("SMOKE_OK: four tabs, two palettes, controller bindings (" + Quickshell.env("QT_QPA_PLATFORM") + ")");
                Qt.quit();
            }
        }
    }
}
