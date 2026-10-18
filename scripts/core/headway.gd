extends RefCounted
## Headway (the gap between consecutive departures from a service's first
## stop). Pure rules: the game keeps the departure log and calls these.
const MAX_SECONDS := 3600
const KEEP := 24
const TICKS_PER_SECOND := 60

## Ticks still to wait before another departure is allowed (0 = may go).
static func remaining_ticks(last_departure: int, target_seconds: int, tick: int) -> int:
	if target_seconds <= 0 or last_departure < 0: return 0
	return maxi(0, last_departure + target_seconds * TICKS_PER_SECOND - tick)

static func record(departures: Array, tick: int) -> Array:
	var result := departures.duplicate()
	result.append(tick)
	while result.size() > KEEP: result.pop_front()
	return result

## {count, last, average}: intervals in seconds between logged departures.
static func stats(departures: Array) -> Dictionary:
	var result := {"count": departures.size(), "last": 0.0, "average": 0.0}
	if departures.size() < 2: return result
	var total := 0.0
	for index in range(1, departures.size()): total += float(departures[index] - departures[index - 1]) / TICKS_PER_SECOND
	result["average"] = total / float(departures.size() - 1)
	result["last"] = float(departures[-1] - departures[-2]) / TICKS_PER_SECOND
	return result

## Seconds for one train to leave the first stop and be back there ready to
## leave again: out and back (shuttle) or once round (loop), plus every dwell.
static func round_trip(route_length: float, speed: float, stops: int, loop: bool, dwell: float) -> float:
	if speed <= 0.0: return INF
	var travel := route_length / speed * (1.0 if loop else 2.0)
	var visits := stops if loop else maxi(1, 2 * stops - 2)
	return travel + dwell * float(visits)

## Shortest gap `trains` trains can keep on average.
static func minimum_headway(round_trip_seconds: float, trains: int) -> float:
	return round_trip_seconds / float(maxi(1, trains))

## Empty when the target is achievable, otherwise a plain explanation.
static func infeasible_reason(target_seconds: int, round_trip_seconds: float, trains: int) -> String:
	if target_seconds <= 0 or is_inf(round_trip_seconds): return ""
	var minimum := minimum_headway(round_trip_seconds, trains)
	if float(target_seconds) >= minimum - 0.5: return ""
	var needed := ceili(round_trip_seconds / float(target_seconds))
	return "A %d s headway needs about %d trains on this route; %d can manage about %d s." % [target_seconds, needed, trains, ceili(minimum)]
