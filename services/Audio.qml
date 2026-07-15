pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Caelestia
import Caelestia.Config
import Caelestia.Services
import qs.utils

Singleton {
    id: root

    property string previousSinkName: ""
    property string previousSourceName: ""

    property list<PwNode> sinks: []
    property list<PwNode> sources: []
    property list<PwNode> streams: []
    property var routeConfig: null
    property list<var> knownSessions: []
    property list<string> runningBinaries: []
    property var appliedStreamIds: ({})
    property var pendingSessionSave: null

    readonly property list<var> appSessions: {
        const activeKeys = new Set(streams.map(node => streamKey(node)));
        return knownSessions.filter(session => activeKeys.has(session.key)
            || (session.binary && runningBinaries.includes(session.binary)));
    }

    readonly property list<var> playbackDevices: {
        const routes = routeConfig?.routes ?? [];
        const managedPattern = routeConfig?.managedSinkPattern ?? "";
        const normalSinks = sinks.filter(node => {
            const name = (node?.name || "").toLowerCase();
            const description = (node?.description || "").toLowerCase();
            return !name.includes("hdmi")
                && !description.includes("hdmi / displayport")
                && (!managedPattern || !name.includes(managedPattern.toLowerCase()));
        });
        return [...routes, ...normalSinks];
    }

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool muted: !!sink?.audio?.muted
    readonly property real volume: sink?.audio?.volume ?? 0

    readonly property bool sourceMuted: !!source?.audio?.muted
    readonly property real sourceVolume: source?.audio?.volume ?? 0

    readonly property alias cava: cava
    readonly property alias beatTracker: beatTracker

    function setVolume(newVolume: real): void {
        if (sink?.ready && sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(GlobalConfig.services.maxVolume, newVolume));
        }
    }

    function incrementVolume(amount: real): void {
        setVolume(volume + (amount || GlobalConfig.services.audioIncrement));
    }

    function decrementVolume(amount: real): void {
        setVolume(volume - (amount || GlobalConfig.services.audioIncrement));
    }

    function setSourceVolume(newVolume: real): void {
        if (source?.ready && source?.audio) {
            source.audio.muted = false;
            source.audio.volume = Math.max(0, Math.min(GlobalConfig.services.maxVolume, newVolume));
        }
    }

    function incrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume + (amount || GlobalConfig.services.audioIncrement));
    }

    function decrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume - (amount || GlobalConfig.services.audioIncrement));
    }

    function setAudioSink(newSink: PwNode): void {
        Pipewire.preferredDefaultAudioSink = newSink;
    }

    function isPlaybackDeviceActive(device: var): bool {
        if (device?.profile)
            return !!device.sinkPattern && (sink?.name || "").includes(device.sinkPattern);
        return device?.id === sink?.id;
    }

    function setPlaybackDevice(device: var): void {
        if (device?.profile && routeConfig?.card) {
            routeSwitch.command = [`${Paths.home}/.local/bin/caelestia-audio-route`, routeConfig.card, device.profile, device.sinkPattern];
            routeSwitch.running = true;
        } else {
            setAudioSink(device);
        }
    }

    function setAudioSource(newSource: PwNode): void {
        Pipewire.preferredDefaultAudioSource = newSource;
    }

    function cycleNextAudioOutput(): void {
        if (sinks.length === 0)
            return;

        const currentIndex = sinks.findIndex(s => s === sink);
        const nextIndex = (currentIndex + 1) % sinks.length;
        setAudioSink(sinks[nextIndex]);
    }

    function setStreamVolume(stream: PwNode, newVolume: real): void {
        if (stream?.ready && stream?.audio) {
            stream.audio.muted = false;
            stream.audio.volume = Math.max(0, Math.min(GlobalConfig.services.maxVolume, newVolume));
        }
    }

    function setStreamMuted(stream: PwNode, muted: bool): void {
        if (stream?.ready && stream?.audio) {
            stream.audio.muted = muted;
        }
    }

    function getStreamVolume(stream: PwNode): real {
        return stream?.audio?.volume ?? 0;
    }

    function getStreamMuted(stream: PwNode): bool {
        return !!stream?.audio?.muted;
    }

    function getStreamName(stream: PwNode): string {
        if (!stream)
            return qsTr("Unknown");
        // Try application name first, then description, then name
        return stream.properties["application.name"] || stream.description || stream.name || qsTr("Unknown Application");
    }

    function streamBinary(stream: PwNode): string {
        const binary = stream?.properties?.["application.process.binary"] || stream?.name || "";
        return binary.split("/").pop();
    }

    function streamKey(stream: PwNode): string {
        const identity = stream?.properties?.["application.id"]
            || stream?.properties?.["application.name"]
            || streamBinary(stream)
            || stream?.name;
        return (identity || `stream-${stream?.id ?? "unknown"}`).toLowerCase();
    }

    function saveKnownSessions(): void {
        if (sessionStorage.loaded)
            sessionStorage.setText(JSON.stringify(knownSessions, null, 2));
    }

    function updateKnownSession(session: var): void {
        if (!session?.key || !session?.binary)
            return;
        const sessions = [...knownSessions];
        const index = sessions.findIndex(item => item.key === session.key);
        const saved = {
            key: session.key,
            name: session.name,
            binary: session.binary,
            volume: session.volume,
            muted: session.muted
        };
        if (index < 0)
            sessions.push(saved);
        else
            sessions[index] = saved;
        knownSessions = sessions;
        saveKnownSessions();
    }

    function syncKnownSessions(): void {
        const applied = Object.assign({}, appliedStreamIds);
        for (const node of streams) {
            if (!node?.ready || !node?.audio)
                continue;
            const key = streamKey(node);
            const saved = knownSessions.find(session => session.key === key);
            if (saved && !applied[node.id]) {
                node.audio.volume = saved.volume;
                node.audio.muted = saved.muted;
                applied[node.id] = true;
            }
            updateKnownSession({
                key,
                name: getStreamName(node),
                binary: streamBinary(node),
                volume: saved?.volume ?? node?.audio?.volume ?? 0,
                muted: saved?.muted ?? node?.audio?.muted ?? false
            });
        }
        appliedStreamIds = applied;
    }

    function setAppSessionVolume(session: var, newVolume: real): void {
        const volume = Math.max(0, Math.min(GlobalConfig.services.maxVolume, newVolume));
        const nodes = appSessionNodes(session);
        if (nodes.length > 0) {
            for (const node of nodes)
                setStreamVolume(node, volume);
            pendingSessionSave = Object.assign({}, session, {volume, muted: false});
            sessionSaveTimer.restart();
        } else {
            updateKnownSession(Object.assign({}, session, {volume, muted: false}));
        }
    }

    function appSessionNodes(session: var): list<PwNode> {
        return streams.filter(node => streamKey(node) === session.key);
    }

    function appSessionActive(session: var): bool {
        return appSessionNodes(session).length > 0;
    }

    function appSessionVolume(session: var): real {
        const node = appSessionNodes(session)[0];
        return node?.audio?.volume ?? session?.volume ?? 0;
    }

    function appSessionMuted(session: var): bool {
        const node = appSessionNodes(session)[0];
        return node?.audio?.muted ?? session?.muted ?? false;
    }

    function refreshAudioNodes(): void {
        const newSinks = [];
        const newSources = [];
        const newStreams = [];

        for (const node of Pipewire.nodes.values) {
            if (!node.isStream) {
                if (node.isSink)
                    newSinks.push(node);
                else if (node.audio)
                    newSources.push(node);
            } else if (node.isSink && node.audio) {
                newStreams.push(node);
            }
        }

        const sameNodes = (current, next) => current.length === next.length
            && current.every((node, index) => node?.id === next[index]?.id);
        if (!sameNodes(sinks, newSinks))
            sinks = newSinks;
        if (!sameNodes(sources, newSources))
            sources = newSources;
        if (!sameNodes(streams, newStreams)) {
            streams = newStreams;
            Qt.callLater(syncKnownSessions);
        }
    }

    onSinkChanged: {
        if (!sink?.ready)
            return;

        const newSinkName = sink.description || sink.name || qsTr("Unknown Device");

        if (previousSinkName && previousSinkName !== newSinkName && GlobalConfig.utilities.toasts.audioOutputChanged)
            Toaster.toast(qsTr("Audio output changed"), qsTr("Now using: %1").arg(newSinkName), "volume_up");

        previousSinkName = newSinkName;
    }

    onSourceChanged: {
        if (!source?.ready)
            return;

        const newSourceName = source.description || source.name || qsTr("Unknown Device");

        if (previousSourceName && previousSourceName !== newSourceName && GlobalConfig.utilities.toasts.audioInputChanged)
            Toaster.toast(qsTr("Audio input changed"), qsTr("Now using: %1").arg(newSourceName), "mic");

        previousSourceName = newSourceName;
    }

    Component.onCompleted: {
        previousSinkName = sink?.description || sink?.name || qsTr("Unknown Device");
        previousSourceName = source?.description || source?.name || qsTr("Unknown Device");
        refreshAudioNodes();
    }

    Connections {
        function onValuesChanged(): void {
            root.refreshAudioNodes();
        }

        target: Pipewire.nodes
    }

    PwObjectTracker {
        objects: [...Pipewire.nodes.values]
    }

    FileView {
        printErrors: false
        path: `${Paths.config}/audio-routes.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.routeConfig = JSON.parse(text());
            } catch (e) {
                console.error("Failed to parse audio route configuration:", e.message);
                root.routeConfig = null;
            }
        }
        onLoadFailed: root.routeConfig = null
    }

    FileView {
        id: sessionStorage

        property bool loaded

        printErrors: false
        path: `${Paths.state}/audio-sessions.json`
        onLoaded: {
            try {
                const sessions = JSON.parse(text());
                const byName = new Map();
                for (const session of sessions) {
                    if (session.binary === "caelestia-shell" || session.binary === "pw-cat")
                        continue;
                    const key = (session.name || session.key).toLowerCase();
                    byName.set(key, Object.assign({}, session, {key}));
                }
                root.knownSessions = [...byName.values()];
            } catch (e) {
                root.knownSessions = [];
            }
            loaded = true;
            root.saveKnownSessions();
            root.syncKnownSessions();
        }
        onLoadFailed: err => {
            loaded = true;
            if (err === FileViewError.FileNotFound)
                setText("[]");
        }
    }

    Process {
        id: runningApps

        running: true
        command: ["/usr/bin/ps", "-eo", "comm="]
        stdout: StdioCollector {
            onStreamFinished: {
                const binaries = [...new Set(text.split("\n").map(line => line.trim()).filter(Boolean))].sort();
                if (binaries.join("\n") !== root.runningBinaries.join("\n"))
                    root.runningBinaries = binaries;
                root.refreshAudioNodes();
            }
        }
    }

    Timer {
        id: sessionSaveTimer

        interval: 350
        onTriggered: {
            if (root.pendingSessionSave) {
                root.updateKnownSession(root.pendingSessionSave);
                root.pendingSessionSave = null;
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            if (!runningApps.running)
                runningApps.running = true;
        }
    }

    Process {
        id: routeSwitch

        onExited: exitCode => {
            if (exitCode !== 0)
                console.error("Failed to switch audio route, exit code:", exitCode);
        }
    }

    CavaProvider {
        id: cava

        bars: GlobalConfig.services.visualiserBars
    }

    BeatTracker {
        id: beatTracker
    }

    IpcHandler {
        function cycleOutput(): void {
            root.cycleNextAudioOutput();
        }

        target: "audio"
    }
}
