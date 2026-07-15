pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

Rectangle {
    id: root

    required property int workspaceId
    required property bool active
    required property var controller

    readonly property bool dropTarget: controller.draggingTargetWorkspace === workspaceId
        && controller.draggingFromWorkspace !== workspaceId

    radius: Tokens.rounding.medium
    color: dropTarget ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainer
    border.width: active || dropTarget ? 2 : 1
    border.color: dropTarget
        ? Colours.palette.m3primary
        : active ? Colours.palette.m3secondary : Colours.palette.m3outlineVariant

    Behavior on color {
        ColorAnimation { duration: 140 }
    }

    StyledText {
        anchors.centerIn: parent
        text: root.workspaceId
        color: root.dropTarget ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3outline
        font: Tokens.font.body.builders.large.weight(Font.DemiBold).build()
        opacity: root.dropTarget ? 0.7 : 0.34
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: root.controller.activateWorkspace(root.workspaceId)
    }

    DropArea {
        anchors.fill: parent

        onEntered: drag => root.controller.enterWorkspace(root.workspaceId, drag.source)
        onExited: root.controller.leaveWorkspace(root.workspaceId)
    }
}
