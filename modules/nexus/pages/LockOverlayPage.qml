import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Lock overlay")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        ToggleRow {
            first: true
            text: qsTr("Hide notification details when locked")
            subtext: qsTr("Show the app and time without notification content")
            checked: GlobalConfig.lock.hideNotifDetails
            onToggled: GlobalConfig.lock.hideNotifDetails = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Hide music/video details when locked")
            subtext: qsTr("Show centred playback controls without artwork or track details")
            checked: GlobalConfig.lock.hideMediaDetails
            onToggled: GlobalConfig.lock.hideMediaDetails = checked
        }
    }
}
