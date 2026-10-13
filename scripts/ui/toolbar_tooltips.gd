extends RefCounted
## Descriptions stay separate from icons and read current InputMap bindings.
static func refresh(game: Node) -> void:
	var keys = game.InputActions
	var build: String = keys.mouse_label(keys.BUILD)
	var reset: String = keys.mouse_label(keys.RESET_TOOL)
	var descriptions := {
		game.straight_button: "Drag between two points with %s. Diagonal approaches and junction switches are automatic." % build,
		game.curve_button: "Hold %s and draw freely; track follows changes in direction." % build,
		game.switch_button: "Add or reshape a junction (£%d). Reserved switches cannot be changed." % game.SWITCH_COST,
		game.remove_button: "Select Remove, then drag with %s. Holding/dragging %s also removes track; reserved tiles are protected.\nShortcut: %s" % [build, reset, keys.key_label(keys.SELECT_REMOVE)],
		game.signal_button: "Click straight track to cycle automatic block signal, manual stop and removal. A manual stop does not release automatically.",
		game.waypoint_button: "Place a routing marker on track, then assign it to a route leg in Routes. Waypoints are not passenger stops.",
		game.routes_button: "Edit stops, Shuttle/Loop mode, platforms, waypoints and departure schedules. Opens paused.",
		game.fleet_button: "Buy, assign, name and upgrade trains; manage coaches, withdrawals and linked services. Opens paused.",
		game.traffic_button: "Hold or release trains and review deadlock recovery. Reversal obeys physical track and reservations. Opens paused.",
		game.inspect_button: "Select Inspect, then click a train, station or industry. Direct clicks can also inspect objects.\nShortcut: %s" % keys.key_label(keys.TOGGLE_INSPECT),
		game.reservation_button: "Toggle hatched tiles showing actual reserved authority. This is operating data, not a traffic prediction.",
		game.inspection_button: "View routes, blocks and ownership; review construction drafts, service impact and blueprints.",
		game.problems_button: "Review current problems and saved incidents. Inspect or locate the selected train; historical incidents may be resolved.",
		game.find_button: "Search trains, services, stations and industries; locate or inspect the selected object.",
		game.save_button: "Choose one of four save slots. Its previous save becomes that slot's backup. Opens paused.",
		game.load_button: "Load one of four saved games, or start fresh in a selected slot. Save first to keep current unsaved progress.",
		game.backup_button: "Choose a slot's previous manual save. Each slot has an independent backup.",
		game.folder_button: "Open the local folder containing your saves, backups, settings and blueprint library.",
		game.settings_button: "Change fullscreen, UI scale, palettes, reduced motion, keyboard/mouse bindings and alert preferences.",
		game.map_button: "Show/hide the network map. Click it to jump the camera; visibility is remembered.\nShortcut: %s" % keys.key_label(keys.TOGGLE_MAP),
		game.goals_button: "Show/hide objectives and rewards; visibility is remembered.\nShortcut: %s" % keys.key_label(keys.TOGGLE_GOALS),
		game.undo_button: "Undo the last construction group while paused, if occupancy and funds still permit it.",
		game.redo_button: "Reapply the last undone construction group while paused, subject to current safety and funds.",
	}
	for control in descriptions:
		var title: String = str(control.get_meta("toolbar_label", control.text))
		control.tooltip_text = title + "\n" + str(descriptions[control])
	var shortcuts: PackedStringArray = []
	for index in range(game.GAME_SPEEDS.size()):
		shortcuts.append("%s: %d×" % [keys.key_label(keys.SPEED_ACTIONS[index]), int(game.GAME_SPEEDS[index])])
		game.speed_selector.set_item_tooltip(index, keys.key_label(keys.SPEED_ACTIONS[index]))
	game.speed_selector.tooltip_text = "Simulation speed\n" + ", ".join(shortcuts) + ". Selecting a speed keeps pause unchanged; paused simulation does not advance."
