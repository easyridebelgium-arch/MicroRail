extends SceneTree
## The interface scale must not change how large the map looks.
## Run: godot --headless --path . --script res://tests/test_ui_scale.gd

const Settings = preload("res://scripts/core/game_settings.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1

	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	# Headless windows default to 64x64. Adaptive layout must be tested with
	# an actual desktop size rather than the old fixed reference canvas.
	root.size = Vector2i(1280, 720)
	var original_scale: float = Settings.ui_scale
	var scene: PackedScene = load("res://scenes/main/main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)

	check(Settings.UI_SCALES.has(2.0), "200% is offered")
	check(Settings.nearest_scale(1.9) == 2.0, "1.9 snaps to 200%")

	var base_zoom: float = game.camera.zoom.x * game.applied_ui_scale

	Settings.ui_scale = 2.0
	game._apply_settings()
	check(is_equal_approx(game.camera.zoom.x * 2.0, base_zoom), "200% keeps the player's zoom (camera zoom halves)")

	game._zoom_camera(game.ZOOM_STEP)
	var zoomed: float = game.camera.zoom.x * game.applied_ui_scale
	check(zoomed > base_zoom or is_equal_approx(zoomed, game.MAX_ZOOM), "zoom in works at 200%")

	game._reset_camera()
	check(is_equal_approx(game.camera.zoom.x, 0.5), "reset gives the compensated zoom at 200%")

	check(not game.header_title.visible and Settings.use_compact_header(), "200% uses the compact header")
	check(game.instructions.text.count("\n") == 1, "compact status text is two lines")

	# The Apply button must stay reachable at the largest scale.
	game.settings_dialog.open_dialog()
	await process_frame
	await process_frame
	var dialog: ConfirmationDialog = game.settings_dialog
	var logical: Vector2 = game.get_viewport_rect().size
	check(float(dialog.size.y) <= logical.y + 1.0, "settings dialog fits the view height at 200%% (dialog %d, view %d)" % [dialog.size.y, logical.y])
	var ok_rect: Rect2 = dialog.get_ok_button().get_global_rect()
	check(Rect2(Vector2.ZERO, Vector2(dialog.size)).encloses(ok_rect), "Apply button lies inside the settings dialog at 200%")
	dialog.hide()

	Settings.ui_scale = 1.0
	game._apply_settings()
	check(is_equal_approx(game.camera.zoom.x, 1.0), "back to 100% restores the camera zoom")
	check(game.header_title.visible and not Settings.use_compact_header(), "100% uses the full header")

	check(game.header_box.get_parent() == game.get_node("Interface"), "header box exists")
	game._layout_header()
	check(game.header_background.offset_bottom >= game.header_box.size.y, "header background covers the header box")

	Settings.ui_scale = original_scale
	game.queue_free()
	await process_frame
	print("UI scale tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
