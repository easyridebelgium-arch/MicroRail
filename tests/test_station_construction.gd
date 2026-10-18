extends SceneTree
const Construction = preload("res://scripts/core/station_construction.gd")
const Generator = preload("res://scripts/core/world_generator.gd")
const World = preload("res://scripts/core/world_catalog.gd")
const Platforms = preload("res://scripts/core/platforms.gd")
const Services = preload("res://scripts/service_routes.gd")
const Demand = preload("res://scripts/core/passenger_demand.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var generated := Generator.generate("42", 3)
	var world: Dictionary = generated.world
	var stop := Vector2i(generated.planning.station_candidates[0].cell[0], generated.planning.station_candidates[0].cell[1])
	var town_id: String = world.settlements[0].id
	var tracks: Dictionary = {}
	var quoted := Construction.preview(world, stop, tracks, {}, {}, 1000)
	check(quoted.ok and quoted.settlement_id == town_id and quoted.cost == {"station": 250, "track": 50, "total": 300}, "preview links a nearby city and itemizes five new platform tiles")
	check(quoted.platform_cells.size() == 5 and quoted.building_cells.size() == 6 and world.facilities.size() == 4 and tracks.is_empty(), "preview does not build, charge or mutate geometry")
	var pending := Construction.draft(world, stop, tracks, {}, {}, 1000)
	var bought := Construction.purchase(pending, world, tracks, {}, {}, 1000)
	check(bought.ok and bought.money == 700 and bought.spent == 300 and bought.tracks.size() == 5, "purchase returns matching geometry and balance snapshots")
	check(world.facilities.size() == 4 and tracks.is_empty(), "purchase cannot partially mutate caller state")
	check(World.valid(bought.world) and Construction.valid_links(bought.world) and bought.world.facilities[-1].settlement_id == town_id, "built station has valid stable city identity")
	var platform := Platforms.measure(bought.tracks, {}, stop, 32)
	check(platform.tiles == 5 and Platforms.max_wagons(platform, 32) == 4, "initial centered platform fits the existing maximum consist")
	check(bought.catchments[town_id] == quoted.stop_id and bought.catchments.values().count("") == 2, "only the linked city gains station access")
	check(not Construction.preview(bought.world, stop + Vector2i(0, 1), bought.tracks, {}, {}, 1000).ok, "second station cannot duplicate the same city's passengers")
	check(not Construction.preview(World.tutorial(), stop, {}, {}, {}, 1000).ok, "tutorial does not acquire unsupported construction")
	var unsupported: Dictionary = world.duplicate(true)
	unsupported["size"] = [100, 50]
	check(not Construction.preview(unsupported, stop, {}, {}, {}, 1000).ok, "unsupported map size does not silently reuse the current placement profile")
	unsupported = world.duplicate(true)
	unsupported.settlements.resize(2)
	check(not Construction.preview(unsupported, stop, {}, {}, {}, 1000).ok, "unsupported city density needs a new profile contract")
	var missing := Construction.preview(world, Vector2i(78, 49), {}, {}, {}, 1000)
	check(not missing.ok and missing.message.contains("outside"), "whole platform footprint must remain in bounds")
	missing = Construction.preview(world, Vector2i(77, 32), {}, {}, {}, 1000)
	check(not missing.ok and missing.message.contains("within 6"), "freestanding station outside catchment rejected")
	var city := Vector2i(world.settlements[0].cell[0], world.settlements[0].cell[1])
	missing = Construction.preview(world, city, {}, {}, {}, 1000)
	check(not missing.ok and missing.message.contains("city buildings"), "platform cannot cut through the city")
	for bad_kind in [true, "NE", "junction_6_2_0", "cross_0_2"]:
		check(not Construction.preview(world, stop, {stop: bad_kind}, {}, {}, 1000).ok, "incompatible track is never replaced")
	var reused := {stop: "rail_2_6", stop + Vector2i(1, 0): false}
	quoted = Construction.preview(world, stop, reused, {}, {}, 1000)
	var reused_draft := Construction.draft(world, stop, reused, {}, {}, 1000)
	bought = Construction.purchase(reused_draft, world, reused, {}, {}, 1000)
	check(quoted.ok and quoted.cost.track == 30 and bought.spent == 280 and bought.tracks[stop] == "rail_2_6", "compatible existing track is reused without extra charge or representation changes")
	var building_tile: Vector2i = pending.building_cells[0]
	missing = Construction.preview(world, stop, {building_tile: false}, {}, {}, 1000)
	check(not missing.ok and missing.message.contains("cover track"), "building cannot cover existing rail")
	for blocked_cell in [stop, stop + Vector2i(2, 0), building_tile]:
		missing = Construction.preview(world, stop, {}, {}, {blocked_cell: 7}, 1000)
		check(not missing.ok and missing.message.contains("train #7"), "train occupancy and authority protect the complete footprint")
		check(not Construction.preview(world, stop, {}, {blocked_cell: "stop"}, {}, 1000).ok, "signals on any footprint tile need explicit removal")
	check(not Construction.preview(world, stop, {}, {}, {}, 299).ok and Construction.preview(world, stop, {}, {}, {}, 300).ok, "exact affordability boundary")
	var rejected := Construction.purchase(pending, world, {}, {}, {}, 299)
	check(not rejected.ok and not rejected.has("world") and not rejected.has("money"), "funds are rechecked on purchase without a partial charge")
	rejected = Construction.purchase(pending, world, {}, {}, {stop: 5}, 1000)
	check(not rejected.ok and rejected.message.contains("train #5"), "new train claims invalidate a previously clear preview")
	rejected = Construction.purchase(pending, world, {stop: false}, {}, {}, 1000)
	check(not rejected.ok and rejected.message.contains("changed"), "intervening platform edits require a fresh quote")
	rejected = Construction.purchase(pending, world, {}, {stop: "auto"}, {}, 1000)
	check(not rejected.ok and rejected.message.contains("changed"), "intervening signal edits cannot be overwritten")
	var changed_world: Dictionary = world.duplicate(true)
	changed_world.settlements[0].name = "Renamed City"
	check(not Construction.purchase(pending, changed_world, {}, {}, {}, 1000).ok, "city/catalog changes invalidate the draft")
	var tampered := pending.duplicate(true)
	tampered.cost.total = 0
	tampered.stop_id = "free_station"
	tampered.name = "Fake"
	bought = Construction.purchase(tampered, world, {}, {}, {}, 1000)
	check(bought.ok and bought.spent == 300 and bought.station_id == "station:" + pending.stop_id, "purchase recomputes price and identity instead of trusting draft metadata")
	check(not Construction.purchase({}, world, {}, {}, {}, 1000).ok, "missing draft fails cleanly")
	var other_tracks := {Vector2i(79, 49): true}
	bought = Construction.purchase(pending, world, other_tracks, {}, {}, 1000)
	check(bought.ok and bought.tracks[Vector2i(79, 49)] == true, "unrelated rail edits survive an otherwise fresh purchase")
	# A hand-positioned flat catalog exercises equal-distance allocation and custom routes.
	world = Generator.generate("7", 3).world
	for index in range(3): world.settlements[index].cell = [10 + index * 20, 9]
	var tie_world: Dictionary = world.duplicate(true)
	tie_world.settlements[0].cell = [10, 9]
	tie_world.settlements[1].cell = [18, 9]
	var tie := Construction.preview(tie_world, Vector2i(14, 13), {}, {}, {}, 1000)
	tie_world.settlements.reverse()
	check(tie.ok and tie.settlement_id == "town:01" and Construction.preview(tie_world, Vector2i(14, 13), {}, {}, {}, 1000).settlement_id == tie.settlement_id, "equal-distance catchment tie uses stable town ID independent of row order")
	tracks = {}
	var balance := 1000
	for center in [Vector2i(10, 13), Vector2i(30, 13)]:
		pending = Construction.draft(world, center, tracks, {}, {}, balance)
		bought = Construction.purchase(pending, world, tracks, {}, {}, balance)
		if bought.ok:
			world = bought.world
			tracks = bought.tracks
			balance = bought.money
	check(balance == 400 and world.facilities.size() == 6, "two independent city stations purchase sequentially")
	var catalog := World.new()
	catalog.restore_state(JSON.parse_string(JSON.stringify(world)))
	check(Construction.valid_links(catalog.save_state()) and Construction.catchments(catalog.save_state())["town:03"] == "", "JSON preserves city access while the third city stays unserved")
	for x in range(8, 33): tracks[Vector2i(x, 13)] = false
	var route := Services.build(tracks, ["city_01", "city_02"], 32, {}, "shuttle", {}, catalog.stations())
	check(route.error.is_empty() and route.cells.front() == Vector2i(10, 13) and route.cells.back() == Vector2i(30, 13), "new station identities route through the authoritative graph")
	var demand := Demand.new(catalog.stations().keys(), catalog.stations())
	check(demand.station_ids.size() == 2 and not demand.queues.has("city_03") and demand.waiting("city_01") == 8, "catalog consumers see only constructed stations, never a phantom unserved city queue")
	var duplicate: Dictionary = world.duplicate(true)
	var duplicate_station: Dictionary = duplicate.facilities[-1].duplicate(true)
	duplicate_station.id = "station:duplicate"
	duplicate_station.stop_id = "duplicate"
	duplicate_station.cell = [31, 17]
	duplicate.facilities.append(duplicate_station)
	check(World.valid(duplicate) and not Construction.valid_links(duplicate), "construction link validator rejects duplicate city ownership beyond core catalog checks")
	var corpus_ok := true
	for count in range(3, 9):
		for seed_value in range(8):
			generated = Generator.generate(str(seed_value), count)
			world = generated.world
			tracks = {}
			balance = 10000
			for candidate in generated.planning.station_candidates:
				var center := Vector2i(candidate.cell[0], candidate.cell[1])
				pending = Construction.draft(world, center, tracks, {}, {}, balance)
				bought = Construction.purchase(pending, world, tracks, {}, {}, balance)
				if not bought.ok:
					corpus_ok = false
					continue
				world = bought.world
				tracks = bought.tracks
				balance = bought.money
			corpus_ok = corpus_ok and Construction.valid_links(world) and world.facilities.size() == count + 4 and balance == 10000 - count * 300 and not Construction.catchments(world).values().has("")
	check(corpus_ok, "all 264 proposed stations across 48 seeded maps purchase without overlap, duplicated catchments or accounting loss")
	print("Station construction: %d checks, %d failures (264 placements)" % [checks, failures])
	quit(1 if failures else 0)
