extends SceneTree
const Routes = preload("res://scripts/service_routes.gd")
const Runtime = preload("res://scripts/core/runtime_routes.gd")
const Demand = preload("res://scripts/core/passenger_demand.gd")
const Rng = preload("res://scripts/core/sim_rng.gd")
const Travel = preload("res://scripts/core/directional_routes.gd")
const Passenger = preload("res://scripts/passenger_service.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var catalog := {
		"delta": {"name": "Delta", "cell": Vector2i(6, 12)},
		"echo": {"name": "Echo", "cell": Vector2i(12, 12)},
		"foxtrot": {"name": "Foxtrot", "cell": Vector2i(18, 12)},
		"golf": {"name": "Golf", "cell": Vector2i(24, 12)}
	}
	var tracks: Dictionary = {}
	for x in range(6, 25): tracks[Vector2i(x, 12)] = false
	for x in range(6, 13): tracks[Vector2i(x, 13)] = false
	var config: Dictionary = Routes.defaults()
	config.passenger.stops = ["delta", "echo", "foxtrot", "golf"]
	check(Routes.is_valid(config, catalog) and not Routes.is_valid(config), "four unfamiliar stops validate only in explicit catalog")
	var built: Dictionary = Routes.build(tracks, config.passenger.stops, 32.0, {}, "shuttle", {}, catalog)
	check(built.cells.size() == 19 and built.distances.size() == 4 and built.error.is_empty(), "four-stop route follows relocated physical track")
	check(Routes.stop_cell({"delta": 2}, "delta", catalog) == Vector2i(6, 13), "platform offset uses provided station position")
	var siding: Dictionary = Routes.build(tracks, ["delta", "echo"], 32.0, {}, "shuttle", {"delta": 2, "echo": 2}, catalog)
	check(siding.cells[0] == Vector2i(6, 13) and siding.cells[-1] == Vector2i(12, 13), "platform path uses catalog geometry")
	check(Runtime.passenger_path(built.cells, config.passenger.stops, 32.0, {}, "shuttle", {}, catalog).distances == built.distances, "retained path reconstructs custom stop distances")
	check(Runtime.passenger_path(built.cells, config.passenger.stops, 32.0).is_empty(), "retained custom route cannot validate against tutorial defaults")
	var unknown: Dictionary = Routes.build(tracks, ["delta", "missing"], 32.0, {}, "shuttle", {}, catalog)
	check(unknown.cells.is_empty() and unknown.error.contains("Unknown station"), "unknown stops return a diagnostic instead of script failure")
	var loop: Dictionary = Routes.build(tracks, ["delta", "golf"], 32.0, {}, "loop", {}, catalog)
	check(loop.cells[0] == loop.cells[-1] and Runtime.connected(loop.cells, tracks, catalog), "planned reversal at unfamiliar terminal is recognised")
	check(not Runtime.connected(loop.cells, tracks), "catalog does not silently grant reversal at non-tutorial location")
	var travel := Travel.new()
	check(travel.is_clear(loop.cells, loop.path, 0.0, loop.path.get_baked_length(), tracks, 32.0, catalog), "directional validation uses custom reversal stops")
	check(not travel.is_clear(loop.cells, loop.path, 0.0, loop.path.get_baked_length(), tracks, 32.0), "cached directional result changes with catalog")
	var directive: Dictionary = config.passenger.duplicate(true)
	directive.waypoints = {"delta>echo": [[12, 12]]}
	check(not Routes.valid_waypoints(directive, catalog), "new station tile cannot masquerade as pass-through waypoint")
	directive.waypoints = {"delta>echo": [[4, 8]]}
	check(Routes.valid_waypoints(directive, catalog), "unused former tutorial station tile is no longer protected by default")
	var missing_track: Dictionary = tracks.duplicate()
	missing_track.erase(Vector2i(15, 12))
	check(Routes.build(missing_track, config.passenger.stops, 32.0, {}, "shuttle", {}, catalog).error.contains("Echo"), "missing-path error uses current station names")
	var demand := Demand.new(["golf", "delta", "foxtrot", "echo"])
	check(demand.station_ids == ["delta", "echo", "foxtrot", "golf"] and demand.waiting("delta") == 8 and not demand.queues.has("a"), "queues belong to instance catalog with deterministic ID order")
	for id in demand.station_ids: demand.reset_total(id, 0)
	var rng := Rng.new(42)
	check(demand.generate("delta", 10, 5, rng, 60) == 5 and demand.waiting("delta") == 5, "custom arrivals honour queue capacity")
	check(demand.queues.delta.keys().all(func(id: String) -> bool: return catalog.has(id) and id != "delta"), "arrivals use only catalog destinations")
	var manifest: Dictionary = {}
	check(demand.board("delta", ["echo", "foxtrot", "golf"], 3, manifest, 120) == 3 and Demand.total(manifest) == 3, "custom queues board eligible passengers within capacity")
	var journeys: Array = demand.last_journeys.duplicate(true)
	var saved: Dictionary = demand.save_state(manifest, 120)
	var aggregates: Dictionary = {"passengers_on_train": 3}
	for id in demand.station_ids: aggregates["waiting_at_" + id] = demand.waiting(id)
	check(Demand.valid_state(saved, aggregates, config.passenger, 120, demand.station_ids) and not Demand.valid_state(saved, aggregates, config.passenger, 120), "queue/batch validation follows supplied identities")
	check(Demand.valid_state(saved, {"passengers_on_train": 3}, config.passenger, 120, demand.station_ids), "custom queues do not require invented legacy waiting counters")
	var restored := Demand.new()
	restored.restore_state(JSON.parse_string(JSON.stringify(saved)), demand.station_ids)
	check(restored.save_state(manifest, 120) == saved and not restored.queues.has("a"), "JSON restore changes instance catalog without phantom tutorial queues")
	var before := Demand.total(manifest) + demand.waiting("delta")
	demand.return_to("delta", manifest, 150, journeys)
	check(manifest.is_empty() and demand.waiting("delta") == before and demand.waiting_groups("delta", 150).all(func(row: Dictionary) -> bool: return row.origin == "delta" and row.start == 60), "recovery preserves custom journey origins and counts")
	var bad: Dictionary = saved.duplicate(true)
	bad.queues.delta["a"] = 1
	check(not Demand.valid_state(bad, aggregates, config.passenger, 120, demand.station_ids), "foreign destinations rejected")
	check(not Demand.valid_batches(saved.batches, saved.queues, 120, ["delta", "delta"]), "duplicate station IDs rejected")
	var single := Demand.new(["delta"])
	var rng_before: Dictionary = rng.save_state()
	check(single.waiting("delta") == 0 and single.generate("delta", 5, 100, rng, 0) == 0 and rng.save_state() == rng_before, "one station generates no impossible trips or random draws")
	var reordered := Demand.new(["echo", "foxtrot", "delta", "golf"])
	var ordered := Demand.new(["delta", "echo", "foxtrot", "golf"])
	var rng_a := Rng.new(99)
	var rng_b := Rng.new(99)
	for tick in range(1, 20):
		reordered.generate("delta", 2, 100, rng_a, tick)
		ordered.generate("delta", 2, 100, rng_b, tick)
	check(reordered.save_state({}, 20) == ordered.save_state({}, 20) and rng_a.save_state() == rng_b.save_state(), "catalog insertion order cannot change seeded arrivals or RNG stream")
	var ordinary := Demand.new()
	check(ordinary.waiting("a") == 8 and Routes.STATIONS.a.cell == Vector2i(4, 8), "other instances and tutorial defaults remain isolated")
	var train := Passenger.new()
	train.configuration = config.passenger.duplicate(true)
	train.cells = built.cells
	train.path = built.path
	train.distances.assign(built.distances)
	var state: Dictionary = train.save_state()
	check(Passenger.from_save("passenger_1", state, config.passenger, 20, catalog) != null and Passenger.from_save("passenger_1", state, config.passenger, 20) == null, "extra-train save validates physical custom stop catalog")
	print("Catalog routes/demand: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
