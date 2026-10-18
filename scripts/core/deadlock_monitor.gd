extends RefCounted
## Confirm cycles only after continuous, actual zero-movement waits. A request
## for track ahead, station dwell or loading is not evidence of a deadlock.
const CONFIRM_TICKS := 180 # Three simulation seconds at 60 Hz.
var cycles: Array = []
var new_cycles: Array = []
var cleared_cycles: Array = []
var _started: Dictionary = {}

func update(blocks: Dictionary, tick: int) -> void:
	var found: Dictionary = {}
	var ids: Array = blocks.keys()
	ids.sort()
	for id in ids:
		var path: Array = []
		var current := int(id)
		while blocks.has(current) and not path.has(current):
			path.append(current)
			current = int(blocks[current])
		if not path.has(current): continue
		var cycle: Array = path.slice(path.find(current))
		cycle.sort()
		if cycle.size() < 2: continue
		found[_key(cycle)] = cycle
	var previous: Dictionary = {}
	for cycle in cycles: previous[_key(cycle)] = cycle
	cycles.clear()
	new_cycles.clear()
	cleared_cycles.clear()
	var keys: Array = found.keys()
	keys.sort()
	for key in keys:
		if not _started.has(key): _started[key] = tick
		if tick - int(_started[key]) < CONFIRM_TICKS: continue
		cycles.append(found[key])
		if not previous.has(key): new_cycles.append(found[key])
	for key in previous:
		if not found.has(key): cleared_cycles.append(previous[key])
	for key in _started.keys():
		if not found.has(key): _started.erase(key)

func contains(id: int) -> bool:
	for cycle in cycles:
		if cycle.has(id): return true
	return false

func reset() -> void:
	cycles.clear()
	new_cycles.clear()
	cleared_cycles.clear()
	_started.clear()

static func _key(ids: Array) -> String:
	var names: PackedStringArray = []
	for id in ids: names.append(str(id))
	return ":".join(names)
