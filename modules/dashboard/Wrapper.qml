pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.filedialog
import qs.services
import qs.utils

Item {
    id: root

    required property ScreenState screenState
    readonly property FileDialog facePicker: FileDialog {
        title: qsTr("Select a profile picture")
        filterLabel: qsTr("Image files")
        filters: Images.validImageExtensions
        onAccepted: path => {
            if (CUtils.copyFile(Qt.resolvedUrl(path), Qt.resolvedUrl(`${Paths.home}/.face`)))
                Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-u", "low", "-h", `STRING:image-path:${path}`, "Profile picture changed", `Profile picture changed to ${Paths.shortenHome(path)}`]);
            else
                Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-u", "critical", "Unable to change profile picture", `Failed to change profile picture to ${Paths.shortenHome(path)}`]);
        }
    }

    readonly property real nonAnimHeight: (content.item as Content)?.nonAnimHeight ?? 0
    readonly property bool shouldBeActive: screenState.dashboard && Config.dashboard.enabled && !GameMode.enabled
    property real offsetScale: shouldBeActive ? 0 : 1

    Connections {
        function onEnabledChanged(): void {
            if (GameMode.enabled)
                root.screenState.dashboard = false;
        }

        target: GameMode
    }

    Connections {
        function onDashboardChanged(): void {
            if (GameMode.enabled && root.screenState.dashboard)
                root.screenState.dashboard = false;
        }

        target: root.screenState
    }

    visible: offsetScale < 1
    anchors.topMargin: (-implicitHeight - 5) * offsetScale
    implicitHeight: content.implicitHeight || 854 // Hard coded fallback for first open
    implicitWidth: content.implicitWidth
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        // Outside Game Mode, build the dashboard in the background and retain
        // it for instant first/subsequent opens. Game Mode releases the cache.
        active: !GameMode.enabled

        sourceComponent: Content {
            screenState: root.screenState
            facePicker: root.facePicker
            dashboardActive: root.shouldBeActive
        }
    }
}
