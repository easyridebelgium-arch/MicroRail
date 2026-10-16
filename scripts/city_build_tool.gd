extends RefCounted
## Main-scene adapter. Source artwork is deliberately not required.
const CityArt = preload("res://scripts/art/city_art.gd")
const Start = preload("res://scripts/core/sandbox_start.gd")
const Construction = preload("res://scripts/core/station_construction.gd")
const Generator = preload("res://scripts/core/world_generator.gd")
const Command = preload("res://scripts/core/station_command.gd")
const MODEL_FIELDS := {"city_demand": "city_demand", "world": "world", "passenger_demand": "demand", "amenities": "amenities", "satisfaction": "satisfaction", "demand_response": "demand_response", "journey_ledger": "journey_ledger", "sim_clock": "sim_clock", "sim_rng": "sim_rng", "command_queue": "command_queue", "tracks": "tracks", "money": "money", "total_construction_cost": "total_construction_cost"}
var game: Node2D
var boot: RefCounted
var active := false
var button: Button
func _init(owner_game: Node2D) -> void: game = owner_game

func is_city_game() -> bool: return game.world.state.layout_id == Generator.PROFILE

func prepare() -> bool:
	for argument in (OS.get_cmdline_user_args() if game.startup_allow_cli else PackedStringArray()):
		if argument.begins_with("--city-seed=") and game.startup_city_seed.is_empty(): game.startup_city_seed = argument.trim_prefix("--city-seed=")
		if argument.begins_with("--city-count=") and argument.trim_prefix("--city-count=").is_valid_int(): game.startup_city_count = argument.trim_prefix("--city-count=").to_int()
	if game.startup_city_seed.is_empty(): return false
	boot = Start.new()
	var result: Dictionary = boot.initialize(game.startup_city_seed, game.startup_city_count)
	if not result.ok:
		game._show_notice(result.message)
		return false
	_adopt()
	game.services = {}
	game.fleet = boot.fleet
	game.passenger_service_enabled = false
	game.paused = true
	game.train_position = Vector2.ZERO
	return true

## Rebind saved models directly; loading must never call the generator or reseed RNG.
func restore_context() -> void:
	active = false
	if is_city_game():
		boot = Start.new()
		for field in MODEL_FIELDS: boot.set(MODEL_FIELDS[field], game.get(field))
		boot.initialized = true
	else: boot = null
	refresh()

func configure() -> void:
	button = Button.new()
	button.name = "BuildCityStation"
	button.text = "Station"
	button.toggle_mode = true
	button.tooltip_text = "Build a five-tile passenger station within six tiles of a city. £250 plus missing platform track."
	button.pressed.connect(toggle)
	game.header_toolbar.add_child(button)
	refresh()

func refresh() -> void:
	if button == null: return
	button.visible = is_city_game()
	if not button.visible: active = false
	button.set_pressed_no_signal(active)

func toggle() -> void:
	if not is_city_game(): return
	if game.planning_mode or not game.construction_plan.is_empty():
		game._show_notice("Apply or discard the track draft before placing a station.")
		return
	var was_active := active
	game._reset_track_tools()
	active = not was_active
	game._update_toolbar()
	game.queue_redraw()

func claims() -> Dictionary:
	var result: Dictionary = game.reservations.owners.duplicate()
	result.merge(game.reservations.occupied_owners, true)
	return result

func preview(cell: Vector2i) -> Dictionary:
	var result := Construction.preview(game.world.save_state(), cell, game.tracks, game.track_signals, claims(), game.money)
	var terrain_error: String = game.river_terrain.site_error(Construction.building_cells(cell) + Construction.platform_cells(cell), game.tracks)
	if not terrain_error.is_empty():
		result.ok = false
		result.message = terrain_error
	if not result.settlement_id.is_empty() and game.city_demand.state.cities.has(result.settlement_id):
		result.message += " Population served: %d. A connected service is needed to queue trips." % int(game.city_demand.state.cities[result.settlement_id].population)
	return result

