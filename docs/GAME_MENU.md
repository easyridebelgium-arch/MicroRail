# Game menu and returning to the title screen

Click **Menu** beside Accounts, or press **Escape** with no active tool/gesture.
If you are drawing/removing track or using a tool, the first Escape cancels it;
press Escape again for the menu. Existing management dialogs retain their own
close/cancel behaviour. The Cancel/menu keyboard action can be remapped in Settings.

The menu pauses the fixed-step simulation and offers:

- **Resume:** return to the railway at the prior speed. If you had already paused
  before opening the menu, the simulation stays paused.
- **Save game — Slot N:** save to the active slot using normal atomic writes and
  its previous-save backup. The menu shows success or the actual refusal/error.
  Use the toolbar Save chooser when you want a different one of the four slots.
- **Settings:** change options; closing Settings returns to the game menu.
- **Return to Main Menu:** choose **Save and Return**, **Return Without Saving**
  or **Cancel**. Cancel returns to the paused game menu.

The Settings screen's **Return to Main Menu** uses this same protected exit flow.
It no longer leaves directly with only a "save first" label.

Saving must succeed before **Save and Return** leaves the game. An unapplied
construction draft or file error keeps the game open and explains the problem.
Resume to apply/discard a draft through Overlays, then save again. Opening the
menu cancels an unfinished mouse stroke but preserves already staged draft edits.
**Return Without Saving** explicitly discards unsaved progress/drafts and leaves
the previous saved file untouched. The menu does not add automatic saving or change
the save schema.

Menus use the shared button styling with a navy panel. Content scrolls and windows
clamp to the viewport at larger UI scales; focus starts on Resume or on Cancel in
the exit confirmation. Map input, panning, speed shortcuts and simulation ticks
remain blocked while the menu/settings/exit flow owns input.

Preview: [game menu](images/game_menu.png) and
[save/discard choice](images/menu_save_confirmation.png).

Validation: `tests/test_game_menu.gd` checks Escape, prior pause/speed, modal
behaviour, Settings return, drafts, failed saves, 200% scaling, both real title-scene
transitions and unchanged files on discard. Related display, track gestures,
construction, toolbar, first-session, save-slot and new-game suites protect the
existing controls. A Compatibility-renderer smoke check injects a real Escape key
event and captures the visible dialogs.
