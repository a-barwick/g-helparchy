import QtQuick
import ".." as Backend
import qs.Commons
import qs.Ui
import "Format.js" as Format

Column {
    id: view
    required property Backend.AsusController controller
    required property QtObject bar
    spacing: Style.space(10)

    Row {
        width: parent.width
        Text {
            text: "CUSTOM FAN CURVES"
            color: view.bar.foreground
            font.family: view.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - masterSw.width - resetAllBtn.width - Style.space(16)
        }
        Rectangle {
            id: masterSw
            width: Style.space(48)
            height: Style.space(20)
            radius: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            color: view.controller.fanCurveEnabled ? Qt.rgba(0.27, 0.8, 0.27, 0.3) : Qt.rgba(view.bar.foreground.r, view.bar.foreground.g, view.bar.foreground.b, 0.08)
            MouseArea {
                id: masterSwMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: view.controller.profileLoaded
                cursorShape: Qt.PointingHandCursor
                onClicked: view.controller.toggleFanCurves()
            }
            PanelToolTip {
                visible: masterSwMouse.containsMouse
                text: "Master switch for custom fan curves.\nOff means the firmware's own curves run instead."
            }
            Text {
                text: view.controller.fanCurveEnabled ? "ON" : "OFF"
                color: view.controller.fanCurveEnabled ? "#44cc44" : Qt.darker(view.bar.foreground, 1.6)
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.centerIn: parent
            }
        }
        Button {
            id: resetAllBtn
            text: "Reset all"
            tooltipText: "Restore the firmware's default fan curves\nfor the profile selected below."
            fontSize: Style.font.caption
            foreground: view.bar.foreground
            fontFamily: view.bar.fontFamily
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            bordered: true
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.space(6)
            onClicked: view.controller.resetFanCurves()
        }
    }
    Text {
        visible: !view.controller.fanCurveEnabled
        width: parent.width
        text: "Turn this on to enable per-fan custom curves below."
        wrapMode: Text.WordWrap
        color: Qt.darker(view.bar.foreground, 1.4)
        font.family: view.bar.fontFamily
        font.pixelSize: Style.font.caption
    }

    // Curves are stored per power profile. Editing whichever
    // profile is active is rarely what you want when tuning,
    // so the target is picked explicitly here.
    Column {
        width: parent.width
        spacing: Style.space(4)
        Text {
            text: "Editing curves for"
            color: Qt.darker(view.bar.foreground, 1.4)
            font.family: view.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
        }
        Row {
            id: fpRow
            width: parent.width
            spacing: Style.space(4)
            readonly property real cw: view.controller.profiles.length > 0 ? (width - spacing * (view.controller.profiles.length - 1)) / view.controller.profiles.length : 0
            Repeater {
                model: view.controller.profiles
                Button {
                    required property var modelData
                    width: fpRow.cw
                    text: String(modelData) + (view.controller.currentProfile === modelData ? " •" : "")
                    tooltipText: "Edit the fan curves stored for the " + modelData + " profile." + (view.controller.currentProfile === modelData ? "\nThis is the profile currently active (•)." : "\nChanges apply when you switch to that profile.")
                    fontSize: Style.font.caption
                    foreground: view.bar.foreground
                    fontFamily: view.bar.fontFamily
                    horizontalPadding: Style.spacing.controlPaddingX
                    verticalPadding: Style.spacing.controlPaddingY
                    bordered: true
                    active: view.controller.fanProfile === modelData
                    onClicked: view.controller.selectFanProfile(String(modelData))
                }
            }
        }
    }

    // CPU Fan
    Column {
        width: parent.width
        spacing: Style.space(4)
        opacity: view.controller.fanCurveEnabled ? 1 : 0.5
        Row {
            width: parent.width
            spacing: Style.space(8)
            Rectangle {
                width: Style.space(12)
                height: Style.space(12)
                radius: Style.space(6)
                color: view.controller.cpuFanEnabled ? "#44cc44" : "#666"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "CPU Fan"
                color: view.bar.foreground
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: Format.fmtRpm(view.controller.sensors.fanCpu) + "   " + Format.fmtTemp(view.controller.sensors.cpuTemp)
                color: Qt.darker(view.bar.foreground, 1.5)
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                width: parent.width - Style.space(12) - Style.space(48) - Style.space(70)
            }
            Rectangle {
                width: Style.space(48)
                height: Style.space(20)
                radius: Style.space(10)
                color: view.controller.cpuFanEnabled ? Qt.rgba(0.27, 0.8, 0.27, 0.3) : Qt.rgba(view.bar.foreground.r, view.bar.foreground.g, view.bar.foreground.b, 0.08)
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    id: cpuSwMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: view.controller.fanCurveEnabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.controller.toggleCpuFan()
                }
                PanelToolTip {
                    visible: cpuSwMouse.containsMouse
                    text: "Use the custom curve below for the CPU fan."
                }
                Text {
                    text: view.controller.cpuFanEnabled ? "ON" : "OFF"
                    color: view.controller.cpuFanEnabled ? "#44cc44" : Qt.darker(view.bar.foreground, 1.6)
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    anchors.centerIn: parent
                }
            }
        }
        FanCurveEditor {
            width: parent.width
            points: view.controller.cpuFanPoints
            enabledState: view.controller.cpuFanEnabled
            interactive: view.controller.fanCurveEnabled
            accent: "#44cc44"
            foreground: view.bar.foreground
            fontFamily: view.bar.fontFamily
            onCommit: function (pts) {
                view.controller.commitFanCurve("cpu", pts);
            }
            onReset: view.controller.resetFanCurves()
        }
    }
    // GPU Fan
    Column {
        width: parent.width
        spacing: Style.space(4)
        opacity: view.controller.fanCurveEnabled ? 1 : 0.5
        Row {
            width: parent.width
            spacing: Style.space(8)
            Rectangle {
                width: Style.space(12)
                height: Style.space(12)
                radius: Style.space(6)
                color: view.controller.gpuFanEnabled ? "#4488ff" : "#666"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "GPU Fan"
                color: view.bar.foreground
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: Format.fmtRpm(view.controller.sensors.fanGpu) + (view.controller.sensors.gpuTemp >= 0 ? "   " + Format.fmtTemp(view.controller.sensors.gpuTemp) : "")
                color: Qt.darker(view.bar.foreground, 1.5)
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                width: parent.width - Style.space(12) - Style.space(48) - Style.space(70)
            }
            Rectangle {
                width: Style.space(48)
                height: Style.space(20)
                radius: Style.space(10)
                color: view.controller.gpuFanEnabled ? Qt.rgba(0.27, 0.53, 1, 0.3) : Qt.rgba(view.bar.foreground.r, view.bar.foreground.g, view.bar.foreground.b, 0.08)
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    id: gpuSwMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: view.controller.fanCurveEnabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.controller.toggleGpuFan()
                }
                PanelToolTip {
                    visible: gpuSwMouse.containsMouse
                    text: "Use the custom curve below for the GPU fan."
                }
                Text {
                    text: view.controller.gpuFanEnabled ? "ON" : "OFF"
                    color: view.controller.gpuFanEnabled ? "#4488ff" : Qt.darker(view.bar.foreground, 1.6)
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    anchors.centerIn: parent
                }
            }
        }
        FanCurveEditor {
            width: parent.width
            points: view.controller.gpuFanPoints
            enabledState: view.controller.gpuFanEnabled
            interactive: view.controller.fanCurveEnabled
            accent: "#4488ff"
            foreground: view.bar.foreground
            fontFamily: view.bar.fontFamily
            onCommit: function (pts) {
                view.controller.commitFanCurve("gpu", pts);
            }
            onReset: view.controller.resetFanCurves()
        }
    }
    // Mid Fan — only laptops with a third fan report this.
    Column {
        visible: view.controller.hasMidFan
        width: parent.width
        spacing: Style.space(4)
        opacity: view.controller.fanCurveEnabled ? 1 : 0.5
        Row {
            width: parent.width
            spacing: Style.space(8)
            Rectangle {
                width: Style.space(12)
                height: Style.space(12)
                radius: Style.space(6)
                color: view.controller.midFanEnabled ? "#cc9944" : "#666"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "Mid Fan"
                color: view.bar.foreground
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(60)
            }
            Rectangle {
                width: Style.space(48)
                height: Style.space(20)
                radius: Style.space(10)
                color: view.controller.midFanEnabled ? Qt.rgba(0.8, 0.6, 0.27, 0.3) : Qt.rgba(view.bar.foreground.r, view.bar.foreground.g, view.bar.foreground.b, 0.08)
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    id: midSwMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: view.controller.fanCurveEnabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.controller.toggleMidFan()
                }
                PanelToolTip {
                    visible: midSwMouse.containsMouse
                    text: "Use the custom curve below for the middle fan."
                }
                Text {
                    text: view.controller.midFanEnabled ? "ON" : "OFF"
                    color: view.controller.midFanEnabled ? "#cc9944" : Qt.darker(view.bar.foreground, 1.6)
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    anchors.centerIn: parent
                }
            }
        }
        FanCurveEditor {
            width: parent.width
            points: view.controller.midFanPoints
            enabledState: view.controller.midFanEnabled
            interactive: view.controller.fanCurveEnabled
            accent: "#cc9944"
            foreground: view.bar.foreground
            fontFamily: view.bar.fontFamily
            onCommit: function (pts) {
                view.controller.commitFanCurve("mid", pts);
            }
            onReset: view.controller.resetFanCurves()
        }
    }
}
