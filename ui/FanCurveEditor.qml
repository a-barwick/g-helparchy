import QtQuick
import qs.Commons
import qs.Ui
import "../logic/FanCurves.js" as FanCurves

Column {
    id: editor
    property var points: []
    property bool enabledState: false
    property color accent: "#44cc44"
    property color foreground: "white"
    property string fontFamily: "monospace"
    property bool interactive: true
    signal commit(var points)
    signal reset

    width: parent ? parent.width : 0
    spacing: Style.space(4)

    Rectangle {
        width: parent.width
        height: Style.space(64)
        radius: Style.cornerRadius
        color: Qt.rgba(editor.foreground.r, editor.foreground.g, editor.foreground.b, 0.04)
        opacity: editor.interactive ? 1 : 0.4

        Canvas {
            id: canvas
            anchors.fill: parent
            anchors.margins: Style.space(6)
            renderStrategy: Canvas.Immediate

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                if (editor.points.length < 2)
                    return;
                var w = width, h = height;
                ctx.strokeStyle = Qt.rgba(editor.foreground.r, editor.foreground.g, editor.foreground.b, 0.6);
                ctx.lineWidth = 2;
                ctx.beginPath();
                for (var i = 0; i < editor.points.length; i++) {
                    var px = (editor.points[i].temp - 30) / 70 * w;
                    var py = h - (editor.points[i].speed / 100) * h;
                    if (i === 0)
                        ctx.moveTo(px, py);
                    else
                        ctx.lineTo(px, py);
                }
                ctx.stroke();
            }

            Connections {
                target: editor
                function onPointsChanged() {
                    canvas.requestPaint();
                }
            }

            Repeater {
                model: editor.points
                Rectangle {
                    id: handle
                    required property var modelData
                    required property int index
                    width: Style.space(10)
                    height: Style.space(10)
                    radius: Style.space(5)
                    color: editor.enabledState ? editor.accent : Qt.rgba(editor.foreground.r, editor.foreground.g, editor.foreground.b, 0.4)
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.3)
                    x: (modelData.temp - 30) / 70 * canvas.width - width / 2
                    y: canvas.height - (modelData.speed / 100) * canvas.height - height / 2

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Style.space(4)
                        enabled: editor.interactive
                        cursorShape: Qt.PointingHandCursor
                        drag.target: handle
                        drag.axis: Drag.XAndYAxis
                        drag.minimumX: -handle.width / 2
                        drag.maximumX: canvas.width - handle.width / 2
                        drag.minimumY: -handle.height / 2
                        drag.maximumY: canvas.height - handle.height / 2
                        onPositionChanged: {
                            if (!drag.active)
                                return;
                            var temp = (handle.x + handle.width / 2) / canvas.width * 70 + 30;
                            var speed = (1 - (handle.y + handle.height / 2) / canvas.height) * 100;
                            editor.points = FanCurves.moveFanPoint(editor.points, index, temp, speed);
                        }
                        onReleased: editor.commit(editor.points)
                    }
                }
            }
        }

        // Sits under the handles so it never eats a drag, and explains the
        // axes — the graph has no room for labelled ones.
        MouseArea {
            id: curveHelp
            anchors.fill: parent
            z: -1
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
        PanelToolTip {
            visible: curveHelp.containsMouse
            text: "Fan curve: temperature (30–100 °C) left to right,\nfan speed (0–100%) bottom to top.\nDrag a point to change it."
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: Style.space(2)
            text: editor.points.length + " pts"
            color: Qt.darker(editor.foreground, 1.6)
            font.family: editor.fontFamily
            font.pixelSize: 8
        }
    }

    Row {
        width: parent.width
        Item {
            width: parent.width - resetBtn.width
            height: 1
        }
        Button {
            id: resetBtn
            text: "Reset"
            tooltipText: "Restore this profile's default fan curves."
            fontSize: Style.font.caption
            foreground: editor.foreground
            fontFamily: editor.fontFamily
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            bordered: true
            onClicked: editor.reset()
        }
    }
}
