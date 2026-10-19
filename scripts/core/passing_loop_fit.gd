extends RefCounted
## Read-only local clearance at both red-signal holding points, using runtime geometry.
const Template = preload("res://scripts/core/passing_loop_template.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const Router = preload("res://scripts/rail_router.gd")
const Reservations = preload("res://scripts/core/track_reservations.gd")
const Signals = preload("res://scripts/core/block_signals.gd")
const Fleet = preload("res://scripts/fleet.gd")
const ALLOWANCE := 2.0

static func inspect(anchor: Vector2i, length: int, orientation: int, tracks: Dictionary, signs: Dictionary, fleet: Dictionary, tile_size: float) -> Dictionary:
	var design := Template.design(length, orientation)
	if design.is_empty() or tile_size <= 0: return {"ok": false, "message": "Choose a valid passing-loop preview first."}
	var expected: Dictionary = {}
	var expected_signs: Dictionary = {}
	var origin := anchor + Template.footprint_offset(orientation)
	for row in design.tiles: expected[origin + Vector2i(row[0], row[1])] = row[2]
	for row in design.signals: expected_signs[origin + Vector2i(row[0], row[1])] = row[2]
	for cell in expected:
		if typeof(tracks.get(cell)) != typeof(expected[cell]) or tracks.get(cell) != expected[cell] or signs.get(cell) != expected_signs.get(cell):
			return {"ok": false, "message": "Last loop preview has been edited. Fit unavailable: discard and place a fresh template to measure its holding points."}
	var main := _branch(anchor, length, orientation, false, tile_size)
	var loop := _branch(anchor, length, orientation, true, tile_size)
	var rows: Array = []
	var measured: Dictionary = {}
	for train in fleet.get("trains", []):
		var body := Fleet.length(train)
		if not measured.has(body): measured[body] = {"main": _fits(main, body, tile_size), "loop": _fits(loop, body, tile_size)}
		rows.append({"id": int(train.id), "name": str(train.name), "length": body, "stored": str(train.service).is_empty(), "main": measured[body].main, "loop": measured[body].loop})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return {"ok": true, "main_span": main.span, "loop_span": loop.span, "trains": rows, "tile_size": tile_size}

static func describe(result: Dictionary) -> String:
	if not result.ok: return str(result.message)
	var tile_size: float = float(result.get("tile_size", 32.0))
	var lines: PackedStringArray = ["Last loop preview — measured train fit", "Inner holding spans: main %.1f tiles; loop %.1f tiles." % [result.main_span / tile_size, result.loop_span / tile_size], "Checks the whole body at both red-signal stops, clear of both signals and switches, with a small planning allowance."]
	if result.trains.is_empty(): lines.append("No owned trains to compare. Buy a train or add carriages, then review this preview again.")
	for train in result.trains:
		lines.append("#%d %s%s — %.1f tiles: main %s; loop %s." % [train.id, train.name, " (stored)" if train.stored else "", train.length / tile_size, "fits" if train.main else "TOO SHORT", "fits" if train.loop else "TOO SHORT"])
	lines.append("If too short: choose a longer loop or shorten the consist, then discard and preview again. Local geometry only: not route assignment, block isolation or a deadlock guarantee. Apply still checks cost and current reservations.")
	return "\n".join(lines)

static func _branch(anchor: Vector2i, length: int, orientation: int, detour: bool, tile_size: float) -> Dictionary:
	var canonical: Array[Vector2i] = [Vector2i(-1, 0), Vector2i.ZERO]
	if detour:
		for y in [1, 2, 3]: canonical.append(Vector2i(0, y))
		for x in range(1, length): canonical.append(Vector2i(x, 3))
		for y in [2, 1, 0]: canonical.append(Vector2i(length - 1, y))
	else:
		for x in range(1, length): canonical.append(Vector2i(x, 0))
	canonical.append(Vector2i(length, 0))
	var cells: Array[Vector2i] = []
	for cell in canonical: cells.append(anchor + Template.transform(cell, orientation))
	var path := Router.make_path(cells, tile_size)
	var entrance := anchor + Template.transform(Vector2i(0, 2) if detour else Vector2i(1, 0), orientation)
	var exit_cell := anchor + Template.transform(Vector2i(length - 1, 2) if detour else Vector2i(length - 2, 0), orientation)
	var first_index := cells.find(entrance)
	var last_index := cells.find(exit_cell)
	var interior: Dictionary = {}
	for index in range(first_index + 1, last_index): interior[cells[index]] = true
	var helper := Reservations.new()
	var spans := helper._route_spans(path, cells, tile_size)
	var low := 0.0
	var high := path.get_baked_length()
	for span in spans:
		if span[1] == first_index + 1: low = span[0]
		if span[1] == last_index: high = span[0]
	var middle := (low + high) * 0.5
	var stops: Array = []
	# Measure the leading single-vehicle pose at each red signal, using the same
	# limiter as actual movement. Longer consists offset their centre behind it.
	for direction in [1, -1]:
		var boundary: Vector2i = exit_cell if direction == 1 else entrance
		var train := {"id": 1, "cells": cells, "path": path, "distance": middle, "forward": direction == 1, "moving": true, "length": Reservations.VEHICLE_LENGTH}
		var signals := Signals.new()
		var local_tracks: Dictionary = {}
		# Block construction only needs valid connectivity; authority is irrelevant
		# because the chosen downstream boundary is explicitly held red.
		for index in range(1, cells.size() - 1): local_tracks[cells[index]] = Geometry.from_ports(cells[index - 1] - cells[index], cells[index + 1] - cells[index])
		signals.configure(local_tracks, {boundary: "stop"})
		signals.update([train], {}, tile_size)
		var limit := signals.limit(train, path.get_baked_length() if direction == 1 else 0.0, tile_size)
		stops.append({"distance": float(limit.distance) - direction * ALLOWANCE, "direction": direction, "held": not limit.conflict.is_empty()})
	return {"path": path, "interior": interior, "stops": stops, "span": high - low}

static func _fits(branch: Dictionary, body: float, tile_size: float) -> bool:
	var helper := Reservations.new()
	for stop in branch.stops:
		if not stop.held: return false
		var centre: float = stop.distance - stop.direction * maxf(0.0, (body - Reservations.VEHICLE_LENGTH) * 0.5)
		for cell in helper.footprint(branch.path, centre, tile_size, body):
			if not branch.interior.has(cell): return false
	return true
