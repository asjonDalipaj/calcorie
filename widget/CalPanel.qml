pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "calpalette.js" as Pal
import "calmath.js" as Cal

// The full console. It is a layer-shell window rather than an expanding card: a calorie log
// needs a keyboard, a list and room for the maths, and none of those belong on a wallpaper.
PanelWindow {
    id: panel

    property var widget: null
    property int initialTab: 0
    readonly property real d: 1
    readonly property var p: Pal

    signal dismissed()

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:calcalories"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    FontLoader { id: silk; source: "fonts/Silkscreen-Regular.ttf" }
    FontLoader { id: body; source: "fonts/PixelifySans.ttf" }

    CalAi { id: ai }

    property int tab: 0
    property string foodName: ""
    property string foodKcal: ""
    property string targetDraft: "2200"
    property var draft: Cal.defaultProfile()
    property string status: ""
    property string aiPromptText: ""
    property string aiStatus: ""
    property bool aiKeyEdit: false
    property bool aiAddOpen: false
    property bool confirmReset: false
    property bool savedFlash: false

    readonly property int suggested: Cal.suggested(panel.draft)
    readonly property int maintenance: Math.round(Cal.tdee(panel.draft))
    readonly property int basal: Math.round(Cal.bmr(panel.draft))
    readonly property var aiPicked: {
        const picked = []
        for (let i = 0; i < ai.items.length; i++)
            if (ai.items[i].selected)
                picked.push(ai.items[i])
        return picked
    }
    readonly property int aiPickedKcal: {
        let sum = 0
        for (let i = 0; i < panel.aiPicked.length; i++) sum += Number(panel.aiPicked[i].kcal) || 0
        return sum
    }
    readonly property int aiProtein: {
        let sum = 0
        for (let i = 0; i < panel.aiPicked.length; i++) sum += Number(panel.aiPicked[i].protein) || 0
        return sum
    }
    readonly property int aiCarbs: {
        let sum = 0
        for (let i = 0; i < panel.aiPicked.length; i++) sum += Number(panel.aiPicked[i].carbs) || 0
        return sum
    }
    readonly property int aiFat: {
        let sum = 0
        for (let i = 0; i < panel.aiPicked.length; i++) sum += Number(panel.aiPicked[i].fat) || 0
        return sum
    }
    readonly property int projectedLeft: panel.widget ? panel.widget.targetKcal - panel.widget.eaten - panel.aiPickedKcal : 0

    function selectTab(index: int): void {
        panel.tab = index
        if (panel.widget)
            panel.widget.panelTab = index
    }

    function loadDraft(): void {
        if (!panel.widget)
            return
        panel.draft = Object.assign({}, panel.widget.profile)
        panel.targetDraft = String(panel.widget.targetKcal)
    }

    function setDraft(key: string, value: var): void {
        const next = Object.assign({}, panel.draft)
        next[key] = value
        panel.draft = Cal.cleanProfile(next)
    }

    function submitFood(): void {
        if (!panel.widget)
            return
        const name = panel.foodName.trim()
        const kcal = Number(panel.foodKcal)
        if (name.length === 0 || !Number.isFinite(kcal) || kcal <= 0) {
            panel.status = "Name it and give it calories."
            return
        }
        if (panel.widget.addEntry(name, kcal)) {
            panel.status = "Logged " + name + " at " + Math.round(kcal) + " kcal."
            panel.foodName = ""
            panel.foodKcal = ""
        }
    }

    function quickAdd(item: var): void {
        if (!panel.widget)
            return
        if (panel.widget.addEntry(item.label, item.kcal))
            panel.status = "Logged " + item.label.toLowerCase() + ". " + item.kcal + " kcal."
    }

    function saveAiKey(): void {
        if (ai.saveKey(keyField.text)) {
            keyField.text = ""
            panel.aiStatus = "DeepSeek key saved in the keyring."
            Qt.callLater(() => aiPrompt.forceInputFocus())
        }
    }

    function askAi(): void {
        panel.aiStatus = ""
        if (!panel.widget)
            return
        ai.estimate(panel.aiPromptText)
    }

    function addAiItems(): void {
        if (!panel.widget || panel.aiPicked.length === 0)
            return
        const count = panel.aiPicked.length
        const total = panel.aiPickedKcal
        if (panel.widget.addEntries(panel.aiPicked)) {
            panel.status = "Added " + count + (count === 1 ? " ingredient" : " ingredients")
                + " at " + Cal.comma(total) + " kcal. Review the log."
            ai.clear()
            panel.aiAddOpen = false
            panel.aiPromptText = ""
            panel.selectTab(0)
        }
    }

    function addAiExtra(): void {
        if (!ai.addItem(aiExtraName.text, Number(aiExtraKcal.text))) {
            panel.aiStatus = "Name the extra ingredient and give it calories."
            return
        }
        panel.aiStatus = "Extra ingredient added."
        aiExtraName.text = ""
        aiExtraKcal.text = ""
        panel.aiAddOpen = false
    }

    function useSuggestion(): void {
        panel.draft = Cal.cleanProfile(panel.draft)
        panel.targetDraft = String(panel.suggested)
        panel.status = "Suggestion loaded. Save it when it looks right."
    }

    function applyGoal(): void {
        if (!panel.widget)
            return
        const target = Number(panel.targetDraft)
        if (!Number.isFinite(target) || target < 800) {
            panel.status = "Use a target above 800 kcal."
            return
        }
        panel.widget.saveProfile(panel.draft, target)
        panel.status = "Saved " + Cal.comma(target) + " kcal for today."
        panel.savedFlash = true
        savedTimer.restart()
    }

    function addWater(): void {
        if (!panel.widget)
            return
        if (panel.widget.addWater())
            panel.status = "One glass logged. " + panel.widget.waterGlasses + " of " + panel.widget.waterGoal + "."
        else
            panel.status = "Water goal reached for today."
    }

    function removeWater(): void {
        if (!panel.widget)
            return
        panel.widget.removeWater()
        panel.status = "One glass removed."
    }

    function resetWater(): void {
        if (!panel.widget)
            return
        panel.widget.resetWater()
        panel.status = "Water count reset."
    }

    function cycleWaterGoal(): void {
        if (!panel.widget)
            return
        const options = [6, 8, 10, 12]
        const at = options.indexOf(panel.widget.waterGoal)
        panel.widget.setWaterGoal(options[(at + 1) % options.length])
        panel.status = "Water goal: " + panel.widget.waterGoal + " glasses."
    }

    function toggleWaterReminder(): void {
        if (!panel.widget)
            return
        panel.widget.setWaterReminder(!panel.widget.waterReminder)
        panel.status = panel.widget.waterReminder ? "Water reminders on." : "Water reminders off."
    }

    function setWaterInterval(minutes: int): void {
        if (!panel.widget)
            return
        panel.widget.setWaterInterval(minutes)
        panel.status = "Water reminder every " + panel.widget.waterIntervalMin + " min."
    }

    function testWater(): void {
        if (!panel.widget)
            return
        panel.widget.sendWaterNotification(true)
        panel.status = "Water notification sent."
    }

    function requestReset(): void {
        if (!panel.confirmReset) {
            panel.confirmReset = true
            panel.status = "Tap reset again to clear today."
            resetTimer.restart()
            return
        }
        if (panel.widget)
            panel.widget.resetDay()
        panel.confirmReset = false
        panel.status = "Today's log is empty again."
    }

    Timer {
        id: savedTimer
        interval: 1600
        onTriggered: panel.savedFlash = false
    }
    Timer {
        id: resetTimer
        interval: 2600
        onTriggered: {
            panel.confirmReset = false
            if (panel.status === "Tap reset again to clear today.")
                panel.status = ""
        }
    }
    function focusFirst(): void {
        if (panel.contentItem)
            panel.contentItem.forceActiveFocus()
        if (panel.tab === 0 && foodField)
            foodField.forceInputFocus()
        else if (panel.tab === 1 && (!ai.hasKey || panel.aiKeyEdit) && !ai.privacyBlocked && keyField)
            keyField.forceInputFocus()
        else if (panel.tab === 1 && aiPrompt)
            aiPrompt.forceInputFocus()
        else if (panel.tab === 2 && targetField)
            targetField.forceInputFocus()
        else if (panel.tab === 3 && waterAddButton)
            waterAddButton.forceActiveFocus()
    }
    Timer {
        id: focusTimer
        interval: 220
        onTriggered: panel.focusFirst()
    }
    Timer {
        id: lateFocus
        interval: 700
        onTriggered: panel.focusFirst()
    }

    Component.onCompleted: {
        panel.tab = panel.initialTab
        panel.loadDraft()
        ai.refreshKey()
        focusTimer.start()
        lateFocus.start()
    }
    onWidgetChanged: panel.loadDraft()
    Connections {
        target: panel.widget
        function onPanelTabChanged(): void { panel.tab = panel.widget.panelTab }
    }
    Shortcut { sequence: "Escape"; onActivated: panel.dismissed() }

    Rectangle {
        anchors.fill: parent
        color: Pal.scrim
        opacity: 0.62
        MouseArea {
            anchors.fill: parent
            onClicked: panel.dismissed()
        }
    }

    PixelBox {
        id: sheet
        anchors.centerIn: parent
        width: Math.min(Math.round(680 * panel.d), (panel.screen ? panel.screen.width : 1280) - Math.round(40 * panel.d))
        height: Math.min(Math.round(660 * panel.d), (panel.screen ? panel.screen.height : 800) - Math.round(40 * panel.d))
        fill: Pal.paper
        line: Pal.ink
        lineWidth: Math.round(2 * panel.d)
        shadowOffset: Math.round(9 * panel.d)
        cut: Math.round(10 * panel.d)
        headerHeight: Math.round(64 * panel.d)
        headerFill: Pal.peach

        opacity: 0
        scale: 0.96
        NumberAnimation on opacity { from: 0; to: 1; duration: 150; easing.type: Easing.OutQuad }
        NumberAnimation on scale { from: 0.96; to: 1; duration: 230; easing.type: Easing.OutBack }

        MouseArea { anchors.fill: parent }

        // Header
        Text {
            x: Math.round(20 * panel.d)
            y: Math.round(18 * panel.d)
            text: "CAL-O-MATIC"
            color: Pal.ink
            font.family: "Silkscreen"
            font.pixelSize: Math.round(18 * panel.d)
            font.letterSpacing: Math.round(1.4 * panel.d)
            renderType: Text.NativeRendering
        }

        PixelButton {
            d: panel.d
            width: Math.round(38 * panel.d)
            height: Math.round(38 * panel.d)
            anchors.right: parent.right
            anchors.rightMargin: Math.round(18 * panel.d)
            anchors.top: parent.top
            anchors.topMargin: Math.round(13 * panel.d)
            label: "×"
            accessibleName: "Close console"
            compact: true
            fillColor: Pal.rose
            onClicked: panel.dismissed()
        }

        // Body
        Item {
            anchors.fill: parent
            anchors.topMargin: Math.round(78 * panel.d)
            anchors.leftMargin: Math.round(22 * panel.d)
            anchors.rightMargin: Math.round(22 * panel.d)
            anchors.bottomMargin: Math.round(20 * panel.d)

            ColumnLayout {
                anchors.fill: parent
                spacing: Math.round(9 * panel.d)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(7 * panel.d)

                    PixelButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(40 * panel.d)
                        d: panel.d
                        compact: true
                        label: "LOG FOOD"
                        labelSize: 13
                        selected: panel.tab === 0
                        fillColor: Pal.paper2
                        onClicked: panel.selectTab(0)
                    }
                    PixelButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(40 * panel.d)
                        d: panel.d
                        compact: true
                        label: "AI ESTIMATE"
                        labelSize: 13
                        selected: panel.tab === 1
                        fillColor: Pal.paper2
                        onClicked: {
                            panel.aiStatus = ""
                            panel.selectTab(1)
                            ai.refreshKey()
                        }
                    }
                    PixelButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(40 * panel.d)
                        d: panel.d
                        compact: true
                        label: "DAILY BUDGET"
                        labelSize: 13
                        selected: panel.tab === 2
                        fillColor: Pal.paper2
                        onClicked: {
                            panel.loadDraft()
                            panel.selectTab(2)
                        }
                    }
                    PixelButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(40 * panel.d)
                        d: panel.d
                        compact: true
                        label: "WATER"
                        labelSize: 13
                        selected: panel.tab === 3
                        fillColor: Pal.paper2
                        onClicked: panel.selectTab(3)
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: panel.tab
                    clip: true

                    // ── LOG ─────────────────────────────────────
                    Item {
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Math.round(8 * panel.d)

                            PixelBox {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.round(112 * panel.d)
                                fill: Pal.paper2
                                line: Pal.ink
                                lineWidth: Math.round(2 * panel.d)
                                shadowOffset: 0
                                cut: Math.round(4 * panel.d)

                                Item {
                                    anchors.fill: parent
                                    anchors.margins: Math.round(10 * panel.d)

                                    Text {
                                        text: panel.widget && panel.widget.over ? "OVER BY" : "LEFT TODAY"
                                        color: Pal.inkSoft
                                        font.family: "Silkscreen"
                                        font.pixelSize: Math.round(14 * panel.d)
                                        font.letterSpacing: Math.round(1 * panel.d)
                                        renderType: Text.NativeRendering
                                    }
                                    Text {
                                        y: Math.round(16 * panel.d)
                                        text: panel.widget ? panel.widget.remainingText : "0"
                                        color: panel.widget && panel.widget.over ? Pal.tomatoInk : Pal.ink
                                        font.family: "Silkscreen"
                                        font.pixelSize: Math.round(44 * panel.d)
                                        font.weight: Font.Bold
                                        renderType: Text.NativeRendering
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        text: panel.widget ? "of " + panel.widget.targetText + " kcal" : ""
                                        color: Pal.inkSoft
                                        font.family: "Pixelify Sans"
                                        font.pixelSize: Math.round(14 * panel.d)
                                        renderType: Text.NativeRendering
                                    }
                                    Row {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: Math.round(12 * panel.d)
                                        spacing: Math.round(3 * panel.d)
                                        Repeater {
                                            model: 12
                                            Item {
                                                required property int index
                                                width: Math.max(2, Math.floor((parent.width - Math.round(33 * panel.d)) / 12))
                                                height: Math.round(12 * panel.d)
                                                readonly property bool lit: panel.widget ? index < panel.widget.filledSegments : false
                                                readonly property bool partial: panel.widget ? index === panel.widget.filledSegments && panel.widget.partialSegment > 0.01 : false
                                                readonly property color tint: panel.widget && panel.widget.over
                                                    ? (index % 2 === 0 ? Pal.tomato : Pal.rose)
                                                    : Pal.cycle[index % Pal.cycle.length]
                                                Rectangle {
                                                    anchors.fill: parent
                                                    color: parent.lit ? parent.tint : Pal.paper
                                                    border.width: Math.max(1, Math.round(panel.d))
                                                    border.color: Pal.ink
                                                    opacity: parent.lit ? 1 : 0.4
                                                }
                                                Rectangle {
                                                    visible: parent.partial
                                                    width: Math.round(parent.width * Math.round((panel.widget ? panel.widget.partialSegment : 0) * 4) / 4)
                                                    height: parent.height
                                                    color: parent.tint
                                                    border.width: Math.max(1, Math.round(panel.d))
                                                    border.color: Pal.ink
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Math.round(6 * panel.d)
                                Text {
                                    Layout.fillWidth: true
                                    text: "QUICK ADD"
                                    color: Pal.inkSoft
                                    font.family: "Silkscreen"
                                    font.pixelSize: Math.round(14 * panel.d)
                                    font.letterSpacing: Math.round(1 * panel.d)
                                    renderType: Text.NativeRendering
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Math.round(4 * panel.d)
                                Repeater {
                                    model: [
                                        { label: "COFFEE", kcal: 5, fill: Pal.lemon },
                                        { label: "BANANA", kcal: 105, fill: Pal.lemon },
                                        { label: "EGGS", kcal: 140, fill: Pal.mint },
                                        { label: "TOAST", kcal: 80, fill: Pal.peach },
                                        { label: "BOWL", kcal: 520, fill: Pal.lilac }
                                    ]
                                    PixelButton {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Math.round(36 * panel.d)
                                        d: panel.d
                                        compact: true
                                        label: modelData.label + " " + modelData.kcal
                                        labelSize: 13
                                        fillColor: modelData.fill
                                        onClicked: panel.quickAdd(modelData)
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Math.round(5 * panel.d)
                                PixelField {
                                    id: foodField
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.round(42 * panel.d)
                                    d: panel.d
                                    placeholder: "What did you eat?"
                                    text: panel.foodName
                                    nextTab: foodKcalField
                                    onTextChanged: panel.foodName = text
                                    onAccepted: panel.submitFood()
                                }
                                PixelField {
                                    id: foodKcalField
                                    Layout.preferredWidth: Math.round(94 * panel.d)
                                    Layout.preferredHeight: Math.round(42 * panel.d)
                                    d: panel.d
                                    digitsOnly: true
                                    placeholder: "kcal"
                                    text: panel.foodKcal
                                    previousTab: foodField
                                    nextTab: addButton
                                    onTextChanged: panel.foodKcal = text
                                    onAccepted: panel.submitFood()
                                }
                                PixelButton {
                                    id: addButton
                                    Layout.preferredWidth: Math.round(72 * panel.d)
                                    Layout.preferredHeight: Math.round(42 * panel.d)
                                    d: panel.d
                                    label: "ADD"
                                    compact: true
                                    fillColor: Pal.mint
                                    enabled: panel.foodName.trim().length > 0 && Number(panel.foodKcal) > 0
                                    onClicked: panel.submitFood()
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                ListView {
                                    id: entryList
                                    anchors.fill: parent
                                    clip: true
                                    spacing: Math.round(3 * panel.d)
                                    boundsBehavior: Flickable.StopAtBounds
                                    model: panel.widget ? panel.widget.entries : []
                                    onCountChanged: Qt.callLater(positionViewAtEnd)

                                    delegate: Item {
                                        id: row
                                        required property var modelData
                                        width: entryList.width
                                        height: Math.round(48 * panel.d)

                                        PixelBox {
                                            anchors.fill: parent
                                            fill: index % 2 === 0 ? Pal.paper2 : Pal.paper
                                            line: Pal.ink
                                            lineWidth: Math.max(1, Math.round(panel.d))
                                            shadowOffset: 0
                                            cut: Math.round(2 * panel.d)
                                        }
                                        Column {
                                            x: Math.round(9 * panel.d)
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - Math.round(112 * panel.d)
                                            spacing: Math.round(1 * panel.d)
                                            Text {
                                                width: parent.width
                                                text: row.modelData.name
                                                color: Pal.ink
                                                font.family: "Pixelify Sans"
                                                font.pixelSize: Math.round(14 * panel.d)
                                                font.weight: Font.Medium
                                                renderType: Text.NativeRendering
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                text: Cal.timeLabel(row.modelData.at)
                                                color: Pal.inkSoft
                                                font.family: "Silkscreen"
                                                font.pixelSize: Math.round(14 * panel.d)
                                                renderType: Text.NativeRendering
                                            }
                                        }
                                        Text {
                                            anchors.right: deleteButton.left
                                            anchors.rightMargin: Math.round(8 * panel.d)
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Cal.comma(row.modelData.kcal)
                                            color: Pal.ink
                                            font.family: "Silkscreen"
                                            font.pixelSize: Math.round(14 * panel.d)
                                            renderType: Text.NativeRendering
                                        }
                                        PixelButton {
                                            id: deleteButton
                                            width: Math.round(30 * panel.d)
                                            height: Math.round(30 * panel.d)
                                            anchors.right: parent.right
                                            anchors.rightMargin: Math.round(6 * panel.d)
                                            anchors.verticalCenter: parent.verticalCenter
                                            d: panel.d
                                            compact: true
                                            label: "×"
                                            labelSize: 13
                                            fillColor: Pal.rose
                                            onClicked: {
                                                panel.widget.removeEntry(row.modelData.id)
                                                panel.status = "Removed " + row.modelData.name + "."
                                            }
                                        }
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    visible: panel.widget && panel.widget.entries.length === 0
                                    spacing: Math.round(4 * panel.d)
                                    CarrotMascot {
                                        width: Math.round(54 * panel.d)
                                        height: Math.round(64 * panel.d)
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        mood: "empty"
                                    }
                                    Text {
                                        text: "Nothing logged yet."
                                        color: Pal.ink
                                        font.family: "Silkscreen"
                                        font.pixelSize: Math.round(14 * panel.d)
                                        renderType: Text.NativeRendering
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    Text {
                                        text: "Add a bite below. The carrot is patient."
                                        color: Pal.inkSoft
                                        font.family: "Pixelify Sans"
                                        font.pixelSize: Math.round(14 * panel.d)
                                        renderType: Text.NativeRendering
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.round(54 * panel.d)

                                Rectangle {
                                    width: Math.round(4 * panel.d)
                                    height: parent.height
                                    color: Pal.lilac
                                }
                                Column {
                                    x: Math.round(12 * panel.d)
                                    width: parent.width - Math.round(12 * panel.d)
                                    spacing: Math.round(3 * panel.d)
                                    Text {
                                        text: "DAY NOTE"
                                        color: Pal.inkSoft
                                        font.family: "Silkscreen"
                                        font.pixelSize: Math.round(14 * panel.d)
                                        font.letterSpacing: Math.round(1 * panel.d)
                                        renderType: Text.NativeRendering
                                    }
                                    Text {
                                        width: parent.width
                                        text: panel.widget ? panel.widget.dayNote : ""
                                        color: Pal.ink
                                        font.family: "Pixelify Sans"
                                        font.pixelSize: Math.round(14 * panel.d)
                                        renderType: Text.NativeRendering
                                        wrapMode: Text.WordWrap
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Math.round(6 * panel.d)
                                Text {
                                    Layout.fillWidth: true
                                    text: panel.status
                                    color: Pal.inkSoft
                                    font.family: "Pixelify Sans"
                                    font.pixelSize: Math.round(14 * panel.d)
                                    renderType: Text.NativeRendering
                                    elide: Text.ElideRight
                                }
                                PixelButton {
                                    Layout.preferredWidth: Math.round(98 * panel.d)
                                    Layout.preferredHeight: Math.round(32 * panel.d)
                                    d: panel.d
                                    compact: true
                                    label: panel.confirmReset ? "SURE?" : "RESET DAY"
                                    labelSize: 13
                                    fillColor: panel.confirmReset ? Pal.rose : Pal.paper2
                                    onClicked: panel.requestReset()
                                }
                            }
                        }
                    }

                    // ── AI ESTIMATE ──────────────────────────────
                    Item {
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Math.round(8 * panel.d)

                            Text {
                                Layout.fillWidth: true
                                text: "Describe a meal. DeepSeek estimates the portion, calories and macros; Ctrl+Enter asks."
                                color: Pal.inkSoft
                                font.family: "Pixelify Sans"
                                font.pixelSize: Math.round(14 * panel.d)
                                renderType: Text.NativeRendering
                                wrapMode: Text.WordWrap
                            }

                            PixelBox {
                                visible: ai.privacyBlocked
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.round(72 * panel.d)
                                fill: Pal.rose
                                line: Pal.ink
                                lineWidth: Math.round(2 * panel.d)
                                shadowOffset: 0
                                cut: Math.round(4 * panel.d)

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: Math.round(9 * panel.d)
                                    spacing: Math.round(3 * panel.d)
                                    Text {
                                        text: "ONLINE AI IS OFF"
                                        color: Pal.ink
                                        font.family: "Silkscreen"
                                        font.pixelSize: Math.round(14 * panel.d)
                                        renderType: Text.NativeRendering
                                    }
                                    Text {
                                        width: parent.width
                                        text: "Settings → AI privacy is set to local only. The rest of the widget still works."
                                        color: Pal.ink
                                        font.family: "Pixelify Sans"
                                        font.pixelSize: Math.round(14 * panel.d)
                                        renderType: Text.NativeRendering
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            PixelBox {
                                visible: (!ai.hasKey || panel.aiKeyEdit) && !ai.privacyBlocked
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.round(190 * panel.d)
                                fill: Pal.paper2
                                line: Pal.ink
                                lineWidth: Math.round(2 * panel.d)
                                shadowOffset: 0
                                cut: Math.round(4 * panel.d)

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Math.round(10 * panel.d)
                                    spacing: Math.round(6 * panel.d)

                                    Text {
                                        text: "DEEPSEEK KEY"
                                        color: Pal.ink
                                        font.family: "Silkscreen"
                                        font.pixelSize: Math.round(14 * panel.d)
                                        font.letterSpacing: Math.round(1 * panel.d)
                                        renderType: Text.NativeRendering
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: ai.keyLoading ? "Reading the system keyring…"
                                            : "Kept in the system keyring, never in widget settings. Or set DEEPSEEK_API_KEY in the shell environment."
                                        color: Pal.inkSoft
                                        font.family: "Pixelify Sans"
                                        font.pixelSize: Math.round(14 * panel.d)
                                        renderType: Text.NativeRendering
                                        wrapMode: Text.WordWrap
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Math.round(5 * panel.d)
                                        PixelField {
                                            id: keyField
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Math.round(42 * panel.d)
                                            d: panel.d
                                            password: true
                                            placeholder: "sk-…"
                                            nextTab: saveKeyButton
                                            onAccepted: panel.saveAiKey()
                                        }
                                        PixelButton {
                                            id: saveKeyButton
                                            Layout.preferredWidth: Math.round(80 * panel.d)
                                            Layout.preferredHeight: Math.round(42 * panel.d)
                                            d: panel.d
                                            compact: true
                                            label: "SAVE"
                                            labelSize: 13
                                            fillColor: Pal.mint
                                            enabled: keyField.text.trim().length > 0
                                            onClicked: panel.saveAiKey()
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            Layout.fillWidth: true
                                            text: ai.error.length > 0 ? ai.error
                                                : panel.aiStatus.length > 0 ? panel.aiStatus
                                                : "One request per press."
                                            color: Pal.inkSoft
                                            font.family: "Pixelify Sans"
                                            font.pixelSize: Math.round(14 * panel.d)
                                            renderType: Text.NativeRendering
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: "GET A KEY ↗"
                                            color: Pal.ink
                                            font.family: "Silkscreen"
                                            font.pixelSize: Math.round(14 * panel.d)
                                            renderType: Text.NativeRendering
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Qt.openUrlExternally("https://platform.deepseek.com/api_keys")
                                            }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                visible: ai.hasKey && !panel.aiKeyEdit && !ai.privacyBlocked
                                Layout.fillWidth: true
                                spacing: Math.round(6 * panel.d)

                                PixelTextArea {
                                    id: aiPrompt
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.round(108 * panel.d)
                                    d: panel.d
                                    placeholder: "e.g. chicken shawarma wrap, large, extra garlic sauce"
                                    text: panel.aiPromptText
                                    nextTab: askButton
                                    onTextChanged: panel.aiPromptText = text
                                    onSubmitted: panel.askAi()
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Math.round(6 * panel.d)
                                    PixelButton {
                                        id: askButton
                                        Layout.preferredWidth: Math.round(162 * panel.d)
                                        Layout.preferredHeight: Math.round(42 * panel.d)
                                        d: panel.d
                                        compact: true
                                        label: ai.busy ? "ASKING…" : "ASK DEEPSEEK"
                                        labelSize: 13
                                        fillColor: Pal.lemon
                                        enabled: !ai.busy && panel.aiPromptText.trim().length > 0
                                        onClicked: panel.askAi()
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: ai.busy ? "one request, 45 s limit"
                                            : panel.aiStatus.length > 0 ? panel.aiStatus
                                            : ai.keySource.length > 0 ? "KEY READY · " + ai.keySource : ""
                                        color: Pal.inkSoft
                                        font.family: "Pixelify Sans"
                                        font.pixelSize: Math.round(14 * panel.d)
                                        renderType: Text.NativeRendering
                                        elide: Text.ElideRight
                                    }
                                    PixelButton {
                                        Layout.preferredWidth: Math.round(56 * panel.d)
                                        Layout.preferredHeight: Math.round(42 * panel.d)
                                        d: panel.d
                                        compact: true
                                        label: "KEY"
                                        labelSize: 13
                                        fillColor: Pal.paper2
                                        onClicked: {
                                            ai.clear()
                                            panel.aiKeyEdit = true
                                            panel.aiStatus = ""
                                            Qt.callLater(() => keyField.forceInputFocus())
                                        }
                                    }
                                    PixelButton {
                                        Layout.preferredWidth: Math.round(74 * panel.d)
                                        Layout.preferredHeight: Math.round(42 * panel.d)
                                        d: panel.d
                                        compact: true
                                        label: "CLEAR"
                                        labelSize: 13
                                        fillColor: Pal.paper2
                                        enabled: !ai.busy && (panel.aiPromptText.length > 0 || ai.items.length > 0 || ai.error.length > 0)
                                        onClicked: {
                                            ai.clear()
                                            panel.aiPromptText = ""
                                            panel.aiStatus = ""
                                        }
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                PixelBox {
                                    visible: ai.busy && !panel.aiKeyEdit
                                    anchors.fill: parent
                                    fill: Pal.paper2
                                    line: Pal.ink
                                    lineWidth: Math.round(2 * panel.d)
                                    shadowOffset: 0
                                    cut: Math.round(4 * panel.d)

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: Math.round(4 * panel.d)
                                        Text {
                                            text: "ASKING DEEPSEEK…"
                                            color: Pal.ink
                                            font.family: "Silkscreen"
                                            font.pixelSize: Math.round(14 * panel.d)
                                            renderType: Text.NativeRendering
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: "One request. No retries."
                                            color: Pal.inkSoft
                                            font.family: "Pixelify Sans"
                                            font.pixelSize: Math.round(14 * panel.d)
                                            renderType: Text.NativeRendering
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }

                                PixelBox {
                                    visible: !ai.busy && ai.error.length > 0 && ai.hasKey && !panel.aiKeyEdit
                                    anchors.fill: parent
                                    fill: Pal.rose
                                    line: Pal.ink
                                    lineWidth: Math.round(2 * panel.d)
                                    shadowOffset: 0
                                    cut: Math.round(4 * panel.d)

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: Math.round(10 * panel.d)
                                        spacing: Math.round(3 * panel.d)
                                        Text {
                                            text: "NO ESTIMATE"
                                            color: Pal.ink
                                            font.family: "Silkscreen"
                                            font.pixelSize: Math.round(14 * panel.d)
                                            renderType: Text.NativeRendering
                                        }
                                        Text {
                                            width: parent.width
                                            text: ai.error
                                            color: Pal.ink
                                            font.family: "Pixelify Sans"
                                            font.pixelSize: Math.round(14 * panel.d)
                                            renderType: Text.NativeRendering
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 4
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                PixelBox {
                                    visible: !ai.busy && ai.error.length === 0 && ai.items.length > 0 && !panel.aiKeyEdit
                                    anchors.fill: parent
                                    fill: Pal.mint
                                    line: Pal.ink
                                    lineWidth: Math.round(2 * panel.d)
                                    shadowOffset: 0
                                    cut: Math.round(4 * panel.d)
                                    dither: true

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: Math.round(9 * panel.d)
                                        spacing: Math.round(3 * panel.d)

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Math.round(28 * panel.d)
                                            Text {
                                                text: "AI ESTIMATE"
                                                color: Pal.ink
                                                font.family: "Silkscreen"
                                                font.pixelSize: Math.round(14 * panel.d)
                                                font.letterSpacing: Math.round(0.8 * panel.d)
                                                renderType: Text.NativeRendering
                                            }
                                            Text {
                                                text: panel.aiPicked.length + " / " + ai.items.length + " SELECTED"
                                                color: Pal.inkSoft
                                                font.family: "Silkscreen"
                                                font.pixelSize: Math.round(14 * panel.d)
                                                renderType: Text.NativeRendering
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: Cal.comma(panel.aiPickedKcal) + " KCAL"
                                                color: Pal.ink
                                                font.family: "Silkscreen"
                                                font.pixelSize: Math.round(20 * panel.d)
                                                font.weight: Font.Bold
                                                renderType: Text.NativeRendering
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: "Tick what was actually in the meal."
                                            color: Pal.inkSoft
                                            font.family: "Pixelify Sans"
                                            font.pixelSize: Math.round(14 * panel.d)
                                            renderType: Text.NativeRendering
                                        }

                                        Flickable {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            clip: true
                                            contentHeight: aiItemColumn.height
                                            boundsBehavior: Flickable.StopAtBounds

                                            Column {
                                                id: aiItemColumn
                                                width: parent.width
                                                spacing: Math.round(2 * panel.d)

                                                Repeater {
                                                    model: ai.items
                                                    RowLayout {
                                                        required property var modelData
                                                        required property int index
                                                        width: aiItemColumn.width
                                                        height: Math.round(24 * panel.d)
                                                        spacing: Math.round(5 * panel.d)
                                                        opacity: modelData.selected ? 1 : 0.52

                                                        PixelCheck {
                                                            Layout.preferredWidth: Math.round(20 * panel.d)
                                                            Layout.preferredHeight: Math.round(20 * panel.d)
                                                            d: panel.d
                                                            accessibleName: modelData.name
                                                            checked: modelData.selected
                                                            onToggled: ai.setSelected(index, !modelData.selected)
                                                        }
                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: modelData.name
                                                            color: modelData.selected ? Pal.ink : Pal.inkSoft
                                                            font.family: "Pixelify Sans"
                                                            font.pixelSize: Math.round(14 * panel.d)
                                                            renderType: Text.NativeRendering
                                                            elide: Text.ElideRight
                                                        }
                                                        Text {
                                                            text: modelData.protein + "P  " + modelData.carbs + "C  " + modelData.fat + "F"
                                                            visible: (modelData.protein + modelData.carbs + modelData.fat) > 0
                                                            color: Pal.inkSoft
                                                            font.family: "Silkscreen"
                                                            font.pixelSize: Math.round(14 * panel.d)
                                                            renderType: Text.NativeRendering
                                                        }
                                                        Text {
                                                            text: Cal.comma(modelData.kcal)
                                                            color: Pal.ink
                                                            font.family: "Silkscreen"
                                                            font.pixelSize: Math.round(14 * panel.d)
                                                            renderType: Text.NativeRendering
                                                        }
                                                    }
                                                }

                                                RowLayout {
                                                    width: aiItemColumn.width
                                                    height: Math.round(34 * panel.d)
                                                    spacing: Math.round(4 * panel.d)
                                                    visible: !panel.aiAddOpen
                                                    PixelButton {
                                                        Layout.preferredWidth: Math.round(190 * panel.d)
                                                        Layout.preferredHeight: Math.round(32 * panel.d)
                                                        d: panel.d
                                                        compact: true
                                                        label: "+ ADD INGREDIENT"
                                                        labelSize: 13
                                                        fillColor: Pal.paper
                                                        onClicked: {
                                                            panel.aiAddOpen = true
                                                            Qt.callLater(() => aiExtraName.forceInputFocus())
                                                        }
                                                    }
                                                }

                                                RowLayout {
                                                    width: aiItemColumn.width
                                                    height: Math.round(38 * panel.d)
                                                    spacing: Math.round(4 * panel.d)
                                                    visible: panel.aiAddOpen
                                                    PixelField {
                                                        id: aiExtraName
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: Math.round(38 * panel.d)
                                                        d: panel.d
                                                        placeholder: "extra ingredient"
                                                        nextTab: aiExtraKcal
                                                        onAccepted: aiExtraKcal.forceInputFocus()
                                                    }
                                                    PixelField {
                                                        id: aiExtraKcal
                                                        Layout.preferredWidth: Math.round(72 * panel.d)
                                                        Layout.preferredHeight: Math.round(38 * panel.d)
                                                        d: panel.d
                                                        digitsOnly: true
                                                        placeholder: "kcal"
                                                        nextTab: aiExtraAdd
                                                        onAccepted: panel.addAiExtra()
                                                    }
                                                    PixelButton {
                                                        id: aiExtraAdd
                                                        Layout.preferredWidth: Math.round(36 * panel.d)
                                                        Layout.preferredHeight: Math.round(38 * panel.d)
                                                        d: panel.d
                                                        compact: true
                                                        label: "+"
                                                        labelSize: 13
                                                        fillColor: Pal.lemon
                                                        onClicked: panel.addAiExtra()
                                                    }
                                                    PixelButton {
                                                        Layout.preferredWidth: Math.round(32 * panel.d)
                                                        Layout.preferredHeight: Math.round(38 * panel.d)
                                                        d: panel.d
                                                        compact: true
                                                        label: "×"
                                                        labelSize: 13
                                                        fillColor: Pal.rose
                                                        onClicked: {
                                                            panel.aiAddOpen = false
                                                            aiExtraName.text = ""
                                                            aiExtraKcal.text = ""
                                                        }
                                                    }
                                                }

                                                Text {
                                                    width: aiItemColumn.width
                                                    height: ai.note.length > 0 ? Math.round(20 * panel.d) : 0
                                                    text: ai.note
                                                    visible: ai.note.length > 0
                                                    color: Pal.inkSoft
                                                    font.family: "Pixelify Sans"
                                                    font.pixelSize: Math.round(14 * panel.d)
                                                    renderType: Text.NativeRendering
                                                    wrapMode: Text.WordWrap
                                                    maximumLineCount: 2
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Math.round(42 * panel.d)
                                            spacing: Math.round(4 * panel.d)
                                            visible: (panel.aiProtein + panel.aiCarbs + panel.aiFat) > 0
                                            Repeater {
                                                model: [
                                                    { label: "PROTEIN", value: panel.aiProtein, fill: Pal.rose },
                                                    { label: "CARBS", value: panel.aiCarbs, fill: Pal.lemon },
                                                    { label: "FAT", value: panel.aiFat, fill: Pal.peach }
                                                ]
                                                PixelBox {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: Math.round(38 * panel.d)
                                                    fill: modelData.fill
                                                    line: Pal.ink
                                                    lineWidth: Math.max(1, Math.round(panel.d))
                                                    shadowOffset: 0
                                                    cut: Math.round(2 * panel.d)
                                                    Column {
                                                        anchors.centerIn: parent
                                                        spacing: 0
                                                        Text {
                                                            text: modelData.label
                                                            color: Pal.inkSoft
                                                            font.family: "Silkscreen"
                                                            font.pixelSize: Math.round(14 * panel.d)
                                                            renderType: Text.NativeRendering
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                        }
                                                        Text {
                                                            text: modelData.value + "g"
                                                            color: Pal.ink
                                                            font.family: "Silkscreen"
                                                            font.pixelSize: Math.round(14 * panel.d)
                                                            renderType: Text.NativeRendering
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Math.max(1, Math.round(panel.d))
                                            color: Pal.ink
                                            opacity: 0.22
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Math.round(38 * panel.d)
                                            Text {
                                                text: "AFTER THIS MEAL"
                                                color: Pal.inkSoft
                                                font.family: "Silkscreen"
                                                font.pixelSize: Math.round(14 * panel.d)
                                                font.letterSpacing: Math.round(0.8 * panel.d)
                                                renderType: Text.NativeRendering
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: panel.projectedLeft >= 0
                                                    ? Cal.comma(panel.projectedLeft) + " LEFT"
                                                    : Cal.comma(-panel.projectedLeft) + " OVER"
                                                color: panel.projectedLeft >= 0 ? Pal.ink : Pal.tomatoInk
                                                font.family: "Silkscreen"
                                                font.pixelSize: Math.round(20 * panel.d)
                                                font.weight: Font.Bold
                                                renderType: Text.NativeRendering
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.topMargin: Math.round(2 * panel.d)
                                            spacing: Math.round(5 * panel.d)
                                            PixelButton {
                                                Layout.preferredWidth: Math.round(128 * panel.d)
                                                Layout.preferredHeight: Math.round(34 * panel.d)
                                                d: panel.d
                                                compact: true
                                                label: "ADD SELECTED"
                                                labelSize: 13
                                                fillColor: Pal.lemon
                                                enabled: panel.aiPicked.length > 0
                                                onClicked: panel.addAiItems()
                                            }
                                            PixelButton {
                                                Layout.preferredWidth: Math.round(90 * panel.d)
                                                Layout.preferredHeight: Math.round(34 * panel.d)
                                                d: panel.d
                                                compact: true
                                                label: "DISCARD"
                                                labelSize: 13
                                                fillColor: Pal.paper
                                                onClicked: {
                                                    ai.clear()
                                                    panel.aiAddOpen = false
                                                    panel.aiStatus = ""
                                                }
                                            }
                                            Item { Layout.fillWidth: true }
                                        }
                                    }
                                }
                                Column {
                                    visible: !ai.busy && ai.error.length === 0 && ai.items.length === 0
                                        && !ai.privacyBlocked
                                    anchors.centerIn: parent
                                    spacing: Math.round(6 * panel.d)

                                    CarrotMascot {
                                        width: Math.round(54 * panel.d)
                                        height: Math.round(64 * panel.d)
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        mood: "under"
                                    }
                                    Text {
                                        text: ai.hasKey ? "Ready when you are." : "Add a key to ask DeepSeek."
                                        color: Pal.ink
                                        font.family: "Silkscreen"
                                        font.pixelSize: Math.round(14 * panel.d)
                                        renderType: Text.NativeRendering
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    Text {
                                        text: "Review the estimate before it joins the log."
                                        color: Pal.inkSoft
                                        font.family: "Pixelify Sans"
                                        font.pixelSize: Math.round(14 * panel.d)
                                        renderType: Text.NativeRendering
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }
                        }
                    }
                    // ── GOAL ────────────────────────────────────
                    Item {
                        Flickable {
                            anchors.fill: parent
                            clip: true
                            contentHeight: goalColumn.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: goalColumn
                                width: parent.width
                                spacing: Math.round(7 * panel.d)

                                Text {
                                    Layout.fillWidth: true
                                    text: "A budget from your body, not a wish. Mifflin–St Jeor, then a small adjustment for the direction you picked."
                                    color: Pal.inkSoft
                                    font.family: "Pixelify Sans"
                                    font.pixelSize: Math.round(14 * panel.d)
                                    renderType: Text.NativeRendering
                                    wrapMode: Text.WordWrap
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Math.round(10 * panel.d)

                                    CalStepper {
                                        Layout.fillWidth: true
                                        d: panel.d
                                        label: "WEIGHT"
                                        suffix: "kg"
                                        value: panel.draft.weight
                                        from: 35
                                        to: 250
                                        onChanged: value => panel.setDraft("weight", value)
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(1, Math.round(panel.d))
                                        Layout.preferredHeight: Math.round(28 * panel.d)
                                        Layout.alignment: Qt.AlignVCenter
                                        color: Pal.ink
                                        opacity: 0.16
                                    }
                                    CalStepper {
                                        Layout.fillWidth: true
                                        d: panel.d
                                        label: "HEIGHT"
                                        suffix: "cm"
                                        value: panel.draft.height
                                        from: 120
                                        to: 230
                                        onChanged: value => panel.setDraft("height", value)
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(1, Math.round(panel.d))
                                        Layout.preferredHeight: Math.round(28 * panel.d)
                                        Layout.alignment: Qt.AlignVCenter
                                        color: Pal.ink
                                        opacity: 0.16
                                    }
                                    CalStepper {
                                        Layout.fillWidth: true
                                        d: panel.d
                                        label: "AGE"
                                        suffix: ""
                                        value: panel.draft.age
                                        from: 14
                                        to: 100
                                        onChanged: value => panel.setDraft("age", value)
                                    }
                                }

                                Text {
                                    text: "BODY"
                                    color: Pal.inkSoft
                                    font.family: "Silkscreen"
                                    font.pixelSize: Math.round(14 * panel.d)
                                    font.letterSpacing: Math.round(1 * panel.d)
                                    renderType: Text.NativeRendering
                                }
                                CalChips {
                                    Layout.fillWidth: true
                                    d: panel.d
                                    options: [
                                        { value: "female", label: "F", fill: Pal.rose },
                                        { value: "male", label: "M", fill: Pal.sky },
                                        { value: "neutral", label: "X", fill: Pal.lilac }
                                    ]
                                    value: panel.draft.sex
                                    onPicked: value => panel.setDraft("sex", value)
                                }

                                Text {
                                    text: "ACTIVITY"
                                    color: Pal.inkSoft
                                    font.family: "Silkscreen"
                                    font.pixelSize: Math.round(14 * panel.d)
                                    font.letterSpacing: Math.round(1 * panel.d)
                                    renderType: Text.NativeRendering
                                }
                                CalChips {
                                    Layout.fillWidth: true
                                    d: panel.d
                                    options: [
                                        { value: "1.2", label: "SIT", fill: Pal.paper2 },
                                        { value: "1.375", label: "LIGHT", fill: Pal.mint },
                                        { value: "1.55", label: "MOVE", fill: Pal.lemon },
                                        { value: "1.725", label: "HARD", fill: Pal.peach }
                                    ]
                                    value: String(panel.draft.activity)
                                    onPicked: value => panel.setDraft("activity", Number(value))
                                }

                                Text {
                                    text: "DIRECTION"
                                    color: Pal.inkSoft
                                    font.family: "Silkscreen"
                                    font.pixelSize: Math.round(14 * panel.d)
                                    font.letterSpacing: Math.round(1 * panel.d)
                                    renderType: Text.NativeRendering
                                }
                                CalChips {
                                    Layout.fillWidth: true
                                    d: panel.d
                                    options: [
                                        { value: "cut", label: "CUT", fill: Pal.rose },
                                        { value: "keep", label: "KEEP", fill: Pal.mint },
                                        { value: "build", label: "BUILD", fill: Pal.sky }
                                    ]
                                    value: panel.draft.goal
                                    onPicked: value => panel.setDraft("goal", value)
                                }

                                PixelBox {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.round(96 * panel.d)
                                    fill: Pal.mint
                                    line: Pal.ink
                                    lineWidth: Math.round(2 * panel.d)
                                    shadowOffset: 0
                                    cut: Math.round(4 * panel.d)

                                    Item {
                                        anchors.fill: parent
                                        anchors.margins: Math.round(9 * panel.d)
                                        RowLayout {
                                            anchors.fill: parent
                                            spacing: Math.round(14 * panel.d)
                                            Column {
                                                Layout.fillWidth: true
                                                Text { text: "BMR"; color: Pal.inkSoft; font.family: "Silkscreen"; font.pixelSize: Math.round(14 * panel.d); renderType: Text.NativeRendering }
                                                Text { text: Cal.comma(panel.basal); color: Pal.ink; font.family: "Silkscreen"; font.pixelSize: Math.round(22 * panel.d); font.weight: Font.Bold; renderType: Text.NativeRendering }
                                            }
                                            Column {
                                                Layout.fillWidth: true
                                                Text { text: "MAINTENANCE"; color: Pal.inkSoft; font.family: "Silkscreen"; font.pixelSize: Math.round(14 * panel.d); renderType: Text.NativeRendering }
                                                Text { text: Cal.comma(panel.maintenance); color: Pal.ink; font.family: "Silkscreen"; font.pixelSize: Math.round(22 * panel.d); font.weight: Font.Bold; renderType: Text.NativeRendering }
                                            }
                                            Column {
                                                Layout.fillWidth: true
                                                Text { text: "SUGGESTED"; color: Pal.inkSoft; font.family: "Silkscreen"; font.pixelSize: Math.round(14 * panel.d); renderType: Text.NativeRendering }
                                                Text { text: Cal.comma(panel.suggested); color: Pal.ink; font.family: "Silkscreen"; font.pixelSize: Math.round(22 * panel.d); font.weight: Font.Bold; renderType: Text.NativeRendering }
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Math.round(6 * panel.d)
                                    Text {
                                        text: "TARGET"
                                        color: Pal.inkSoft
                                        font.family: "Silkscreen"
                                        font.pixelSize: Math.round(14 * panel.d)
                                        renderType: Text.NativeRendering
                                    }
                                    PixelField {
                                        id: targetField
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Math.round(42 * panel.d)
                                        d: panel.d
                                        digitsOnly: true
                                        placeholder: "kcal"
                                        text: panel.targetDraft
                                        onTextChanged: panel.targetDraft = text
                                        onAccepted: panel.applyGoal()
                                    }
                                    PixelButton {
                                        Layout.preferredWidth: Math.round(132 * panel.d)
                                        Layout.preferredHeight: Math.round(42 * panel.d)
                                        d: panel.d
                                        compact: true
                                        label: "USE " + Cal.comma(panel.suggested)
                                        labelSize: 13
                                        fillColor: Pal.lemon
                                        onClicked: panel.useSuggestion()
                                    }
                                    PixelButton {
                                        Layout.preferredWidth: Math.round(74 * panel.d)
                                        Layout.preferredHeight: Math.round(42 * panel.d)
                                        d: panel.d
                                        compact: true
                                        label: panel.savedFlash ? "SAVED" : "SAVE"
                                        fillColor: panel.savedFlash ? Pal.mint : Pal.lilac
                                        onClicked: panel.applyGoal()
                                    }
                                }

                                Row {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.round(54 * panel.d)
                                    spacing: Math.round(12 * panel.d)

                                    Rectangle {
                                        width: Math.round(4 * panel.d)
                                        height: parent.height
                                        color: Pal.sky
                                    }
                                    Text {
                                        width: parent.width - Math.round(16 * panel.d)
                                        text: "An estimate, not a verdict. The trend across two or three weeks beats any single day."
                                        color: Pal.inkSoft
                                        font.family: "Pixelify Sans"
                                        font.pixelSize: Math.round(14 * panel.d)
                                        renderType: Text.NativeRendering
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                    // ── WATER ─────────────────────────────────────
                    Item {
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Math.round(8 * panel.d)

                            Text {
                                Layout.fillWidth: true
                                text: "One glass is 250 ml. Drink, tap, repeat."
                                color: Pal.inkSoft
                                font.family: "Pixelify Sans"
                                font.pixelSize: Math.round(14 * panel.d)
                                renderType: Text.NativeRendering
                                wrapMode: Text.WordWrap
                            }

                            PixelBox {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.round(185 * panel.d)
                                fill: Pal.paper2
                                line: Pal.ink
                                lineWidth: Math.round(2 * panel.d)
                                shadowOffset: 0
                                cut: Math.round(4 * panel.d)

                                Item {
                                    anchors.fill: parent
                                    anchors.margins: Math.round(14 * panel.d)

                                    RowLayout {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        Text {
                                            text: "WATER"
                                            color: Pal.ink
                                            font.family: "Silkscreen"
                                            font.pixelSize: Math.round(14 * panel.d)
                                            font.letterSpacing: Math.round(1 * panel.d)
                                            renderType: Text.NativeRendering
                                        }
                                        Item { Layout.fillWidth: true }
                                        PixelButton {
                                            Layout.preferredWidth: Math.round(120 * panel.d)
                                            Layout.preferredHeight: Math.round(30 * panel.d)
                                            d: panel.d
                                            compact: true
                                            label: (panel.widget ? panel.widget.waterGoal : 8) + " GLASSES"
                                            labelSize: 12
                                            fillColor: Pal.sky
                                            onClicked: panel.cycleWaterGoal()
                                        }
                                    }

                                    Row {
                                        anchors.left: parent.left
                                        anchors.bottom: glassesRow.top
                                        anchors.bottomMargin: Math.round(5 * panel.d)
                                        spacing: Math.round(8 * panel.d)
                                        Text {
                                            text: (panel.widget ? panel.widget.waterGlasses : 0)
                                            color: Pal.ink
                                            font.family: "Silkscreen"
                                            font.pixelSize: Math.round(44 * panel.d)
                                            font.weight: Font.Bold
                                            renderType: Text.NativeRendering
                                        }
                                        Column {
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: Math.round(6 * panel.d)
                                            spacing: 0
                                            Text {
                                                text: "OF " + (panel.widget ? panel.widget.waterGoal : 8)
                                                color: Pal.inkSoft
                                                font.family: "Silkscreen"
                                                font.pixelSize: Math.round(14 * panel.d)
                                                renderType: Text.NativeRendering
                                            }
                                            Text {
                                                text: "GLASSES"
                                                color: Pal.inkSoft
                                                font.family: "Silkscreen"
                                                font.pixelSize: Math.round(12 * panel.d)
                                                renderType: Text.NativeRendering
                                            }
                                        }
                                    }

                                    Row {
                                        id: glassesRow
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        height: Math.round(44 * panel.d)
                                        spacing: Math.round(4 * panel.d)
                                        Repeater {
                                            model: panel.widget ? panel.widget.waterGoal : 8
                                            PixelBox {
                                                required property int index
                                                width: Math.round(40 * panel.d)
                                                height: Math.round(44 * panel.d)
                                                fill: panel.widget && index < panel.widget.waterGlasses ? Pal.sky : Pal.paper
                                                line: Pal.ink
                                                lineWidth: Math.max(1, Math.round(panel.d))
                                                shadowOffset: 0
                                                cut: Math.round(2 * panel.d)
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Math.round(6 * panel.d)
                                PixelButton {
                                    id: waterAddButton
                                    Layout.preferredWidth: Math.round(176 * panel.d)
                                    Layout.preferredHeight: Math.round(42 * panel.d)
                                    d: panel.d
                                    compact: true
                                    label: "+ 250 ML"
                                    labelSize: 13
                                    fillColor: Pal.sky
                                    enabled: panel.widget && panel.widget.waterGlasses < panel.widget.waterGoal
                                    onClicked: panel.addWater()
                                }
                                PixelButton {
                                    Layout.preferredWidth: Math.round(50 * panel.d)
                                    Layout.preferredHeight: Math.round(42 * panel.d)
                                    d: panel.d
                                    compact: true
                                    label: "−"
                                    labelSize: 13
                                    fillColor: Pal.paper2
                                    enabled: panel.widget && panel.widget.waterGlasses > 0
                                    onClicked: panel.removeWater()
                                }
                                PixelButton {
                                    Layout.preferredWidth: Math.round(120 * panel.d)
                                    Layout.preferredHeight: Math.round(42 * panel.d)
                                    d: panel.d
                                    compact: true
                                    label: "RESET WATER"
                                    labelSize: 12
                                    fillColor: Pal.paper2
                                    enabled: panel.widget && panel.widget.waterGlasses > 0
                                    onClicked: panel.resetWater()
                                }
                                Item { Layout.fillWidth: true }
                            }

                            PixelBox {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.round(178 * panel.d)
                                fill: Pal.paper
                                line: Pal.ink
                                lineWidth: Math.round(2 * panel.d)
                                shadowOffset: 0
                                cut: Math.round(4 * panel.d)

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Math.round(12 * panel.d)
                                    spacing: Math.round(5 * panel.d)

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: "WATER REMINDER"
                                            color: Pal.ink
                                            font.family: "Silkscreen"
                                            font.pixelSize: Math.round(14 * panel.d)
                                            renderType: Text.NativeRendering
                                        }
                                        Item { Layout.fillWidth: true }
                                        PixelButton {
                                            Layout.preferredWidth: Math.round(68 * panel.d)
                                            Layout.preferredHeight: Math.round(30 * panel.d)
                                            d: panel.d
                                            compact: true
                                            label: panel.widget && panel.widget.waterReminder ? "ON" : "OFF"
                                            labelSize: 12
                                            selected: panel.widget && panel.widget.waterReminder
                                            fillColor: Pal.paper2
                                            onClicked: panel.toggleWaterReminder()
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: "Every " + (panel.widget ? panel.widget.waterIntervalMin : 60)
                                            + " min, 08:00–22:00. Stops at the goal."
                                        color: Pal.inkSoft
                                        font.family: "Pixelify Sans"
                                        font.pixelSize: Math.round(14 * panel.d)
                                        renderType: Text.NativeRendering
                                        wrapMode: Text.WordWrap
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Math.round(6 * panel.d)
                                        Text {
                                            text: "EVERY"
                                            color: Pal.inkSoft
                                            font.family: "Silkscreen"
                                            font.pixelSize: Math.round(13 * panel.d)
                                            renderType: Text.NativeRendering
                                        }
                                        CalChips {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Math.round(34 * panel.d)
                                            d: panel.d
                                            options: [
                                                { value: "30", label: "30", fill: Pal.paper2 },
                                                { value: "45", label: "45", fill: Pal.paper2 },
                                                { value: "60", label: "60", fill: Pal.paper2 },
                                                { value: "90", label: "90", fill: Pal.paper2 }
                                            ]
                                            value: panel.widget ? String(panel.widget.waterIntervalMin) : "60"
                                            onPicked: value => panel.setWaterInterval(Number(value))
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Math.round(6 * panel.d)
                                        PixelButton {
                                            Layout.preferredWidth: Math.round(70 * panel.d)
                                            Layout.preferredHeight: Math.round(32 * panel.d)
                                            d: panel.d
                                            compact: true
                                            label: "TEST"
                                            labelSize: 12
                                            fillColor: Pal.sky
                                            onClicked: panel.testWater()
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: panel.status.length > 0 ? panel.status
                                                : panel.widget && panel.widget.waterReminder
                                                    ? "Next nudge after " + panel.widget.waterIntervalMin + " min."
                                                    : "Reminders are off."
                                            color: Pal.inkSoft
                                            font.family: "Pixelify Sans"
                                            font.pixelSize: Math.round(13 * panel.d)
                                            renderType: Text.NativeRendering
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }

                }
            }
        }
    }
}
