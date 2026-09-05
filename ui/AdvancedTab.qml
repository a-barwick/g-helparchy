import QtQuick
import ".." as Backend
import qs.Commons
import qs.Ui
import "../logic/Platform.js" as Platform

Column {
    id: view
    required property Backend.AsusController controller
    required property QtObject bar
    spacing: Style.space(8)
    Row {
        width: parent.width
        Text {
            width: parent.width - defaultsBtn.width - Style.space(8)
            text: "Firmware power limits. Only the controls this laptop actually reports are shown."
            wrapMode: Text.WordWrap
            color: Qt.darker(view.bar.foreground, 1.4)
            font.family: view.bar.fontFamily
            font.pixelSize: Style.font.caption
            anchors.verticalCenter: parent.verticalCenter
        }
        Button {
            id: defaultsBtn
            text: "Defaults"
            tooltipText: view.controller.armouryActionError || "Put every power limit below back to the value\nthe firmware reports as its default."
            fontSize: Style.font.caption
            foreground: view.bar.foreground
            fontFamily: view.bar.fontFamily
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            bordered: true
            anchors.verticalCenter: parent.verticalCenter
            onClicked: view.controller.restorePowerDefaults()
        }
    }
    Text {
        visible: view.controller.armouryActionError !== ""
        width: parent.width
        text: view.controller.armouryActionError
        wrapMode: Text.WordWrap
        color: "#ff7770"
        font.family: view.bar.fontFamily
        font.pixelSize: Style.font.caption
    }
    Column {
        visible: view.controller.armourySupported.pptPl1 || view.controller.armourySupported.pptPl2
        width: parent.width
        spacing: Style.space(4)
        Text {
            text: "CPU Power"
            color: Qt.darker(view.bar.foreground, 1.4)
            font.family: view.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
        }
        Row {
            visible: view.controller.armourySupported.pptPl1
            width: parent.width
            spacing: Style.space(4)
            Text {
                text: "PL1"
                color: Qt.darker(view.bar.foreground, 1.4)
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.caption
                width: Style.space(40)
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    id: pl1Help
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
                PanelToolTip {
                    visible: pl1Help.containsMouse
                    text: Platform.armouryTips.ppt_pl1_spl
                }
            }
            PanelSlider {
                width: parent.width - Style.space(40) - Style.space(32) - Style.space(4) * 2
                bar: view.bar
                minimum: view.controller.pptPl1Min
                maximum: view.controller.pptPl1Max
                step: 1
                integer: true
                value: view.controller.pptPl1
                onReleased: function (v) {
                    view.controller.setPptPl1(v);
                }
            }
            Text {
                text: view.controller.pptPl1 + "W"
                color: view.bar.foreground
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                width: Style.space(32)
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Row {
            visible: view.controller.armourySupported.pptPl2
            width: parent.width
            spacing: Style.space(4)
            Text {
                text: "PL2"
                color: Qt.darker(view.bar.foreground, 1.4)
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.caption
                width: Style.space(40)
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    id: pl2Help
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
                PanelToolTip {
                    visible: pl2Help.containsMouse
                    text: Platform.armouryTips.ppt_pl2_sppt
                }
            }
            PanelSlider {
                width: parent.width - Style.space(40) - Style.space(32) - Style.space(4) * 2
                bar: view.bar
                minimum: view.controller.pptPl2Min
                maximum: view.controller.pptPl2Max
                step: 1
                integer: true
                value: view.controller.pptPl2
                onReleased: function (v) {
                    view.controller.setPptPl2(v);
                }
            }
            Text {
                text: view.controller.pptPl2 + "W"
                color: view.bar.foreground
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                width: Style.space(32)
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
    Column {
        visible: view.controller.armourySupported.nvDynBoost || view.controller.armourySupported.nvTempTarget
        width: parent.width
        spacing: Style.space(4)
        Text {
            text: "GPU Power"
            color: Qt.darker(view.bar.foreground, 1.4)
            font.family: view.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
        }
        Row {
            visible: view.controller.armourySupported.nvDynBoost
            width: parent.width
            spacing: Style.space(4)
            Text {
                text: "Boost"
                color: Qt.darker(view.bar.foreground, 1.4)
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.caption
                width: Style.space(40)
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    id: boostHelp
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
                PanelToolTip {
                    visible: boostHelp.containsMouse
                    text: Platform.armouryTips.nv_dynamic_boost
                }
            }
            PanelSlider {
                width: parent.width - Style.space(40) - Style.space(32) - Style.space(4) * 2
                bar: view.bar
                minimum: view.controller.nvDynBoostMin
                maximum: view.controller.nvDynBoostMax
                step: 1
                integer: true
                value: view.controller.nvDynBoost
                onReleased: function (v) {
                    view.controller.setNvDynBoost(v);
                }
            }
            Text {
                text: view.controller.nvDynBoost + "W"
                color: view.bar.foreground
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                width: Style.space(32)
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Row {
            visible: view.controller.armourySupported.nvTempTarget
            width: parent.width
            spacing: Style.space(4)
            Text {
                text: "Temp"
                color: Qt.darker(view.bar.foreground, 1.4)
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.caption
                width: Style.space(40)
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    id: tempHelp
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
                PanelToolTip {
                    visible: tempHelp.containsMouse
                    text: Platform.armouryTips.nv_temp_target
                }
            }
            PanelSlider {
                width: parent.width - Style.space(40) - Style.space(32) - Style.space(4) * 2
                bar: view.bar
                minimum: view.controller.nvTempTargetMin
                maximum: view.controller.nvTempTargetMax
                step: 1
                integer: true
                value: view.controller.nvTempTarget
                onReleased: function (v) {
                    view.controller.setNvTempTarget(v);
                }
            }
            Text {
                text: view.controller.nvTempTarget + "°C"
                color: view.bar.foreground
                font.family: view.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                width: Style.space(32)
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
