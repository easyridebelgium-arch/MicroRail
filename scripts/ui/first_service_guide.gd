extends RefCounted
## Optional, repeatable assistance. No purchases, route edits or simulation commands.
const Guide = preload("res://scripts/core/first_service.gd")
const Advice = preload("res://scripts/core/first_connection_advice.gd")
const Stations = preload("res://scripts/core/station_construction.gd")
var game: Node
var dialog: AcceptDialog
var heading: Label
var steps: Label
var detail: Label
var action_button: Button
var button: Button
var snapshot: Dictionary = {}
var elapsed := 0.0
var active := false
var was_paused := true
var preview_button: Button
var hide_preview_button: Button
var preview: Dictionary = {}
var preview_source: Array = []

func configure(owner_game: Node) -> void:
	game = owner_game
	dialog = AcceptDialog.new()
	dialog.title = "First service guide"
	dialog.ok_button_text = "Close guide"
	dialog.exclusive = true
	dialog.confirmed.connect(close_guide)
	dialog.canceled.connect(close_guide)
	dialog.close_requested.connect(close_guide)
	dialog.theme = game.game_menu.theme
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 100
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	dialog.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	heading = _label(column)
	steps = _label(column)
	detail = _label(column)
	preview_button = Button.new()
	preview_button.text = "Preview suggested connection on map"
	preview_button.tooltip_text = "Pause and frame a dashed planning guide. Nothing is built or reserved."
	preview_button.pressed.connect(show_preview)
	column.add_child(preview_button)
	action_button = Button.new()
	action_button.pressed.connect(_perform)
	column.add_child(action_button)
	game.get_node("Interface").add_child(dialog)
	button = Button.new()
	button.text = "Guide"
	button.custom_minimum_size = Vector2(96, 40)
	button.icon = preload("res://assets/ui/feedback/icons/first_service_guide.tres")
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 24)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.tooltip_text = "Optional first-service checklist. Available again from the game menu."
	button.pressed.connect(open_guide)
	game.get_node("Interface/ConstructionHistory").add_child(button)
	hide_preview_button = Button.new()
	hide_preview_button.text = "Hide suggestion"
	hide_preview_button.tooltip_text = "Remove the first-connection planning overlay. The game stays paused."
	hide_preview_button.pressed.connect(clear_preview)
	hide_preview_button.hide()
	game.get_node("Interface/ConstructionHistory").add_child(hide_preview_button)
	refresh(0.0, true)

func _label(column: Control) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)
	return label

func open_guide() -> void:
	# Stop costs/time while reading, then restore the prior pause choice on Close.
	# Build/Fleet and Resume actions deliberately choose their own pause state.
	if game.is_dragging or game.right_pending:
		game._show_notice("Finish or cancel the track stroke before opening the guide.")
		return
	if not active:
		was_paused = game.paused
	active = true
	game.paused = true
	refresh(0.0, true)
	dialog.popup_centered_clamped(Vector2i(620, 480), 0.85)
	dialog.get_ok_button().grab_focus()

func close_guide(restore_pause: bool = true) -> void:
	if restore_pause and active: game.paused = was_paused
	active = false
	dialog.hide()
	game._update_toolbar()

func refresh(delta: float, force: bool = false) -> void:
	if not preview.is_empty() and preview_source != _source(): clear_preview()
	elapsed += delta
	if not force and (elapsed < 0.25 or not (dialog.visible or game.objective_panel.visible)): return
	elapsed = 0.0
	snapshot = Guide.inspect(game)
	preview_button.visible = (snapshot.get("shared", false) and not snapshot.complete) or (not snapshot.get("freight", false) and not snapshot.get("shared", false) and snapshot.city_mode and game.station_definitions().is_empty())
	preview_button.text = "Show challenge stations and loop" if snapshot.get("shared", false) else "Preview suggested connection on map"
	var lines: PackedStringArray = []
	for index in range(snapshot.rows.size()):
		var row: Dictionary = snapshot.rows[index]
		lines.append(("[Done] " if row.done else "[Next] " if snapshot.next == index else "[ ] ") + str(row.title))
	heading.text = "First passenger journey complete — %d delivered. Keep improving your railway." % snapshot.delivered if snapshot.delivered > 0 else "Your first city service" if snapshot.city_mode else "Your first tutorial service"
	if snapshot.get("shared", false): heading.text = "Passing Place — shared-track checklist"
	if snapshot.get("freight", false): heading.text = "Timber Connection — freight checklist"
	steps.text = "\n".join(lines)
	detail.text = snapshot.suggestion + "\n\n" + ("These checks describe the current company. You can reopen this guide at any time; it does not reset progress or pay rewards." if snapshot.complete else str(snapshot.rows[snapshot.next].hint))
	if snapshot.get("shared", false) and snapshot.complete: detail.text = snapshot.suggestion + "\n\nChallenge completion is saved. You can change the network or retire services without losing this milestone."
	action_button.visible = not snapshot.complete
	if not snapshot.complete: action_button.text = snapshot.rows[snapshot.next].button

func _source() -> Array:
	return [game.world.state, game.river_terrain.profile, game.tracks, game.track_signals, game.reservations.owners]

func clear_preview() -> void:
	preview.clear()
	preview_source.clear()
	hide_preview_button.hide()
	game.queue_redraw()

