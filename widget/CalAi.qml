import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services.deferred
import "calai.js" as AiLib

// One-shot DeepSeek estimate. The key stays in the system keyring; the request carries one
// description and asks for strict JSON. No streaming, no retries, no background process.
Item {
    id: root

    visible: false
    width: 0
    height: 0

    property bool busy: false
    property bool keyLoading: false
    property string keySource: ""
    property string error: ""
    property var items: []
    property int totalKcal: 0
    property string note: ""
    property string lastDescription: ""

    readonly property bool onlineAllowed: (Config.options?.policies?.ai ?? 0) !== 2
    readonly property bool privacyBlocked: !root.onlineAllowed
    readonly property string _envKey: String(Quickshell.env("DEEPSEEK_API_KEY") ?? Quickshell.env("DEEPSEEK_KEY") ?? "")
    property string _storedKey: ""
    readonly property string apiKey: root._storedKey.length > 0 ? root._storedKey : root._envKey
    readonly property bool hasKey: root.apiKey.length > 0
    readonly property bool ready: root.onlineAllowed && root.hasKey && !root.keyLoading

    function refreshKey(): void {
        if (!root.onlineAllowed)
            return
        if (KeyringStorage.loaded) {
            root._readKey()
            return
        }
        if (!root.keyLoading) {
            root.keyLoading = true
            KeyringStorage.fetchKeyringData()
            keyFallback.restart()
        }
    }

    function _readKey(): void {
        const keys = KeyringStorage.keyringData?.apiKeys ?? {}
        const own = String(keys["calcalories-deepseek"] ?? "").trim()
        const shared = String(keys["deepseek"] ?? "").trim()
        root._storedKey = own.length > 0 ? own : shared
        root.keySource = own.length > 0 ? "widget keyring"
            : shared.length > 0 ? "DeepSeek keyring"
            : root._envKey.length > 0 ? "DEEPSEEK_API_KEY"
            : ""
        root.keyLoading = false
    }

    function saveKey(value: string): bool {
        const key = String(value ?? "").trim()
        if (key.length === 0) {
            root.error = "Paste a DeepSeek API key first."
            return false
        }
        if (!KeyringStorage.loaded) {
            root.error = "Reading the system keyring; press Save again in a moment."
            root.refreshKey()
            return false
        }
        KeyringStorage.setNestedField(["apiKeys", "calcalories-deepseek"], key)
        root._storedKey = key
        root.keySource = "widget keyring"
        root.error = ""
        root.keyLoading = false
        return true
    }

    function setSelected(index: int, selected: bool): void {
        if (index < 0 || index >= root.items.length)
            return
        const next = root.items.slice()
        next[index] = Object.assign({}, next[index], { selected: Boolean(selected) })
        root.items = next
    }

    function addItem(name: string, kcal: int): bool {
        const label = String(name ?? "").trim().slice(0, 48)
        const calories = Math.round(Number(kcal) || 0)
        if (label.length === 0 || calories <= 0 || calories > 5000)
            return false
        root.items = root.items.concat([{
            name: label,
            kcal: calories,
            protein: 0,
            carbs: 0,
            fat: 0,
            selected: true,
            source: "manual"
        }])
        return true
    }

    function removeItem(index: int): void {
        if (index < 0 || index >= root.items.length)
            return
        const next = root.items.slice()
        next.splice(index, 1)
        root.items = next
    }

    function clear(): void {
        root.error = ""
        root.items = []
        root.totalKcal = 0
        root.note = ""
        root.lastDescription = ""
    }

    function estimate(description: string): void {
        if (root.busy)
            return
        if (!root.onlineAllowed) {
            root.error = "Online AI is disabled by your AI privacy policy."
            return
        }
        if (!root.hasKey) {
            root.error = "Connect DeepSeek first."
            return
        }
        const text = String(description ?? "").trim()
        if (text.length === 0) {
            root.error = "Describe the meal first."
            return
        }

        const payload = AiLib.buildPayload(text)
        root.error = ""
        root.items = []
        root.totalKcal = 0
        root.note = ""
        root.lastDescription = text
        root.busy = true
        request.out = ""
        request.err = ""
        request.environment = ({
            CAL_KEY: root.apiKey,
            CAL_PAYLOAD: JSON.stringify(payload)
        })
        request.running = true
    }

    Timer {
        id: keyFallback
        interval: 1600
        onTriggered: {
            if (!KeyringStorage.loaded) {
                root.keyLoading = false
                root._readKey()
            }
        }
    }

    Connections {
        target: KeyringStorage
        function onLoadedChanged(): void {
            if (KeyringStorage.loaded)
                root._readKey()
        }
        function onKeyringDataChanged(): void {
            if (KeyringStorage.loaded)
                root._readKey()
        }
    }

    Process {
        id: request
        property string out: ""
        property string err: ""
        environment: ({ CAL_KEY: "", CAL_PAYLOAD: "" })
        command: [
            "/usr/bin/bash", "-c",
            "printf '%s' \"$CAL_PAYLOAD\" | /usr/bin/curl -sS --max-time 45 "
                + "-H 'Content-Type: application/json' "
                + "-H \"Authorization: Bearer $CAL_KEY\" "
                + "'https://api.deepseek.com/chat/completions' --data-binary @-"
        ]

        stdout: StdioCollector {
            onStreamFinished: request.out = text
        }
        stderr: StdioCollector {
            onStreamFinished: request.err = text
        }
        onExited: (exitCode, exitStatus) => {
            root.busy = false
            if (exitCode !== 0 && request.out.trim().length === 0) {
                const detail = request.err.trim()
                root.error = detail.length > 0 ? detail : "DeepSeek request failed (exit " + exitCode + ")."
                return
            }
            const result = AiLib.parseResponse(request.out)
            if (!result.ok) {
                root.error = result.error
                return
            }
            root.items = result.items
            root.totalKcal = result.totalKcal
            root.note = result.note
        }
    }
}
