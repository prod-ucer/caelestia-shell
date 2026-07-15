pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus

Singleton {
    id: root

    property var currentWindow

    function activeScreen(): var {
        const monitor = Hypr.focusedMonitor;
        return Screens.screens.find(screen => Hypr.monitorFor(screen) === monitor) ?? null;
    }

    function create(parent: Item, props: var): void {
        const requested = props ?? ({});
        if (!requested.screen)
            requested.screen = activeScreen();
        const window = nexusComp.createObject(parent ?? dummy, requested);
        if (window)
            currentWindow = window;
    }

    function toggle(): void {
        const screen = activeScreen();
        if (currentWindow) {
            const sameScreen = currentWindow.screen === screen;
            currentWindow.destroy();
            currentWindow = null;
            if (sameScreen)
                return;
        }
        create(null, { screen });
    }

    QtObject {
        id: dummy
    }

    Component {
        id: nexusComp

        FloatingWindow {
            id: win

            color: Colours.tPalette.m3surface
            surfaceFormat.opaque: false

            onVisibleChanged: {
                if (!visible)
                    destroy();
            }
            Component.onDestruction: {
                if (root.currentWindow === win)
                    root.currentWindow = null;
            }

            implicitWidth: nexus.implicitWidth
            implicitHeight: nexus.implicitHeight

            minimumSize.width: Math.min(contentItem.Tokens.sizes.nexus.minWidth, screen.width * 0.9)
            minimumSize.height: Math.min(contentItem.Tokens.sizes.nexus.minHeight, screen.height * 0.9)

            contentItem.Config.screen: screen.name
            contentItem.Tokens.screen: screen.name

            title: qsTr("Nexus — %1").arg(PageRegistry.pages[nexus.nState.currentPageIdx].label)

            Nexus {
                id: nexus

                anchors.fill: parent
                nState.screen: win.screen
                nState.isWindow: true
                onClose: win.destroy()
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
