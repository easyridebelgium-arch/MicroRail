extends RefCounted
const LOGS = preload("res://resources/cargo/logs.tres")
const TIMBER = preload("res://resources/cargo/timber.tres")
const DEFINITION = preload("res://resources/industries/sawmill.tres")
const CELL := Vector2i(18, 24)
var state: Dictionary = defaults()
static func defaults() -> Dictionary:
	return {"definition_version": 1, "installed": false, "logs": 0, "timber": 0, "progress": 0, "received": 0, "consumed": 0, "produced": 0, "loaded": 0, "sold": 0}
func accept(amount: int) -> int:
	var accepted := mini(amount, DEFINITION.input_capacity - int(state.logs))
	state.logs += accepted
	state.received += accepted
	return accepted
func take(amount: int) -> int:
	var loaded := mini(amount, int(state.timber))
	state.timber -= loaded
	state.loaded += loaded
	return loaded
func tick() -> void:
	if not state.installed: return
	if state.logs < DEFINITION.input_per_batch or state.timber + DEFINITION.output_per_batch > DEFINITION.output_capacity:
		state.progress = 0
		return
	state.progress += 1
	if state.progress < DEFINITION.processing_ticks: return
	state.progress = 0
	state.logs -= DEFINITION.input_per_batch
	state.consumed += DEFINITION.input_per_batch
	state.timber += DEFINITION.output_per_batch
	state.produced += DEFINITION.output_per_batch
func summary(to_factory: bool = false) -> String:
	var text := "Sawmill: %s\nRecipe: %d logs → %d timber every %.1f simulation seconds\nInput: %d / %d logs; output: %d / %d timber\nProcessing: %d / %d ticks\nReceived %d logs; consumed %d; produced %d timber; loaded %d; delivered %d\nTimber sells for £%d at the terminal. Logs unloaded here do not pay. Storage stalls processing without discarding cargo." % ["operating" if state.installed else "not installed", DEFINITION.input_per_batch, DEFINITION.output_per_batch, DEFINITION.processing_ticks / 60.0, state.logs, DEFINITION.input_capacity, state.timber, DEFINITION.output_capacity, state.progress, DEFINITION.processing_ticks, state.received, state.consumed, state.produced, state.loaded, state.sold, TIMBER.terminal_price]
	return text.replace("Timber sells for £%d at the terminal." % TIMBER.terminal_price, "Timber goes to the factory; intermediate unloading earns no payment.") if to_factory else text
func save_state() -> Dictionary: return state.duplicate(true)
func restore_state(value: Dictionary) -> void:
	state = value.duplicate(true)
	for key in state:
		if key != "installed": state[key] = int(state[key])
static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != defaults().size() or not value.get("installed") is bool: return false
	for key in defaults():
		if key == "installed": continue
		var number: Variant = value.get(key)
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)) or float(number) != floor(float(number)) or number < 0 or number > 1000000000: return false
	if value.definition_version != DEFINITION.schema_version or value.logs > DEFINITION.input_capacity or value.timber > DEFINITION.output_capacity or value.progress >= DEFINITION.processing_ticks: return false
	if value.progress > 0 and (value.logs < DEFINITION.input_per_batch or value.timber + DEFINITION.output_per_batch > DEFINITION.output_capacity): return false
	if value.received != value.logs + value.consumed or value.produced != value.timber + value.loaded or value.loaded < value.sold: return false
	if value.consumed * DEFINITION.output_per_batch != value.produced * DEFINITION.input_per_batch: return false
	if not value.installed:
		for key in value:
			if key not in ["installed", "definition_version"] and value[key] != 0: return false
	return true

static func valid_game(data: Dictionary, positions: Dictionary = {}) -> bool:
	if not valid(data.get("sawmill")): return false
	var stock: Dictionary = data.sawmill
	var freight: Dictionary = data.freight
	var stage: Variant = freight.get("chain_stage")
	if typeof(stage) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(stage)) or float(stage) != floor(float(stage)) or stage < 0 or stage > 2: return false
	if freight.get("recovery_stop") not in ["forest", "sawmill", "factory", "terminal"] or freight.get("leg_origin") not in ["forest", "sawmill", "factory", "terminal"]: return false
	var cargo: Variant = freight.get("cargo")
	if typeof(cargo) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(cargo)) or float(cargo) != floor(float(cargo)) or cargo < 0 or cargo > 1000000000: return false
	if not stock.installed: return stage == 0
	if stock.loaded != stock.sold + int(data.get("factory", {}).get("received", 0)) + (int(cargo) if int(stage) == 1 else 0): return false
	var loading_cell: Vector2i = positions.get("sawmill", CELL)
	var cells: Array = data.runtime.freight_cells
	if count_points(cells, loading_cell) != 1 or count_points(data.services.freight.get("waypoints", {}).get("forest>terminal", []), loading_cell) != 1: return false
	var pad := false
	for entry in data.tracks:
		if entry[0] == loading_cell.x and entry[1] == loading_cell.y: pad = typeof(entry[2]) == TYPE_BOOL and entry[2] == false
	return pad

static func count_points(points: Array, loading_cell: Vector2i = CELL) -> int:
	var count := 0
	for point in points:
		if point is Array and point.size() == 2 and point[0] == loading_cell.x and point[1] == loading_cell.y: count += 1
	return count
