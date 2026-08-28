pragma Singleton

import QtQuick
import Quickshell

/**
 * BluetoothConnection
 *
 * Centralized utility for bluetooth connect/disconnect logic. Provides a single
 * source of truth for how trust is handled around a state change, eliminating
 * code duplication across the bar popout and the settings pages.
 *
 * Trust matters in both directions:
 *
 *  - Connecting: BlueZ refuses to connect a bonded device that is not trusted,
 *    so trust has to be granted first and allowed to settle.
 *
 *  - Disconnecting: BlueZ auto-reconnects a trusted device as soon as it
 *    advertises again, which for a device that re-advertises immediately (ZMK
 *    keyboards, many earbuds) means a manual disconnect appears to be ignored
 *    and the device flaps straight back to connected. Dropping trust first
 *    makes the disconnect stick; the connect path above re-grants it, so the
 *    device still connects with a single click afterwards.
 */
Singleton {
    id: root

    function setConnected(device: var, connected: bool): void {
        if (!device)
            return;

        if (connected) {
            if (device.bonded && !device.trusted) {
                device.trusted = true;
                const currentDevice = device;
                Qt.callLater(() => currentDevice.connected = true);
            } else {
                device.connected = true;
            }
        } else {
            device.trusted = false;
            device.connected = false;
        }
    }

    function toggleConnected(device: var): void {
        if (device)
            root.setConnected(device, !device.connected);
    }
}
