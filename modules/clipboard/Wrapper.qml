pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState

    readonly property bool shouldBeActive: screenState.clipboard
    property real offsetScale: shouldBeActive ? 0 : 1
    property list<var> records
    property int requestedIndex
    property var pendingPinItem

    function refresh(): void {
        listProcess.running = false;
        listProcess.running = true;
    }

    function act(command: string, key: string, item = null): void {
        pendingPinItem = item;
        actionProcess.command = [Quickshell.env("HOME") + "/.local/bin/caelestia-clipboard", command, key];
        actionProcess.running = true;
    }

    visible: offsetScale < 1
    implicitWidth: Math.min(screen.width * 0.4, 560)
    implicitHeight: Math.min(screen.height * 0.62, 600)
    anchors.topMargin: (-implicitHeight - 5) * offsetScale
    opacity: 1 - offsetScale

    onShouldBeActiveChanged: {
        if (shouldBeActive) {
            requestedIndex = 0;
            refresh();
            Qt.callLater(() => list.forceActiveFocus());
        }
    }

    Behavior on offsetScale {
        Anim {}
    }

    Process {
        id: listProcess

        command: [Quickshell.env("HOME") + "/.local/bin/caelestia-clipboard", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.records = JSON.parse(text);
                } catch (error) {
                    console.warn("Failed to load clipboard history", error);
                    root.records = [];
                }
            }
        }
    }

    Process {
        id: actionProcess

        stdout: StdioCollector {
            onStreamFinished: {
                if (actionProcess.command[1] !== "toggle-pin" || !root.pendingPinItem)
                    return;
                try {
                    const result = JSON.parse(text);
                    if (result.remove)
                        root.refresh();
                    else
                        root.pendingPinItem.applyPinResult(result.key, result.pinned);
                } catch (error) {
                    console.warn("Failed to update clipboard pin", error);
                    root.refresh();
                }
                root.pendingPinItem = null;
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        Row {
            width: parent.width
            spacing: Tokens.spacing.medium

            StyledText {
                width: parent.width - clearButton.width - parent.spacing
                text: qsTr("Clipboard")
                font: Tokens.font.title.large
                color: Colours.palette.m3onSurface
            }

            TextButton {
                id: clearButton

                text: qsTr("Clear all")
                onClicked: {
                    const pinned = root.records.filter(item => item.pinned);
                    root.records = pinned;
                    actionProcess.command = [Quickshell.env("HOME") + "/.local/bin/caelestia-clipboard", "clear", pinned[0]?.key ?? ""];
                    actionProcess.running = true;
                }
            }
        }

        StyledListView {
            id: list

            width: parent.width
            height: parent.height - y
            clip: true
            spacing: Tokens.spacing.small
            model: root.records
            currentIndex: -1
            highlightMoveDuration: 70
            highlightMoveVelocity: -1

            Connections {
                target: root

                function onRecordsChanged(): void {
                    Qt.callLater(() => {
                        list.currentIndex = Math.min(root.requestedIndex, list.count - 1);
                        if (list.currentIndex >= 0)
                            list.positionViewAtIndex(list.currentIndex, ListView.Contain);
                    });
                }
            }

            Keys.onEscapePressed: root.screenState.clipboard = false
            Keys.onReturnPressed: {
                if (currentItem)
                    currentItem.copy();
            }
            Keys.onRightPressed: {
                if (currentItem && !currentItem.pinned)
                    currentItem.togglePin();
            }
            Keys.onLeftPressed: {
                if (currentItem && currentItem.pinned)
                    currentItem.togglePin();
            }

            delegate: Rectangle {
                id: item

                required property var modelData
                required property int index
                property bool pinned: modelData.pinned
                property string recordKey: modelData.key
                property bool pinBusy

                function applyPinResult(key: string, isPinned: bool): void {
                    recordKey = key;
                    pinned = isPinned;
                    root.records[index].key = key;
                    root.records[index].pinned = isPinned;
                    pinBusy = false;
                }

                function copy(): void {
                    root.act("copy", recordKey);
                    root.screenState.clipboard = false;
                }

                function togglePin(): void {
                    if (pinBusy)
                        return;
                    pinBusy = true;
                    root.requestedIndex = index;
                    root.act("toggle-pin", recordKey, item);
                }

                width: ListView.view.width
                height: modelData.image ? Math.min(140, root.height * 0.25) : Math.max(54, textItem.implicitHeight + Tokens.padding.medium * 2)
                radius: Tokens.rounding.medium
                color: ListView.isCurrentItem ? Colours.tPalette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer

                Image {
                    id: preview

                    visible: !!modelData.image
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: Tokens.padding.small
                    width: visible ? Math.min(parent.width * 0.42, 260) : 0
                    source: modelData.image
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                StyledText {
                    id: textItem

                    anchors.left: preview.visible ? preview.right : parent.left
                    anchors.right: pinButton.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Tokens.padding.medium
                    text: modelData.preview
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                    maximumLineCount: modelData.image ? 3 : 2
                    wrapMode: Text.Wrap
                }

                IconButton {
                    id: pinButton

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: Tokens.padding.small
                    icon: item.pinned ? "keep" : "keep_off"
                    enabled: !item.pinBusy
                    onClicked: item.togglePin()
                }

                MouseArea {
                    anchors.left: parent.left
                    anchors.right: pinButton.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    onClicked: {
                        list.currentIndex = item.index;
                        item.copy();
                    }
                }
            }
        }
    }
}