func show_preview() -> void:
	if game.is_dragging or game.right_pending or not game.construction_plan.is_empty():
		detail.text = "Finish the stroke and apply or discard the draft before previewing a suggestion."
		return
	if game.seeded_challenge.state.id == "passing_place":
		var shared = preload("res://scripts/core/shared_track_challenge.gd")
		var line: Array[Vector2i] = []
		for x in range(shared.LEFT.x, shared.RIGHT.x + 1): line.append(Vector2i(x, shared.LEFT.y))
		var loop: Array[Vector2i] = [shared.ANCHOR]
		for y in range(15, 18): loop.append(Vector2i(44, y))
		for x in range(45, 53): loop.append(Vector2i(x, 17))
		for y in [16, 15, 14]: loop.append(Vector2i(52, y))
		preview = {"a": shared.LEFT, "b": shared.RIGHT, "cells": line, "loop_cells": loop, "budget": 2040}
		preview_source = _source().duplicate(true)
		close_guide(false)
		game.paused = true
		hide_preview_button.show()
		_frame_preview()
		game._show_notice("Dashed challenge guide only. Original checked setup £2040 including two shuttles; nothing purchased. Use Station, Connect and the loop draft tools to build it.")
		game._update_toolbar()
		game.queue_redraw()
		return
	if not game.city_builder.is_city_game() or not game.station_definitions().is_empty():
		clear_preview()
		refresh(0.0, true)
		return
	var result := Advice.recommend(game.world.state, game.river_terrain, game.tracks, game.track_signals, game.reservations.owners)
	if result.is_empty():
		detail.text = "No validated simple connection found. Other station sites or detours may still work."
		return
	preview = result
	preview_source = _source().duplicate(true)
	close_guide(false)
	game.paused = true
	hide_preview_button.show()
	_frame_preview()
	game._show_notice("Dashed suggestion only — £%d including stations and shuttle. Nothing purchased. Hide suggestion to clear; resume manually when ready." % preview.budget)
	game._update_toolbar()
	game.queue_redraw()

func _frame_preview() -> void:
	var bounds := Rect2(game._cell_center(preview.a), Vector2.ONE)
	for cell in preview.cells: bounds = bounds.expand(game._cell_center(cell))
	bounds = bounds.grow(game.TILE_SIZE * 4.0)
	var view: Rect2 = game.get_viewport_rect()
	var left := 368.0 if game.network_map.visible or game.objective_panel.visible else 24.0
	left = minf(left, view.size.x * 0.45)
	var top: float = minf(game.header_background.offset_bottom + 24.0, view.size.y - 120.0)
	var usable := Rect2(Vector2(left, top), Vector2(maxf(80.0, view.size.x - left - 24.0), maxf(80.0, view.size.y - top - 64.0)))
	var zoom_value: float = minf(1.0 / game.applied_ui_scale, minf(usable.size.x / bounds.size.x, usable.size.y / bounds.size.y))
	game.camera.zoom = Vector2.ONE * zoom_value
	game.camera.position = bounds.get_center() - (usable.get_center() - view.get_center()) / zoom_value
	game.camera.force_update_scroll()

func draw_preview() -> void:
	if preview.is_empty() or preview_source != _source(): return
	var ink := Color(1.0, 0.95, 0.7, 0.9)
	for index in range(1, preview.cells.size()):
		game.draw_dashed_line(game._cell_center(preview.cells[index - 1]), game._cell_center(preview.cells[index]), ink, 2.0, 5.0)
	var loop_cells: Array = preview.get("loop_cells", [])
	for index in range(1, loop_cells.size()):
		game.draw_dashed_line(game._cell_center(loop_cells[index - 1]), game._cell_center(loop_cells[index]), ink, 2.0, 5.0)
	for stop in [preview.a, preview.b]:
		for cell in Stations.platform_cells(stop):
			var rect := Rect2(Vector2(cell) * game.TILE_SIZE, Vector2.ONE * game.TILE_SIZE).grow(-3.0)
			game.draw_rect(rect, ink, false, 2.0)
			game.draw_line(rect.position, rect.end, ink, 1.0)
		game.draw_string(ThemeDB.fallback_font, game._cell_center(stop) + Vector2(-40, -game.TILE_SIZE * 2.0), "Suggested station", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)

func _perform() -> void:
	refresh(0.0, true)
	if snapshot.complete: return
	var action: String = snapshot.rows[snapshot.next].action
	if not game.construction_plan.is_empty():
		detail.text = "Apply or discard the construction draft in Overlays first. The guide keeps your draft intact."
		return
	close_guide(false)
	match action:
		"stations":
			game.paused = true
			if not game.city_builder.active: game.city_builder.toggle()
		"connect":
			game.paused = true
			game._select_straight_track()
		"shared_preview":
			game.paused = true
			game.inspection_button.button_pressed = true
			game.inspection_panel.plan_toggle.button_pressed = true
			game.inspection_panel.loop_length.value = 9
			game.inspection_panel.loop_orientation.select(0)
			game._draft_passing_loop(Vector2i(44, 14))
		"shared_routes": game._open_routes_editor(Vector2i(48, 17), "Passing Place: choose the Town 2→Town 3 service and leg, Add waypoint 48,17, review then Apply. Leave Town 3→Town 2 on the main branch. Nothing is added automatically.")
		"forest":
			game.paused = true
			game._inspect_station_at(game.FOREST_SITE)
		"contracts": game.contracts_dialog.open_dialog("timber")
		"fleet": game._open_fleet_editor()
		"run":
			game.paused = false
			game._clear_construction_history()
	game._update_toolbar()
