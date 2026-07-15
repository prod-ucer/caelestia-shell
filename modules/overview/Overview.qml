pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.components.containers
import qs.components.misc
import qs.services

Scope {
    id: root

    property bool opened
    property string monitorName

    function openOverview(): void {
        const monitor = Hypr.focusedMonitor;
        if (!monitor)
            return;

        monitorName = monitor.name;
        opened = true;
    }

    function closeOverview(): void {
        opened = false;
    }

    function toggleOverview(): void {
        if (opened)
            closeOverview();
        else
            openOverview();
    }

    Variants {
        model: Screens.screens

        StyledWindow {
            id: window

            required property ShellScreen modelData
            readonly property HyprlandMonitor monitor: Hypr.monitorFor(modelData)
            readonly property bool targetVisible: root.opened && monitor?.name === root.monitorName
            property real revealProgress: 0

            screen: modelData
            name: "overview"
            visible: targetVisible || revealProgress > 0

            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: targetVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            OverviewContent {
                id: content

                anchors.fill: parent
                revealProgress: window.revealProgress
                screen: window.modelData
                monitor: window.monitor
                overview: root
                opened: window.targetVisible
            }

            Behavior on revealProgress {
                NumberAnimation {
                    duration: window.targetVisible ? 100 : 70
                    easing.type: window.targetVisible ? Easing.OutCubic : Easing.InCubic
                }
            }

            onTargetVisibleChanged: {
                revealProgress = targetVisible ? 1 : 0;
                if (targetVisible)
                    content.forceActiveFocus();
            }
        }
    }

    IpcHandler {
        function open(): void {
            root.openOverview();
        }

        function close(): void {
            root.closeOverview();
        }

        function toggle(): void {
            root.toggleOverview();
        }

        function status(): string {
            return `${root.opened ? "open" : "closed"}:${root.monitorName}`;
        }

        target: "overview"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "overview"
        description: "Toggle the workspace overview"
        onPressed: root.toggleOverview()
    }
}
