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

var _risk_key: Array = []
var _risks := PackedStringArray()
## Conservative structural facts, not a traffic prediction. Cache by geometry
## and retained route cells; opening the overlay never runs a simulation.
func structural(tracks: Dictionary, trains: Array) -> PackedStringArray:
	var signature: Array = [tracks.hash()]
	for train in trains: signature.append([train.id, train.cells.hash()])
	if signature == _risk_key: return _risks
	_risk_key = signature
	_risks = []
	var geometry = preload("res://scripts/track_geometry.gd")
	for a in range(trains.size()):
		if not Runtime.connected(trains[a].cells, tracks): continue
		var first: Dictionary = {}
		for cell in trains[a].cells: first[cell] = true
		for b in range(a + 1, trains.size()):
			if not Runtime.connected(trains[b].cells, tracks): continue
			var shared: Dictionary = {}
			for cell in trains[b].cells:
				if first.has(cell) and geometry.connections(tracks.get(cell)).size() == 2: shared[cell] = true
			var longest: Array[Vector2i] = []
			while not shared.is_empty():
				var pending: Array[Vector2i] = [shared.keys()[0]]
				shared.erase(pending[0])
				var index := 0
				while index < pending.size():
					var cell := pending[index]
					index += 1
					for port in geometry.connections(tracks[cell]):
						var next: Vector2i = cell + port
						if shared.has(next) and geometry.connections(tracks[next]).has(-port):
							shared.erase(next)
							pending.append(next)
				if pending.size() > longest.size(): longest = pending
			if longest.size() >= 4:
				_risks.append("Layout review: #%d and #%d share an unbranched run of %d tiles near %d,%d. Review passing places and approach signals. This identifies shared infrastructure, not a forecast or proof of deadlock." % [trains[a].id, trains[b].id, longest.size(), longest[0].x, longest[0].y])
	return _risks
