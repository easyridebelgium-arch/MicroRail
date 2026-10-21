extends AcceptDialog
## A paused, read-only view; completion never opens this window automatically.
const Review = preload("res://scripts/core/scenario_review.gd")
var game: Node
var details: Label
var export_picker: FileDialog
var export_status: Label
var summary := ""
var body: VBoxContainer
var export_button: Button
func configure(owner_game: Node) -> void:
	game = owner_game
	title = "Scenario completion review"
	ok_button_text = "Close"
	exclusive = true
	export_picker = FileDialog.new()
	export_picker.title = "Export scenario result summary"
	export_picker.access = FileDialog.ACCESS_FILESYSTEM
	export_picker.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_picker.filters = PackedStringArray(["*.txt ; Text summaries"])
	export_picker.exclusive = true
	add_child(export_picker)
	export_picker.file_selected.connect(_export)
	visibility_changed.connect(func() -> void:
		if not visible: export_picker.hide())
	body = VBoxContainer.new()
	add_child(body)
	var actions := HFlowContainer.new()
	body.add_child(actions)
	for entry in [["Copy summary", "copy"], ["Export .txt", "export"]]:
		var button := Button.new()
		button.text = entry[0]
		if entry[1] == "export": export_button = button
		button.pressed.connect(_share.bind(entry[1]))
		actions.add_child(button)
	export_status = Label.new()
	export_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(export_status)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 100
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(details)
func open_dialog() -> void:
	body.custom_minimum_size.x = minf(640.0, game.get_viewport_rect().size.x * 0.85 - 32.0)
	var state: Dictionary = game.seeded_challenge.state
	export_status.text = "Copy or save this report for playtest feedback."
	summary = Review.export_summary(state, game.SeededChallenges.DEFINITIONS.get(state.id, {}), game._progress_values(), game.world.state, game.river_terrain.profile)
	details.text = Review.describe(state, game.SeededChallenges.DEFINITIONS.get(state.id, {}), game._progress_values())
	popup_centered_clamped(Vector2i(680, 560), 0.85)
	# Autowrapped labels need a layout pass at the selected width before clamping.
	await get_tree().process_frame
	await get_tree().process_frame
	if visible: popup_centered_clamped(Vector2i(680, 560), 0.85)

func _share(action: StringName) -> void:
	if summary.is_empty(): return
	if action == "copy":
		DisplayServer.clipboard_set(summary)
		export_status.text = "Summary copied to clipboard."
	elif action == "export":
		export_picker.current_file = "microrail-%s-results.txt" % game.seeded_challenge.state.id
		export_picker.popup_centered_clamped(Vector2i(720, 520), 0.85)

func _export(path: String) -> void:
	var result := Review.write_summary(path, summary)
	export_status.text = "Summary saved to %s" % path if result == OK else "Could not save summary (%s). Choose another location and try again." % error_string(result)
