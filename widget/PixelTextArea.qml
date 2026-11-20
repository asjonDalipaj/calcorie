import QtQuick
import "calpalette.js" as Pal

Item {
    id: root

    property alias text: edit.text
    property string placeholder: ""
    property var nextTab: null
    property real d: 1

    signal submitted()

    implicitWidth: Math.round(280 * d)
    implicitHeight: Math.round(92 * d)

    function forceInputFocus(): void {
        edit.forceActiveFocus()
    }

    PixelBox {
        anchors.fill: parent
        fill: Pal.paper
        line: edit.activeFocus ? Pal.ink : Pal.inkSoft
        lineWidth: Math.max(1, Math.round(2 * d))
        shadowOffset: Math.round(2 * d)
        cut: Math.round(3 * d)
    }

    TextEdit {
        id: edit
        anchors.fill: parent
        anchors.margins: Math.round(8 * d)
        color: Pal.ink
        selectionColor: Pal.lemon
        selectedTextColor: Pal.ink
        font.family: "Pixelify Sans"
        font.pixelSize: Math.round(16 * d)
        font.weight: Font.Medium
        wrapMode: TextEdit.Wrap
        selectByMouse: true
        clip: true
        textFormat: TextEdit.PlainText
        inputMethodHints: Qt.ImhNoPredictiveText

        Keys.onPressed: event => {
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    && (event.modifiers & Qt.ControlModifier)) {
                root.submitted()
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                if (root.nextTab) {
                    if (typeof root.nextTab.forceInputFocus === "function")
                        root.nextTab.forceInputFocus()
                    else
                        root.nextTab.forceActiveFocus()
                }
                event.accepted = true
            }
        }
    }

    Text {
        anchors.fill: edit
        anchors.margins: 0
        visible: edit.text.length === 0
        text: root.placeholder
        color: Pal.inkSoft
        font: edit.font
        wrapMode: Text.WordWrap
        opacity: 0.72
    }

    Rectangle {
        visible: edit.activeFocus
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
