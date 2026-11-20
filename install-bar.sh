#!/usr/bin/env bash
# Put the Calcorie chip into the installed Material (ii) bar.
# This patches the installed ii plugin, because the bar's module registry is
# built into BarContent.qml. Re-run after an iNiR update; backups are kept as
# *.bak-calcalories next to each patched file.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="${INIR_II_PLUGIN:-$HOME/.local/share/inir/plugins/ii}"
BAR="$PLUGIN/bar"
RESTART=1
[ "${1:-}" = "--no-restart" ] && RESTART=0

if [ ! -f "$BAR/BarContent.qml" ] || [ ! -f "$PLUGIN/MaterialConfigSchema.qml" ]; then
    echo "iNiR Material plugin not found at $PLUGIN" >&2
    exit 1
fi

cp "$ROOT/widget/CalBar.qml" "$BAR/CalBar.qml"
cp "$ROOT/widget/CalCarrot.qml" "$BAR/CalCarrot.qml"

python3 - "$BAR/BarContent.qml" "$PLUGIN/MaterialConfigSchema.qml" "$PLUGIN/settings/BarModuleOrderEditor.qml" <<'PY'
from pathlib import Path
import sys

bar_path, schema_path, editor_path = map(Path, sys.argv[1:])

def backup(path):
    backup_path = Path(str(path) + ".bak-calcalories")
    if not backup_path.exists():
        backup_path.write_text(path.read_text())

# ── BarContent: register the module and make it visible ───────────────
bar = bar_path.read_text()
backup(bar_path)
if '"calories": caloriesModuleComponent' not in bar:
    bar = bar.replace(
        '        "weather": weatherComponent,\n        "spacer": spacerComponent,\n',
        '        "weather": weatherComponent,\n        "calories": caloriesModuleComponent,\n        "spacer": spacerComponent,\n',
        1)
if 'id: caloriesModuleComponent' not in bar:
    needle = '    Component {\n        id: rightSidebarButtonComponent\n'
    insert = '''    Component {
        id: caloriesModuleComponent
        CalBar {
            visible: root._moduleVisible("calories")
            Layout.alignment: Qt.AlignVCenter
        }
    }
    Component {
        id: rightSidebarButtonComponent
'''
    if needle not in bar:
        raise SystemExit("BarContent.qml: right sidebar component anchor missing")
    bar = bar.replace(needle, insert, 1)
if '"calories"' not in (bar.split('_rightIds', 1)[1].split('\n', 1)[0] if '_rightIds' in bar else ''):
    bar = bar.replace(
        '    readonly property var _rightIds:       root._zone("right",       ["rightSidebarButton", "tray", "timer", "shellUpdate", "spacer", "weather"])',
        '    readonly property var _rightIds:       root._zone("right",       ["rightSidebarButton", "calories", "tray", "timer", "shellUpdate", "spacer", "weather"])',
        1)
bar_path.write_text(bar)

# ── Schema: declare the module and the default right-zone entry ──────
schema = schema_path.read_text()
backup(schema_path)
if 'property bool calories: true' not in schema:
    schema = schema.replace(
        '            property bool weather: true\n            property bool taskbar: false\n',
        '            property bool weather: true\n            property bool calories: true\n            property bool taskbar: false\n',
        1)
if 'rightSidebarButton", "calories"' not in schema:
    schema = schema.replace(
        'property list<string> right: ["rightSidebarButton", "tray", "timer", "shellUpdate", "spacer", "weather"]',
        'property list<string> right: ["rightSidebarButton", "calories", "tray", "timer", "shellUpdate", "spacer", "weather"]',
        1)
schema_path.write_text(schema)

# ── Settings editor: show the module with a name and icon ─────────────
editor = editor_path.read_text()
backup(editor_path)
if '"calories"' not in editor:
    editor = editor.replace(
        'right: ["rightSidebarButton", "tray", "timer", "shellUpdate", "spacer", "weather"],',
        'right: ["rightSidebarButton", "calories", "tray", "timer", "shellUpdate", "spacer", "weather"],',
        1)
    editor = editor.replace(
        '"clock", "utilButtons", "battery", "rightSidebarButton", "tray", "timer", "shellUpdate", "spacer", "weather"',
        '"clock", "utilButtons", "battery", "rightSidebarButton", "calories", "tray", "timer", "shellUpdate", "spacer", "weather"',
        1)
    editor = editor.replace(
        'weather: "cloud" })[id] || "widgets"',
        'weather: "cloud", calories: "nutrition" })[id] || "widgets"',
        1)
    editor = editor.replace(
        'weather: Translation.tr("Weather") })[id] || id',
        'weather: Translation.tr("Weather"), calories: Translation.tr("Calories") })[id] || id',
        1)
    editor = editor.replace(
        'tray: "sysTray", weather: "weather",',
        'tray: "sysTray", weather: "weather", calories: "calories",',
        1)
editor_path.write_text(editor)
PY

if command -v inir >/dev/null 2>&1; then
    inir calcorie bar true >/dev/null 2>&1 || true
fi

if [ "$RESTART" -eq 1 ]; then
    systemctl --user restart inir.service
    echo "Bar chip installed; iNiR restarted. Left-click toggles the console, right-click opens AI."
else
    echo "Bar chip installed. Restart iNiR to load it: systemctl --user restart inir.service"
fi
