extends SceneTree
const Generator = preload("res://scripts/core/world_generator.gd")
const World = preload("res://scripts/core/world_catalog.gd")
const SimRng = preload("res://scripts/core/sim_rng.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for bad_seed in ["", "01", "-1", "1.5", "9223372036854775808", " 5"]:
		var rejected := Generator.generate(bad_seed)
		check(not rejected.ok and not rejected.has("world") and not rejected.has("rng_state"), "invalid seed rejected atomically")
	for count in [-1, 0, 2, 9, 100]:
		check(not Generator.generate("0", count).ok, "unsupported city density rejected")
	var distinct: Dictionary = {}
	var corpus_ok := true
	var clear_ok := true
	var repeat_ok := true
	for count in range(3, 9):
		for seed_value in range(32):
			var generated := Generator.generate(str(seed_value), count)
			if not generated.ok:
				corpus_ok = false
				continue
			var world: Dictionary = generated.world
			corpus_ok = corpus_ok and World.valid(world) and world.settlements.size() == count and world.facilities.size() == 4
			repeat_ok = repeat_ok and generated == Generator.generate(str(seed_value), count)
			if count == 4: distinct[JSON.stringify(world.settlements)] = true
			# Independently check town separation and the entire future freight strip.
			var claimed: Dictionary = {}
			for town in world.settlements:
				var x: int = town.cell[0]
				var y: int = town.cell[1]
				for tile_y in range(y - 1, y + 6):
					for tile_x in range(x - 4, x + 5):
						var tile := Vector2i(tile_x, tile_y)
						clear_ok = clear_ok and tile_x >= 0 and tile_x < 80 and tile_y >= 0 and tile_y < 50 and not claimed.has(tile)
						claimed[tile] = true
			var start: Array = generated.planning.freight_corridor[0]
			var end: Array = generated.planning.freight_corridor[1]
			for tile_y in range(int(start[1]) - 2, int(start[1]) + 3):
				for tile_x in range(int(start[0]) - 4, int(end[0]) + 5):
					clear_ok = clear_ok and not claimed.has(Vector2i(tile_x, tile_y))
	check(corpus_ok, "192 seed/density cases have requested cities and a valid four-industry catalog")
	check(clear_ok, "all cities, station approaches and future freight/passing strips remain separate and in bounds")
	check(repeat_ok, "same seed and density reproduce geometry, witnesses and RNG continuation across the corpus")
	check(distinct.size() > 24, "different seeds produce varied city layouts")
	var result := Generator.generate("9223372036854775807", 8)
	check(result.ok and result.world.layout_seed == "9223372036854775807", "maximum seed is preserved exactly as text")
	var json: Dictionary = JSON.parse_string(JSON.stringify(result))
	check(Generator.valid_initial(json.world) and SimRng.is_valid_state(json.rng_state), "JSON retains valid geometry and continuation")
	var catalog := World.new()
	catalog.restore_state(json.world)
	check(catalog.save_state() == result.world and catalog.stations().is_empty(), "saved generated geometry restores without creating stations")
	check(catalog.facilities().size() == 2 and catalog.industry_positions().size() == 4, "processors remain unbuilt but retain future sites")
	check(not World.valid_tutorial(result.world, false, false), "generated foundation cannot be mistaken for a playable tutorial save")
	var stream_a := SimRng.new()
	var stream_b := SimRng.new()
	stream_a.restore_state(result.rng_state)
	stream_b.restore_state(json.rng_state)
	var continuation_ok := true
	for index in range(20): continuation_ok = continuation_ok and stream_a.randi() == stream_b.randi()
	check(continuation_ok, "JSON-restored RNG continues the same simulation stream")
	await process_frame
	check(result == Generator.generate("9223372036854775807", 8), "frame passage does not influence generation")
	var copy: Dictionary = result.world.duplicate(true)
	copy.settlements[1].cell = copy.settlements[0].cell.duplicate()
	check(not Generator.valid_initial(copy), "overlapping towns rejected beyond basic catalog validation")
	copy = result.world.duplicate(true)
	copy.settlements[0].cell = [1, 1]
	check(not Generator.valid_initial(copy), "town with out-of-bounds station approaches rejected")
	copy = result.world.duplicate(true)
	copy.settlements[0].cell = copy.facilities[0].cell.duplicate()
	check(not Generator.valid_initial(copy), "town on freight corridor rejected")
	copy = result.world.duplicate(true)
	copy.facilities[1].cell = [copy.facilities[0].cell[0] + 2, copy.facilities[0].cell[1]]
	check(not Generator.valid_initial(copy), "unbuilt processor sites also require clearance")
	copy = result.world.duplicate(true)
	copy.facilities[2].cell[1] += 1
	check(not Generator.valid_initial(copy), "broken freight construction corridor rejected")
	copy = result.world.duplicate(true)
	copy.facilities[1].enabled = true
	check(not Generator.valid_initial(copy), "initial sandbox does not silently buy a processor")
	for field in ["generator_version", "content_version"]:
		copy = result.world.duplicate(true)
		copy[field] += 1
		check(not Generator.valid_initial(copy), "unsupported generation/content contract rejected")
	check(World.valid_tutorial(World.tutorial(), false, false), "existing tutorial remains valid")
	print("World generator: %d checks, %d failures (192 layout cases)" % [checks, failures])
	quit(1 if failures else 0)
