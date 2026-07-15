pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

StyledClippingRect {
    id: root

    required property HyprlandToplevel client
    required property ShellScreen screen
    required property var controller
    required property real workspaceWidth
    required property real workspaceHeight
    required property real workspaceSpacing
    required property int groupStartWorkspace

    readonly property string address: controller.addressFor(client)
    readonly property int workspaceId: client?.workspace?.id ?? client?.lastIpcObject?.workspace?.id ?? -1
    readonly property int displayedWorkspaceId: pendingWorkspaceId > 0 ? pendingWorkspaceId : workspaceId
    readonly property int workspaceIndex: displayedWorkspaceId - groupStartWorkspace
    readonly property int workspaceColumn: Math.max(0, workspaceIndex % controller.columns)
    readonly property int workspaceRow: Math.max(0, Math.floor(workspaceIndex / controller.columns))
    readonly property var geometry: client?.lastIpcObject ?? ({})
    readonly property var windowPosition: geometry.at ?? [controller.usableX, controller.usableY]
    readonly property var windowSize: geometry.size ?? [320, 180]
    readonly property real scaleX: workspaceWidth / controller.usableWidth
    readonly property real scaleY: workspaceHeight / controller.usableHeight
    readonly property real edgePadding: 4
    readonly property real previewWidth: Math.max(36, Math.min(workspaceWidth - edgePadding * 2, windowSize[0] * scaleX))
    readonly property real previewHeight: Math.max(28, Math.min(workspaceHeight - edgePadding * 2, windowSize[1] * scaleY))
    readonly property real geometryLocalX: Math.max(edgePadding, Math.min(workspaceWidth - previewWidth - edgePadding, (windowPosition[0] - controller.usableX) * scaleX))
    readonly property real geometryLocalY: Math.max(edgePadding, Math.min(workspaceHeight - previewHeight - edgePadding, (windowPosition[1] - controller.usableY) * scaleY))
    readonly property real localX: pendingLocalX >= 0 ? pendingLocalX : geometryLocalX
    readonly property real localY: pendingLocalY >= 0 ? pendingLocalY : geometryLocalY
    readonly property real canonicalX: workspaceColumn * (workspaceWidth + workspaceSpacing) + localX
    readonly property real canonicalY: workspaceRow * (workspaceHeight + workspaceSpacing) + localY

    property bool dragActive
    property bool wasDragged
    property real pressX
    property real pressY
    property int pendingWorkspaceId: -1
    property real pendingLocalX: -1
    property real pendingLocalY: -1

    readonly property bool floating: geometry.floating ?? false
    readonly property bool fullscreen: (geometry.fullscreen ?? 0) !== 0
    readonly property bool rearrangeTarget: controller.draggingTargetAddress === address

    function holdLocalPosition(x: real, y: real): void {
        pendingLocalX = x;
        pendingLocalY = y;
    }

    implicitWidth: previewWidth
    implicitHeight: previewHeight
    radius: Math.min(Tokens.rounding.small, width / 8, height / 8)
    color: Colours.palette.m3surfaceContainerHigh
    border.width: dragActive || rearrangeTarget ? 2 : 1
    border.color: dragActive || rearrangeTarget ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
    z: dragActive ? 10000 : 10 + (geometry.fullscreen ?? 0) * 2 + (geometry.floating ? 1 : 0)

    Drag.active: dragActive
    Drag.source: root
    Drag.hotSpot.x: pressX
    Drag.hotSpot.y: pressY

    Binding on x {
        value: root.canonicalX
        when: !root.dragActive && !dragArea.drag.active
        restoreMode: Binding.RestoreNone
    }

    Binding on y {
        value: root.canonicalY
        when: !root.dragActive && !dragArea.drag.active
        restoreMode: Binding.RestoreNone
    }

    Behavior on x {
        enabled: !root.dragActive

        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }

    Behavior on y {
        enabled: !root.dragActive

        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }

    ScreencopyView {
        anchors.fill: parent
        captureSource: root.client?.wayland ?? null // qmllint disable unresolved-type
        live: root.controller.opened
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        implicitHeight: Math.min(30, Math.max(20, parent.height * 0.22))
        color: Qt.alpha(Colours.palette.m3surface, 0.88)

        Row {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 5

            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: Math.min(16, parent.height - 4)
                implicitHeight: implicitWidth
                source: Icons.getAppIcon(root.geometry.class ?? "", "image-missing")
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - x)
                text: root.client?.title ?? root.geometry.title ?? ""
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.small
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    MouseArea {
        id: dragArea

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        drag.target: (pressedButtons & Qt.LeftButton) ? root : null
        drag.threshold: 8

        onPressed: event => {
            root.wasDragged = false;
            root.pressX = event.x;
            root.pressY = event.y;
        }

        onPositionChanged: {
            if (drag.active && !root.dragActive) {
                root.dragActive = true;
                root.wasDragged = true;
                root.controller.beginDrag(root);
            }
        }

        onReleased: {
            if (!root.dragActive)
                return;

            root.controller.finishDrag(root);
            root.dragActive = false;
        }

        onCanceled: {
            root.controller.cancelDrag(root.address);
            root.dragActive = false;
        }

        onClicked: event => {
            if (root.wasDragged)
                return;

            if (event.button === Qt.LeftButton)
                root.controller.focusClient(root.address);
            else if (event.button === Qt.MiddleButton)
                root.controller.closeClient(root.address);
        }
    }

    DropArea {
        anchors.fill: parent
        enabled: !root.dragActive

        onEntered: drag => root.controller.enterWindow(root, drag.source)
        onExited: root.controller.leaveWindow(root.address)
    }

    Connections {
        target: root.controller

        function onCancelDragRequested(address: string): void {
            if (!address || address === root.address)
                root.dragActive = false;
        }
    }

    onWorkspaceIdChanged: {
        if (pendingWorkspaceId === workspaceId)
            pendingWorkspaceId = -1;
    }

    onWindowPositionChanged: {
        pendingLocalX = -1;
        pendingLocalY = -1;
    }

    Component.onDestruction: controller.cancelDrag(address)
}
