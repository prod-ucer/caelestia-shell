pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property PopoutState popouts
    property bool devicesExpanded
    readonly property var playbackDevices: Audio.playbackDevices

    function deviceName(device): string {
        return device?.label || device?.properties?.["node.nick"] || device?.description || device?.name || qsTr("Unknown device");
    }

    function currentDeviceName(): string {
        const route = playbackDevices.find(device => Audio.isPlaybackDeviceActive(device));
        return deviceName(route || Audio.sink);
    }

    implicitWidth: 430
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.medium

        StyledText {
            text: qsTr("Audio")
            font: Tokens.font.title.medium
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: volumeRow.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            RowLayout {
                id: volumeRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                IconButton {
                    implicitWidth: implicitHeight
                    implicitHeight: Math.round(Tokens.sizes.bar.innerWidth * 0.68)
                    icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                    checked: Audio.muted
                    isToggle: true
                    type: IconButton.Tonal
                    onClicked: Audio.setStreamMuted(Audio.sink, !Audio.muted)
                }

                StyledSlider {
                    Layout.fillWidth: true
                    value: Audio.volume
                    enabled: !Audio.muted
                    onInteraction: value => Audio.setVolume(value)
                }

                StyledText {
                    id: percentLabel

                    Layout.preferredWidth: percentMetrics.width
                    text: Audio.muted ? qsTr("Muted") : `${Math.round(Audio.volume * 100)}%`
                    color: Audio.muted ? Colours.palette.m3outline : Colours.palette.m3onSurface
                    font: Tokens.font.label.medium
                    horizontalAlignment: Text.AlignRight

                    TextMetrics {
                        id: percentMetrics
                        text: "100%"
                        font: percentLabel.font
                    }
                }
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.small
            text: qsTr("Playback device")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.large
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            ButtonBase {
                id: deviceCombo

                Layout.fillWidth: true
                implicitWidth: 1
                implicitHeight: deviceLabel.implicitHeight + Tokens.padding.medium * 2
                inactiveColour: Colours.tPalette.m3surfaceContainer
                inactiveOnColour: Colours.palette.m3onSurface
                onClicked: root.devicesExpanded = !root.devicesExpanded

                StyledText {
                    id: deviceLabel

                    anchors.left: parent.left
                    anchors.right: expandIcon.left
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.rightMargin: Tokens.spacing.small
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.currentDeviceName()
                    color: deviceCombo.onColour
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                MaterialIcon {
                    id: expandIcon

                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.padding.medium
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.devicesExpanded ? "expand_less" : "expand_more"
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            StyledClippingRect {
                Layout.fillWidth: true
                implicitHeight: root.devicesExpanded ? Math.min(deviceList.contentHeight, 220) : 0
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainer
                opacity: root.devicesExpanded ? 1 : 0

                Behavior on implicitHeight {
                    Anim {}
                }

                StyledListView {
                    id: deviceList

                    anchors.fill: parent
                    clip: true
                    model: ScriptModel {
                        values: [...root.playbackDevices]
                    }

                    delegate: ButtonBase {
                        id: deviceOption

                        required property var modelData
                        required property int index

                        width: ListView.view.width
                        implicitWidth: 1
                        implicitHeight: optionLabel.implicitHeight + Tokens.padding.medium * 2
                        inactiveColour: Audio.isPlaybackDeviceActive(modelData) ? Colours.palette.m3primaryContainer : "transparent"
                        inactiveOnColour: Audio.isPlaybackDeviceActive(modelData) ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                        onClicked: {
                            Audio.setPlaybackDevice(modelData);
                            root.devicesExpanded = false;
                        }

                        StyledText {
                            id: optionLabel

                            anchors.left: parent.left
                            anchors.right: selectedIcon.left
                            anchors.leftMargin: Tokens.padding.medium
                            anchors.rightMargin: Tokens.spacing.small
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.deviceName(deviceOption.modelData)
                            color: deviceOption.onColour
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        MaterialIcon {
                            id: selectedIcon

                            anchors.right: parent.right
                            anchors.rightMargin: Tokens.padding.medium
                            anchors.verticalCenter: parent.verticalCenter
                            text: "check"
                            color: deviceOption.onColour
                            opacity: Audio.isPlaybackDeviceActive(deviceOption.modelData) ? 1 : 0
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.small
            text: Audio.appSessions.length === 0 ? qsTr("App Volumes") : qsTr("App Volumes · %1").arg(Audio.appSessions.length)
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.large
        }

        StyledClippingRect {
            Layout.fillWidth: true
            implicitHeight: Math.min(Math.max(appList.contentHeight, 64), 220)
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            StyledListView {
                id: appList

                anchors.fill: parent
                clip: true
                spacing: 1
                model: ScriptModel {
                    values: [...Audio.appSessions]
                }

                delegate: Item {
                    id: stream

                    required property var modelData
                    required property int index
                    readonly property real sessionVolume: Audio.appSessionVolume(modelData)
                    readonly property bool sessionMuted: Audio.appSessionMuted(modelData)
                    readonly property bool sessionActive: Audio.appSessionActive(modelData)

                    anchors.left: appList.contentItem.left
                    anchors.right: appList.contentItem.right
                    implicitHeight: 56
                    opacity: stream.sessionActive ? 1 : 0.65

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.rightMargin: Tokens.padding.medium
                        anchors.topMargin: Tokens.padding.small
                        anchors.bottomMargin: Tokens.padding.small
                        spacing: Tokens.spacing.extraSmall

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                text: Icons.getVolumeIcon(stream.sessionVolume, stream.sessionMuted)
                                color: Colours.palette.m3onSurfaceVariant
                                fontStyle: Tokens.font.icon.small
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: stream.modelData.name
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                            }

                            StyledText {
                                text: Math.round(stream.sessionVolume * 100) + "%"
                                color: Colours.palette.m3outline
                                font: Tokens.font.label.small
                            }
                        }

                        StyledSlider {
                            Layout.fillWidth: true
                            implicitHeight: 8
                            radius: Tokens.rounding.extraSmall
                            value: stream.sessionVolume
                            animateChanges: false
                            onInteraction: value => Audio.setAppSessionVolume(stream.modelData, value)
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: appList.count === 0
                    text: qsTr("No remembered audio applications are running")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                }
            }
        }
    }
}
