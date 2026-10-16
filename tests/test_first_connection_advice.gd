extends SceneTree
const Advice = preload("res://scripts/core/first_connection_advice.gd")
const Generator = preload("res://scripts/core/world_generator.gd")
const Terrain = preload("res://scripts/core/river_terrain.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	var terrain := Terrain.new()
	var world: Dictionary = Generator.generate("42", 4).world
	var before := JSON.stringify(world)
	for profile in Terrain.PROFILES:
		terrain.profile = profile
		var text := Advice.describe(world, terrain, 5000)
		check(text.contains("lower bound") and text.contains("£400 shuttle"), "honest complete startup budget on " + profile)
		check(text == Advice.describe(world, terrain, 5000), "repeatable advice on " + profile)
		check(Advice.describe(world, terrain, 0).contains("below this minimum"), "insufficient money is explicit on " + profile)
		check(JSON.stringify(world) == before, "inspection leaves generated world unchanged")
	# Three separated cities: closest is across the river, distant same-bank
	# alternative makes the water surcharge material to the comparison.
	world.settlements[0].cell = [10, 9]
	world.settlements[1].cell = [10, 23]
	world.settlements[2].cell = [64, 9]
	world.settlements.resize(3)
	terrain.profile = "flat"
	var flat := Advice.describe(world, terrain, 5000)
	terrain.profile = "wide_river_v1"
	var wide := Advice.describe(world, terrain, 5000)
	check(flat.contains("At least £1090") and not flat.contains("Bridge surcharge"), "flat lower bound includes platforms once")
	check(wide.contains("At least £1210") and wide.contains("Bridge surcharge at least £120"), "wide river adds three actual water surcharges")
	check(wide.contains("both banks clear") and wide.contains("not a route quote"), "cross-bank advice explains approach limits")
	terrain.profile = "meander_v1"
	check(Advice.describe(world, terrain, 5000).contains("Bridge surcharge at least £80"), "meander uses two water tiles")
	world.settlements[2].cell = [27, 9]
	terrain.profile = "wide_river_v1"
	var same_bank := Advice.describe(world, terrain, 5000)
	check(same_bank.contains("%s and %s" % [world.settlements[0].name, world.settlements[2].name]) and not same_bank.contains("Bridge surcharge"), "bridge expense can favor a farther same-bank pair")
	print("First connection advice: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
