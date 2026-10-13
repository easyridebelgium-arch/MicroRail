extends SceneTree
const Stats = preload("res://scripts/core/passenger_satisfaction.gd")
const Demand = preload("res://scripts/core/passenger_demand.gd")
const Amenities = preload("res://scripts/core/amenities.gd")
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
	check(Stats.score(15 * 60, 0) == 100 and Stats.score(45 * 60, 0) == 90, "grace period and waiting penalty follow documented formula")
	check(Stats.score(1000000, 0) == 10 and Stats.score(1000000, 10) == 20, "comfort cannot remove severe waiting penalty")
	check(Stats.comfort(["shelter", "waiting_room", "kiosk"]) == 10, "amenity comfort bonuses are explicit and additive")
	var stats := Stats.new()
	var demand := Demand.new()
	var amenities := Amenities.new()
	for key in Demand.STATIONS: demand.reset_total(key, 0)
	check(stats.company(demand, 0, amenities).rating == -1, "empty history/queues show no data instead of invented rating")
	var manifest := {"b": 3}
	demand.return_to("a", manifest, 0)
	check(stats.company(demand, 45 * 60, amenities).rating == 90, "unserved waiting demand affects company rating")
	var aboard: Dictionary = {}
	demand.board("a", ["b"], 2, aboard, 45 * 60)
	stats.record("a", demand.last_boarding, 45 * 60, [])
	check(stats.history.a[0].count == 2 and stats.history.a[0].wait == 45 * 60, "actual boarded count and waiting age feed statistics")
	check(stats.station("a", demand.waiting_groups("a", 45 * 60), 45 * 60, []).rating == 90, "partial cohort is weighted correctly alongside boarded experience")
	amenities.owned.a = ["shelter"]
	check(stats.company(demand, 45 * 60, amenities).rating == 91, "upgrades improve current queue but do not rewrite historical comfort")
	var saved := stats.save_state()
	check(Stats.valid_state(saved, 45 * 60), "legitimate saved history validates")
	var restored := Stats.new()
	restored.restore_state(saved)
	check(restored.company(demand, 45 * 60, amenities) == stats.company(demand, 45 * 60, amenities), "round trip preserves measured rating")
	var bad := saved.duplicate(true)
	bad.a[0].tick += 1
	check(not Stats.valid_state(bad, 45 * 60), "future measurement rejected")
	bad = saved.duplicate(true)
	bad.a[0].wait = bad.a[0].tick + 1
	check(not Stats.valid_state(bad, 45 * 60), "waiting before simulation origin rejected")
	bad = saved.duplicate(true)
	bad.a[0].count = 1.5
	check(not Stats.valid_state(bad, 45 * 60), "fractional passenger weights rejected")
	for tick in range(3000, 3200): stats.record("a", [{"count": 1, "wait": 0}], tick, [])
	check(stats.history.a.size() == Stats.MAX_GROUPS and stats.history.a.front().tick == 3072, "history retains a bounded recent window")
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	game.sim_clock.tick = 2700
	for x in range(4, 21): game.tracks[Vector2i(x, 8)] = false
	game._check_route()
	for key in Demand.STATIONS: game.passenger_demand.reset_total(key, 0)
	manifest = {"b": 2}
	game.passenger_demand.return_to("a", manifest, 0)
	var money: int = game.money
	var position: Vector2 = game.train_position
	var grants: Dictionary = game.reservations.owners.duplicate(true)
	game._board_waiting("a", ["b"], 1, game.passenger_destinations)
	check(game.satisfaction.history.a.size() == 1 and game.satisfaction.history.a[0].wait == 2700, "game boarding hook records real waiting sample")
	check(game.money == money and game.train_position == position and game.reservations.owners == grants, "measurement cannot change cash, position or authority")
	check(game._destination_queue_text("a").contains("Waiting satisfaction: 90 / 100"), "station inspector explains measured rating")
	game.selected_station = game.STATION_A
	game.station_panel.show()
	game._update_station_inspector()
	check(game.station_summary.text.contains("Waiting satisfaction: 90 / 100"), "rating is visible before expanding station details")
	game.station_panel.hide()
	game.header_controls.open_accounts()
	check(game.header_controls.accounts_text.text.contains("Passenger waiting satisfaction") and game.header_controls.accounts_text.text.contains("Journey time, punctuality"), "Accounts presents company and station evidence with honest scope")
	game.header_controls.accounts_dialog.hide()
	check(game._save_game(4), "game saves measured satisfaction")
	game.satisfaction = Stats.new()
	check(game._load_slot(4) and game.satisfaction.history.a[0].wait == 2700 and game.train_position == position, "loading restores history without moving train")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(4)))
	bad = payload.duplicate(true)
	bad.satisfaction.a[0].comfort = 100
	check(not game._is_valid_save(bad), "full validation rejects invented comfort bonus")
	payload.version = 30
	payload.erase("satisfaction")
	var migrated := Migrations.migrate(payload)
	check(migrated.ok and migrated.data.version == Migrations.CURRENT_VERSION and migrated.data.satisfaction == Stats.defaults() and migrated.data.demand == payload.demand and game._is_valid_save(migrated.data), "v30 migration preserves arrival groups and starts history empty")
	var settings = game.GameSettings
	var old_scale: float = settings.ui_scale
	for scale_value in [1.0, 1.5, 2.0]:
		settings.ui_scale = scale_value
		game._apply_settings()
		game.header_controls.open_accounts()
		await process_frame
		await process_frame
		var dialog = game.header_controls.accounts_dialog
		check(float(dialog.size.y) <= game.get_viewport_rect().size.y + 1 and Rect2(Vector2.ZERO, Vector2(dialog.size)).encloses(dialog.get_ok_button().get_global_rect()), "satisfaction Accounts/Close fits at %s%%" % (scale_value * 100))
		dialog.hide()
	settings.ui_scale = old_scale
	game._apply_settings()
	game.queue_free()
	await process_frame
	var baseline := frame_case(30)
	for fps in [60, 120]: check(frame_case(fps) == baseline, "history/rating match at %d FPS" % fps)
	print("Passenger satisfaction: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func frame_case(fps: int) -> Dictionary:
	var clock := Clock.new()
	var demand := Demand.new()
	var stats := Stats.new()
	var amenities := Amenities.new()
	for key in Demand.STATIONS: demand.reset_total(key, 0)
	var manifest := {"b": 5}
	demand.return_to("a", manifest, 0)
	for frame in range(fps * 50):
		for step in range(clock.advance(1.0 / fps)):
			clock.begin_tick()
			if clock.tick == 2700:
				demand.board("a", ["b"], 3, manifest, clock.tick)
				stats.record("a", demand.last_boarding, clock.tick, [])
	return {"tick": clock.tick, "history": stats.save_state(), "rating": stats.company(demand, clock.tick, amenities)}
