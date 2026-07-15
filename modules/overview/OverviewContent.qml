pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.services

FocusScope {
    id: root

    required property ShellScreen screen
    required property HyprlandMonitor monitor
    required property var overview
    required property bool opened
    required property real revealProgress

    readonly property int columns: 5
    readonly property int rows: 2
    readonly property int workspacesShown: columns * rows
    readonly property int activeWorkspaceId: Math.max(1, Math.min(100, monitor?.activeWorkspace?.id ?? 1))
    readonly property int workspaceGroup: Math.floor((activeWorkspaceId - 1) / workspacesShown)

    readonly property var reserved: monitor?.lastIpcObject?.reserved ?? [0, 0, 0, 0]
    readonly property real usableX: screen.x + (reserved[0] ?? 0)
    readonly property real usableY: screen.y + (reserved[1] ?? 0)
    readonly property real usableWidth: Math.max(1, screen.width - (reserved[0] ?? 0) - (reserved[2] ?? 0))
    readonly property real usableHeight: Math.max(1, screen.height - (reserved[1] ?? 0) - (reserved[3] ?? 0))
    readonly property real workspaceAspect: usableWidth / usableHeight

    readonly property real outerPadding: Tokens.padding.extraLarge
    readonly property real gridSpacing: Math.max(4, Tokens.spacing.small)
    readonly property real maxGridWidth: Math.max(1, width - outerPadding * 2)
    readonly property real maxGridHeight: Math.max(1, height * 0.72)
    readonly property real workspaceWidth: Math.max(1, Math.min((maxGridWidth - gridSpacing * (columns - 1)) / columns, ((maxGridHeight - gridSpacing * (rows - 1)) / rows) * workspaceAspect))
    readonly property real workspaceHeight: workspaceWidth / workspaceAspect
    readonly property real gridWidth: workspaceWidth * columns + gridSpacing * (columns - 1)
    readonly property real gridHeight: workspaceHeight * rows + gridSpacing * (rows - 1)

    property string draggingAddress
    property string draggingTargetAddress
    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1

    signal cancelDragRequested(string address)

    readonly property list<var> clients: {
        const firstWorkspace = workspaceGroup * workspacesShown + 1;
        const lastWorkspace = firstWorkspace + workspacesShown - 1;
        return Hypr.toplevels.values.filter(client => {
            const data = client?.lastIpcObject;
            const workspaceId = client?.workspace?.id ?? data?.workspace?.id ?? -1;
            const className = String(data?.class ?? "").toLowerCase();
            const address = root.addressFor(client);
            return !!client?.wayland
                && !!address
                && data?.mapped !== false
                && workspaceId >= firstWorkspace
                && workspaceId <= lastWorkspace
                && !className.includes("caelestia")
                && !className.includes("quickshell");
        });
    }

    function addressFor(client): string {
        const ipcAddress = client?.lastIpcObject?.address;
        if (ipcAddress)
            return String(ipcAddress);
        if (client?.address === undefined || client?.address === null)
            return "";
        return `0x${client.address}`;
    }

    function beginDrag(preview): void {
        if (!preview?.address)
            return;

        draggingAddress = preview.address;
        draggingTargetAddress = "";
        draggingFromWorkspace = preview.workspaceId;
        draggingTargetWorkspace = -1;
    }

    function enterWorkspace(workspaceId: int, source): void {
        if (!draggingAddress || source?.address !== draggingAddress)
            return;
        draggingTargetWorkspace = workspaceId;
    }

    function leaveWorkspace(workspaceId: int): void {
        if (draggingTargetWorkspace === workspaceId)
            draggingTargetWorkspace = -1;
    }

    function enterWindow(target, source): void {
        if (!draggingAddress || source?.address !== draggingAddress || target?.address === draggingAddress)
            return;

        draggingTargetWorkspace = target.workspaceId;
        draggingTargetAddress = target.workspaceId === draggingFromWorkspace
            && !source.floating && !source.fullscreen
            && !target.floating && !target.fullscreen
                ? target.address
                : "";
    }

    function leaveWindow(address: string): void {
        if (draggingTargetAddress === address)
            draggingTargetAddress = "";
    }

    function finishDrag(preview): void {
        const address = preview?.address ?? "";
        const sourceWorkspace = draggingFromWorkspace;
        const targetWorkspace = draggingTargetWorkspace;
        const targetAddress = draggingTargetAddress;

        draggingAddress = "";
        draggingTargetAddress = "";
        draggingFromWorkspace = -1;
        draggingTargetWorkspace = -1;

        if (!address || targetWorkspace < 1)
            return;

        if (targetWorkspace === sourceWorkspace) {
            if (preview.floating)
                repositionFloating(preview, sourceWorkspace);
            else if (targetAddress)
                Hypr.dispatch(Hypr.usingLua
                    ? `hl.dsp.window.swap({ window = "address:${address}", target = "address:${targetAddress}" })`
                    : `swapwindow address:${targetAddress}`);
            return;
        }

        preview.pendingWorkspaceId = targetWorkspace;

        Hypr.dispatch(Hypr.usingLua
            ? `hl.dsp.window.move({ window = "address:${address}", workspace = "${targetWorkspace}", follow = false })`
            : `movetoworkspacesilent ${targetWorkspace},address:${address}`);
    }

    function repositionFloating(preview, workspaceId: int): void {
        const workspaceIndex = workspaceId - workspaceGroup * workspacesShown - 1;
        const column = Math.max(0, workspaceIndex % columns);
        const row = Math.max(0, Math.floor(workspaceIndex / columns));
        const workspaceX = column * (workspaceWidth + gridSpacing);
        const workspaceY = row * (workspaceHeight + gridSpacing);
        const localX = Math.max(preview.edgePadding, Math.min(workspaceWidth - preview.width - preview.edgePadding, preview.x - workspaceX));
        const localY = Math.max(preview.edgePadding, Math.min(workspaceHeight - preview.height - preview.edgePadding, preview.y - workspaceY));
        const realX = Math.round(usableX + localX / preview.scaleX);
        const realY = Math.round(usableY + localY / preview.scaleY);

        preview.holdLocalPosition(localX, localY);
        Hypr.dispatch(Hypr.usingLua
            ? `hl.dsp.window.move({ window = "address:${preview.address}", x = ${realX}, y = ${realY}, relative = false })`
            : `movewindowpixel exact ${realX} ${realY},address:${preview.address}`);
    }

    function cancelDrag(address = ""): void {
        if (address && draggingAddress !== address)
            return;

        cancelDragRequested(address);
        draggingAddress = "";
        draggingTargetAddress = "";
        draggingFromWorkspace = -1;
        draggingTargetWorkspace = -1;
    }

    function activateWorkspace(workspaceId: int): void {
        if (draggingAddress)
            return;

        overview.closeOverview();
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "${workspaceId}" })` : `workspace ${workspaceId}`);
    }

    function focusClient(address: string): void {
        if (!address)
            return;

        overview.closeOverview();
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:${address}" })` : `focuswindow address:${address}`);
    }

    function closeClient(address: string): void {
        if (!address)
            return;

        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "address:${address}" })` : `closewindow address:${address}`);
    }

    onOpenedChanged: {
        if (!opened)
            cancelDrag();
    }

    Keys.onEscapePressed: overview.closeOverview()

    Rectangle {
        anchors.fill: parent
        color: Colours.palette.m3scrim
        opacity: 0.72 * root.revealProgress

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: root.overview.closeOverview()
        }
    }

    Item {
        id: workspaceGrid

        anchors.centerIn: parent
        implicitWidth: root.gridWidth
        implicitHeight: root.gridHeight
        opacity: root.revealProgress
        scale: 0.97 + root.revealProgress * 0.03

        Grid {
            anchors.fill: parent
            columns: root.columns
            rows: root.rows
            spacing: root.gridSpacing

            Repeater {
                model: root.workspacesShown

                WorkspaceCell {
                    required property int index

                    implicitWidth: root.workspaceWidth
                    implicitHeight: root.workspaceHeight
                    workspaceId: root.workspaceGroup * root.workspacesShown + index + 1
                    active: workspaceId === root.activeWorkspaceId
                    controller: root
                }
            }
        }

        Item {
            anchors.fill: parent
            z: 10

            Repeater {
                model: ScriptModel {
                    values: root.clients
                }

                WindowPreview {
                    required property var modelData

                    client: modelData
                    screen: root.screen
                    controller: root
                    workspaceWidth: root.workspaceWidth
                    workspaceHeight: root.workspaceHeight
                    workspaceSpacing: root.gridSpacing
                    groupStartWorkspace: root.workspaceGroup * root.workspacesShown + 1
                }
            }
        }
    }
}
