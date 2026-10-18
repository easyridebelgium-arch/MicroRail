extends RefCounted
## Read-only preview against retained runtime paths; never requests authority.
const Directional = preload("res://scripts/core/directional_routes.gd")
const Runtime = preload("res://scripts/core/runtime_routes.gd")

var _guards: Dictionary = {}

func analyze(tracks: Dictionary, changes: Dictionary, trains: Array, owners: Dictionary, tile_size: float) -> Dictionary:
	var proposed := tracks.duplicate()
	var changed: Dictionary = {}
	var blocked: Dictionary = {}
	for cell in changes:
		if tracks.has(cell) and typeof(tracks[cell]) == typeof(changes[cell]) and tracks[cell] == changes[cell]: continue
		changed[cell] = changes[cell]
		if owners.has(cell): blocked[cell] = owners[cell]
		if changes[cell] == null: proposed.erase(cell)
		else: proposed[cell] = changes[cell]
	var live_ids: Dictionary = {}
	for train in trains: live_ids[train.id] = true
	for id in _guards.keys():
		if not live_ids.has(id): _guards.erase(id)
	var affected: Array = []
	for train in trains:
		var cells: Array[Vector2i] = train.cells
		var touched := false
		for cell in cells:
			if changed.has(cell):
				touched = true
				break
		if not touched: continue
		if not _guards.has(train.id): _guards[train.id] = Directional.new()
		var guard = _guards[train.id]
		var before: bool = guard.is_clear(cells, train.path, train.distance, train.target, tracks, tile_size)
		var after: bool = guard.is_clear(cells, train.path, train.distance, train.target, proposed, tile_size)
		var effect := "Route track edited; current leg remains clear"
		if before and not after: effect = "Breaks current leg; train will stop in place"
		elif not before and after: effect = "Restores current leg"
		elif not after: effect = "Current leg remains incomplete"
		elif not Runtime.connected(cells, proposed): effect = "Current leg clear; a later leg remains incomplete"
		affected.append({"key": train.key, "id": train.id, "name": train.name, "effect": effect})
	return {"affected": affected, "blocked": blocked}
