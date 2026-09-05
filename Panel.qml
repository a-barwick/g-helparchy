import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui as Ui
import qs.Ui
import "ui"
import "logic/Platform.js" as Platform
import "ui/Format.js" as Format

Ui.Panel {
    id: root
    moduleName: "io.github.a-barwick.g-helparchy"
    ipcTarget: "io.github.a-barwick.g-helparchy"
    manageIpc: false

    // The drawer can anchor the popup to its own visible button.
    property var anchorItem: null
    // Allows isolated previews to construct the whole panel without probes.
    property bool active: true

    AsusController {
        id: asus
        active: root.active
        panelOpen: root.opened
        suggestEfficiency: root.setting("suggestEfficiency", true) === true
        refreshInterval: Math.max(5, Math.min(60, Number(root.setting("refreshIntervalSec", 10)) || 10)) * 1000
    }

    // ---- Tabs -----------------------------------------------------------
    property string tabKey: "main"
    readonly property var tabs: {
        var t = [
            {
                key: "main",
                label: "Main"
            }
        ];
        if (asus.supported.hasAura || !asus.infoLoaded)
            t.push({
                key: "rgb",
                label: "RGB"
            });
        if (asus.supported.hasFanCurve || !asus.infoLoaded)
            t.push({
                key: "fan",
                label: "Fan"
            });
        t.push({
            key: "advanced",
            label: "Advanced"
        });
        return t;
    }
    readonly property int tabIndex: {
        for (var i = 0; i < tabs.length; i++)
            if (tabs[i].key === tabKey)
                return i;
        return 0;
    }
    function selectTab(index) {
        if (tabs.length === 0)
            return;
        var n = tabs.length, i = ((index % n) + n) % n;
        tabKey = tabs[i].key;
    }

    visible: asus.asusctlAvailable
    implicitWidth: asus.asusctlAvailable ? button.implicitWidth : 0
    implicitHeight: asus.asusctlAvailable ? button.implicitHeight : 0

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: Platform.profileIcon(asus.currentProfile)
        slotSize: Style.bar.iconSlot
        // Tooltip doubles as the at-a-glance sensor readout, so the common
        // "how hot is it right now" question needs no click at all.
        tooltipText: {
            var t = "g-helparchy — " + Platform.profileLabel(asus.currentProfile);
            if (asus.sensors.cpuTemp >= 0)
                t += "\nCPU  " + Format.fmtTemp(asus.sensors.cpuTemp) + "   " + Format.fmtRpm(asus.sensors.fanCpu);
            if (asus.sensors.gpuTemp >= 0)
                t += "\nGPU  " + Format.fmtTemp(asus.sensors.gpuTemp) + "   " + Format.fmtRpm(asus.sensors.fanGpu);
            if (asus.efficiencySuggested)
                t += "\nHigh-power settings during light use";
            return t;
        }
        onPressed: function (b) {
            root.toggle();
        }
        // Scroll cycles profiles without opening the panel — the fastest path
        // to Silent/Turbo, and what `cycleProfile` was written for.
        onWheelMoved: function (delta) {
            asus.cycleProfile(delta > 0 ? 1 : -1);
        }
    }

    Rectangle {
        visible: asus.efficiencySuggested
        width: Style.space(6)
        height: width
        radius: width / 2
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Style.space(2)
        anchors.topMargin: Style.space(2)
        color: "#ffb347"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.35)
        z: 2
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem || button
        owner: root
        bar: root.bar
        open: root.opened && asus.asusctlAvailable
        focusTarget: keyCatcher
        // The Flickable inside is inset by `flickMargin` on every side, so the
        // panel has to be asked for that much extra in both axes — sizing it
        // to the raw content height clipped the final row of whichever tab was
        // showing (the last slider on Advanced, the overdrive toggle on Main).
        readonly property real flickMargin: Style.space(12)
        contentWidth: panel.fittedContentWidth(Style.space(360) + flickMargin * 2)
        contentHeight: panel.fittedContentHeight(scrollCol.implicitHeight + flickMargin * 2)

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: panel.flickMargin
            contentHeight: scrollCol.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick

            Column {
                id: scrollCol
                width: parent.width
                spacing: Style.space(12)

                // TABS — no hero header; the bar icon + active tab already
                // identify the panel, so the title/profile line is dropped
                // to give tab content more room before it needs to scroll.
                Row {
                    id: tabRow
                    width: parent.width
                    spacing: Style.space(4)
                    readonly property real cellWidth: root.tabs.length > 0 ? (width - spacing * (root.tabs.length - 1)) / root.tabs.length : 0
                    Repeater {
                        model: root.tabs
                        Button {
                            required property var modelData
                            required property int index
                            width: tabRow.cellWidth
                            text: modelData.label
                            fontSize: Style.font.bodySmall
                            foreground: root.bar.foreground
                            fontFamily: root.bar.fontFamily
                            horizontalPadding: Style.spacing.controlPaddingX
                            verticalPadding: Style.spacing.controlPaddingY
                            bordered: true
                            active: root.tabIndex === index
                            onClicked: root.selectTab(index)
                        }
                    }
                }

                PanelSeparator {
                    foreground: root.bar.foreground
                }

                // Tab bodies are plain always-built Columns toggled by `visible`
                // rather than Loader/Component — Quickshell's incubator can take
                // multiple frames to finish building a freshly-activated Loader's
                // Component, which showed up as tab content intermittently
                // rendering blank/short right after opening. Building everything
                // up front as part of the panel's normal synchronous construction
                // avoids that race entirely.

                // ============================================================ MAIN TAB
                MainTab {
                    visible: root.tabKey === "main"
                    width: parent.width
                    controller: asus
                    bar: root.bar
                    showBatteryLimit: root.setting("showBatteryLimit", true) === true
                    onVisibleChanged: if (visible)
                        cursorActive = false
                }

                // ============================================================= RGB TAB
                RgbTab {
                    visible: root.tabKey === "rgb"
                    width: parent.width
                    controller: asus
                    bar: root.bar
                }

                // ============================================================= FAN TAB
                FanTab {
                    visible: root.tabKey === "fan"
                    width: parent.width
                    controller: asus
                    bar: root.bar
                }

                // ======================================================== ADVANCED TAB
                AdvancedTab {
                    visible: root.tabKey === "advanced"
                    width: parent.width
                    controller: asus
                    bar: root.bar
                }
            }
        }

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onMoveRequested: function (dx, dy) {
                if (dy !== 0)
                    flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY - dy * 40));
            }
        }
    }

    IpcHandler {
        target: "io.github.a-barwick.g-helparchy"
        function open() {
            root.open();
        }
        function close() {
            root.close();
        }
        function show() {
            root.open();
        }
        function hide() {
            root.close();
        }
        function toggle() {
            root.toggle();
        }
        function refresh() {
            asus.refresh();
        }
    }
}
