# Window size and fullscreen

The desktop game starts maximized. The map and header fill the window, including
wide or tall monitors. Resizing reveals more or less map instead of stretching a
fixed 1280×720 scene. Map zoom stays under player control, and Settings' interface
scale still enlarges the controls independently.

Open **Settings → Display → Fullscreen**, then press **Apply**, or press **F11**.
Press F11 again to return to the previous windowed or maximized mode. Fullscreen
is saved in `user://settings.cfg`, independently of game saves, and is restored
next time the game starts. The shortcut can be changed in Settings' key list.
Key capture takes precedence over fullscreen; holding the key does not repeatedly
toggle the window. The shortcut also works inside Settings.

When testing through Godot's embedded Game view, the editor controls the size of
the host area and can display a smaller, centered game. Turn off embedded game
running and run the project in a **separate window** to use the game's maximized
window and native fullscreen. Godot supports fullscreen; this is an editor
preview setting rather than a game engine restriction.

`tests/test_display_settings.gd` checks live viewport sizes from 1280×720 to
1920×1200 at 100% and 200% UI scale, full-width toolbars, accessible Apply buttons,
settings persistence, shortcut remapping and unchanged simulation state.
Headless testing cannot verify monitor takeover or desktop window decorations;
window mode transitions/restoration are checked on an unattached Godot Window.
For a desktop check, run separately, press F11 twice, then enable fullscreen in
Settings and restart the game to confirm restoration on your monitor.