func submit(cell: Vector2i) -> void:
	game._rebuild_reservations()
	if not game.river_terrain.site_error(Construction.building_cells(cell) + Construction.platform_cells(cell), game.tracks).is_empty():
		game._show_notice("Stations need dry land.")
		return
	var draft := Construction.draft(game.world.save_state(), cell, game.tracks, game.track_signals, claims(), game.money)
	if not draft.ok:
		game._show_notice(draft.message)
		return
	game._submit_command("build_station", Command.encode(draft))

func execute(data: Dictionary) -> void:
	if not is_city_game() or boot == null: return
	var draft := Command.decode(data)
	if draft.is_empty():
		game._show_notice("Invalid station command. Preview the station again.")
		return
	var command_cell := Vector2i(int(data.get("x", -1)), int(data.get("y", -1)))
	if not game.river_terrain.site_error(Construction.building_cells(command_cell) + Construction.platform_cells(command_cell), game.tracks).is_empty():
		game._show_notice("Stations need dry land.")
		return
	game._rebuild_reservations()
	for field in MODEL_FIELDS: boot.set(MODEL_FIELDS[field], game.get(field))
	var result: Dictionary = boot.commit_station(draft, game.track_signals, claims())
	if not result.ok:
		game._show_notice(result.message)
		return
	_adopt()
	game.network_map.facilities = game._facility_markers()
	game._clear_construction_history()
	game._check_route()
	game._record_event("station_built", str(result.station_id), {"x": data.x, "y": data.y, "spent": result.spent})
	game._show_notice(result.message)
	game.queue_redraw()

func _adopt() -> void:
	for field in MODEL_FIELDS: game.set(field, boot.get(MODEL_FIELDS[field]))

func platform_protected(cell: Vector2i) -> bool:
	if not is_city_game(): return false
	for station in game.world.stations().values():
		if cell in Construction.platform_cells(station.cell): return true
	return false

func draw_cities() -> void:
	for town in game.world.state.settlements:
		var center := Vector2i(int(town.cell[0]), int(town.cell[1]))
		var bounds := Generator.town_bounds(center)
		game.draw_rect(Rect2(Vector2(bounds.position) * game.TILE_SIZE, Vector2(bounds.size) * game.TILE_SIZE), Color("#394538"))
		var population: int = game.city_demand.state.cities[town.id].population
		var initial: int = game.city_growth.state.cities[town.id].initial
		CityArt.draw_city(game, Rect2(Vector2(bounds.position) * game.TILE_SIZE, Vector2(bounds.size) * game.TILE_SIZE), population, initial)
		var served := false
		for station in game.world.stations().values():
			if station.settlement_id == town.id: served = true
		var history: Array = game.city_growth.state.cities[town.id].history
		var change_label := "" if history.is_empty() or int(history.back().delta) == 0 else " | last %+d" % int(history.back().delta)
		game.draw_string(ThemeDB.fallback_font, Vector2(bounds.position) * game.TILE_SIZE + Vector2(0, -5), "%s (%d)" % [town.name, population] + change_label + (" — station built" if served else " — needs a station"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

func draw_preview() -> void:
	if not active or game._modal_open() or game._mouse_is_over_interface(): return
	var quoted := preview(game.hovered_cell)
	var colour := Color("#56b4e9") if quoted.ok else Color("#e69f00")
	for cell in quoted.building_cells + quoted.platform_cells:
		var rectangle := Rect2(Vector2(cell) * game.TILE_SIZE, Vector2.ONE * game.TILE_SIZE)
		game.draw_rect(rectangle, Color(colour, 0.2))
		game.draw_rect(rectangle, colour, false, 2)
		game.draw_line(rectangle.position, rectangle.end, colour, 1)
	var at: Vector2 = game._cell_center(game.hovered_cell)
	game.draw_circle(at, Construction.CATCHMENT_RADIUS * game.TILE_SIZE, colour, false, 1)
	game.draw_string(ThemeDB.fallback_font, at + Vector2(8, -12), ("+ " if quoted.ok else "× ") + "£%d" % int(quoted.cost.total), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, colour)
