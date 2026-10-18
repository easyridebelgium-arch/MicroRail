extends RefCounted
## Inspect-mode modal. Does not edit track or acquire train authority.
var game: Node
var dialog: AcceptDialog
var detail: Label
var cell := Vector2i(-1, -1)
var active := false
var was_paused := true
func configure(owner_game: Node) -> void:
	game = owner_game
	dialog = AcceptDialog.new()
	dialog.title = "Bridge span inspector"
	dialog.ok_button_text = "Close"
	dialog.exclusive = true
	dialog.theme = game.game_menu.theme
	dialog.confirmed.connect(close)
	dialog.canceled.connect(close)
	dialog.close_requested.connect(close)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 100
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.add_child(scroll)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(detail)
	game.get_node("Interface").add_child(dialog)
func open_at(at: Vector2i) -> bool:
	var report: Dictionary = game.river_terrain.inspect_span(at, game.tracks, game.reservations.owners)
	if report.is_empty(): return false
	if not active: was_paused = game.paused
	active = true
	game.paused = true
	cell = at
	var cells: Array = report.cells
	var status := "Complete straight bridge" if report.complete else "Incomplete or incompatible span"
	var lines: PackedStringArray = [status, "Banks %s → %s | %d water tiles + 2 dry bank tiles" % [str(cells[0]), str(cells.back()), report.water_count], "Full new span: rails £%d + bridge surcharge £%d = £%d." % [report.rail_cost, report.surcharge, report.full_cost], "Missing rails: %d, material cost £%d. Incompatible existing rails: %d." % [report.missing.size(), report.missing_cost, report.incompatible.size()], "Existing water-deck refund value £%d; dry bank rails are separate (£5 each)." % report.deck_refund]
	if not report.missing.is_empty(): lines.append("Missing: " + str(report.missing))
	if not report.incompatible.is_empty(): lines.append("Incompatible: " + str(report.incompatible))
	lines.append("No current tile reservations on this span." if report.holders.is_empty() else "Tile reservations held by train IDs: " + str(report.holders))
	lines.append("This is a paused snapshot of tile claims, not block authority or permission to edit. Approach rails cost extra. Existing signals, protected land, available funds and live claims are checked again by construction previews.")
	lines.append("Build all water tiles and both dry banks as straight north–south rail. Remove all water-deck tiles together; banks cannot be removed while supporting deck rails remain. Partial removal or reserved tiles may prevent the whole edit. These values do not promise a refund until removal succeeds.")
	detail.text = "\n\n".join(lines)
	dialog.popup_centered_clamped(Vector2i(620, 500), 0.85)
	game._update_toolbar()
	game.queue_redraw()
	return true
func close(restore_pause: bool = true) -> void:
	if active and restore_pause: game.paused = was_paused
	active = false
	dialog.hide()
	cell = Vector2i(-1, -1)
	game._update_toolbar()
	game.queue_redraw()
func draw_span() -> void:
	if not dialog.visible: return
	for point in game.river_terrain.span(cell.x):
		var rect := Rect2(Vector2(point) * game.TILE_SIZE, Vector2.ONE * game.TILE_SIZE).grow(-2.0)
		game.draw_rect(rect, Color.WHITE, false, 2.0)
		game.draw_line(rect.position, rect.end, Color.WHITE, 1.0)
