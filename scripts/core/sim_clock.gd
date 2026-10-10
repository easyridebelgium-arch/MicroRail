extends RefCounted
## Fixed-timestep simulation clock.
##
## Rendering runs at whatever frame rate the machine manages. The simulation
## advances in constant steps, so results never depend on frame rate.
##
## Usage in the main loop:
##     for _i in sim_clock.advance(delta):
##         sim_clock.begin_tick()
##         _simulation_step(SimClock.TICK_SECONDS)

const TICKS_PER_SECOND: int = 60
const TICK_SECONDS: float = 1.0 / float(TICKS_PER_SECOND)

## After a long stall (window drag, debugger pause) drop the backlog instead of
## running hundreds of steps in one frame.
const MAX_STEPS_PER_FRAME: int = 8
const MAX_SPEED: float = 8.0
const MAX_SAVED_TICK: int = 1_000_000_000_000

## Number of simulation steps completed so far. Use it as the game timestamp.
var tick: int = 0

## Simulation speed multiplier. 0 pauses, 1 is normal. Not saved (UI state).
var speed: float = 1.0

var _accumulator: float = 0.0


## Returns how many whole simulation steps to run for this frame.
func advance(frame_delta: float) -> int:
	if frame_delta <= 0.0 or speed <= 0.0:
		return 0

	_accumulator += frame_delta * clampf(speed, 0.0, MAX_SPEED)

	var steps: int = int(_accumulator / TICK_SECONDS)

	if steps > MAX_STEPS_PER_FRAME:
		steps = MAX_STEPS_PER_FRAME
		_accumulator = 0.0
	else:
		_accumulator -= float(steps) * TICK_SECONDS

	return steps


## Call once before each simulation step so events get the right timestamp.
func begin_tick() -> void:
	tick += 1


func elapsed_seconds() -> float:
	return float(tick) * TICK_SECONDS


func reset() -> void:
	tick = 0
	_accumulator = 0.0


func save_state() -> Dictionary:
	return {"tick": tick}


func restore_state(state: Dictionary) -> void:
	tick = int(state["tick"])
	_accumulator = 0.0


static func is_valid_state(state: Variant) -> bool:
	if not state is Dictionary:
		return false

	var value: Variant = state.get("tick")

	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false

	var number: float = float(value)

	if not is_finite(number) or number < 0.0 or number != floor(number):
		return false

	return number <= float(MAX_SAVED_TICK)
