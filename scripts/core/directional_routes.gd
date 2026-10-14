extends RefCounted
## Check only the retained path between the current position and next destination.
## Cache occurrence spans so repeated tiles on later legs stay distinct.
const Runtime = preload("res://scripts/core/runtime_routes.gd")
const Reservations = preload("res://scripts/core/track_reservations.gd")
var _helper = Reservations.new()
var _path_id := 0
var _cells_hash := 0
var _spans: Array = []
var _last_key: Array = []
var _last_result := false

func is_clear(cells: Array[Vector2i], path: Curve2D, current: float, target: float, tracks: Dictionary, tile_size: float, station_catalog: Dictionary = preload("res://scripts/service_routes.gd").STATIONS) -> bool:
	if cells.is_empty() or path.point_count < 2: return false
	var cells_hash := cells.hash()
	if _path_id != path.get_instance_id() or _cells_hash != cells_hash:
		_path_id = path.get_instance_id()
		_cells_hash = cells_hash
		_spans = _helper._route_spans(path, cells, tile_size)
		_last_key.clear()
	var first := _helper._index_at(_spans, current)
	var last := _helper._index_at(_spans, target)
	var key: Array = [first, last, tracks.hash(), station_catalog.hash()]
	if key == _last_key: return _last_result
	_last_key = key
	var section: Array[Vector2i] = cells.slice(mini(first, last), maxi(first, last) + 1)
	_last_result = tracks.has(section[0]) if section.size() == 1 else Runtime.connected(section, tracks, station_catalog)
	return _last_result
