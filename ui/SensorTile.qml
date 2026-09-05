import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
    id: tile
    property string caption: ""
    property string value: ""
    property string sub: ""
    property color valueColor: "white"
    property color foreground: "white"
    property string fontFamily: "monospace"
    property string tip: ""

    height: Style.space(46)
    radius: Style.cornerRadius
    color: Qt.rgba(tile.foreground.r, tile.foreground.g, tile.foreground.b, 0.05)

    MouseArea {
        id: tileHelp
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
    PanelToolTip {
        visible: tile.tip !== "" && tileHelp.containsMouse
        text: tile.tip
    }

    Column {
        anchors.centerIn: parent
        spacing: Style.space(1)
        Text {
            text: tile.caption
            color: Qt.darker(tile.foreground, 1.7)
            font.family: tile.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: tile.value
            color: tile.valueColor
            font.family: tile.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            visible: tile.sub !== ""
            text: tile.sub
            color: Qt.darker(tile.foreground, 1.5)
            font.family: tile.fontFamily
            font.pixelSize: Style.font.caption
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
