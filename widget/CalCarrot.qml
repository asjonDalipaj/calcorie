import QtQuick

// A 9×10 carrot for the bar chip. Deliberately simpler than CarrotMascot:
// at this size the leaves and the two eye pixels are the whole read.
Item {
    id: root

    implicitWidth: 18
    implicitHeight: 20

    Canvas {
        anchors.fill: parent
        antialiasing: false

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.antialiasing = false

            const rows = [
                "..g...g..",
                ".ggg.ggg.",
                "..ggggg..",
                "...ggg...",
                "...oco...",
                "..occco..",
                "..ocwco..",
                "...oco...",
                "...oco...",
                "....o...."
            ]
            const colors = {
                o: "#372A45",
                c: "#FFB38A",
                g: "#A8E6CF",
                w: "#FFF3DC"
            }
            const cell = 2
            const ox = Math.round((root.width - cell * 9) / 2)
            const oy = Math.round((root.height - cell * 10) / 2)

            for (let y = 0; y < rows.length; y++) {
                const row = rows[y]
                for (let x = 0; x < row.length; x++) {
                    const ch = row[x]
                    if (ch === ".")
                        continue
                    ctx.fillStyle = colors[ch] ?? "#372A45"
                    ctx.fillRect(ox + x * cell, oy + y * cell, cell, cell)
                }
            }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
}
