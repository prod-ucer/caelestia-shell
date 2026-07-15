pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3tertiary
    readonly property int padding: Config.bar.clock.background ? Tokens.padding.medium : Tokens.padding.extraSmall
    readonly property var font: Tokens.font.body.builders.small.scale(1.0)

    implicitWidth: layout.implicitWidth + root.padding * 2
    implicitHeight: Math.round(Tokens.sizes.bar.innerWidth * 0.68)

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Config.bar.clock.background ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall

        Loader {
            Layout.alignment: Qt.AlignVCenter
            asynchronous: true
            active: Config.bar.clock.showIcon
            visible: active

            sourceComponent: MaterialIcon {
                verticalAlignment: Text.AlignVCenter
                text: "calendar_month"
                color: root.colour
            }
        }

        Loader {
            Layout.alignment: Qt.AlignVCenter
            asynchronous: true
            active: Config.bar.clock.showDate
            visible: active

            sourceComponent: RowLayout {
                spacing: layout.spacing
                Layout.alignment: Qt.AlignVCenter

                StyledText {
                    id: dateText

                    Layout.alignment: Qt.AlignVCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Time.format("ddd")
                    font: root.font.build()
                    color: root.colour
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Time.format("d")
                    font: root.font.build()
                    color: root.colour
                }
            }
        }

        StyledRect {
            visible: Config.bar.clock.showDate
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 1
            implicitHeight: hourMetrics.height
            color: Qt.alpha(root.colour, 0.5)
        }

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                id: hourText

                Layout.alignment: Qt.AlignVCenter
                text: Time.hourStr
                verticalAlignment: Text.AlignVCenter
                font: root.font.build()
                color: root.colour

                TextMetrics {
                    id: hourMetrics

                    font: root.font.build()
                    text: Time.hourStr
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                verticalAlignment: Text.AlignVCenter
                text: ":"
                font: root.font.build()
                color: root.colour
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                verticalAlignment: Text.AlignVCenter
                text: Time.minuteStr
                font: root.font.build()
                color: root.colour
            }

            Loader {
                Layout.alignment: Qt.AlignVCenter
                asynchronous: true
                active: GlobalConfig.services.useTwelveHourClock
                visible: active

                sourceComponent: StyledText {
                    verticalAlignment: Text.AlignVCenter
                    text: Time.amPmStr.toLowerCase()
                    font: Tokens.font.body.builders.small.scale(0.9).build()
                    color: root.colour
                }
            }
        }
    }
}
