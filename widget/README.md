# Calcorie

A pastel pixel calorie widget for iNiR / Material. The card sits on the desktop; click it to open the console. The
console uses 16 px fields and a 13–14 px minimum for labels, with a 680×660 panel so the type can breathe.

- **Log food** by name and calories, or use the five quick-add chips.
- **AI estimate** sends a meal description to DeepSeek and parses a strict-JSON list of items, kcal and macros. Tick the ingredients that were actually in the meal, add one more by hand, then add only the selected items. Nothing is sent until you press **Ask DeepSeek**.
- **Daily budget** uses Mifflin–St Jeor, an activity factor and a cut / keep / build adjustment. You can override the target.
- **Water** logs 250 ml glasses, cycles a 6/8/10/12 goal, and can remind you every 30/45/60/90 minutes, 08:00–22:00.
  Reminders stop when the goal is reached and can be switched off.
- **Today resets** at local midnight; the log is kept in the widget's own iNiR config.
- **The carrot** squashes when you log something and changes expression when you get close to, or past, the budget.
- **No idle animation** and no background process. Motion stops when iNiR says the desktop is not visible.

## Install

The installed folder and config key keep the original `calcalories` id so existing data survives; `inir calcorie` is
the new command alias. To install, copy this folder to `~/.config/inir/widgets/calcalories`, then:

```sh
inir custom-widgets reload
inir background setWidgetEnabled custom.calcalories true
inir background focusWidget custom.calcalories false
```

Click the card to open the console. In edit mode the card drags and scales like any other desktop widget.
`./install-bar.sh` adds a carrot chip to the top bar; left-click toggles the console, right-click opens AI,
middle-click opens Water.

For the AI estimate, paste a DeepSeek key in **AI estimate** once; it is stored in the system keyring (key id
`calcorie-deepseek`, falling back to the existing `calcalories-deepseek`). You can also set `DEEPSEEK_API_KEY` in the iNiR environment. The key is never written to
widget settings. Use **KEY** in the ask row to replace a stored key. If your iNiR AI privacy policy is set to
local-only, the AI tab says so and does not call out.

## IPC

```sh
inir calcorie toggle
inir calcorie ai
inir calcorie water
inir calcorie waterAdd
inir calcorie waterTest
inir calcorie add "Banana" 105
inir calcorie reset
inir calcorie defaults   # empty log, neutral example profile, 2,200 kcal
```

## Privacy

Everything is local except the optional AI estimate. The widget writes the calorie log and water state under
`background.widgets.custom.calcalories` in `~/.config/inir/config.json`: `targetKcal`, `profileJson`, `entriesJson`,
`logDay`, `waterGlasses`, `waterGoal`, `waterReminder`, `waterIntervalMin`, `waterLastReminder` and `waterDay`. A meal
description is sent to DeepSeek only when you press **Ask DeepSeek**.

## Fonts

Silkscreen and Pixelify Sans, both SIL Open Font License 1.1; see `fonts/OFL-*.txt`.
