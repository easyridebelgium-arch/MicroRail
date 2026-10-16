extends SceneTree
const Response = preload("res://scripts/core/demand_response.gd")
const Demand = preload("res://scripts/core/passenger_demand.gd")
const Amenities = preload("res://scripts/core/amenities.gd")
const Rng = preload("res://scripts/core/sim_rng.gd")
const Clock = preload("res://scripts/core/sim_clock.gd")
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
	check(Response.target(75, 10, true) == 100 and Response.target(100, 10, true) == 125 and Response.target(10, 10, true) == 50, "rating maps to bounded documented targets")
	check(Response.target(100, 9, true) == 100 and Response.target(100, 100, false) == 100 and Response.target(-1, 0, false) == 100, "growth requires evidence and connection; no data remains neutral")
	var response := Response.new()
	response.arrivals("a", 3, 100, 10, true)
	check(response.state.a.factor == 101 and response.state.a.carry == 3, "first response is one percentage point with fractional carry")
	for interval in range(100): response.arrivals("a", 3, 100, 10, true)
	check(response.state.a.factor == 125, "good service reaches upper bound without overshoot")
	response.arrivals("a", 3, 10, 10, true)
	check(response.state.a.factor == 124, "negative response is gradual too")
	for interval in range(100): response.arrivals("a", 3, 10, 10, true)
	check(response.state.a.factor == 50, "poor service reaches positive floor")
	response.state.a.carry = 0
	var total := 0
	for interval in range(10): total += response.arrivals("a", 3, 10, 10, true)
	check(total == 15, "fractional accumulation gives exact sustained half demand")
	var saved := response.save_state()
	var restored := Response.new()
	restored.restore_state(saved)
	for interval in range(7):
		check(response.arrivals("a", 4, 90, 25, true) == restored.arrivals("a", 4, 90, 25, true), "load preserves carry and smoothing step %d" % interval)
	var bad := saved.duplicate(true)
	bad.a.factor = 0
	check(not Response.valid_state(bad), "zero-demand factor rejected")
	bad = saved.duplicate(true)
	bad.a.carry = 100
	check(not Response.valid_state(bad), "invalid fractional carry rejected")
	bad = saved.duplicate(true)
	bad.a.factor = 90.5
	check(not Response.valid_state(bad), "fractional factor rejected")
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	for station in Demand.STATIONS: game.passenger_demand.reset_total(station, 0)
	game.satisfaction.record("a", [{"count": 10, "wait": 0}], 0, [])
	var cash: int = game.money
	var position: Vector2 = game.train_position
	var grants: Dictionary = game.reservations.owners.duplicate(true)
	game._generate_passengers(game.PASSENGER_INTERVAL)
	check(game.demand_response.state.a.factor == 101 and game.demand_response.state.c.factor == 100, "actual generation uses measured service evidence and live connections")
	check(game.money == cash and game.train_position == position and game.reservations.owners == grants, "demand cannot move trains, spend money or grant track")
	game.selected_station = game.STATION_A
	game.station_panel.show()
	game._update_station_inspector()
	check(game.station_summary.text.contains("Demand response: 101%") and game.station_details.text.contains("current target 125%"), "station summary and details explain current and target response")
	game.station_panel.hide()
	game.header_controls.open_accounts()
	check(game.header_controls.accounts_text.text.contains("Demand response: 101%"), "Accounts includes response evidence")
	game.header_controls.accounts_dialog.hide()
	check(game._save_game(4), "game saves response state")
	var actual: Dictionary = game.demand_response.save_state()
	game.demand_response = Response.new()
	check(game._load_slot(4) and game.demand_response.save_state() == actual and game.train_position == position, "normal load restores response without relocation")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(4)))
	bad = payload.duplicate(true)
	bad.demand_response.a.factor = 126
	check(not game._is_valid_save(bad), "full save validation enforces response bounds")
	payload.version = 31
	payload.erase("demand_response")
	var old := Migrations.migrate(payload)
	check(old.ok and old.data.version == Migrations.CURRENT_VERSION and old.data.demand_response == Response.defaults() and old.data.demand.queues == payload.demand.queues and old.data.demand.primary == payload.demand.primary and old.data.satisfaction == payload.satisfaction and game._is_valid_save(old.data), "v31 migration preserves counts, ages and satisfaction with neutral response")
	game.passenger_held = true
	game._generate_passengers(game.PASSENGER_INTERVAL)
	check(game.demand_response.state.a.factor == 100, "holding the only connection removes the growth bonus gradually")
	game.passenger_held = false
	# A full station refuses new random arrivals, but response never discards queues.
	game.passenger_demand.reset_total("b", game.amenities.queue_limit("b"))
	var counts: Dictionary = game.passenger_demand.queues.b.duplicate(true)
	var rng_before: Dictionary = game.sim_rng.save_state()
	var proposed: int = game.demand_response.arrivals("b", 3, 10, 0, false)
	game.passenger_demand.generate("b", proposed, game.amenities.queue_limit("b"), game.sim_rng, game.sim_clock.tick)
	check(game.passenger_demand.queues.b == counts and game.sim_rng.save_state() == rng_before, "full queue retains waiting riders and consumes no destination RNG")
	game.queue_free()
	await process_frame
	var baseline := frame_case(30)
	for fps in [60, 120]: check(frame_case(fps) == baseline, "response/amenity carry, destinations and RNG match at %d FPS" % fps)
	print("Demand response: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func frame_case(fps: int) -> Dictionary:
	var response := Response.new()
	var demand := Demand.new()
	var amenities := Amenities.new()
	amenities.buy("a", "shelter", 10000)
	var rng := Rng.new(12345)
	var clock := Clock.new()
	for station in Demand.STATIONS: demand.reset_total(station, 0)
	for frame in range(fps * 180):
		for step in range(clock.advance(1.0 / fps)):
			clock.begin_tick()
			if clock.tick % 300 != 0: continue
			for key in Demand.STATIONS:
				var rating := 100 if clock.tick < 3600 else 10
				var batch := response.arrivals(key, amenities.arrivals(key, 3), rating, 20, true)
				demand.generate(key, batch, amenities.queue_limit(key), rng, clock.tick)
	return {"response": response.save_state(), "amenities": amenities.to_save(), "demand": demand.save_state({}, clock.tick), "rng": rng.save_state(), "tick": clock.tick}
