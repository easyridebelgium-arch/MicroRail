extends RefCounted
## Reusable geometry of the passing-loop example; placement uses normal drafts.
const Blueprints = preload("res://scripts/core/track_blueprints.gd")
const WIDTH := 9
const HEIGHT := 4

static func design() -> Dictionary:
	var tiles: Array = []
	for x in range(WIDTH):
		tiles.append([x, 0, "junction_6_2_4" if x == 0 else "junction_2_6_4" if x == WIDTH - 1 else false])
		tiles.append([x, 3, "NE" if x == 0 else "NW" if x == WIDTH - 1 else false])
	for x in [0, WIDTH - 1]:
		for y in [1, 2]: tiles.append([x, y, true])
	return {"version": Blueprints.VERSION, "name": "Guided passing loop", "width": WIDTH, "height": HEIGHT, "tiles": tiles, "signals": [[1, 0, "auto"], [7, 0, "auto"], [0, 2, "auto"], [8, 2, "auto"]]}

static func instructions(anchor: Vector2i) -> String:
	return "Passing-loop draft: switches %d,%d and %d,%d; loop waypoint %d,%d. Review cost, reservations and affected services before Apply plan. Connect the outer switch ends to your line. In Routes, give one service the loop waypoint; leave the other on the main branch. Four automatic signals separate both branches. Keep station approaches outside this footprint. Short template: check that your whole train fits between holding points. This does not automatically choose branches or prevent every deadlock." % [anchor.x, anchor.y, anchor.x + 8, anchor.y, anchor.x + 4, anchor.y + 3]
