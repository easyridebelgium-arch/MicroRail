extends PanelContainer
## Read-only feedback beside the pointer; never receives mouse/focus input.
var game: Node
var message: Label

func configure(owner_game: Node) -> void:
	game = owner_game
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	theme = game.header_box.theme
	z_index = 100
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.add_theme_font_size_override("font_size", 14)
	margin.add_child(message)
	hide()

func preview_text() -> String:
	if not game.is_dragging: return ""
	var lines: PackedStringArray = []
	var draft: bool = game.planning_mode
	var blocked: int = game.construction_feedback.get("blocked", {}).size()
	if game.demolition_mode:
		var count: int = game.demolition_cells.size()
		lines.append("DRAFT — remove %d" % count if draft else "PARTIAL — remove %d" % count if blocked > 0 else "REMOVE — %d pieces" % count)
		lines.append("Refund £%d%s" % [count * game.TRACK_REFUND, " at Apply plan" if draft else ""])
		if count == 0: lines.append("No editable track selected.")
		if blocked > 0: lines.append("%d reserved tiles %s" % [blocked, "need rechecking at Apply" if draft else "skipped; other tiles can be removed"])
	else:
		var error: String = str(game.build_plan.get("error", ""))
		var cost: int = game._build_plan_cost()
		if not error.is_empty():
			lines.append("× CANNOT BUILD")
			lines.append(error)
		else:
			lines.append("DRAFT — stroke £%d" % cost if draft else "× RESERVED TRACK — £%d" % cost if blocked > 0 else "× INSUFFICIENT CASH — £%d" % cost if game.money < cost else "✓ BUILD — £%d" % cost)
			lines.append("Track %d × £%d; switches %d × £%d" % [int(game.build_plan.get("new_count", 0)), game.TRACK_BUILD_COST, int(game.build_plan.get("switch_count", 0)), game.SWITCH_COST])
			if not draft and game.money < cost: lines.append("Available £%d; need £%d more" % [game.money, cost - game.money])
		if blocked > 0: lines.append("%d reserved tiles; %s" % [blocked, "recheck at Apply" if draft else "edit cannot commit now"])
	var affected: int = game.construction_feedback.get("affected", []).size()
	if affected > 0: lines.append("%s affects %d services — details in Overlays" % ["Draft" if draft else "Selection", affected])
	if draft: lines.append("Stroke preview; full draft price/validation in Overlays.")
	return "\n".join(lines)

func refresh_at(pointer: Vector2, allowed: bool) -> void:
	var text := preview_text() if allowed else ""
	if text.is_empty():
		hide()
		return
	message.text = text
	var view: Vector2 = game.get_viewport_rect().size
	custom_minimum_size.x = minf(260.0, maxf(32.0, view.x - 16.0))
	# Resizing the wrapping text precedes measuring its new minimum height.
	size = Vector2(custom_minimum_size.x, 0)
	show()
	var desired := pointer + Vector2(18, 22)
	if desired.x + size.x > view.x - 8: desired.x = pointer.x - size.x - 18
	if desired.y + size.y > view.y - 8: desired.y = pointer.y - size.y - 18
	position = Vector2(clampf(desired.x, 8, maxf(8, view.x - size.x - 8)), clampf(desired.y, 8, maxf(8, view.y - size.y - 8)))
