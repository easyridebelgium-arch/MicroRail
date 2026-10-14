extends RefCounted
const TIMBER = preload("res://resources/cargo/timber.tres")
const GOODS = preload("res://resources/cargo/goods.tres")
const DEFINITION = preload("res://resources/industries/factory.tres")
const CELL := Vector2i(23, 24)
var state: Dictionary = defaults()
static func defaults() -> Dictionary:
	return {"definition_version": 1, "installed": false, "input": 0, "output": 0, "progress": 0, "received": 0, "consumed": 0, "produced": 0, "loaded": 0, "sold": 0}
func accept(amount: int) -> int:
	var accepted := mini(amount, DEFINITION.input_capacity - int(state.input))
	state.input += accepted
	state.received += accepted
	return accepted
func take(amount: int) -> int:
	var loaded := mini(amount, int(state.output))
	state.output -= loaded
	state.loaded += loaded
	return loaded
func tick() -> void:
	if not state.installed: return
	if state.input < DEFINITION.input_per_batch or state.output + DEFINITION.output_per_batch > DEFINITION.output_capacity:
		state.progress = 0
		return
	state.progress += 1
	if state.progress < DEFINITION.processing_ticks: return
	state.progress = 0
	state.input -= DEFINITION.input_per_batch
	state.consumed += DEFINITION.input_per_batch
	state.output += DEFINITION.output_per_batch
	state.produced += DEFINITION.output_per_batch
func summary() -> String:
	return "Factory: %s\nRecipe: %d timber → %d goods every %.1f simulation seconds\nInput: %d / %d timber; output: %d / %d goods\nProcessing: %d / %d ticks\nReceived %d timber; consumed %d; produced %d goods; loaded %d; delivered %d\nGoods sell for £%d at the terminal. Timber unloaded here do not pay. Storage stalls processing without discarding cargo." % ["operating" if state.installed else "not installed", DEFINITION.input_per_batch, DEFINITION.output_per_batch, DEFINITION.processing_ticks / 60.0, state.input, DEFINITION.input_capacity, state.output, DEFINITION.output_capacity, state.progress, DEFINITION.processing_ticks, state.received, state.consumed, state.produced, state.loaded, state.sold, GOODS.terminal_price]
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
	if value.definition_version != DEFINITION.schema_version or value.input > DEFINITION.input_capacity or value.output > DEFINITION.output_capacity or value.progress >= DEFINITION.processing_ticks: return false
	if value.progress > 0 and (value.input < DEFINITION.input_per_batch or value.output + DEFINITION.output_per_batch > DEFINITION.output_capacity): return false
	if value.received != value.input + value.consumed or value.produced != value.output + value.loaded or value.loaded < value.sold: return false
	if value.consumed * DEFINITION.output_per_batch != value.produced * DEFINITION.input_per_batch: return false
	if not value.installed:
		for key in value:
			if key not in ["installed", "definition_version"] and value[key] != 0: return false
	return true

static func valid_game(data: Dictionary, positions: Dictionary = {}) -> bool:
	if not valid(data.get("factory")): return false
	var stock: Dictionary = data.factory
	if not stock.installed: return int(data.freight.chain_stage) < 2
	if not data.sawmill.installed: return false
	if stock.loaded != stock.sold + (int(data.freight.cargo) if int(data.freight.chain_stage) == 2 else 0): return false
	var loading_cell: Vector2i = positions.get("factory", CELL)
	# Factory loading track must remain on the saved physical route and directive.
	var count := 0
	for point in data.runtime.freight_cells:
		if point[0] == loading_cell.x and point[1] == loading_cell.y: count += 1
	if count != 1: return false
	count = 0
	for point in data.services.freight.get("waypoints", {}).get("forest>terminal", []):
		if point[0] == loading_cell.x and point[1] == loading_cell.y: count += 1
	if count != 1: return false
	for entry in data.tracks:
		if entry[0] == loading_cell.x and entry[1] == loading_cell.y: return typeof(entry[2]) == TYPE_BOOL and entry[2] == false
	return false
