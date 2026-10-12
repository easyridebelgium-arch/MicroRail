extends RefCounted
## Formal platform measurement. A stop's platform is the continuous run of
## straight horizontal, signal-free track through its stop tile; trains stop
## centred on that tile. Laying more straight track lengthens the platform, so
## no extra building tool is needed. Pure data: no scene or save state.
const Consists = preload("res://scripts/core/consists.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const Reservations = preload("res://scripts/core/track_reservations.gd")

## Returns {cell, left, right, tiles, length}. `left`/`right` count whole tiles
## beyond the stop tile on each side; a stop on non-straight track has none.
static func measure(tracks: Dictionary, signs: Dictionary, stop: Vector2i, tile_size: float) -> Dictionary:
	var result := {"cell": stop, "left": 0, "right": 0, "tiles": 0, "length": 0.0}
	if not _usable(tracks, signs, stop): return result
	var left := 0
	while _usable(tracks, signs, stop + Vector2i(-(left + 1), 0)): left += 1
	var right := 0
	while _usable(tracks, signs, stop + Vector2i(right + 1, 0)): right += 1
	result.left = left
	result.right = right
	result.tiles = left + right + 1
	result.length = float(result.tiles) * tile_size
	return result

## Whole tiles needed each side of the stop tile for a train of `body` pixels,
## matching the reservation footprint (half the body plus its 0.5 px margin).
static func side_tiles_needed(body: float, tile_size: float) -> int:
	return maxi(0, ceili((body * 0.5 + 0.5 - tile_size * 0.5) / tile_size))

static func fits(platform: Dictionary, body: float, tile_size: float) -> bool:
	if int(platform.tiles) <= 0: return false
	var needed := side_tiles_needed(body, tile_size)
	return int(platform.left) >= needed and int(platform.right) >= needed

## Longest train, in pixels, that stops centred on this platform.
static func longest_body(platform: Dictionary, tile_size: float) -> float:
	if int(platform.tiles) <= 0: return 0.0
	return tile_size * float(2 * mini(int(platform.left), int(platform.right)) + 1) - 1.0

## Most attached vehicles the platform accepts (0 means the locomotive alone).
static func max_wagons(platform: Dictionary, tile_size: float) -> int:
	var result := -1
	for count in range(Consists.MAX_WAGONS + 1):
		var wagons: Array = []
		wagons.resize(count)
		if fits(platform, Consists.length({"wagons": wagons}), tile_size): result = count
	return result

static func describe(platform: Dictionary, tile_size: float) -> String:
	if int(platform.tiles) <= 0: return "Platform: no straight signal-free track at the stop"
	var most := max_wagons(platform, tile_size)
	var fit := "no train fits" if most < 0 else ("locomotive only" if most == 0 else "locomotive + %d vehicle%s" % [most, "" if most == 1 else "s"])
	return "Platform: %d tiles (%.0f px), fits %s" % [int(platform.tiles), float(platform.length), fit]

## Platform numbers are tied to the row offset from the station's stop tile, so
## they never renumber when another siding appears: 1 = the stop tile's own
## track, 2 = the row below it, 3 = the row above it.
const ROW_OFFSETS: Array[int] = [0, 1, -1]

static func number_for_offset(offset: int) -> int:
	return ROW_OFFSETS.find(offset) + 1

## Every platform of a station: its own track plus any straight signal-free
## siding on a neighbouring row through the same column. Returns dictionaries
## from `measure` plus `id` ("<station>/<number>"), `number` and `offset`,
## ordered by number.
static func for_station(tracks: Dictionary, signs: Dictionary, key: String, stop: Vector2i, tile_size: float) -> Array:
	var result: Array = []
	for offset in ROW_OFFSETS:
		var platform := measure(tracks, signs, stop + Vector2i(0, offset), tile_size)
		if int(platform.tiles) <= 0: continue
		platform["offset"] = offset
		platform["number"] = number_for_offset(offset)
		platform["id"] = "%s/%d" % [key, platform.number]
		result.append(platform)
	return result

## Basic assignment: the lowest-numbered platform that fits the whole train and
## is not in `busy` (platform IDs). Returns the platform ID, or "" if none.
static func assign(platforms: Array, body: float, tile_size: float, busy: Dictionary = {}) -> String:
	for platform in platforms:
		if busy.has(platform.id): continue
		if fits(platform, body, tile_size): return str(platform.id)
	return ""

static func _usable(tracks: Dictionary, signs: Dictionary, cell: Vector2i) -> bool:
	return tracks.has(cell) and not signs.has(cell) and Geometry.same_connections(tracks[cell], false)
