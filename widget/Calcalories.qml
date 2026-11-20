pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.shared.background.widgets
import "calpalette.js" as Pal
import "calmath.js" as Cal

// A pastel pixel calorie counter with a carrot who has opinions about lunch.
// The card is deliberately its own sticker, so it keeps its pastel palette on any wallpaper.
AbstractBackgroundWidget {
    id: root

    configEntryName: "custom.calcalories"
    defaultConfig: ({
        placementStrategy: "free", widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        showBackground: false, backgroundOpacity: 0, borderWidth: 0, borderOpacity: 0, cornerRadius: 0, useBlur: false,
        x: 430, y: 140, targetKcal: 2200, profileJson: "", entriesJson: "[]", logDay: "",
        waterGlasses: 0, waterGoal: 8, waterReminder: true, waterIntervalMin: 60,
        waterLastReminder: 0, waterDay: ""
    })
    widgetSurfaceEnabled: false
    needsColText: false
    resizableAxes: ({ uniform: "widgetScale" })
    resizeMinWidth: 320
    resizeMinHeight: 210

    readonly property real d: root.scaleFactor

    FontLoader { id: silk; source: "fonts/Silkscreen-Regular.ttf" }
    FontLoader { id: silkBold; source: "fonts/Silkscreen-Bold.ttf" }
    FontLoader { id: body; source: "fonts/PixelifySans.ttf" }

    // ── The day ───────────────────────────────────────────────
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: root.visible
    }
    readonly property string dayKey: Cal.todayKey(clock.date)

    property bool hydrated: false
    property string logDay: ""
    property var entries: []
    property var profile: Cal.defaultProfile()
    property int targetKcal: 2200
    property bool panelOpen: false
    property int waterGlasses: 0
    property int waterGoal: 8
    property bool waterReminder: true
    property int waterIntervalMin: 60
    property double waterLastReminder: 0
    property string waterDay: ""
    property bool hovered: false
    property real pressScale: 1
    property real statScale: 1
    property real squash: 0
    property real burst: 0
    property int burstTick: 0
    property bool blink: false
    property int panelTab: 0

    readonly property int eaten: {
        let sum = 0
        for (let i = 0; i < root.entries.length; i++)
            sum += Number(root.entries[i].kcal) || 0
        return sum
    }
    readonly property int remaining: root.targetKcal - root.eaten
    readonly property bool over: root.remaining < 0
    readonly property real ratio: root.targetKcal > 0 ? root.eaten / root.targetKcal : 0
    readonly property string mood: root.entries.length === 0 ? "empty"
        : root.over ? "over" : root.ratio >= 0.82 ? "near" : "under"
    readonly property string moodWord: root.mood === "over" ? "OOF"
        : root.mood === "near" ? "ALMOST" : root.mood === "empty" ? "READY" : "ON TRACK"
    readonly property string remainingText: Cal.comma(Math.abs(root.remaining))
    readonly property string targetText: Cal.comma(root.targetKcal)
    readonly property string eatenText: Cal.comma(root.eaten)
    readonly property string dayLabel: Qt.formatDate(clock.date, "ddd dd").toUpperCase()
    readonly property string dayNote: root.entries.length === 0 ? "A blank receipt. Add the first bite."
        : root.over ? "Over by " + Cal.comma(-root.remaining) + " kcal. Walk it off, or start fresh tomorrow."
        : root.remaining > 700 ? "Room for " + Cal.comma(root.remaining) + " kcal. Make it a proper meal."
        : root.remaining > 250 ? "Room for " + Cal.comma(root.remaining) + " kcal. A snack, not a feast."
        : "Room for " + Cal.comma(root.remaining) + " kcal. Keep it light."
    readonly property int waterRemaining: Math.max(0, root.waterGoal - root.waterGlasses)
    readonly property real waterRatio: root.waterGoal > 0 ? Math.min(1, root.waterGlasses / root.waterGoal) : 0
    readonly property int filledSegments: Math.min(12, Math.floor(root.ratio * 12))
    readonly property real partialSegment: Math.min(1, Math.max(0, root.ratio * 12 - root.filledSegments))

    implicitWidth: Math.round(400 * root.d)
    implicitHeight: Math.round(260 * root.d)

    onDayKeyChanged: {
        if (!root.hydrated)
            return
        if (root.logDay !== root.dayKey || root.waterDay !== root.dayKey)
            root.resetDay()
    }

    Component.onCompleted: Qt.callLater(root.hydrate)
    Connections {
        target: Config
        function onReadyChanged(): void { root.hydrate() }
    }

    function hydrate(): void {
        if (root.hydrated || !Config.ready)
            return
        root.profile = Cal.parseProfile(String(root._readConfigKey("profileJson") ?? ""))
        root.entries = Cal.parseEntries(String(root._readConfigKey("entriesJson") ?? "[]"))
        root.targetKcal = Math.round(Cal.clamp(Number(root._readConfigKey("targetKcal") ?? 2200), 800, 6000))
        const storedDay = String(root._readConfigKey("logDay") ?? "")
        root.logDay = storedDay.length > 0 ? storedDay : root.dayKey
        root.hydrated = true
        if (root.logDay !== root.dayKey || root.waterDay !== root.dayKey)
            root.resetDay()
    }

    function setBarPill(enabled: bool): string {
        const on = Boolean(enabled)
        Config.setNestedValue("material.bar.modules.calories", on)
        Config.setNestedValue("material.bar.layout.migrated", true)
        let right = Array.from(Config.options?.material?.bar?.layout?.right ?? [])
        right = right.filter(id => id !== "calories")
        if (on) {
            const anchor = right.indexOf("rightSidebarButton")
            right.splice(anchor >= 0 ? anchor + 1 : 0, 0, "calories")
        }
        Config.setNestedValue("material.bar.layout.right", right)
        return on ? "Bar pill on." : "Bar pill off."
    }

    function saveState(): void {
        root._setOutputValues({
            targetKcal: root.targetKcal,
            profileJson: JSON.stringify(root.profile),
            entriesJson: JSON.stringify(root.entries),
            logDay: root.logDay,
            waterGlasses: root.waterGlasses,
            waterGoal: root.waterGoal,
            waterReminder: root.waterReminder,
            waterIntervalMin: root.waterIntervalMin,
            waterLastReminder: root.waterLastReminder,
            waterDay: root.waterDay
        })
    }

    function addEntry(name: string, kcal: int): bool {
        const cleanName = String(name ?? "").trim().slice(0, 42)
        const cleanKcal = Math.round(Cal.clamp(kcal, 1, 5000))
        if (cleanName.length === 0 || !Number.isFinite(cleanKcal) || cleanKcal <= 0)
            return false
        root.entries = root.entries.concat([{
            id: Date.now() + Math.floor(Math.random() * 1000),
            name: cleanName,
            kcal: cleanKcal,
            at: new Date().toISOString()
        }])
        root.logDay = root.dayKey
        root.saveState()
        root.celebrate()
        return true
    }

    function addEntries(list: var): bool {
        const clean = []
        for (let i = 0; i < (list ?? []).length; i++) {
            const item = list[i]
            if (!item)
                continue
            const name = String(item.name ?? "").trim().slice(0, 48)
            const kcal = Math.round(Cal.clamp(item.kcal, 1, 5000))
            if (name.length === 0 || kcal <= 0)
                continue
            clean.push({ name: name, kcal: kcal })
        }
        if (clean.length === 0)
            return false
        const stamp = Date.now()
        root.entries = root.entries.concat(clean.map((item, index) => ({
            id: stamp + index + Math.floor(Math.random() * 1000),
            name: item.name,
            kcal: item.kcal,
            at: new Date().toISOString()
        })))
        root.logDay = root.dayKey
        root.saveState()
        root.celebrate()
        return true
    }

    function removeEntry(id: int): void {
        root.entries = root.entries.filter(entry => Number(entry.id) !== Number(id))
        root.saveState()
    }

    function resetDay(): void {
        root.entries = []
        root.logDay = root.dayKey
        root.waterGlasses = 0
        root.waterDay = root.dayKey
        root.waterLastReminder = Date.now()
        root.saveState()
    }

    function addWater(): bool {
        if (!root.hydrated || root.waterGlasses >= root.waterGoal)
            return false
        root.waterGlasses += 1
        root.waterDay = root.dayKey
        root.waterLastReminder = Date.now()
        root.saveState()
        return true
    }

    function removeWater(): void {
        if (root.waterGlasses <= 0)
            return
        root.waterGlasses -= 1
        root.waterDay = root.dayKey
        root.saveState()
    }

    function resetWater(): void {
        root.waterGlasses = 0
        root.waterDay = root.dayKey
        root.waterLastReminder = Date.now()
        root.saveState()
    }

    function setWaterGoal(goal: int): void {
        root.waterGoal = Math.round(Cal.clamp(goal, 4, 16))
        if (root.waterGlasses > root.waterGoal)
            root.waterGlasses = root.waterGoal
        root.saveState()
    }

    function setWaterReminder(enabled: bool): void {
        root.waterReminder = Boolean(enabled)
        if (root.waterReminder)
            root.waterLastReminder = Date.now()
        root.saveState()
    }

    function setWaterInterval(minutes: int): void {
        root.waterIntervalMin = Math.round(Cal.clamp(minutes, 15, 180))
        root.waterLastReminder = Date.now()
        root.saveState()
    }

    function sendWaterNotification(test: bool): void {
        if (!test && (!root.waterReminder || root.waterGlasses >= root.waterGoal))
            return
        const left = Math.max(0, root.waterGoal - root.waterGlasses)
        const body = root.waterGlasses + " of " + root.waterGoal + " glasses today"
            + (left > 0 ? " — " + left + " to go." : ".")
        Quickshell.execDetached(["notify-send", "-a", "Calcorie",
            "-i", "dialog-information", "Water break", body])
        if (!test) {
            root.waterLastReminder = Date.now()
            root.saveState()
        }
    }

    function checkWaterReminder(): void {
        if (!root.waterReminder || root.waterGlasses >= root.waterGoal)
            return
        const hour = new Date().getHours()
        if (hour < 8 || hour >= 22)
            return
        if (root.waterLastReminder > 0 && Date.now() - root.waterLastReminder < root.waterIntervalMin * 60000)
            return
        root.sendWaterNotification(false)
    }

    function resetAll(): void {
        root.profile = Cal.defaultProfile()
        root.targetKcal = 2200
        root.entries = []
        root.logDay = root.dayKey
        root.waterGlasses = 0
        root.waterGoal = 8
        root.waterReminder = true
        root.waterIntervalMin = 60
        root.waterLastReminder = Date.now()
        root.waterDay = root.dayKey
        root.saveState()
    }

    function useTarget(value: int): void {
        root.targetKcal = Math.round(Cal.clamp(value, 800, 6000))
        root.saveState()
    }

    function saveProfile(nextProfile: var, nextTarget: int): void {
        root.profile = Cal.cleanProfile(nextProfile)
        root.targetKcal = Math.round(Cal.clamp(nextTarget, 800, 6000))
        root.saveState()
    }

    function celebrate(): void {
        if (!root.animationsActive) {
            root.statScale = 1
            root.squash = 0
            return
        }
        statBump.restart()
        carrotBounce.restart()
        burstAnim.restart()
        root.blink = true
        blinkTimer.restart()
        root.burstTick += 1
    }

    function openPanel(tab: int): void {
        if (GlobalStates.widgetEditMode)
            return
        if (tab !== undefined)
            root.panelTab = tab
        root.panelOpen = true
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.hydrated && root.waterReminder
        onTriggered: root.checkWaterReminder()
    }

    SequentialAnimation {
        id: statBump
        NumberAnimation { target: root; property: "statScale"; to: 1.09; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "statScale"; to: 1; duration: 360; easing.type: Easing.OutElastic; easing.amplitude: 1.8; easing.period: 0.3 }
    }
    SequentialAnimation {
        id: carrotBounce
        NumberAnimation { target: root; property: "squash"; to: 1; duration: 80; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "squash"; to: 0; duration: 520; easing.type: Easing.OutElastic; easing.amplitude: 2.2; easing.period: 0.3 }
    }
    SequentialAnimation {
        id: hoverPeek
        NumberAnimation { target: root; property: "squash"; to: 0.24; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "squash"; to: 0; duration: 320; easing.type: Easing.OutElastic; easing.amplitude: 1.8; easing.period: 0.3 }
    }
    Timer {
        id: blinkTimer
        interval: 140
        onTriggered: root.blink = false
    }
    NumberAnimation {
        id: burstAnim
        target: root
        property: "burst"
        from: 0
        to: 1
        duration: 520
        easing.type: Easing.OutCubic
        onStopped: root.burst = 0
    }

    // ── The sticker ───────────────────────────────────────────
    Item {
        id: stage
        anchors.fill: parent
        scale: root.pressScale
        transformOrigin: Item.Center

        Behavior on scale {
            enabled: root.animationsActive
            NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
        }
        transform: Translate {
            y: root.hovered && !GlobalStates.widgetEditMode ? Math.round(-2 * root.d) : 0
            Behavior on y {
                enabled: root.animationsActive
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }

        readonly property real bodyW: root.width - Math.round(6 * root.d)

        PixelBox {
            anchors.fill: parent
            fill: Pal.paper
            line: Pal.ink
            lineWidth: Math.max(2, Math.round(2 * root.d))
            shadowOffset: Math.round(6 * root.d)
            cut: Math.round(8 * root.d)
            headerHeight: Math.round(38 * root.d)
            headerFill: Pal.peach
        }

        // Header: a pocket console label, not a dashboard title.
        Row {
            x: Math.round(16 * root.d)
            y: Math.round(11 * root.d)
            spacing: Math.round(6 * root.d)
            Rectangle {
                width: Math.round(5 * root.d)
                height: width
                color: Pal.ink
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "CALCORIE"
                color: Pal.ink
                font.family: "Silkscreen"
                font.pixelSize: Math.round(14 * root.d)
                font.letterSpacing: Math.round(1.2 * root.d)
                renderType: Text.NativeRendering
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: Math.round(16 * root.d)
            y: Math.round(12 * root.d)
            spacing: Math.round(4 * root.d)
            Repeater {
                model: [Pal.mint, Pal.lemon, Pal.rose]
                Rectangle {
                    required property var modelData
                    width: Math.round(5 * root.d)
                    height: width
                    color: modelData
                    border.width: Math.max(1, Math.round(root.d))
                    border.color: Pal.ink
                }
            }
            Text {
                text: root.dayLabel
                color: Pal.ink
                font.family: "Silkscreen"
                font.pixelSize: Math.round(14 * root.d)
                renderType: Text.NativeRendering
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Mascot stage.
        PixelBox {
            id: mascotStage
            x: Math.round(14 * root.d)
            y: Math.round(54 * root.d)
            width: Math.round(108 * root.d)
            height: Math.round(130 * root.d)
            fill: Pal.paper2
            line: Pal.ink
            lineWidth: Math.max(1, Math.round(2 * root.d))
            shadowOffset: 0
            cut: Math.round(4 * root.d)
            dither: true
        }
        CarrotMascot {
            id: mascot
            anchors.horizontalCenter: mascotStage.horizontalCenter
            y: mascotStage.y + Math.round(4 * root.d)
            width: Math.round(88 * root.d)
            height: Math.round(106 * root.d)
            mood: root.mood
            squash: root.squash
            blink: root.blink
        }
        Text {
            anchors.horizontalCenter: mascotStage.horizontalCenter
            anchors.bottom: mascotStage.bottom
            anchors.bottomMargin: Math.round(5 * root.d)
            text: root.moodWord
            color: Pal.inkSoft
            font.family: "Silkscreen"
            font.pixelSize: Math.round(14 * root.d)
            font.letterSpacing: Math.round(0.8 * root.d)
            renderType: Text.NativeRendering
        }

        // Tiny pixel sparkles around the stage.
        Repeater {
            model: [
                { x: 108, y: 58, s: 4, c: Pal.lemon },
                { x: 116, y: 150, s: 3, c: Pal.sky },
                { x: 5, y: 138, s: 3, c: Pal.lilac },
                { x: 96, y: 43, s: 2, c: Pal.rose }
            ]
            Rectangle {
                required property var modelData
                x: Math.round(modelData.x * root.d)
                y: Math.round(modelData.y * root.d)
                width: Math.round(modelData.s * root.d)
                height: width
                color: modelData.c
                border.width: modelData.s > 3 ? Math.max(1, Math.round(root.d)) : 0
                border.color: Pal.ink
            }
        }

        // The number.
        Column {
            x: Math.round(140 * root.d)
            y: Math.round(54 * root.d)
            width: stage.bodyW - Math.round(156 * root.d)
            spacing: Math.round(1 * root.d)

            Text {
                text: root.over ? "OVER BY" : "KCAL LEFT"
                color: Pal.inkSoft
                font.family: "Silkscreen"
                font.pixelSize: Math.round(14 * root.d)
                font.letterSpacing: Math.round(1.1 * root.d)
                renderType: Text.NativeRendering
            }

            Item {
                width: parent.width
                height: Math.round(54 * root.d)
                scale: root.statScale
                transformOrigin: Item.BottomLeft

                Text {
                    width: parent.width
                    height: parent.height
                    text: root.remainingText
                    color: root.over ? Pal.tomatoInk : Pal.ink
                    font.family: "Silkscreen"
                    font.pixelSize: Math.round(48 * root.d)
                    font.weight: Font.Bold
                    renderType: Text.NativeRendering
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    fontSizeMode: Text.Fit
                    minimumPixelSize: Math.round(26 * root.d)
                }
            }

            Text {
                text: "of " + root.targetText + " kcal"
                color: Pal.inkSoft
                font.family: "Pixelify Sans"
                font.pixelSize: Math.round(14 * root.d)
                renderType: Text.NativeRendering
            }

            Row {
                width: parent.width
                height: Math.round(12 * root.d)
                spacing: Math.round(3 * root.d)
                Repeater {
                    model: 12
                    Item {
                        required property int index
                        width: Math.max(2, Math.floor((parent.width - Math.round(33 * root.d)) / 12))
                        height: Math.round(12 * root.d)
                        readonly property bool lit: index < root.filledSegments
                        readonly property bool partial: index === root.filledSegments && root.partialSegment > 0.01
                        readonly property color tint: root.over ? (index % 2 === 0 ? Pal.tomato : Pal.rose)
                            : Pal.cycle[index % Pal.cycle.length]

                        Rectangle {
                            anchors.fill: parent
                            color: parent.lit ? parent.tint : Pal.paper2
                            border.width: Math.max(1, Math.round(root.d))
                            border.color: Pal.ink
                            opacity: parent.lit ? 1 : 0.46
                        }
                        Rectangle {
                            visible: parent.partial
                            width: Math.round(parent.width * Math.round(root.partialSegment * 4) / 4)
                            height: parent.height
                            color: parent.tint
                            border.width: Math.max(1, Math.round(root.d))
                            border.color: Pal.ink
                        }
                        Rectangle {
                            visible: parent.lit
                            x: Math.round(root.d)
                            y: Math.round(root.d)
                            width: Math.max(1, parent.width - Math.round(2 * root.d))
                            height: Math.max(1, Math.round(root.d))
                            color: Pal.paper
                            opacity: 0.28
                        }
                    }
                }
            }
        }

        // Stats line.
        Row {
            x: Math.round(140 * root.d)
            y: Math.round(186 * root.d)
            width: stage.bodyW - Math.round(156 * root.d)
            spacing: Math.round(6 * root.d)
            Text {
                text: root.eatenText + " in"
                color: Pal.ink
                font.family: "Silkscreen"
                font.pixelSize: Math.round(14 * root.d)
                renderType: Text.NativeRendering
            }
            Rectangle {
                width: Math.round(2 * root.d)
                height: Math.round(9 * root.d)
                color: Pal.ink
                opacity: 0.3
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.entries.length + (root.entries.length === 1 ? " bite" : " bites")
                color: Pal.inkSoft
                font.family: "Pixelify Sans"
                font.pixelSize: Math.round(14 * root.d)
                renderType: Text.NativeRendering
            }
            Rectangle {
                width: Math.round(2 * root.d)
                height: Math.round(9 * root.d)
                color: Pal.ink
                opacity: 0.3
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                width: Math.round(5 * root.d)
                height: Math.round(5 * root.d)
                color: Pal.sky
                border.width: Math.max(1, Math.round(root.d))
                border.color: Pal.ink
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.waterGlasses + "/" + root.waterGoal + " water"
                color: Pal.inkSoft
                font.family: "Pixelify Sans"
                font.pixelSize: Math.round(14 * root.d)
                renderType: Text.NativeRendering
            }
        }

        // Footer strip.
        Rectangle {
            x: Math.round(14 * root.d)
            y: Math.round(210 * root.d)
            width: stage.bodyW - Math.round(32 * root.d)
            height: Math.max(1, Math.round(root.d))
            color: Pal.ink
            opacity: 0.22
        }
        Text {
            x: Math.round(16 * root.d)
            y: Math.round(218 * root.d)
            text: root.over ? "TAP TO LOG + WALK IT OFF" : "TAP TO LOG A BITE"
            color: Pal.ink
            font.family: "Silkscreen"
            font.pixelSize: Math.round(14 * root.d)
            font.letterSpacing: Math.round(0.7 * root.d)
            renderType: Text.NativeRendering
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: Math.round(16 * root.d)
            y: Math.round(215 * root.d)
            spacing: Math.round(2 * root.d)
            Repeater {
                model: [2, 1, 3, 1, 2, 1, 4, 1, 2, 3, 1]
                Rectangle {
                    required property int modelData
                    width: Math.round(modelData * root.d)
                    height: Math.round(14 * root.d)
                    color: Pal.ink
                    opacity: 0.34
                }
            }
        }

        // Pixel confetti: only during the 0.5s after a bite.
        Repeater {
            model: 10
            Rectangle {
                required property int index
                readonly property real angle: (index / 10) * Math.PI * 2 + 0.3
                readonly property real dist: (34 + (index % 4) * 9) * root.d
                width: Math.round((3 + (index % 2)) * root.d)
                height: width
                color: Pal.cycle[index % Pal.cycle.length]
                x: Math.round(66 * root.d + Math.cos(angle) * dist * root.burst - width / 2)
                y: Math.round(108 * root.d + Math.sin(angle) * dist * root.burst - height / 2)
                visible: root.burst > 0
                opacity: Math.max(0, 1 - root.burst)
            }
        }
    }

    // The whole sticker is one big hit area; edit mode keeps the base's drag and resize.
    MouseArea {
        id: cardMouse
        anchors.fill: parent
        enabled: !GlobalStates.widgetEditMode
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            root.hovered = true
            if (root.animationsActive) {
                hoverPeek.restart()
                root.blink = true
                blinkTimer.restart()
            }
        }
        onExited: root.hovered = false
        onPressed: root.pressScale = 0.985
        onReleased: root.pressScale = 1
        onCanceled: root.pressScale = 1
        onClicked: root.openPanel(0)
    }

    LazyLoader {
        active: root.panelOpen
        CalPanel {
            widget: root
            initialTab: root.panelTab
            screen: root.desktop ? root.desktop.screen : null
            onDismissed: root.panelOpen = false
        }
    }

    /// Open the calorie console.
    /// Close the calorie console.
    /// Toggle the calorie console.
    /// Log a food by name and calories.
    /// Start today with an empty log.
    IpcHandler {
        target: "calcalories"
        function open(): void { root.openPanel(0) }
        function budget(): void { root.openPanel(2) }
        function ai(): void { root.openPanel(1) }
        function water(): void { root.openPanel(3) }
        function waterAdd(): void { root.addWater() }
        function waterTest(): void { root.sendWaterNotification(true) }
        function close(): void { root.panelOpen = false }
        function toggle(): void { root.panelOpen = !root.panelOpen }
        function add(name: string, kcal: int): void { root.addEntry(name, kcal) }
        function reset(): void { root.resetDay() }
        function defaults(): void { root.resetAll() }
        function bar(enabled: bool): string { return root.setBarPill(enabled) }
    }

    // New name, same widget. Keep the original target so existing keybinds,
    // scripts and the installed folder continue to work.
    IpcHandler {
        target: "calcorie"
        function open(): void { root.openPanel(0) }
        function budget(): void { root.openPanel(2) }
        function ai(): void { root.openPanel(1) }
        function water(): void { root.openPanel(3) }
        function waterAdd(): void { root.addWater() }
        function waterTest(): void { root.sendWaterNotification(true) }
        function close(): void { root.panelOpen = false }
        function toggle(): void { root.panelOpen = !root.panelOpen }
        function add(name: string, kcal: int): void { root.addEntry(name, kcal) }
        function reset(): void { root.resetDay() }
        function defaults(): void { root.resetAll() }
        function bar(enabled: bool): string { return root.setBarPill(enabled) }
    }
}
