extends RefCounted
## Colours the player must be able to tell apart, chosen by role so colour is
## never the only cue. The Default palette matches the colours the game used
## before this system existed.
##
## Colour-blind safe uses the Okabe-Ito set (blue / orange / yellow /
## vermillion), designed to stay distinguishable for the common forms of
## colour-vision deficiency. Valid/invalid placement is also shown with an
## X mark in the game, so it never relies on colour alone.
##
## Usage: Palette.get_color(Palette.Role.PREVIEW)

const Settings = preload("res://scripts/core/game_settings.gd")

enum Role {
	PREVIEW,
	PREVIEW_FILL,
	HOVER_OK,
	HOVER_BAD,
	BAD_FILL,
	BAD_MARK,
	TRAIN_PASSENGER,
	TRAIN_FREIGHT,
	MAP_PASSENGER,
	MAP_FREIGHT,
	FACILITY_STATION,
	FACILITY_FOREST,
	FACILITY_TERMINAL
}

static var _table: Dictionary = {}


static func get_color(role: int) -> Color:
	if _table.is_empty():
		_table = _build_table()

	return _table[Settings.palette_mode][role]


static func _build_table() -> Dictionary:
	var table: Dictionary = {}

	table[Settings.PaletteMode.DEFAULT] = {
		Role.PREVIEW: Color(0.35, 0.9, 0.55, 0.8),
		Role.PREVIEW_FILL: Color(0.35, 0.9, 0.55, 0.12),
		Role.HOVER_OK: Color(0.35, 0.9, 0.55, 0.45),
		Role.HOVER_BAD: Color(1.0, 0.2, 0.15, 0.6),
		Role.BAD_FILL: Color(1.0, 0.15, 0.1, 0.3),
		Role.BAD_MARK: Color(1.0, 0.3, 0.25),
		Role.TRAIN_PASSENGER: Color(0.85, 0.22, 0.18),
		Role.TRAIN_FREIGHT: Color(0.15, 0.45, 0.85),
		Role.MAP_PASSENGER: Color.html("#FF655A"),
		Role.MAP_FREIGHT: Color.html("#56A4FF"),
		Role.FACILITY_STATION: Color.html("#F4D56A"),
		Role.FACILITY_FOREST: Color.html("#6ED68C"),
		Role.FACILITY_TERMINAL: Color.html("#F0A75A")
	}

	var sky: Color = Color.html("#56B4E9")
	var orange: Color = Color.html("#E69F00")
	var yellow: Color = Color.html("#F0E442")
	var vermillion: Color = Color.html("#D55E00")
	var bluish_green: Color = Color.html("#009E73")
	var purple: Color = Color.html("#CC79A7")

	table[Settings.PaletteMode.COLOUR_BLIND] = {
		Role.PREVIEW: Color(sky, 0.85),
		Role.PREVIEW_FILL: Color(sky, 0.14),
		Role.HOVER_OK: Color(sky, 0.55),
		Role.HOVER_BAD: Color(vermillion, 0.8),
		Role.BAD_FILL: Color(vermillion, 0.35),
		Role.BAD_MARK: yellow,
		Role.TRAIN_PASSENGER: orange,
		Role.TRAIN_FREIGHT: sky,
		Role.MAP_PASSENGER: orange,
		Role.MAP_FREIGHT: sky,
		Role.FACILITY_STATION: yellow,
		Role.FACILITY_FOREST: bluish_green,
		Role.FACILITY_TERMINAL: purple
	}

	table[Settings.PaletteMode.HIGH_CONTRAST] = {
		Role.PREVIEW: Color(1.0, 1.0, 1.0, 0.95),
		Role.PREVIEW_FILL: Color(1.0, 1.0, 1.0, 0.2),
		Role.HOVER_OK: Color(1.0, 1.0, 1.0, 0.8),
		Role.HOVER_BAD: Color(1.0, 0.0, 1.0, 0.9),
		Role.BAD_FILL: Color(1.0, 0.0, 1.0, 0.4),
		Role.BAD_MARK: Color(1.0, 1.0, 1.0),
		Role.TRAIN_PASSENGER: Color(1.0, 1.0, 0.0),
		Role.TRAIN_FREIGHT: Color(0.0, 1.0, 1.0),
		Role.MAP_PASSENGER: Color(1.0, 1.0, 0.0),
		Role.MAP_FREIGHT: Color(0.0, 1.0, 1.0),
		Role.FACILITY_STATION: Color(1.0, 1.0, 1.0),
		Role.FACILITY_FOREST: Color(0.4, 1.0, 0.4),
		Role.FACILITY_TERMINAL: Color(1.0, 0.6, 0.0)
	}

	return table
