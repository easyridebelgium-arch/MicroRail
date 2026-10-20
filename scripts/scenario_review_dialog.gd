extends AcceptDialog
## A paused, read-only view; completion never opens this window automatically.
const Review = preload("res://scripts/core/scenario_review.gd")
var game: Node
var details: Label
func configure(owner_game: Node) -> void:
	game = owner_game
	title = "Scenario completion review"
	ok_button_text = "Close"
	exclusive = true
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 100
	add_child(scroll)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(details)
func open_dialog() -> void:
	var state: Dictionary = game.seeded_challenge.state
	details.text = Review.describe(state, game.SeededChallenges.DEFINITIONS.get(state.id, {}), game._progress_values())
	popup_centered_clamped(Vector2i(680, 560), 0.85)
