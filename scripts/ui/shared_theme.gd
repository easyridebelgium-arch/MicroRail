extends RefCounted
## One theme shared by gameplay, title and management dialogs.
static func _make_ui_style(
	background: Color,
	border: Color,
	padding: float = 8.0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)

	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding

	return style
static func build() -> Theme:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 16

	var normal := _make_ui_style(
		Color("#202B3C"),
		Color("#35445B")
	)

	var hover := _make_ui_style(
		Color("#2C3D55"),
		Color("#6485AD")
	)

	var pressed := _make_ui_style(
		Color("#245B83"),
		Color("#62B5F2")
	)

	var disabled := _make_ui_style(
		Color("#18212F"),
		Color("#283345")
	)

	for control_type in ["Button", "OptionButton"]:
		ui_theme.set_stylebox("normal", control_type, normal)
		ui_theme.set_stylebox("hover", control_type, hover)
		ui_theme.set_stylebox("pressed", control_type, pressed)
		ui_theme.set_stylebox("hover_pressed", control_type, pressed)
		ui_theme.set_stylebox("disabled", control_type, disabled)

		ui_theme.set_color(
			"font_color",
			control_type,
			Color("#E8EEF6")
		)
		ui_theme.set_color(
			"font_hover_color",
			control_type,
			Color.WHITE
		)
		ui_theme.set_color(
			"font_pressed_color",
			control_type,
			Color.WHITE
		)
		ui_theme.set_color(
			"font_disabled_color",
			control_type,
			Color("#748298")
		)
		ui_theme.set_color(
			"icon_disabled_color",
			control_type,
			Color(1.0, 1.0, 1.0, 0.35)
		)

	ui_theme.set_color("font_color", "Label", Color("#E8EEF6"))

	ui_theme.set_stylebox(
		"panel",
		"PanelContainer",
		_make_ui_style(
			Color("#172131"),
			Color("#35445B"),
			0.0
		)
	)

	ui_theme.set_stylebox(
		"panel",
		"TooltipPanel",
		_make_ui_style(
			Color("#111827"),
			Color("#536780")
		)
	)

	ui_theme.set_color(
		"font_color",
		"TooltipLabel",
		Color("#E8EEF6")
	)
	ui_theme.set_stylebox(
		"background",
		"ProgressBar",
		_make_ui_style(
			Color("#202B3C"),
			Color("#35445B"),
			0.0
		)
	)

	ui_theme.set_stylebox(
		"fill",
		"ProgressBar",
		_make_ui_style(
			Color("#3688BE"),
			Color("#62B5F2"),
			0.0
		)
	)

	return ui_theme
