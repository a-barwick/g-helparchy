import QtQuick
import ".." as Backend
import qs.Commons
import qs.Ui
import "../logic/Platform.js" as Platform
import "../logic/Gpu.js" as Gpu
import "Format.js" as Format

Column {
    id: view
    required property Backend.AsusController controller
    required property QtObject bar
    property bool showBatteryLimit: true
    property bool cursorActive: false
    property int hoveredProfileIndex: -1
    spacing: Style.space(12)

    // LIVE SENSORS — G-Helper's home screen leads with temps
    // and fan speeds, so this sits above the controls. Tiles
    // for hardware that reports nothing stay hidden rather
    // than showing a dash forever.
    Grid {
        id: sensorGrid
        width: parent.width
        columns: 2
        spacing: Style.space(6)
        readonly property real cw: (width - spacing) / 2

        SensorTile {
            width: sensorGrid.cw
            caption: "CPU"
            tip: "Package temperature and the CPU fan's current speed.\nSustained load on this laptop settles around 80–95 °C."
            value: Format.fmtTemp(view.controller.sensors.cpuTemp)
            sub: Format.fmtRpm(view.controller.sensors.fanCpu)
            valueColor: Format.tempColor(view.controller.sensors.cpuTemp)
            foreground: view.bar.foreground
            fontFamily: view.bar.fontFamily
        }
        SensorTile {
            visible: view.controller.hasNvidia
            width: sensorGrid.cw
            caption: "GPU"
            tip: "Discrete GPU temperature, its fan speed, and how busy it is.\nIdles near 0% when nothing is using the dGPU."
            value: Format.fmtTemp(view.controller.sensors.gpuTemp)
            sub: Format.fmtRpm(view.controller.sensors.fanGpu) + (view.controller.sensors.gpuUtil >= 0 ? "   " + view.controller.sensors.gpuUtil + "%" : "")
            valueColor: Format.tempColor(view.controller.sensors.gpuTemp)
            foreground: view.bar.foreground
            fontFamily: view.bar.fontFamily
        }
        SensorTile {
            visible: view.controller.sensors.batPct >= 0
            width: sensorGrid.cw
            caption: "BATTERY"
            tip: "Charge level, whether it is charging, and the current\nflow in watts — draw when discharging, fill rate when charging."
            value: view.controller.sensors.batPct + "%"
            sub: view.controller.sensors.batStatus + (view.controller.sensors.batPower > 0 ? "   " + Format.fmtWatts(view.controller.sensors.batPower) : "")
            valueColor: view.controller.sensors.batPct <= 15 && view.controller.sensors.batStatus !== "Charging" ? "#ff4444" : view.bar.foreground
            foreground: view.bar.foreground
            fontFamily: view.bar.fontFamily
        }
        SensorTile {
            visible: view.controller.hasNvidia && view.controller.sensors.gpuPower >= 0
            width: sensorGrid.cw
            caption: "GPU POWER"
            tip: "Watts the discrete GPU is currently drawing, and the\ndynamic boost ceiling set on the Advanced tab."
            value: view.controller.sensors.gpuPower + " W"
            sub: "boost " + view.controller.nvDynBoost + "W"
            valueColor: view.bar.foreground
            foreground: view.bar.foreground
            fontFamily: view.bar.fontFamily
        }
    }

    Rectangle {
        id: efficiencyBanner
        visible: view.controller.efficiencyBannerVisible
        width: parent.width
        implicitHeight: efficiencyBannerColumn.implicitHeight + Style.space(12)
        radius: Style.cornerRadius
        color: Qt.rgba(1, 0.65, 0.2, 0.08)
        border.width: 1
        border.color: Qt.rgba(1, 0.65, 0.2, 0.28)

        Column {
            id: efficiencyBannerColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(6)
            spacing: Style.space(5)
            Text {
                width: parent.width
                text: view.controller.efficiencyActionMessage !== "" ? view.controller.efficiencyActionMessage : "High-power settings during light use."
                wrapMode: Text.WordWrap
                color: "#ffb347"
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
            }
            Text {
                visible: view.controller.efficiencyActionMessage === ""
                width: parent.width
                text: "Quiet, 60 Hz, and Integrated graphics can stretch the remaining battery."
                wrapMode: Text.WordWrap
                color: Qt.darker(view.bar.foreground, 1.4)
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.caption
            }
            Button {
                visible: view.controller.efficiencyActionMessage === ""
                width: parent.width
                enabled: !view.controller.efficiencyActionRunning
                text: "Switch to Efficiency"
                tooltipText: "Apply Quiet and 60 Hz now, then safely queue Integrated graphics when supported."
                fontSize: Style.font.bodySmall
                foreground: view.bar.foreground
                fontFamily: view.bar.fontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY
                bordered: true
                onClicked: view.controller.switchToEfficiency()
            }
        }
    }

    Column {
        width: parent.width
        spacing: Style.space(8)
        PanelSeparator {
            foreground: view.bar.foreground
        }
        PanelSectionHeader {
            text: "PERFORMANCE MODE"
            foreground: view.bar.foreground
            fontFamily: view.bar.fontFamily
        }
        Row {
            id: pRow
            width: parent.width
            spacing: Style.space(4)
            readonly property real cw: view.controller.profiles.length > 0 ? (width - spacing * (view.controller.profiles.length - 1)) / view.controller.profiles.length : 0
            Repeater {
                model: view.controller.profiles
                Button {
                    required property var modelData
                    required property int index
                    width: pRow.cw
                    iconText: Platform.profileIcon(String(modelData))
                    iconSize: Style.font.title
                    text: String(modelData)
                    tooltipText: Platform.profileDescription(String(modelData))
                    fontSize: Style.font.bodySmall
                    foreground: view.controller.currentProfile === modelData ? Platform.profileColor(String(modelData)) : view.bar.foreground
                    fontFamily: view.bar.fontFamily
                    horizontalPadding: Style.spacing.controlPaddingX
                    verticalPadding: Style.spacing.controlPaddingY
                    bordered: true
                    active: view.controller.currentProfile === modelData
                    hasCursor: view.cursorActive && view.hoveredProfileIndex === index
                    onClicked: view.controller.setProfile(modelData)
                    onHovered: function (h) {
                        if (h) {
                            view.cursorActive = true;
                            view.hoveredProfileIndex = index;
                        }
                    }
                }
            }
        }
    }

    // GPU MODE — firmware intent, real display ownership, and
    // Linux runtime state are shown independently.
    Column {
        visible: view.controller.hasGpuMode
        width: parent.width
        spacing: Style.space(8)
        PanelSeparator {
            foreground: view.bar.foreground
        }
        PanelSectionHeader {
            text: "GPU MODE — APPLIES AT SHUTDOWN"
            foreground: view.bar.foreground
            fontFamily: view.bar.fontFamily
        }
        Row {
            id: gRow
            width: parent.width
            spacing: Style.space(4)
            readonly property real cw: (width - spacing * 2) / 3
            Repeater {
                model: Gpu.gpuModes
                Button {
                    required property var modelData
                    width: gRow.cw
                    // Ultimate needs the mux; hiding it outright would
                    // shuffle the row, so it is disabled instead.
                    enabled: view.controller.canRequestGpuMode && Gpu.gpuModeAvailable(modelData.id, view.controller.armourySupported.gpuMux, view.controller.armourySupported.dgpuDisable)
                    opacity: enabled ? 1 : 0.4
                    iconText: modelData.icon
                    iconSize: Style.font.title
                    text: modelData.name
                    tooltipText: !Gpu.gpuModeAvailable(modelData.id, view.controller.armourySupported.gpuMux, view.controller.armourySupported.dgpuDisable) ? modelData.tip + "\n\nNot available: this laptop does not expose the required firmware attribute." : modelData.tip
                    fontSize: Style.font.bodySmall
                    foreground: view.bar.foreground
                    fontFamily: view.bar.fontFamily
                    horizontalPadding: Style.spacing.controlPaddingX
                    verticalPadding: Style.spacing.controlPaddingY
                    bordered: true
                    active: view.controller.gpuMode === modelData.id
                    onClicked: view.controller.requestGpuMode(modelData.id)
                }
            }
        }

        Rectangle {
            width: parent.width
            implicitHeight: gpuStateColumn.implicitHeight + Style.space(12)
            radius: Style.cornerRadius
            color: Qt.rgba(view.bar.foreground.r, view.bar.foreground.g, view.bar.foreground.b, 0.04)
            border.width: 1
            border.color: Qt.rgba(view.bar.foreground.r, view.bar.foreground.g, view.bar.foreground.b, 0.12)
            Column {
                id: gpuStateColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(6)
                spacing: Style.space(3)
                Text {
                    width: parent.width
                    text: "Display: " + Gpu.displayOwnerLabel(view.controller.gpuStatus.displayDriver) + " · " + view.controller.gpuStatus.displayConnector
                    wrapMode: Text.WordWrap
                    color: view.bar.foreground
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                }
                Text {
                    width: parent.width
                    text: "NVIDIA: " + Gpu.dgpuStateLabel(view.controller.gpuStatus, view.controller.dgpuDisableValue)
                    wrapMode: Text.WordWrap
                    color: view.controller.gpuStatus.users.length > 0 ? "#ffb347" : Qt.darker(view.bar.foreground, 1.3)
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.bodySmall
                }
                Text {
                    visible: view.controller.gpuStatus.users.length > 0
                    width: parent.width
                    text: Gpu.gpuUsersText(view.controller.gpuStatus.users)
                    wrapMode: Text.WrapAnywhere
                    color: Qt.darker(view.bar.foreground, 1.5)
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.caption
                }
                Text {
                    width: parent.width
                    text: "Current firmware: " + Gpu.gpuModeDef(view.controller.currentGpuMode).name
                    wrapMode: Text.WordWrap
                    color: Qt.darker(view.bar.foreground, 1.4)
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.caption
                }
            }
        }

        Rectangle {
            visible: view.controller.gpuHasPending
            width: parent.width
            implicitHeight: pendingColumn.implicitHeight + Style.space(12)
            radius: Style.cornerRadius
            color: Qt.rgba(1, 0.65, 0.2, 0.10)
            border.width: 1
            border.color: Qt.rgba(1, 0.65, 0.2, 0.35)
            Column {
                id: pendingColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(6)
                spacing: Style.space(5)
                Text {
                    width: parent.width
                    text: "Scheduled: " + Gpu.gpuModeDef(view.controller.gpuMode).name + " on the next normal shutdown/reboot."
                    wrapMode: Text.WordWrap
                    color: "#ffb347"
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                }
                Text {
                    width: parent.width
                    text: "This ASUS firmware state can carry into Windows; no Windows files are changed. The panel never shuts down or restarts the laptop."
                    wrapMode: Text.WordWrap
                    color: Qt.darker(view.bar.foreground, 1.4)
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.caption
                }
                Button {
                    width: parent.width
                    enabled: view.controller.currentGpuMode !== "unknown"
                    text: "Keep current " + Gpu.gpuModeDef(view.controller.currentGpuMode).name
                    tooltipText: "Replace the queued GPU values with the current firmware mode. A no-op may still remain queued until shutdown."
                    fontSize: Style.font.bodySmall
                    foreground: view.bar.foreground
                    fontFamily: view.bar.fontFamily
                    horizontalPadding: Style.spacing.controlPaddingX
                    verticalPadding: Style.spacing.controlPaddingY
                    bordered: true
                    onClicked: view.controller.keepCurrentGpuMode()
                }
            }
        }

        Rectangle {
            visible: view.controller.gpuConfirmMode !== ""
            width: parent.width
            implicitHeight: confirmColumn.implicitHeight + Style.space(12)
            radius: Style.cornerRadius
            color: Qt.rgba(1, 0.25, 0.2, 0.10)
            border.width: 1
            border.color: Qt.rgba(1, 0.25, 0.2, 0.4)
            Column {
                id: confirmColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(6)
                spacing: Style.space(5)
                Text {
                    width: parent.width
                    text: view.controller.gpuStatus.usersKnown ? "NVIDIA is busy. Close these processes first, or explicitly continue:\n" + Gpu.gpuUsersText(view.controller.gpuStatus.users) : "GPU process detection is unavailable. Explicit confirmation is required."
                    wrapMode: Text.WrapAnywhere
                    color: "#ff7770"
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                }
                Text {
                    width: parent.width
                    text: "Disabling is only queued now, but these processes may block the firmware change at shutdown."
                    wrapMode: Text.WordWrap
                    color: Qt.darker(view.bar.foreground, 1.4)
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.caption
                }
                Row {
                    width: parent.width
                    spacing: Style.space(4)
                    Button {
                        width: (parent.width - Style.space(4)) / 2
                        text: "Cancel"
                        fontSize: Style.font.bodySmall
                        foreground: view.bar.foreground
                        fontFamily: view.bar.fontFamily
                        horizontalPadding: Style.spacing.controlPaddingX
                        verticalPadding: Style.spacing.controlPaddingY
                        bordered: true
                        onClicked: view.controller.cancelGpuMode()
                    }
                    Button {
                        width: (parent.width - Style.space(4)) / 2
                        text: "Disable anyway"
                        fontSize: Style.font.bodySmall
                        foreground: "#ff7770"
                        fontFamily: view.bar.fontFamily
                        horizontalPadding: Style.spacing.controlPaddingX
                        verticalPadding: Style.spacing.controlPaddingY
                        bordered: true
                        onClicked: view.controller.confirmGpuMode()
                    }
                }
            }
        }

        Text {
            visible: view.controller.gpuActionError !== ""
            width: parent.width
            text: view.controller.gpuActionError
            wrapMode: Text.WordWrap
            color: "#ff7770"
            font.family: view.bar.fontFamily
            font.pixelSize: Style.font.caption
        }
        Text {
            width: parent.width
            text: Gpu.gpuModeDef(view.controller.gpuMode).desc + ". GPU choices do not change the display refresh rate."
            wrapMode: Text.WordWrap
            color: Qt.darker(view.bar.foreground, 1.4)
            font.family: view.bar.fontFamily
            font.pixelSize: Style.font.caption
        }
    }

    // SCREEN — refresh rate comes from Hyprland, overdrive from
    // asusctl; G-Helper pairs them in one control for the same
    // reason (high refresh without OD looks smeary).
    Column {
        visible: view.controller.monitor !== null && view.controller.monitor.rates.length > 1
        width: parent.width
        spacing: Style.space(8)
        PanelSeparator {
            foreground: view.bar.foreground
        }
        PanelSectionHeader {
            text: "SCREEN — " + (view.controller.monitor ? view.controller.monitor.name : "") + (view.controller.hyprmoncfgManaged ? "  ·  " + view.controller.hyprmoncfgProfile : "")
            foreground: view.bar.foreground
            fontFamily: view.bar.fontFamily
        }
        Row {
            id: hzRow
            width: parent.width
            spacing: Style.space(4)
            readonly property int n: view.controller.monitor ? view.controller.monitor.rates.length : 1
            readonly property real cw: (width - spacing * (n - 1)) / Math.max(1, n)
            Repeater {
                model: view.controller.monitor ? view.controller.monitor.rates : []
                Button {
                    required property var modelData
                    width: hzRow.cw
                    text: modelData + " Hz"
                    tooltipText: "Run " + (view.controller.monitor ? view.controller.monitor.name : "the panel") + " at " + modelData + " Hz.\n" + (modelData >= 90 ? "Smoother motion, noticeably more battery drain." : "Lower power draw, longer battery life.") + (view.controller.hyprmoncfgManaged ? "\n\nSaved into the hyprmoncfg profile \"" + view.controller.hyprmoncfgProfile + "\", so it sticks." : "\n\nApplied until the Hyprland config is reloaded.")
                    fontSize: Style.font.bodySmall
                    foreground: view.bar.foreground
                    fontFamily: view.bar.fontFamily
                    horizontalPadding: Style.spacing.controlPaddingX
                    verticalPadding: Style.spacing.controlPaddingY
                    bordered: true
                    active: view.controller.monitor && view.controller.monitor.rate === modelData
                    onClicked: view.controller.setRefreshRate(modelData)
                }
            }
        }
        Toggle {
            id: odToggle
            visible: view.controller.armourySupported.panelOverdrive
            width: parent.width
            label: "Panel Overdrive"
            description: "Faster pixel response at high refresh"
            checked: view.controller.panelOverdrive
            foreground: view.bar.foreground
            accent: Color.accent
            fontFamily: view.bar.fontFamily
            onClicked: view.controller.togglePanelOverdrive()
            // Toggle reports hover as a signal rather than a
            // property, so the tooltip tracks it via a flag.
            property bool tipHovered: false
            onHovered: function (h) {
                odToggle.tipHovered = h;
            }
            PanelToolTip {
                visible: odToggle.tipHovered
                text: Platform.armouryTips.panel_overdrive
            }
        }
    }

    Column {
        visible: view.controller.supported.hasBattery && view.showBatteryLimit
        width: parent.width
        spacing: Style.space(8)
        PanelSeparator {
            foreground: view.bar.foreground
        }
        PanelSectionHeader {
            text: "BATTERY CHARGE LIMIT"
            foreground: view.bar.foreground
            fontFamily: view.bar.fontFamily
        }
        Row {
            width: parent.width
            spacing: Style.space(4)
            PanelSlider {
                width: parent.width - Style.space(44) - Style.space(4)
                bar: view.bar
                minimum: 20
                maximum: 100
                step: 5
                integer: true
                value: view.controller.batteryLimit
                tickCount: 9
                onReleased: function (v) {
                    view.controller.setBatteryLimit(Math.round(v));
                }
            }
            Text {
                text: view.controller.batteryLimit + "%"
                color: view.bar.foreground
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                width: Style.space(44)
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Row {
            width: parent.width
            spacing: Style.space(4)
            Repeater {
                model: [20, 40, 60, 80, 100]
                Button {
                    required property var modelData
                    width: (parent.width - Style.space(4) * 4) / 5
                    text: modelData + "%"
                    tooltipText: modelData === 100 ? "Charge to full.\nConvenient, but hardest on long-term battery health." : "Stop charging at " + modelData + "%.\nLower limits slow battery wear; 60–80% suits a mostly plugged-in laptop."
                    fontSize: Style.font.caption
                    foreground: view.bar.foreground
                    fontFamily: view.bar.fontFamily
                    horizontalPadding: Style.spacing.controlPaddingX
                    verticalPadding: Style.spacing.controlPaddingY
                    bordered: true
                    active: view.controller.batteryLimit === modelData
                    onClicked: view.controller.setBatteryLimit(modelData)
                }
            }
        }
    }
}
