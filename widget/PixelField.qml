import QtQuick
import "calpalette.js" as Pal

Item {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property bool digitsOnly: false
    property bool password: false
    property real d: 1
    property int maximumLength: 42
    property var nextTab: null
    property var previousTab: null

    signal accepted()

    Accessible.role: Accessible.EditableText
    Accessible.name: root.placeholder

    function forceInputFocus(): void {
        input.forceActiveFocus()
    }

    implicitWidth: Math.round(160 * d)
    implicitHeight: Math.round(40 * d)

    PixelBox {
        anchors.fill: parent
        fill: Pal.paper
        line: input.activeFocus ? Pal.ink : Pal.inkSoft
        lineWidth: Math.max(1, Math.round(2 * d))
        shadowOffset: Math.round(2 * d)
        cut: Math.round(3 * d)
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: Math.round(8 * d)
        anchors.rightMargin: Math.round(8 * d)
        anchors.topMargin: Math.round(5 * d)
        anchors.bottomMargin: Math.round(5 * d)
        color: Pal.ink
        selectionColor: Pal.lemon
        selectedTextColor: Pal.ink
        font.family: "Pixelify Sans"
        font.pixelSize: Math.round(16 * root.d)
        font.weight: Font.Medium
        renderType: Text.NativeRendering
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        maximumLength: root.maximumLength
        inputMethodHints: root.digitsOnly ? Qt.ImhDigitsOnly : Qt.ImhNone
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        validator: root.digitsOnly ? intValidator : null
        onAccepted: root.accepted()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                const target = (event.modifiers & Qt.ShiftModifier) ? root.previousTab : root.nextTab
                if (target) {
                    if (typeof target.forceInputFocus === "function")
                        target.forceInputFocus()
                    else
                        target.forceActiveFocus()
                }
                event.accepted = true
            }
        }
    }

    IntValidator {
        id: intValidator
        bottom: 0
        top: 9999
    }

    Text {
        anchors.fill: input
        visible: input.text.length === 0
        text: root.placeholder
        color: Pal.inkSoft
        font: input.font
        renderType: Text.NativeRendering
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        opacity: 0.72
    }

    Rectangle {
        visible: input.activeFocus
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Math.round(5 * d)
        anchors.rightMargin: Math.round(5 * d)
        anchors.bottomMargin: Math.round(2 * d)
        height: Math.max(1, Math.round(2 * d))
        color: Pal.lemon
    }
}
