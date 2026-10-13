extends SceneTree
const Demand = preload("res://scripts/core/passenger_demand.gd")
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
func add(demand: RefCounted, station: String, destination: String, count: int, tick: int) -> void:
	var manifest := {destination: count}
	demand.return_to(station, manifest, tick)
func run() -> void:
	var demand := Demand.new()
	demand.reset_total("a", 0)
	add(demand, "a", "c", 5, 60)
	add(demand, "a", "b", 5, 120)
	var manifest: Dictionary = {}
	check(demand.board("a", ["b", "c"], 3, manifest, 180) == 3 and manifest == {"c": 3}, "older far-destination riders beat newer near-stop riders")
	check(demand.oldest_seconds("a", 180, "c") == 2.0, "partially boarded cohort keeps its arrival time")
	manifest.clear()
	demand.board("a", ["b", "c"], 4, manifest, 240)
	check(manifest == {"c": 2, "b": 2} and demand.queues.a == {"b": 3}, "oldest cohort finishes before newer riders take remaining seats")
	manifest.clear()
	add(demand, "a", "c", 2, 300)
	demand.board("a", ["c"], 1, manifest, 360)
	check(manifest == {"c": 1} and demand.queues.a.b == 3, "unserved older riders remain queued rather than consuming seats")
	demand.reset_total("a", 0)
	add(demand, "a", "c", 2, 400)
	add(demand, "a", "b", 2, 400)
	manifest.clear()
	demand.board("a", ["b", "c"], 2, manifest, 450)
	check(manifest == {"b": 2}, "equal-age tie follows forward destination order")
	demand.reset_total("b", 0)
	add(demand, "b", "c", 2, 10)
	var transfer := {"c": 3}
	demand.interchange("b", ["a", "b"], transfer, 100)
	check(demand.oldest_seconds("b", 160) == 2.5 and demand.batches.b.size() == 2, "transfer arrivals join behind existing station riders")
	manifest.clear()
	demand.board("b", ["c"], 2, manifest, 160)
	check(demand.oldest_seconds("b", 160) == 1.0 and demand.waiting("b") == 3, "boarding old riders reveals the newer interchange waiting age")
	var before_rng := Rng.new(123)
	demand.generate("b", 3, 100, before_rng, 200)
	var saved := demand.save_state({}, 600)
	check(Demand.valid_batches(saved.batches, saved.queues, 600), "all queue counts match saved arrival cohorts")
	var restored := Demand.new()
	restored.restore_state(saved)
	var left: Dictionary = {}
	var right: Dictionary = {}
	demand.board("b", ["c", "a"], 4, left, 650)
	restored.board("b", ["c", "a"], 4, right, 650)
	check(left == right and demand.save_state({}, 650) == restored.save_state({}, 650), "save/load preserves priority and partial cohorts")
	var bad := saved.duplicate(true)
	bad.batches.b[0].tick = 601
	check(not Demand.valid_batches(bad.batches, bad.queues, 600), "future arrival time rejected")
	bad = saved.duplicate(true)
	bad.batches.b[0].count += 1
	check(not Demand.valid_batches(bad.batches, bad.queues, 600), "cohort/count mismatch rejected")
	bad = saved.duplicate(true)
	bad.batches.b.append(bad.batches.b[0].duplicate())
	check(not Demand.valid_batches(bad.batches, bad.queues, 600), "duplicate cohort rejected")
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.paused = true
	game.sim_clock.tick = 600
	game.passenger_demand.reset_total("a", 0, 600)
	add(game.passenger_demand, "a", "b", 7, 60)
	check(game._save_game(4), "game saves aged queues")
	var position: Vector2 = game.train_position
	game.passenger_demand.reset_total("a", 0)
	check(game._load_slot(4) and game.passenger_demand.oldest_seconds("a", 600) == 9.0 and game.train_position == position, "normal load preserves waiting age without moving train")
	check(game._destination_queue_text("a").contains("Oldest wait 9.0s"), "station inspector explains measured wait")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(4)))
	bad = payload.duplicate(true)
	bad.demand.batches.a[0].tick = -1
	check(not game._is_valid_save(bad), "full save validation rejects invalid arrival time")
	payload.version = 29
	payload.demand.erase("batches")
	var old := Migrations.migrate(payload)
	check(old.ok and old.data.version == 30 and old.data.demand.batches.a[0].tick == 600 and game._is_valid_save(old.data), "v29 starts unknown legacy waiting ages at its saved tick")
	check(not payload.demand.has("batches"), "migration does not mutate original save")
	game.queue_free()
	await process_frame
	var baseline := frame_case(30)
	check(baseline.manifest == {"c": 3}, "frame-rate case chooses older riders")
	for fps in [60, 120]: check(frame_case(fps) == baseline, "arrival cohorts/priority match at %d FPS" % fps)
	print("Passenger age: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func frame_case(fps: int) -> Dictionary:
	var demand := Demand.new()
	demand.reset_total("a", 0)
	var clock := Clock.new()
	var manifest: Dictionary = {}
	for frame in range(4 * fps):
		for step in range(clock.advance(1.0 / fps)):
			clock.begin_tick()
			if clock.tick == 60: add(demand, "a", "c", 5, clock.tick)
			elif clock.tick == 120: add(demand, "a", "b", 5, clock.tick)
			elif clock.tick == 180: demand.board("a", ["b", "c"], 3, manifest, clock.tick)
	return {"manifest": manifest, "demand": demand.save_state({}, clock.tick), "tick": clock.tick}
