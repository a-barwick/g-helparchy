import QtQuick
import ".." as Backend
import qs.Commons
import qs.Ui
import "../logic/Aura.js" as Aura

Column {
    id: view
    required property Backend.AsusController controller
    required property QtObject bar
    spacing: Style.space(8)
    // Header with LED toggle
    Row {
        width: parent.width
        Text {
            text: "KEYBOARD RGB"
            color: view.bar.foreground
            font.family: view.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - ledSw.width - Style.space(8)
        }
        Row {
            id: ledSw
            spacing: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                width: Style.space(14)
                height: Style.space(14)
                radius: Style.space(7)
                color: view.controller.ledAwake ? "#44cc44" : "#cc4444"
                anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity {
                    running: view.controller.ledAwake
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 1
                        to: 0.5
                        duration: 800
                    }
                    NumberAnimation {
                        from: 0.5
                        to: 1
                        duration: 800
                    }
                }
            }
            Text {
                text: view.controller.ledAwake ? "ON" : "OFF"
                color: view.controller.ledAwake ? "#44cc44" : "#cc4444"
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
            MouseArea {
                id: ledPowerMouse
                width: Style.space(40)
                height: Style.space(20)
                anchors.verticalCenter: parent.verticalCenter
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.controller.setLedPower(!view.controller.ledAwake)
                PanelToolTip {
                    visible: ledPowerMouse.containsMouse
                    text: view.controller.ledAwake ? "Keyboard lighting is on. Click to turn it off." : "Keyboard lighting is off. Click to turn it on."
                }
            }
        }
    }
    // Effect grid — only modes this laptop's asusctl actually reports supporting.
    Grid {
        width: parent.width
        columns: 3
        spacing: Style.space(3)
        Repeater {
            model: view.controller.auraSupportedEffects
            Rectangle {
                required property var modelData
                width: (parent.width - Style.space(3) * 2) / 3
                height: Style.space(40)
                radius: Style.cornerRadius
                color: view.controller.currentEffect === modelData.id ? Qt.rgba(view.bar.foreground.r, view.bar.foreground.g, view.bar.foreground.b, 0.2) : Qt.rgba(view.bar.foreground.r, view.bar.foreground.g, view.bar.foreground.b, 0.06)
                border.width: view.controller.currentEffect === modelData.id ? 2 : 1
                border.color: view.controller.currentEffect === modelData.id ? view.bar.foreground : "transparent"
                Row {
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text {
                        text: modelData.icon
                        color: view.controller.currentEffect === modelData.id ? view.bar.foreground : Qt.darker(view.bar.foreground, 1.4)
                        font.family: view.bar.fontFamily
                        font.pixelSize: Style.font.body
                    }
                    Text {
                        text: modelData.name
                        color: view.controller.currentEffect === modelData.id ? view.bar.foreground : Qt.darker(view.bar.foreground, 1.6)
                        font.family: view.bar.fontFamily
                        font.pixelSize: Style.font.caption
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: fxMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.controller.selectEffect(modelData.id)
                }
                PanelToolTip {
                    visible: fxMouse.containsMouse
                    text: modelData.tip
                }
            }
        }
    }
    // Effect params
    Column {
        visible: view.controller.needsColor || view.controller.needsColor2 || view.controller.needsSpeed || view.controller.needsDirection
        width: parent.width
        spacing: Style.space(6)
        Column {
            visible: view.controller.needsColor
            width: parent.width
            spacing: Style.space(4)
            Row {
                width: parent.width
                spacing: Style.space(6)
                Rectangle {
                    width: Style.space(20)
                    height: Style.space(20)
                    radius: Style.space(10)
                    color: view.controller.liveColor
                    border.width: 1
                    border.color: Qt.rgba(view.bar.foreground.r, view.bar.foreground.g, view.bar.foreground.b, 0.3)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Color  #" + view.controller.colorHex.toUpperCase()
                    color: view.bar.foreground
                    font.family: "monospace"
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                }
                Item {
                    width: parent.width - Style.space(20) - Style.space(60) - Style.space(6) * 2
                    height: 1
                }
                Button {
                    text: "Set"
                    fontSize: Style.font.caption
                    foreground: view.bar.foreground
                    fontFamily: view.bar.fontFamily
                    horizontalPadding: Style.spacing.controlPaddingX
                    verticalPadding: Style.spacing.controlPaddingY
                    bordered: true
                    active: true
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: view.controller.applyEffect()
                }
            }
            Row {
                width: parent.width
                spacing: Style.space(4)
                Text {
                    text: "R"
                    color: "#ff4444"
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    width: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                }
                PanelSlider {
                    width: parent.width - Style.space(12) - Style.space(24) - Style.space(4) * 2
                    bar: view.bar
                    minimum: 0
                    maximum: 255
                    step: 1
                    integer: true
                    value: view.controller.colorR
                    fillColor: Qt.rgba(1, 0.2, 0.2, 1)
                    knobColor: Qt.rgba(1, 0.3, 0.3, 1)
                    onReleased: function (v) {
                        view.controller.setEffectChannel("r", v, false);
                    }
                }
                Text {
                    text: view.controller.colorR
                    color: view.bar.foreground
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    width: Style.space(24)
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Row {
                width: parent.width
                spacing: Style.space(4)
                Text {
                    text: "G"
                    color: "#44cc44"
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    width: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                }
                PanelSlider {
                    width: parent.width - Style.space(12) - Style.space(24) - Style.space(4) * 2
                    bar: view.bar
                    minimum: 0
                    maximum: 255
                    step: 1
                    integer: true
                    value: view.controller.colorG
                    fillColor: Qt.rgba(0.2, 1, 0.2, 1)
                    knobColor: Qt.rgba(0.3, 1, 0.3, 1)
                    onReleased: function (v) {
                        view.controller.setEffectChannel("g", v, false);
                    }
                }
                Text {
                    text: view.controller.colorG
                    color: view.bar.foreground
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    width: Style.space(24)
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Row {
                width: parent.width
                spacing: Style.space(4)
                Text {
                    text: "B"
                    color: "#4488ff"
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    width: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                }
                PanelSlider {
                    width: parent.width - Style.space(12) - Style.space(24) - Style.space(4) * 2
                    bar: view.bar
                    minimum: 0
                    maximum: 255
                    step: 1
                    integer: true
                    value: view.controller.colorB
                    fillColor: Qt.rgba(0.2, 0.2, 1, 1)
                    knobColor: Qt.rgba(0.3, 0.3, 1, 1)
                    onReleased: function (v) {
                        view.controller.setEffectChannel("b", v, false);
                    }
                }
                Text {
                    text: view.controller.colorB
                    color: view.bar.foreground
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    width: Style.space(24)
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
        Column {
            visible: view.controller.needsColor2
            width: parent.width
            spacing: Style.space(4)
            Row {
                width: parent.width
                spacing: Style.space(6)
                Rectangle {
                    width: Style.space(20)
                    height: Style.space(20)
                    radius: Style.space(10)
                    color: view.controller.liveColor2
                    border.width: 1
                    border.color: Qt.rgba(view.bar.foreground.r, view.bar.foreground.g, view.bar.foreground.b, 0.3)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Color 2  #" + view.controller.color2Hex.toUpperCase()
                    color: view.bar.foreground
                    font.family: "monospace"
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Row {
                width: parent.width
                spacing: Style.space(4)
                Text {
                    text: "R"
                    color: "#ff4444"
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    width: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                }
                PanelSlider {
                    width: parent.width - Style.space(12) - Style.space(24) - Style.space(4) * 2
                    bar: view.bar
                    minimum: 0
                    maximum: 255
                    step: 1
                    integer: true
                    value: view.controller.color2R
                    fillColor: Qt.rgba(1, 0.2, 0.2, 1)
                    knobColor: Qt.rgba(1, 0.3, 0.3, 1)
                    onReleased: function (v) {
                        view.controller.setEffectChannel("r", v, true);
                    }
                }
                Text {
                    text: view.controller.color2R
                    color: view.bar.foreground
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    width: Style.space(24)
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Row {
                width: parent.width
                spacing: Style.space(4)
                Text {
                    text: "G"
                    color: "#44cc44"
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    width: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                }
                PanelSlider {
                    width: parent.width - Style.space(12) - Style.space(24) - Style.space(4) * 2
                    bar: view.bar
                    minimum: 0
                    maximum: 255
                    step: 1
                    integer: true
                    value: view.controller.color2G
                    fillColor: Qt.rgba(0.2, 1, 0.2, 1)
                    knobColor: Qt.rgba(0.3, 1, 0.3, 1)
                    onReleased: function (v) {
                        view.controller.setEffectChannel("g", v, true);
                    }
                }
                Text {
                    text: view.controller.color2G
                    color: view.bar.foreground
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    width: Style.space(24)
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Row {
                width: parent.width
                spacing: Style.space(4)
                Text {
                    text: "B"
                    color: "#4488ff"
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    width: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                }
                PanelSlider {
                    width: parent.width - Style.space(12) - Style.space(24) - Style.space(4) * 2
                    bar: view.bar
                    minimum: 0
                    maximum: 255
                    step: 1
                    integer: true
                    value: view.controller.color2B
                    fillColor: Qt.rgba(0.2, 0.2, 1, 1)
                    knobColor: Qt.rgba(0.3, 0.3, 1, 1)
                    onReleased: function (v) {
                        view.controller.setEffectChannel("b", v, true);
                    }
                }
                Text {
                    text: view.controller.color2B
                    color: view.bar.foreground
                    font.family: view.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    width: Style.space(24)
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
        Row {
            visible: view.controller.needsSpeed
            width: parent.width
            spacing: Style.space(4)
            Text {
                text: "Speed"
                color: Qt.darker(view.bar.foreground, 1.4)
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(40)
            }
            Repeater {
                model: Aura.speeds
                Button {
                    required property var modelData
                    width: (parent.width - Style.space(40) - Style.space(4) * 2) / 3
                    text: Aura.speedLabels[modelData]
                    tooltipText: "How fast the " + view.controller.effectDef.name + " effect animates."
                    fontSize: Style.font.caption
                    foreground: view.bar.foreground
                    fontFamily: view.bar.fontFamily
                    horizontalPadding: Style.spacing.controlPaddingX
                    verticalPadding: Style.spacing.controlPaddingY
                    bordered: true
                    active: view.controller.currentSpeed === modelData
                    onClicked: {
                        view.controller.setEffectSpeed(modelData);
                    }
                }
            }
        }
        Row {
            visible: view.controller.needsDirection
            width: parent.width
            spacing: Style.space(4)
            Text {
                text: "Dir"
                color: Qt.darker(view.bar.foreground, 1.4)
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(40)
            }
            Repeater {
                model: Aura.directions
                Button {
                    required property var modelData
                    width: (parent.width - Style.space(40) - Style.space(4) * 3) / 4
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    tooltipText: "Animate the effect towards the " + modelData + "."
                    fontSize: Style.font.caption
                    foreground: view.bar.foreground
                    fontFamily: view.bar.fontFamily
                    horizontalPadding: Style.spacing.controlPaddingX
                    verticalPadding: Style.spacing.controlPaddingY
                    bordered: true
                    active: view.controller.currentDirection === modelData
                    onClicked: {
                        view.controller.setEffectDirection(modelData);
                    }
                }
            }
        }
        Grid {
            visible: view.controller.needsColor
            width: parent.width
            columns: 6
            spacing: Style.space(3)
            Repeater {
                model: ["ff0000", "ff8800", "ffff00", "00ff00", "00ffff", "0088ff", "aa00ff", "ff00ff", "ffffff", "ffaa44", "44ccff", "88ff00"]
                Rectangle {
                    required property string modelData
                    property color swatchColor: Qt.rgba(parseInt(modelData.substring(0, 2), 16) / 255, parseInt(modelData.substring(2, 4), 16) / 255, parseInt(modelData.substring(4, 6), 16) / 255, 1)
                    width: (parent.width - Style.space(3) * 5) / 6
                    height: Style.space(22)
                    radius: Style.space(4)
                    color: swatchColor
                    border.width: view.controller.colorHex === modelData ? 2 : 1
                    border.color: view.controller.colorHex === modelData ? view.bar.foreground : Qt.rgba(view.bar.foreground.r, view.bar.foreground.g, view.bar.foreground.b, 0.15)
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.controller.setPresetColor(modelData)
                    }
                }
            }
        }
    }
    // LED Brightness
    Column {
        width: parent.width
        spacing: Style.space(4)
        Text {
            text: "LED Brightness"
            color: Qt.darker(view.bar.foreground, 1.4)
            font.family: view.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
        }
        Row {
            width: parent.width
            spacing: Style.space(4)
            Repeater {
                model: ["off", "low", "med", "high"]
                Button {
                    required property var modelData
                    width: (parent.width - Style.space(4) * 3) / 4
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    tooltipText: modelData === "off" ? "Turn the keyboard backlight off entirely." : "Set keyboard backlight brightness to " + modelData + "."
                    fontSize: Style.font.caption
                    foreground: view.bar.foreground
                    fontFamily: view.bar.fontFamily
                    horizontalPadding: Style.spacing.controlPaddingX
                    verticalPadding: Style.spacing.controlPaddingY
                    bordered: true
                    active: view.controller.ledBrightness === modelData
                    onClicked: view.controller.setLedBrightness(modelData)
                }
            }
        }
    }

    // Power states — G-Helper's "keyboard lighting on
    // boot/sleep/awake". asusctl exposes these as one call, so
    // each toggle resends the whole set (see applyLedPower).
    Column {
        width: parent.width
        spacing: Style.space(4)
        PanelSeparator {
            foreground: view.bar.foreground
        }
        Text {
            text: "Lighting active while"
            color: Qt.darker(view.bar.foreground, 1.4)
            font.family: view.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
        }
        Row {
            width: parent.width
            spacing: Style.space(4)
            Button {
                width: (parent.width - Style.space(4) * 2) / 3
                text: "Awake"
                tooltipText: "Keep the keyboard lit while the laptop is in normal use."
                fontSize: Style.font.caption
                foreground: view.bar.foreground
                fontFamily: view.bar.fontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY
                bordered: true
                active: view.controller.ledAwake
                onClicked: view.controller.setLedPower(!view.controller.ledAwake)
            }
            Button {
                width: (parent.width - Style.space(4) * 2) / 3
                text: "Boot"
                tooltipText: "Play the lighting animation during power-on and shutdown."
                fontSize: Style.font.caption
                foreground: view.bar.foreground
                fontFamily: view.bar.fontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY
                bordered: true
                active: view.controller.ledBoot
                onClicked: view.controller.setLedBoot(!view.controller.ledBoot)
            }
            Button {
                width: (parent.width - Style.space(4) * 2) / 3
                text: "Sleep"
                tooltipText: "Keep a breathing light going while the laptop is suspended."
                fontSize: Style.font.caption
                foreground: view.bar.foreground
                fontFamily: view.bar.fontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY
                bordered: true
                active: view.controller.ledSleep
                onClicked: view.controller.setLedSleep(!view.controller.ledSleep)
            }
        }
        Text {
            width: parent.width
            text: "asusctl does not report these back, so they show what this panel last set."
            wrapMode: Text.WordWrap
            color: Qt.darker(view.bar.foreground, 1.6)
            font.family: view.bar.fontFamily
            font.pixelSize: Style.font.caption
        }
    }
}
