import QtQuick
import "calpalette.js" as Pal

Item {
    id: root

    property string mood: "empty" // empty, under, near, over
    property bool blink: false
    property real squash: 0

    implicitWidth: 80
    implicitHeight: 96

    transform: [
        Scale {
            origin.x: root.width / 2
            origin.y: root.height
            xScale: 1 + root.squash * 0.16
            yScale: 1 - root.squash * 0.18
        }
    ]

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: false
        renderStrategy: Canvas.Immediate

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.antialiasing = false

            const rows = [
                "....................",
                "........g...g.......",
                ".......gg..gg.......",
                ".......ggggggg......",
                "......gggllggg......",
                ".......ggllg........",
                ".......ohccso.......",
                "......ohccccso......",
                ".....ohccccccso.....",
                "....ohccccccccso....",
                "....ohccccccccso....",
                "....ohweccccweso....",
                "....oheecccceeso....",
                "....ohccccccccso....",
                "....opccccccccpo....",
                ".....ohcmmmmcso.....",
                ".....ohccttccso.....",
                "......ohccccso......",
                "......ohccccso......",
                ".......ohccso.......",
                ".......ohcso........",
                "........occo........",
                ".........oo.........",
                "...................."
            ]
            const colors = {
                o: Pal.ink,
                c: Pal.peach,
                h: "#FFD0B0",
                s: "#EF8A66",
                g: Pal.mint,
                l: "#7CCFAF",
                e: Pal.ink,
                w: Pal.paper,
                p: Pal.rose,
                m: "#7A3F55",
                t: Pal.tomato
            }
            const cell = Math.max(2, Math.floor(Math.min(root.width / 20, root.height / 24)))
            const ox = Math.round((root.width - cell * 20) / 2)
            const oy = Math.round((root.height - cell * 24) / 2)

            // A stepped contact shadow keeps the carrot sitting on the little stage.
            ctx.globalAlpha = 0.10
            ctx.fillStyle = Pal.ink
            ctx.fillRect(ox + cell * 6, oy + cell * 21, cell * 8, cell)
            ctx.fillRect(ox + cell * 7, oy + cell * 22, cell * 6, cell)
            ctx.globalAlpha = 1

            function put(x, y, colour) {
                ctx.fillStyle = colour
                ctx.fillRect(ox + x * cell, oy + y * cell, cell, cell)
            }

            for (let y = 0; y < rows.length; y++) {
                const row = rows[y]
                for (let x = 0; x < row.length; x++) {
                    const ch = row[x]
                    if (ch !== ".")
                        put(x, y, colors[ch] ?? Pal.ink)
                }
            }

            // The face gets a second pass so a mood never needs a second sprite.
            if (root.mood === "over") {
                for (let x = 5; x <= 8; x++) put(x, 10, Pal.ink)
                for (let x = 11; x <= 14; x++) put(x, 10, Pal.ink)
                for (let x = 7; x <= 12; x++) put(x, 15, "#7A3F55")
                for (let x = 8; x <= 11; x++) put(x, 16, Pal.peach)
            }
            if (root.blink) {
                for (let x = 6; x <= 7; x++) {
                    put(x, 11, Pal.peach)
                    put(x, 12, Pal.peach)
                }
                for (let x = 12; x <= 13; x++) {
                    put(x, 11, Pal.peach)
                    put(x, 12, Pal.peach)
                }
                for (let x = 6; x <= 7; x++) put(x, 12, Pal.ink)
                for (let x = 12; x <= 13; x++) put(x, 12, Pal.ink)
            }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    onMoodChanged: canvas.requestPaint()
    onBlinkChanged: canvas.requestPaint()
}
