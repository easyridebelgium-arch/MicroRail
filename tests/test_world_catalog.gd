extends SceneTree
const World = preload("res://scripts/core/world_catalog.gd")
const Migrations = preload("res://scripts/core/save_migrations.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var catalog := World.new()
	check(World.valid_tutorial(catalog.save_state(), false, false), "tutorial geometry is a valid versioned world")
	check(catalog.facilities().size() == 5 and catalog.stations().size() == 3 and catalog.station_key(Vector2i(20, 8)) == "b", "enabled facilities and station identity lookup")
	check(catalog.station_key(Vector2i(70, 40)) == "", "unknown location does not silently become station A")
	check(catalog.stations().is_read_only() and catalog.stations().a.is_read_only(), "shared station definitions cannot be mutated by consumers")
	var copy := catalog.save_state()
	copy.facilities[0].cell[0] = 70
	check(catalog.stations().a.cell == Vector2i(4, 8), "saved snapshots cannot alter authoritative live geometry")
	copy = JSON.parse_string(JSON.stringify(catalog.save_state()))
	check(World.valid_tutorial(copy, false, false), "JSON float coordinates validate by value")
	var restored := World.new()
	restored.restore_state(copy)
	check(restored.save_state() == catalog.save_state(), "JSON catalog normalizes to exact state")
	copy = catalog.save_state()
	copy.facilities[0].name = "Other Central"
	restored.restore_state(copy)
	check(restored.stations().a.name == "Other Central" and catalog.stations().a.name == "Station A", "separate worlds cannot alter shared global station definitions")
	copy.facilities.reverse()
	restored.restore_state(copy)
	check(restored.facilities()[0].id == catalog.facilities()[0].id and restored.stations().keys() == catalog.stations().keys(), "consumer ordering is stable regardless of saved row order")
	for field in ["schema_version", "generator_version", "content_version"]:
		copy = catalog.save_state()
		copy[field] = 0
		check(not World.valid(copy), "invalid version rejected: " + field)
	for seed in ["01", "-1", "9223372036854775808", "1.5", 5]:
		copy = catalog.save_state()
		copy.layout_seed = seed
		check(not World.valid(copy), "seed must be canonical decimal string within range")
	copy = catalog.save_state()
	copy.facilities[1].id = copy.facilities[0].id
	check(not World.valid(copy), "duplicate/mismatched identity rejected")
	copy = catalog.save_state()
	copy.facilities[1].cell = [4, 8]
	check(not World.valid(copy), "overlapping platforms/buildings rejected")
	copy = catalog.save_state()
	copy.facilities[0].cell = [4.5, 8]
	check(not World.valid(copy), "fractional tile rejected")
	copy = catalog.save_state()
	copy.facilities[0].cell = [80, 8]
	check(not World.valid(copy), "out-of-map platform rejected")
	copy = catalog.save_state()
	copy.facilities[0].settlement_id = "town:missing"
	check(not World.valid(copy), "dangling settlement catchment rejected")
	copy = catalog.save_state()
	copy.facilities[0].cell = [6, 8]
	check(World.valid(copy) and not World.valid_tutorial(copy, false, false), "core supports different geometry but current gameplay rejects unsupported relocation")
	copy = catalog.save_state()
	copy.layout_id = "seeded_flat"
	check(not World.valid(copy), "future sandbox station needs settlement identity")
	copy = {"schema_version": 1, "layout_id": "seeded_flat", "generator_version": 1, "content_version": 1, "layout_seed": "42", "size": [80, 50], "settlements": [{"id": "town:delta", "name": "Delta", "cell": [30, 5]}], "facilities": [{"id": "station:delta", "stop_id": "delta", "kind": "station", "name": "Delta Central", "cell": [30, 8], "settlement_id": "town:delta", "enabled": true}]}
	check(World.valid(copy), "variable station identity and city relation supported in isolated catalog")
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.paused = true
	game.money = 10000
	for x in range(7, 30): game.tracks[Vector2i(x, 24)] = false
	game._check_route()
	var position: Vector2 = game.freight_train.position
	game.build_sawmill()
	game.build_factory()
	check(game.world.facilities().size() == 7 and game.network_map.facilities.size() == 7 and game.freight_train.position == position, "industry installation activates catalog and minimap without movement")
	check(World.valid_tutorial(game.world.save_state(), true, true), "catalog installation agrees with industry state")
	copy = game.world.save_state()
	copy.facilities[0].name = "A Central"
	game.world.restore_state(copy)
	game.selected_station = game.STATION_A
	game.station_panel.show()
	game._update_station_inspector()
	check(game.station_title.text == "A Central" and game.object_rows().any(func(row: Dictionary) -> bool: return row.get("key") == "station:a" and row.title == "A Central"), "station inspector and Find use saved labels")
	game.station_panel.hide()
	game.route_editor.open_editor()
	check(game.route_editor.station_choice.get_item_text(0) == "A Central" and game.route_editor.station_choice.get_item_metadata(0) == "a", "Routes refreshes labels while preserving stop identity")
	game.route_editor.hide()
	game.fleet_editor.open_editor()
	check(game.fleet_editor.start_station.get_item_text(0) == "Start at A Central", "Fleet refreshes saved station labels")
	game.fleet_editor.hide()
	check(game._save_game(4), "catalog saves with operating state")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(4)))
	var rng: Dictionary = game.sim_rng.save_state()
	check(game._load_slot(4) and game.world.stations().a.name == "A Central" and game.freight_train.position == position and game.sim_rng.save_state() == rng, "load preserves catalog label, physical position and random stream")
	copy = payload.duplicate(true)
	copy.world.facilities[0].cell = [6, 8]
	var file := FileAccess.open(game.SaveSlots.path(4), FileAccess.WRITE)
	file.store_string(JSON.stringify(copy))
	file.close()
	var live_world: Dictionary = game.world.save_state()
	check(not game._load_slot(4) and game.world.save_state() == live_world and game.freight_train.position == position, "unsupported saved geometry rejects atomically")
	payload.version = 38
	payload.erase("world")
	var old := Migrations.migrate(payload)
	check(old.ok and World.valid_tutorial(old.data.world, true, true) and old.data.freight == payload.freight and old.data.sim == payload.sim and old.data.state == payload.state, "v38 adds tutorial identities without changing money, trains or RNG")
	game.queue_free()
	await process_frame
	print("World catalog: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
