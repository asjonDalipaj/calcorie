import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

// A compact bar chip for the calorie widget. Left click toggles the console,
// right click opens the AI tab. It reads the same config as the desktop card,
// so it never owns a second copy of the log.
MouseArea {
    id: root

    property int refreshTick: Config.revision
    readonly property string outputName: root.QsWindow.window?.screen?.name ?? ""

    readonly property var state: {
        root.refreshTick
        const base = Config.customWidgetData?.calcalories ?? ({})
        let custom = base
        const overrides = Config.options?.background?.widgets?.outputOverrides ?? []
        for (let i = 0; i < overrides.length; i++) {
            const record = overrides[i]
            if (record && record.output === root.outputName && record.widgets) {
                const own = record.widgets["custom.calcalories"]
                if (own)
                    custom = Object.assign({}, base, own)
            }
        }
        const target = Math.round(Number(custom.targetKcal ?? 2200)) || 2200
        let entries = []
        try {
            entries = JSON.parse(String(custom.entriesJson ?? "[]"))
        } catch (error) {
            entries = []
        }
        let eaten = 0
        for (let i = 0; i < entries.length; i++)
            eaten += Number(entries[i].kcal) || 0
        return { target: target, eaten: eaten, remaining: target - eaten }
    }

    readonly property bool over: root.state.remaining < 0
    readonly property string amount: {
        const value = Math.round(Math.abs(root.state.remaining))
        return String(value).replace(/\B(?=(\d{3})+(?!\d))/g, ",") + (root.over ? " over" : "")
    }
    readonly property color ink: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color accent: root.over
        ? (Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError)
        : (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)

    implicitWidth: pill.width + 8
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: root.over
        ? Translation.tr("Cal-O-Matic, %1 calories over").arg(root.amount)
        : Translation.tr("Cal-O-Matic, %1 calories left").arg(root.amount)

    function run(action: string): void {
        Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "calcalories", action])
    }

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            root.run("ai")
        else if (mouse.button === Qt.MiddleButton)
            root.run("water")
        else
            root.run("toggle")
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.run("toggle")
            event.accepted = true
        }
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: content.implicitWidth + 14
        height: content.implicitHeight + 8
        radius: height / 2
        color: root.containsMouse
            ? (Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover : Appearance.colors.colLayer1Hover)
            : "transparent"
        scale: root.pressed ? 0.96 : 1

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        Behavior on scale {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: 4

            CalCarrot {
                Layout.alignment: Qt.AlignVCenter
                opacity: root.over ? 0.95 : 1
            }
            StyledText {
                text: root.amount
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: root.over ? root.accent : root.ink
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    StyledToolTip {
        extraVisibleCondition: root.containsMouse
        text: root.over
            ? Translation.tr("Cal-O-Matic — %1 kcal over. Click for the log; right-click AI; middle-click water.").arg(root.amount)
            : Translation.tr("Cal-O-Matic — %1 kcal left. Click for the log; right-click AI; middle-click water.").arg(root.amount)
    }
}
