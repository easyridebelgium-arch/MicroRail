extends SceneTree
## Run with a graphics display: godot --path . --script res://tools/check_terrain_render.gd
## Headless dummy rendering cannot detect missing/clipped sprites.
const Settings = preload("res://scripts/core/game_settings.gd")
var failures := 0
var comparisons := 0

func _initialize() -> void: run.call_deferred()

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Terrain render check requires a graphics display; not executed.")
		quit(2)
		return
	root.size = Vector2i(1920, 1080)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.paused = true
	for frame in range(5): await process_frame
	Settings.ui_scale = 1.0
	Settings.palette_mode = Settings.PaletteMode.DEFAULT
	game._apply_settings()
	game.camera.zoom = Vector2(1.15, 1.15)
	game.camera.position = Vector2(650, 420)
	game.camera.force_update_scroll()
	var before: Array = [game.sim_clock.tick, game.sim_rng.save_state(), game.tracks.duplicate(true), game.train_position, game.money]
	var reference: Array = []
	for style in ["summer", "autumn", "winter", "plain", "winter", "summer"]:
		Settings.terrain_style = style
		game._apply_settings()
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var samples: Array = []
		for facility in game.world.facilities():
			# Sample inside opaque grounds: terrain changes cannot legitimately
			# change these pixels. This catches lost atlas sprites after redraws.
			var bounds := Rect2(Vector2(facility.cell) * 32 + Vector2(-30, -62), Vector2(92, 60))
			var screen: Rect2 = game.get_global_transform_with_canvas() * bounds
			var region := Rect2i(Vector2i(screen.position.ceil()), Vector2i(screen.size.floor()))
			samples.append(image.get_region(region).get_data())
		if reference.is_empty():
			reference = samples
		else:
			for index in range(samples.size()):
				comparisons += 1
				if samples[index] != reference[index]:
					failures += 1
					printerr("Facility artwork changed/disappeared after ground switch to ", style, " at index ", index)
	var after: Array = [game.sim_clock.tick, game.sim_rng.save_state(), game.tracks.duplicate(true), game.train_position, game.money]
	if after != before:
		failures += 1
		printerr("Appearance changed simulation state")
	print("Terrain render: %d facility-image comparisons, %d failures; simulation snapshot checked." % [comparisons, failures])
	quit(1 if failures else 0)
