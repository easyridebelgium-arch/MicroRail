extends SceneTree
const Impact = preload("res://scripts/core/construction_impact.gd")
const Router = preload("res://scripts/rail_router.gd")
var impact = Impact.new()
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	var tracks: Dictionary = {}
	var cells: Array[Vector2i] = []
	for x in range(4, 21):
		tracks[Vector2i(x, 8)] = false
		cells.append(Vector2i(x, 8))
	var path := Router.make_path(cells, 32)
	var train := {"key": "passenger", "id": 7, "name": "Test", "cells": cells, "path": path, "distance": 256.0, "target": path.get_baked_length()}
	var original := tracks.duplicate()
	var ahead := impact.analyze(tracks, {Vector2i(18, 8): null}, [train], {}, 32)
	check(ahead.affected.size() == 1 and ahead.affected[0].effect.begins_with("Breaks current"), "gap ahead must warn of a stopped current leg")
	check(tracks == original, "preview must never change the actual network")
	var behind := impact.analyze(tracks, {Vector2i(6, 8): null}, [train], {}, 32)
	check(behind.affected[0].effect.begins_with("Current leg clear"), "gap behind must warn about later travel, not interrupt delivery")
	train.target = 0.0
	check(impact.analyze(tracks, {Vector2i(6, 8): null}, [train], {}, 32).affected[0].effect.begins_with("Breaks current"), "westbound train must treat the same gap as ahead")
	train.target = path.get_baked_length()
	tracks.erase(Vector2i(18, 8))
	check(impact.analyze(tracks, {Vector2i(18, 8): false}, [train], {}, 32).affected[0].effect == "Restores current leg", "repair should recognize the retained missing path")
	tracks[Vector2i(18, 8)] = false
	check(impact.analyze(tracks, {Vector2i(18, 8): true}, [train], {}, 32).affected[0].effect.begins_with("Breaks current"), "incompatible track ports break travel even without demolition")
	check(impact.analyze(tracks, {Vector2i(18, 8): false}, [train], {}, 32).affected.is_empty(), "unchanged track must not count as an edit")
	check(impact.analyze(tracks, {Vector2i(18, 9): false}, [train], {}, 32).affected.is_empty(), "unrelated track must not imply a route change")
	var owned := impact.analyze(tracks, {Vector2i(18, 8): null}, [train], {Vector2i(18, 8): 9}, 32)
	check(owned.blocked[Vector2i(18, 8)] == 9, "preview must report the real reserving train ID")
	var second := train.duplicate()
	second.key = "passenger_4"
	second.id = 12
	second.target = 0.0
	var both := impact.analyze(tracks, {Vector2i(6, 8): null}, [train, second], {}, 32)
	check(both.affected.size() == 2, "shared track edit must list every affected service")
	check(both.affected[0].id == 7 and both.affected[1].id == 12, "permanent train IDs must survive service-key differences")
	check(both.affected[0].effect != both.affected[1].effect, "opposite directions require different impact explanations")
	print("Construction impact: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
