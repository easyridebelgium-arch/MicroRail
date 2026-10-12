extends Node2D

const TILE_SIZE: int = 32

const GRID_COLOR: Color = Color(0.18, 0.23, 0.25)
const SLEEPER_COLOR: Color = Color(0.43, 0.29, 0.17)
const RAIL_COLOR: Color = Color(0.78, 0.82, 0.85)

const TRAIN_CAPACITY: int = 20
const PASSENGER_INTERVAL: float = 5.0
const PASSENGERS_PER_BATCH: int = 3
const MAX_STATION_QUEUE: int = 100
const TICKET_PRICE: int = 5

const STARTING_BALANCE: int = 1000
const TRACK_BUILD_COST: int = 10
const TRACK_REFUND: int = 5
const SWITCH_COST: int = 100
const OPERATING_COST_PER_SECOND: int = 1

# Station positions in grid coordinates.
const STATION_A: Vector2i = Vector2i(4, 8)
const STATION_B: Vector2i = Vector2i(20, 8)
const STATION_C: Vector2i = Vector2i(36, 8)
const NotificationPolicy = preload("res://scripts/core/notification_policy.gd")
const Platforms = preload("res://scripts/core/platforms.gd")
var notifications = NotificationPolicy.new()

const TrafficMetrics = preload("res://scripts/core/traffic_metrics.gd")
const ProblemsDialog = preload("res://scripts/problems_dialog.gd")
var traffic_metrics = TrafficMetrics.new()
var traffic_wait_samples: Dictionary = {}
var problems_dialog: ConfirmationDialog
var problems_button: Button

const Consists = preload("res://scripts/core/consists.gd")
const ObjectBrowser = preload("res://scripts/object_browser.gd")
var object_browser: ConfirmationDialog
var object_pins: Dictionary = {}

const TrackBlueprints = preload("res://scripts/core/track_blueprints.gd")
const BLUEPRINT_PATH := "user://track_blueprints.json"
var blueprint_file_dialog: FileDialog
var blueprints: Array = []
var blueprint_library_error := ""
var blueprint_first := Vector2i(-1, -1)
var blueprint_last := Vector2i(-1, -1)

const SignalCorridor = preload("res://scripts/core/signal_corridor.gd")
var corridor_pick := 0
var corridor_start := Vector2i(-1, -1)
var corridor_end := Vector2i(-1, -1)
var corridor_cells: Array[Vector2i] = []

const ConstructionPlan = preload("res://scripts/core/construction_plan.gd")
var construction_plan = ConstructionPlan.new({"track": TRACK_BUILD_COST, "refund": TRACK_REFUND, "switch": SWITCH_COST})
var planning_mode := false

const ConstructionImpact = preload("res://scripts/core/construction_impact.gd")
const InspectionPanel = preload("res://scripts/inspection_panel.gd")
var demolition_blocked: Dictionary = {}
var construction_analyzer = ConstructionImpact.new()
var inspection_button: Button
var inspection_panel: PanelContainer
var construction_feedback: Dictionary = {"affected": [], "blocked": {}}

const PassengerService = preload("res://scripts/passenger_service.gd")
const ServiceRoutes = preload("res://scripts/service_routes.gd")
const RouteEditor = preload("res://scripts/route_editor.gd")
const Fleet = preload("res://scripts/fleet.gd")
const FleetEditor = preload("res://scripts/fleet_editor.gd")

const TRAIN_SPEED: float = 80.0
const STATION_WAIT: float = 2.0

const SAVE_PATH: String = "user://trainz_save.json"
const SAVE_TEMP_PATH: String = "user://trainz_save.tmp"
const RailRouter = preload("res://scripts/rail_router.gd")
const TrackGeometry = preload("res://scripts/track_geometry.gd")
const TrackBuilder = preload("res://scripts/track_builder.gd")
const SAVE_FIELDS: Array[String] = [
	"money",
	"total_operating_cost",
	"total_construction_cost",
	"total_vehicle_cost",
	"waiting_at_a",
	"waiting_at_b",
	"waiting_at_c",
	"passenger_stop_index",
	"passengers_on_train",
	"passengers_delivered",
	"passenger_timer",
	"operating_timer",
	"travelling_to_b",
	"wait_remaining",
	"train_needs_boarding",
	"paused",
	"capacity_upgrade_level",
	"speed_upgrade_level",
	"forest_stock",
	"logs_produced",
	"log_production_timer",
	"logs_delivered",
	"freight_income",
	"freight_operating_cost",
	"passenger_service_enabled"
]
const MAP_WIDTH: int = 80
const MAP_HEIGHT: int = 50
const KEYBOARD_PAN_SPEED: float = 600.0
const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 3.0
const ZOOM_STEP: float = 1.15
const SAVE_BACKUP_PATH: String = "user://trainz_save.backup.json"
const MAX_CAPACITY_LEVEL: int = 3
const MAX_SPEED_LEVEL: int = 3

const BASE_CAPACITY_UPGRADE_PRICE: int = 250
const BASE_SPEED_UPGRADE_PRICE: int = 200
const CAPACITY_PER_UPGRADE: int = 10
const SPEED_PER_UPGRADE: float = 20.0

const FOREST_SITE: Vector2i = Vector2i(8, 24)
const CARGO_TERMINAL: Vector2i = Vector2i(28, 24)

const LOG_PRODUCTION_INTERVAL: float = 10.0
const LOGS_PER_BATCH: int = 5
const MAX_FOREST_STOCK: int = 100
const FreightTrain = preload("res://scripts/freight_train.gd")
const LOG_DELIVERY_PRICE: int = 8
const GAME_SPEEDS: Array[float] = [1.0, 2.0, 5.0, 10.0]
const SimClock = preload("res://scripts/core/sim_clock.gd")
const BlockSignals = preload("res://scripts/core/block_signals.gd")
const WaypointRouter = preload("res://scripts/waypoint_router.gd")
const DirectionalRoutes = preload("res://scripts/core/directional_routes.gd")
const RuntimeRoutes = preload("res://scripts/core/runtime_routes.gd")
const DeadlockMonitor = preload("res://scripts/core/deadlock_monitor.gd")
const TrafficDialog = preload("res://scripts/traffic_dialog.gd")
const Reservations = preload("res://scripts/core/track_reservations.gd")
const CommandQueue = preload("res://scripts/core/command_queue.gd")
const SimRng = preload("res://scripts/core/sim_rng.gd")
const EventLog = preload("res://scripts/core/event_log.gd")
const SaveMigrations = preload("res://scripts/core/save_migrations.gd")
const GameSettings = preload("res://scripts/core/game_settings.gd")
const InputActions = preload("res://scripts/core/input_actions.gd")
const Palette = preload("res://scripts/core/palette.gd")
const SettingsDialog = preload("res://scripts/settings_dialog.gd")
const SAVE_VERSION: int = SaveMigrations.CURRENT_VERSION
const MAX_CONSTRUCTION_HISTORY: int = 100
const TOOLBAR_ICON_SHEET = preload("res://assets/ui/icons/toolbar.svg")
const NetworkMap = preload("res://scripts/network_map.gd")
const ScenarioGoals = preload("res://scripts/scenario_goals.gd")

# A false value means horizontal; true means vertical.
var tracks: Dictionary = {}
# Switch positions: {cell: 0 (through) or 1 (branch)}. Reservation owners
# lock the switch and set it for their actual movement.
var switch_states: Dictionary = {}
var reservations = Reservations.new()
var deadlocks = DeadlockMonitor.new()
var movement_conflicts: Dictionary = {}
var direct_inspect_train := -1
var direct_inspect_station := Vector2i(-1, -1)
var direct_inspect_cell := Vector2i(-1, -1)
var authority_revision := 0
var authority_tick := 0
var reservation_button: Button
const TrainInspector = preload("res://scripts/train_inspector.gd")
const TrainDiagnostics = preload("res://scripts/core/train_diagnostics.gd")
var train_inspector: AcceptDialog
var movement_blocks: Dictionary = {}
var passenger_travel = DirectionalRoutes.new()
var freight_travel = DirectionalRoutes.new()
var passenger_returning: bool = false
var passenger_return_stop: int = 0
var passenger_held: bool = false
var track_signals: Dictionary = {}
var block_signals = BlockSignals.new()
var waypoint_tool_mode: bool = false
var waypoint_button: Button
var signal_tool_mode: bool = false
var speed_selector: OptionButton
var signal_button: Button
var reservation_trains: Dictionary = {}
var traffic_dialog: ConfirmationDialog
var traffic_button: Button
var reservation_overlay: bool = false
var reservation_waits: Dictionary = {}
var freight_route_cells: Array[Vector2i] = []
var draw_track_mode: bool = false
var build_stroke: Array[Vector2i] = []
var build_plan: Dictionary = {}
var build_last_hover: Vector2i = Vector2i(-99999, -99999)
var hovered_cell: Vector2i = Vector2i(-1, -1)

var route_connected: bool = false
var train_position: Vector2
var travelling_to_b: bool = true
var wait_remaining: float = 0.0
var paused: bool = false
var is_dragging: bool = false
var drag_start: Vector2i = Vector2i.ZERO
var drag_pointer_start: Vector2 = Vector2.INF
const RIGHT_HOLD_SECONDS: float = 0.4
const RIGHT_DRAG_PIXELS: float = 6.0
var right_pending: bool = false
var right_removing: bool = false
var right_map_origin: bool = false
var right_elapsed: float = 0.0
var right_start_point: Vector2 = Vector2.ZERO
var right_start_cell: Vector2i = Vector2i.ZERO

var waiting_at_a: int = 8
var waiting_at_b: int = 8
var waiting_at_c: int = 8
var passenger_stop_index: int = 0
var stop_distances: Array[float] = []
var services: Dictionary = ServiceRoutes.defaults()
var passenger_services: Dictionary = {}
var fleet: Dictionary = Fleet.defaults()
var fleet_editor: FleetEditor
var fleet_button: Button
var total_vehicle_cost: int = 0

var route_editor: RouteEditor
var routes_button: Button
var passenger_route_error: String = "No connected passenger route"
var passengers_on_train: int = 0

var passengers_delivered: int = 0
var money: int = STARTING_BALANCE

var passenger_timer: float = 0.0
var train_needs_boarding: bool = true

var operating_timer: float = 0.0
var total_operating_cost: int = 0
var total_construction_cost: int = 0

var notice: String = ""
var notice_remaining: float = 0.0
var route_cells: Array[Vector2i] = []
var route_path: Curve2D = Curve2D.new()
var route_distance: float = 0.0
var train_heading: float = 0.0
var is_panning: bool = false
var inspect_mode: bool = false
var selected_station: Vector2i = Vector2i(-1, -1)

var station_panel: PanelContainer
var station_title: Label
var station_details: Label
var capacity_upgrade_level: int = 0
var speed_upgrade_level: int = 0

var capacity_upgrade_button: Button
var speed_upgrade_button: Button
var forest_stock: int = 0
var logs_produced: int = 0
var log_production_timer: float = 0.0
var freight_train: FreightTrain
var logs_delivered: int = 0
var freight_income: int = 0
var freight_operating_cost: int = 0
var freight_rule_label: Label
var freight_rule_option: OptionButton

var construction_undo: Array[Dictionary] = []
var construction_redo: Array[Dictionary] = []

var undo_button: Button
var redo_button: Button
var passenger_service_enabled: bool = true
var service_button: Button
var demolition_mode: bool = false
var switch_tool_mode: bool = false
var switch_button: Button
var remove_button: Button
var demolition_cells: Dictionary = {}
var demolition_last_cell: Vector2i = Vector2i.ZERO
var toolbar_icon_textures: Array[Texture2D] = []
var network_map: NetworkMap
var map_button: Button
var scenario_goals: ScenarioGoals = ScenarioGoals.new()

# Phase 0 foundations: fixed-step clock, seeded RNG and the event stream.
var sim_clock: SimClock = SimClock.new()
# The interface scale the camera zoom currently compensates for.
var applied_ui_scale: float = 1.0
var command_queue: CommandQueue = CommandQueue.new()
var sim_rng: SimRng = SimRng.new()
var event_log: EventLog = EventLog.new()
var settings_dialog: SettingsDialog
var settings_button: Button

var objective_panel: PanelContainer
var objective_heading: Label
var objective_description: Label
var objective_progress: ProgressBar
var objective_details: Label
var goals_button: Button

@onready var instructions: Label = $Interface/HeaderBox/Instructions
@onready var straight_button: Button = $Interface/HeaderBox/Toolbar/StraightButton
@onready var curve_button: Button = $Interface/HeaderBox/Toolbar/CurveButton
@onready var rotate_button: Button = $Interface/HeaderBox/Toolbar/RotateButton
@onready var pause_button: Button = $Interface/HeaderBox/Toolbar/PauseButton
@onready var save_button: Button = $Interface/HeaderBox/Toolbar/SaveButton
@onready var load_button: Button = $Interface/HeaderBox/Toolbar/LoadButton
@onready var folder_button: Button = $Interface/HeaderBox/Toolbar/FolderButton
@onready var camera: Camera2D = $Camera2D
@onready var header_background: ColorRect = $Interface/HeaderBackground
@onready var header_box: VBoxContainer = $Interface/HeaderBox
@onready var header_title: Label = $Interface/HeaderBox/Title
@onready var header_toolbar: HFlowContainer = $Interface/HeaderBox/Toolbar
@onready var backup_button: Button = $Interface/HeaderBox/Toolbar/BackupButton
@onready var inspect_button: Button = $Interface/HeaderBox/Toolbar/InspectButton

func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	get_window().focus_exited.connect(_cancel_right_gesture)
	header_box.resized.connect(_layout_header)

	# Player settings first, so keys, scale and colours are right from frame one.
	GameSettings.load_settings()
	InputActions.register_defaults()
	InputActions.apply_bindings(GameSettings.key_bindings)
	InputActions.apply_mouse_bindings(GameSettings.mouse_bindings)
	GameSettings.apply(get_window())

	# A new game gets a fresh seed; loading a save restores the saved one.
	sim_rng.randomize_seed()

	# Each station includes a horizontal platform track.
	tracks[STATION_A] = false
	tracks[STATION_B] = false
	tracks[STATION_C] = false
	tracks[FOREST_SITE] = false
	tracks[CARGO_TERMINAL] = false

	train_position = _cell_center(STATION_A)
	_update_instructions()
	queue_redraw()
	_setup_toolbar()
	_reset_camera()
	_setup_station_inspector()
	_setup_freight_train()
	_setup_history_controls()
	_setup_network_map()
	_setup_objective_panel()
	_setup_routes_editor()
	_setup_fleet_editor()
	_apply_fleet_specs()
	_setup_settings_dialog()
	_setup_reservation_overlay()
	_setup_inspection()
	_load_blueprints()
	_setup_train_inspector()
	_setup_problems()
	_setup_object_browser()
	_setup_traffic_dialog()
	_setup_signal_tool()
	_setup_speed_control()
	_setup_waypoint_tool()
	_rebuild_reservations()
	_setup_modern_ui_theme()
	_setup_toolbar_icons()
	_apply_settings()
	for window in [traffic_dialog, train_inspector, route_editor, fleet_editor, problems_dialog, object_browser]:
		window.window_input.connect(_tool_window_input.bind(window))

func _process(delta: float) -> void:
	_advance_right_gesture(delta)
	_move_camera_with_keyboard(delta)
	hovered_cell = _mouse_to_cell()
	_cancel_direct_inspection_if_dragged(hovered_cell)
	if is_dragging and demolition_mode:
		_collect_demolition_cells(hovered_cell)
	elif is_dragging:
		_refresh_build_plan(hovered_cell)

	# Interface messages expire even while simulation is paused.
	if notice_remaining > 0.0:
		notice_remaining = maxf(0.0, notice_remaining - delta)

	# The simulation advances in fixed steps, whatever the frame rate.
	if not paused:
		for _step in sim_clock.advance(delta):
			if paused: break
			sim_clock.begin_tick()
			_run_due_commands()
			_simulation_step(SimClock.TICK_SECONDS)

	_flush_notifications()
	_update_inspection()
	_update_instructions()
	_update_toolbar()
	_update_station_inspector()
	_update_history_controls()
	_update_network_map()
	_update_objective_panel()
	_layout_header()
	queue_redraw()
	
func _simulation_step(step_seconds: float) -> void:
	_generate_passengers(step_seconds)
	_produce_logs(step_seconds)
	_refresh_directional_routes()
	_rebuild_reservations(true)
	movement_conflicts.clear()
	movement_blocks.clear()
	traffic_wait_samples.clear()
	forest_stock -= freight_train.advance(step_seconds, forest_stock)

	if _passenger_service_is_active():
		_move_train(step_seconds)
		_charge_operating_cost(step_seconds)

	for key in additional_service_keys(): passenger_services[key].advance(self, step_seconds)
	_update_deadlocks()
	traffic_metrics.update(sim_clock.tick, reservation_trains.keys(), traffic_wait_samples)
	_check_scenario_objectives()
	_refresh_directional_routes()
	_flush_notifications()


func _record_event(type: String, subject: String, data: Dictionary = {}) -> void:
	var event: Dictionary = event_log.record(sim_clock.tick, type, subject, data)
	notifications.consume(event, GameSettings.notification_rules)


# True while a dialog owns the keyboard, so game shortcuts stay quiet.
func _modal_open() -> bool:
	return _management_window_is_open() or (settings_dialog != null and settings_dialog.visible) or (blueprint_file_dialog != null and blueprint_file_dialog.visible)


func _unhandled_input(event: InputEvent) -> void:
	if _right_mouse_input(event): return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if not (focused is LineEdit or focused is TextEdit) and event.is_action_pressed(InputActions.TOGGLE_FULLSCREEN):
		GameSettings.toggle_fullscreen(get_window())
		get_viewport().set_input_as_handled()
		return
	if _modal_open():
		_clear_direct_inspection()
		return
	if event is InputEventMouseMotion:
		_cancel_direct_inspection_if_dragged(_mouse_to_cell())

	if not (focused is LineEdit or focused is TextEdit):
		if event.is_action_pressed(InputActions.SELECT_REMOVE):
			_select_remove_tool()
			get_viewport().set_input_as_handled()
			return
		for index in range(InputActions.SPEED_ACTIONS.size()):
			if event.is_action_pressed(InputActions.SPEED_ACTIONS[index]):
				_set_game_speed(index)
				get_viewport().set_input_as_handled()
				return

	if event.is_action_pressed(InputActions.TOGGLE_MAP):
		_toggle_network_map()
		return

	if event.is_action_pressed(InputActions.RESET_CAMERA):
		_cancel_right_gesture()
		_clear_direct_inspection()
		is_dragging = false
		is_panning = false
		demolition_cells.clear()
		demolition_blocked.clear()
		_reset_camera()
		return

	if event.is_action_pressed(InputActions.CANCEL):
		if right_pending:
			_reset_track_tools()
			return
		_clear_direct_inspection()
		corridor_pick = 0
		is_dragging = false
		demolition_cells.clear()
		demolition_blocked.clear()
		return

	if event.is_action_pressed(InputActions.TOGGLE_INSPECT):
		_toggle_inspect_mode()
		return

	if event.is_action_pressed(InputActions.TOGGLE_PAUSE):
		_toggle_pause()
		return

	if event.is_action_pressed(InputActions.TOGGLE_GOALS):
		_toggle_objective_panel()
		return

	if event is InputEventMouseButton:
		var cell: Vector2i = _mouse_to_cell()

		if event.is_action_pressed(InputActions.BUILD):
			if right_pending:
				_reset_track_tools()
				return
			_clear_direct_inspection()
			if demolition_mode:
				if _is_inside_map(cell):
					is_dragging = true
					demolition_last_cell = cell
					demolition_cells.clear()
					demolition_blocked.clear()
					_collect_demolition_cells(cell)
				return
			if corridor_pick > 0:
				_pick_corridor_cell(cell)
				return
			# Left-click cancels an active demolition gesture.
			if is_dragging and demolition_mode:
				is_dragging = false
				demolition_cells.clear()
				demolition_blocked.clear()
				return

			if inspect_mode:
				if not _inspect_train_at(cell): _inspect_station_at(cell)
				return

			if waypoint_tool_mode:
				_use_waypoint_tool(cell)
				return
			if signal_tool_mode:
				_use_signal_tool(cell)
				return
			if switch_tool_mode:
				_use_switch_tool(cell)
				return

			if not planning_mode: _begin_direct_inspection(cell, to_local(_pointer_world()))
			if _can_build_at(cell):
				demolition_mode = false
				demolition_cells.clear()
				demolition_blocked.clear()
				drag_start = cell
				drag_pointer_start = to_local(_pointer_world())
				build_stroke.assign([cell])
				is_dragging = true
				_refresh_build_plan(cell, true)

		if event.is_action_released(InputActions.BUILD):
			if is_dragging and demolition_mode:
				_finish_demolition(cell)
				return
			if _finish_direct_inspection(cell): return
			if is_dragging:
				_finish_track_drag(cell)

func _check_route(force_reset: bool = false) -> void:
	var built: Dictionary = ServiceRoutes.build(tracks, services["passenger"]["stops"], float(TILE_SIZE), services["passenger"].get("waypoints", {}), services["passenger"].get("mode", "shuttle"), services["passenger"].get("platforms", {}))
	var new_route: Array[Vector2i] = []
	new_route.assign(built["cells"])
	for cell in track_signals.keys():
		if not tracks.has(cell) or not TrackGeometry.is_straight(tracks[cell]): track_signals.erase(cell)
	var at_home := route_distance <= 0.001 and passenger_stop_index == 0 and passengers_on_train == 0 and not passenger_returning
	# Only adopt new geometry at the same physical starting position. Away from
	# home, retain the entire travelled path and its distance until repaired.
	if route_cells.is_empty() or at_home:
		if not new_route.is_empty() and (new_route != route_cells or force_reset):
			route_cells = new_route
			route_path = built["path"]
			stop_distances.assign(built["distances"])
			route_distance = 0.0
			passenger_stop_index = 0
			travelling_to_b = true
			wait_remaining = 0.0
			train_needs_boarding = true
			_record_event(EventLog.ROUTE_CHANGED, "passenger", {"connected": true, "tiles": route_cells.size()})
	for key in additional_service_keys(): passenger_services[key].rebuild_at_home(self)
	_refresh_freight_route(new_route)
	_refresh_switch_states(route_cells)
	_refresh_directional_routes()
	_update_train_transform()
	_rebuild_reservations()


func _move_train(delta: float) -> void:
	if not route_connected or passenger_held:
		return
	if wait_remaining > 0.0:
		wait_remaining = maxf(0.0, wait_remaining - delta)
		return
	if train_needs_boarding:
		_board_passengers()
		train_needs_boarding = false
		_record_event(EventLog.TRAIN_DEPARTED, "passenger", {"stop": services["passenger"]["stops"][passenger_stop_index], "passengers": passengers_on_train})
	var next_stop: int = _next_passenger_stop()
	var target_distance: float = _passenger_target_distance()
	route_distance = _reserved_movement("passenger", route_path, route_distance, move_toward(route_distance, target_distance, _get_train_speed() * delta))
	if absf(route_distance - target_distance) < 0.001:
		route_distance = target_distance
		if passenger_returning:
			_return_onboard_passengers()
			passenger_returning = false
			passenger_held = true
			passenger_service_enabled = false
			travelling_to_b = not travelling_to_b
			train_needs_boarding = true
			wait_remaining = 0.0
			_record_event(EventLog.TRAIN_RECOVERED, str(Fleet.assigned(fleet, "passenger")["id"]), {"service": "passenger", "stop": services["passenger"]["stops"][passenger_stop_index], "action": "returned to departure stop"})
			_update_train_transform()
			return
		var unloaded: int = passengers_on_train
		_unload_passengers()
		passenger_stop_index = next_stop
		_record_event(EventLog.TRAIN_ARRIVED, "passenger", {"stop": services["passenger"]["stops"][next_stop], "passengers": unloaded})
		if _passenger_is_loop():
			# The closing leg ends at the same physical station as distance zero.
			# Wrap only after arrival; never rebuild or relocate a moving train.
			if passenger_stop_index == 0: route_distance = 0.0
			travelling_to_b = true
		elif passenger_stop_index == stop_distances.size() - 1:
			travelling_to_b = false
		elif passenger_stop_index == 0:
			travelling_to_b = true
		wait_remaining = STATION_WAIT
		train_needs_boarding = true
	_update_train_transform()


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE_SIZE + Vector2(
		TILE_SIZE / 2.0,
		TILE_SIZE / 2.0
	)


func _mouse_to_cell() -> Vector2i:
	var mouse_position: Vector2 = to_local(_pointer_world())

	return Vector2i(
		int(floor(mouse_position.x / TILE_SIZE)),
		int(floor(mouse_position.y / TILE_SIZE))
	)


func _is_inside_map(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.x < MAP_WIDTH
		and cell.y >= 0
		and cell.y < MAP_HEIGHT
	)


func _is_station_space(cell: Vector2i) -> bool:
	for station in [STATION_A, STATION_B, STATION_C, FOREST_SITE, CARGO_TERMINAL]:
		var inside_columns: bool = (
			cell.x >= station.x - 1
			and cell.x <= station.x + 1
		)

		var inside_rows: bool = (
			cell.y >= station.y - 2
			and cell.y < station.y
		)

		if inside_columns and inside_rows:
			return true

	return false


func _can_build_at(cell: Vector2i) -> bool:
	return _is_inside_map(cell) and not _is_station_space(cell)


func _update_instructions() -> void:
	var direction: String = "Draw track: follow the mouse" if draw_track_mode else "Connect track: drag between two points"
	if inspect_mode:
		direction = "Inspect: click a train, station or industry"
	elif waypoint_tool_mode:
		direction = "Waypoints: click track, then choose service/leg in Routes"
	elif signal_tool_mode:
		direction = "Signals: click straight track — automatic / stop / remove"
	elif is_dragging and demolition_mode:
		direction = "Remove %d tracks — refund £%d" % [demolition_cells.size(), demolition_cells.size() * TRACK_REFUND]
	elif is_dragging and not build_plan.get("error", "").is_empty():
		direction = "Blocked: " + str(build_plan["error"])

	var status: String = _passenger_service_status()

	if paused:
		status = "Paused. Press %s to resume." % InputActions.key_label(InputActions.TOGGLE_PAUSE)

	if notice_remaining > 0.0:
		status = notice
	var stranded: PackedStringArray = []
	if not route_cells.is_empty() and not route_connected: stranded.append("passenger")
	if freight_train != null and not freight_train.route_cells.is_empty() and not freight_train.route_valid: stranded.append("freight")
	if not stranded.is_empty():
		status += " | Route incomplete: %s stopped. Repair track." % "/".join(stranded)

	var preview_cost: int = _get_preview_cost()
	var affordability: String = ""

	if preview_cost > 0 and preview_cost > money:
		affordability = " — insufficient funds"

	if (is_dragging or planning_mode) and not construction_feedback.affected.is_empty():
		direction += " | Affects %d services (details: Overlays)" % construction_feedback.affected.size()
	if (is_dragging or planning_mode) and not construction_feedback.blocked.is_empty():
		direction += " | %d reserved tiles cannot be edited" % construction_feedback.blocked.size()

	if problems_button != null:
		problems_button.text = "Problems (%d)" % problem_rows().size()

	var status_line: String = "%s | Cell: %d,%d | Build: £%d%s | %s" % [
		direction,
		hovered_cell.x,
		hovered_cell.y,
		preview_cost,
		affordability,
		status
	]
	var waiting_line: String = "Waiting: A %d / B %d / C %d | Onboard: %d/%d | Delivered: %d" % [
		waiting_at_a,
		waiting_at_b,
		waiting_at_c,
		passengers_on_train,
		_get_train_capacity(),
		passengers_delivered
	]
	var money_line: String = "Balance: £%d | Fares: £%d | Freight: £%d | Build: £%d | Running: £%d | Fleet: £%d" % [
		money,
		passengers_delivered * TICKET_PRICE,
		freight_income,
		total_construction_cost,
		total_operating_cost + freight_operating_cost,
		total_vehicle_cost
	]

	if GameSettings.use_compact_header():
		instructions.text = "%s\nBalance: £%d | %s" % [status_line, money, waiting_line]
		instructions.tooltip_text = money_line
		return

	instructions.tooltip_text = ""
	instructions.text = (
		"Left-drag: automatic track | Right-drag/hold: remove"
		+ " | Short right-click: cancel | %s: Remove tool" % InputActions.key_label(InputActions.SELECT_REMOVE)
		+ " | %s: pause | %s: cancel" % [
			InputActions.key_label(InputActions.TOGGLE_PAUSE),
			InputActions.key_label(InputActions.CANCEL)
		]
		+ "\n" + status_line
		+ "\n" + waiting_line
		+ "\n" + money_line
	)


func _on_viewport_size_changed() -> void:
	_cancel_right_gesture()
	queue_redraw()
	_layout_header()


# Compact header: no title or key hints, shorter status text, tighter toolbar
# and a smaller objectives panel, so the map keeps most of the window.
func _apply_header_mode() -> void:
	var compact: bool = GameSettings.use_compact_header()
	header_title.visible = not compact
	header_toolbar.add_theme_constant_override("h_separation", 4 if compact else 8)
	instructions.mouse_filter = Control.MOUSE_FILTER_PASS if compact else Control.MOUSE_FILTER_IGNORE

	if objective_progress != null:
		objective_progress.visible = not compact

	_update_instructions()


# The header grows when the toolbar wraps onto more rows; panels below follow it.
func _layout_header() -> void:
	if header_box == null or header_background == null:
		return

	var scale: float = GameSettings.ui_scale
	var header_height: float = header_box.position.y + header_box.size.y + (12.0 * scale)
	header_background.offset_bottom = header_height

	if station_panel != null:
		station_panel.offset_top = header_height + (16.0 * scale)
	if inspection_panel != null:
		# The right column has no bottom toolbar. Let scrolling consume the
		# available space instead of forcing a minimum beyond the viewport.
		var inspection_bottom := get_viewport_rect().size.y - 8.0
		inspection_panel.offset_top = minf(header_height + 8.0 * scale, inspection_bottom - 48.0)
		inspection_panel.offset_bottom = inspection_bottom

	# Left column: objectives, then the network map in whatever height is left
	# above the bottom buttons. Recomputed every frame (cheap, and it follows
	# the Goals and Map toggles and any window or scale change).
	var column_top: float = header_height + (16.0 * scale)
	var bottom_limit: float = get_viewport_rect().size.y - (64.0 * scale)

	if objective_panel != null:
		var objective_height: float = (104.0 if GameSettings.use_compact_header() else 140.0) * scale
		_set_top_left_rect(objective_panel, column_top, column_top + objective_height)

		if objective_panel.visible:
			column_top += objective_height + (12.0 * scale)

	if network_map != null:
		var map_height: float = clampf(bottom_limit - column_top, 120.0 * scale, 200.0 * scale)
		_set_top_left_rect(network_map, column_top, column_top + map_height)


func _set_top_left_rect(control: Control, top: float, bottom: float) -> void:
	if control.anchor_top != 0.0 or control.anchor_bottom != 0.0:
		control.anchor_top = 0.0
		control.anchor_bottom = 0.0

	if not is_equal_approx(control.offset_top, top):
		control.offset_top = top

	if not is_equal_approx(control.offset_bottom, bottom):
		control.offset_bottom = bottom


func _draw() -> void:
	_draw_grid()
	for cell in tracks:
		_draw_track(cell, tracks[cell], false)
	_draw_construction_draft()
	_draw_inspection_paths()
	_draw_station(STATION_A, "Station A")
	_draw_station(STATION_B, "Station B")
	_draw_station(STATION_C, "Station C")
	_draw_station(FOREST_SITE, "Forest")
	_draw_station(CARGO_TERMINAL, "Terminal")
	if inspect_mode:
		if selected_station != Vector2i(-1, -1):
			draw_rect(Rect2(Vector2(selected_station) * TILE_SIZE, Vector2.ONE * TILE_SIZE).grow(3.0), Color(1.0, 0.85, 0.25), false, 2.0)
	elif is_dragging and demolition_mode:
		_draw_demolition_preview()
	elif is_dragging:
		for cell in build_plan.get("tiles", {}):
			_draw_track(cell, build_plan["tiles"][cell], true)
		for cell in build_plan.get("invalid", {}):
			_draw_invalid_build_cell(cell)
	elif _is_inside_map(hovered_cell):
		var color: Color = Palette.get_color(Palette.Role.HOVER_OK if _can_build_at(hovered_cell) else Palette.Role.HOVER_BAD)
		draw_rect(Rect2(Vector2(hovered_cell) * TILE_SIZE, Vector2.ONE * TILE_SIZE), color, false, 2.0)
	if reservation_overlay:
		_draw_reservations()
	_draw_waypoints()
	_draw_signals()
	_draw_train()
	for key in additional_service_keys():
		var running = passenger_services[key]
		_draw_passenger_consist(key, running.path, running.distance, running.position, running.heading, running.forward)


func _draw_grid() -> void:
	var map_size := Vector2(
		MAP_WIDTH * TILE_SIZE,
		MAP_HEIGHT * TILE_SIZE
	)

	draw_rect(
		Rect2(Vector2.ZERO, map_size),
		Color(0.10, 0.15, 0.13)
	)

	for column in range(MAP_WIDTH + 1):
		var x: float = float(column * TILE_SIZE)

		draw_line(
			Vector2(x, 0.0),
			Vector2(x, map_size.y),
			GRID_COLOR
		)

	for row in range(MAP_HEIGHT + 1):
		var y: float = float(row * TILE_SIZE)

		draw_line(
			Vector2(0.0, y),
			Vector2(map_size.x, y),
			GRID_COLOR
		)

	draw_rect(
		Rect2(Vector2.ZERO, map_size),
		Color(0.45, 0.55, 0.48),
		false,
		2.0
	)


func _draw_track(cell: Vector2i, track_type: Variant, preview: bool) -> void:
	var geometry: Dictionary = TrackGeometry.drawing_data(track_type, float(TILE_SIZE))
	if geometry.is_empty():
		return
	draw_set_transform(Vector2(cell) * TILE_SIZE)
	var rail_color: Color = Palette.get_color(Palette.Role.PREVIEW) if preview else RAIL_COLOR
	var sleeper_color: Color = SLEEPER_COLOR
	if preview:
		sleeper_color.a = 0.5
		draw_rect(Rect2(Vector2.ZERO, Vector2.ONE * TILE_SIZE), Palette.get_color(Palette.Role.PREVIEW_FILL))
	var sleepers: PackedVector2Array = geometry["sleepers"]
	for index in range(0, sleepers.size(), 2):
		draw_line(sleepers[index], sleepers[index + 1], sleeper_color, 4.0)
	draw_polyline(geometry["left"], rail_color, 2.0)
	draw_polyline(geometry["right"], rail_color, 2.0)

	# Switches and crossings have further rails.
	for extra in geometry.get("extra", []):
		var extra_sleepers: PackedVector2Array = extra["sleepers"]
		for index in range(0, extra_sleepers.size(), 2):
			draw_line(extra_sleepers[index], extra_sleepers[index + 1], sleeper_color, 4.0)
		draw_polyline(extra["left"], rail_color, 2.0)
		draw_polyline(extra["right"], rail_color, 2.0)

	# A switch shows where it is set: a filled marker on the open exit, with a
	# ring at the stem so the state is not carried by colour alone.
	if not preview and TrackGeometry.is_switch(track_type):
		var ports: Array[Vector2i] = TrackGeometry.connections(track_type)
		var open_exit: Vector2i = ports[2] if int(switch_states.get(cell, 0)) == 1 else ports[1]
		var middle: Vector2 = Vector2.ONE * TILE_SIZE / 2.0
		draw_circle(middle + Vector2(open_exit) * TILE_SIZE * 0.3, 4.0, Palette.get_color(Palette.Role.FACILITY_STATION))
		draw_arc(middle + Vector2(ports[0]) * TILE_SIZE * 0.3, 4.0, 0.0, TAU, 12, Palette.get_color(Palette.Role.FACILITY_STATION), 1.5)
	draw_set_transform(Vector2.ZERO)


func _draw_station(cell: Vector2i, station_name: String) -> void:
	var origin: Vector2 = Vector2(cell) * TILE_SIZE

	var footprint := Rect2(
		origin + Vector2(-TILE_SIZE, -2 * TILE_SIZE),
		Vector2(3 * TILE_SIZE, 2 * TILE_SIZE)
	)

	# Reserved station grounds.
	draw_rect(
		footprint,
		Color(0.17, 0.20, 0.22)
	)

	draw_rect(
		footprint,
		Color(0.35, 0.40, 0.43),
		false,
		1.0
	)

	# Name centered inside the reserved area.
	draw_string(
		ThemeDB.fallback_font,
		origin + Vector2(-24, -38),
		station_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		80.0,
		16,
		Color.WHITE
	)

	# Platform alongside the station track.
	draw_rect(
		Rect2(
			origin + Vector2(-24, -16),
			Vector2(80, 12)
		),
		Color(0.65, 0.68, 0.70)
	)

	draw_line(
		origin + Vector2(-24, -4),
		origin + Vector2(56, -4),
		Color(0.95, 0.80, 0.25),
		2.0
	)


func _draw_train() -> void:
	_draw_passenger_consist("passenger", route_path, route_distance, train_position, train_heading, travelling_to_b)

func _draw_passenger_vehicle(at: Vector2, angle: float, id: int) -> void:
	draw_set_transform(at, angle)

	var body := Rect2(
		Vector2(-13, -7),
		Vector2(26, 14)
	)

	draw_rect(body, Palette.get_color(Palette.Role.TRAIN_PASSENGER))
	draw_rect(body, Color(0.15, 0.08, 0.08), false, 1.0)

	# The front of the train always points along its heading.
	draw_rect(
		Rect2(Vector2(5, -5), Vector2(6, 10)),
		Color(0.65, 0.85, 0.95)
	)

	# Restore normal drawing coordinates.
	draw_set_transform(Vector2.ZERO, 0.0)
	if not passenger_services.is_empty():
		draw_string(ThemeDB.fallback_font, at + Vector2(-10, -12), "#%d" % id, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)







func _finish_track_drag(end_cell: Vector2i) -> void:
	_refresh_build_plan(end_cell, true)
	is_dragging = false
	if not build_plan.get("error", "").is_empty():
		_show_notice(build_plan["error"])
		return
	var changes: Dictionary = build_plan["changes"]
	if changes.is_empty():
		_show_notice("This route is already built.")
		return
	if planning_mode:
		construction_plan.stage(changes, tracks)
		_show_notice("Track stroke added to draft. Use Overlays → Apply plan when ready.")
		return
	var cost: int = _build_plan_cost()
	if cost > 0 and money < cost:
		_show_notice("Insufficient funds: need £%d, available £%d." % [cost, money])
		return
	var cells: Array = []
	var expected: Array = []
	for cell in changes:
		cells.append([cell.x, cell.y, changes[cell]])
		expected.append([cell.x, cell.y, tracks.get(cell)])
	_submit_command("build", {"cells": cells, "new_count": int(build_plan["new_count"]), "expected": expected})


# Paused edits run at once (and are stamped with the current tick). While the
# simulation runs, edits wait for the start of the next simulation step.
func _submit_command(type: String, data: Dictionary) -> void:
	if paused:
		_execute_command({"seq": 0, "tick": sim_clock.tick, "type": type, "data": data})
		return

	if command_queue.enqueue(sim_clock.tick + 1, type, data).is_empty():
		_show_notice("Too many pending commands; try again in a moment.")


func _run_due_commands() -> void:
	for command in command_queue.drain(sim_clock.tick):
		_execute_command(command)


func _execute_command(command: Dictionary) -> void:
	var data: Dictionary = command["data"]

	match str(command["type"]):
		"build":
			_execute_build(data)
		"demolish":
			_execute_demolish(data)
		"set_tile":
			_execute_set_tile(data)
		"set_signal":
			_execute_set_signal(data)


func _use_switch_tool(cell: Vector2i) -> void:
	if planning_mode:
		var working: Dictionary = construction_plan.projected(tracks)
		if _plan_protected(cell) or not working.has(cell): return
		var next: Variant = TrackGeometry.next_switch_variant(working[cell])
		if next != null: construction_plan.stage({cell: next}, tracks)
		return
	_rebuild_reservations()
	if reservations.owners.has(cell):
		_show_notice("Track reserved by train #%d; wait until it clears." % int(reservations.owners[cell]))
		return
	if not _can_demolish(cell):
		_show_notice("Click a straight piece of track to place a switch.")
		return

	var next: Variant = TrackGeometry.next_switch_variant(tracks[cell])

	if next == null:
		_show_notice("Switches can only replace straight track.")
		return

	_submit_command("set_tile", {"x": cell.x, "y": cell.y, "tile": next})


# Cycling retains the original two-port connection, whether straight or curved.
# Removing a switch restores that base.
func _execute_set_tile(data: Dictionary) -> void:
	_rebuild_reservations()
	var cell := Vector2i(int(data["x"]), int(data["y"]))
	var new_tile: Variant = data["tile"]

	if not _can_demolish(cell) or not _is_valid_track_type(new_tile):
		return

	var old_tile: Variant = tracks[cell]
	var old_base: Variant = TrackGeometry.switch_base(old_tile)
	var new_base: Variant = TrackGeometry.switch_base(new_tile)

	if old_base == null or new_base == null or not TrackGeometry.same_connections(old_base, new_base):
		return

	var cost: int = 0
	var change: String = "changed"

	if not TrackGeometry.is_switch(old_tile) and TrackGeometry.is_switch(new_tile):
		cost = SWITCH_COST
		change = "placed"
	elif TrackGeometry.is_switch(old_tile) and not TrackGeometry.is_switch(new_tile):
		cost = -SWITCH_COST
		change = "removed"

	if cost > 0 and money < cost:
		_show_notice("Insufficient funds: a switch costs £%d, available £%d." % [cost, money])
		return

	tracks[cell] = new_tile
	money -= cost
	total_construction_cost += maxi(cost, 0)
	_record_construction_change({cell: old_tile}, {cell: new_tile}, -cost, maxi(cost, 0))
	_record_event(EventLog.SWITCH_CHANGED, "player", {"change": change, "x": cell.x, "y": cell.y, "cost": cost})
	_check_route()

	match change:
		"placed": _show_notice("Switch placed for £%d. Click it again to change it." % cost)
		"removed": _show_notice("Switch removed. Refunded £%d." % -cost)
		_: _show_notice("Switch changed.")

	queue_redraw()


# Rules are checked again here because time may have passed since the click.
func _execute_build(data: Dictionary) -> void:
	var changes: Dictionary = {}

	for entry in data["cells"]:
		changes[Vector2i(int(entry[0]), int(entry[1]))] = entry[2]

	_rebuild_reservations()
	for entry in data.get("expected", []):
		var cell := Vector2i(int(entry[0]), int(entry[1]))
		if not ConstructionPlan._same(tracks.get(cell), entry[2]):
			_show_notice("Track changed before this stroke was applied. Redraw it.")
			return
	var transaction = ConstructionPlan.new({"track": TRACK_BUILD_COST, "refund": TRACK_REFUND, "switch": SWITCH_COST})
	transaction.stage(changes, tracks)
	var error: String = transaction.validate(tracks, reservations.owners, track_signals, Vector2i(MAP_WIDTH, MAP_HEIGHT), _plan_protected, money)
	if not error.is_empty():
		_show_notice(error)
		return
	var new_count: int = 0
	for cell in changes:
		if not tracks.has(cell): new_count += 1
	var cost: int = int(transaction.quote().net)

	var before: Dictionary = {}
	for cell in changes:
		before[cell] = tracks.get(cell)
		tracks[cell] = changes[cell]
	money -= cost
	total_construction_cost += cost
	_record_construction_change(before, changes, -cost, cost)
	_record_event(EventLog.TRACK_BUILT, "player", {"tiles": changes.size(), "new_tiles": new_count, "cost": cost})
	_check_route()
	_show_notice("Built %d new tiles for £%d; connections adjusted automatically." % [new_count, cost])
	queue_redraw()


func _generate_passengers(delta: float) -> void:
	passenger_timer += delta
	while passenger_timer >= PASSENGER_INTERVAL:
		passenger_timer -= PASSENGER_INTERVAL
		for key in ServiceRoutes.STATIONS:
			# Returned passengers may exceed normal station capacity. Never discard
			# that queue while limiting new arrivals.
			_set_waiting(key, maxi(_waiting(key), mini(_waiting(key) + PASSENGERS_PER_BATCH, MAX_STATION_QUEUE)))


func _board_passengers() -> void:
	var key: String = services["passenger"]["stops"][passenger_stop_index]
	var boarding: int = mini(_waiting(key), _get_train_capacity() - passengers_on_train)
	_set_waiting(key, _waiting(key) - boarding)
	passengers_on_train += boarding


func _unload_passengers() -> void:
	passengers_delivered += passengers_on_train
	money += passengers_on_train * TICKET_PRICE
	passengers_on_train = 0

func _charge_operating_cost(delta: float) -> void:
	operating_timer += delta

	while operating_timer >= 1.0:
		operating_timer -= 1.0
		var cost: int = Fleet.running_cost(Fleet.assigned(fleet, "passenger"))
		money -= cost
		total_operating_cost += cost


func _show_notice(message: String) -> void:
	notice = message
	notice_remaining = 4.0
	
func _get_preview_cost() -> int:
	if inspect_mode or not is_dragging or demolition_mode:
		return 0
	return _build_plan_cost()


func _build_plan_cost() -> int:
	return int(build_plan.get("new_count", 0)) * TRACK_BUILD_COST + int(build_plan.get("switch_count", 0)) * SWITCH_COST


func _save_game() -> void:
	if not construction_plan.is_empty():
		_show_notice("Apply or discard the construction draft before saving.")
		return
	if is_dragging:
		_show_notice("Finish or cancel track placement before saving.")
		return

	# Commands still waiting for the next step would otherwise be lost.
	for command in command_queue.drain(sim_clock.tick + 1):
		_execute_command(command)
	_sync_fleet_upgrades()
	var saved_tracks: Array = []

	for cell in tracks:
		saved_tracks.append([
			cell.x,
			cell.y,
			tracks[cell]
		])

	var state: Dictionary = {}

	for field in SAVE_FIELDS:
		state[field] = get(field)

	var data: Dictionary = {
		"version": SAVE_VERSION,
		"runtime": _saved_runtime_routes(),
		"passenger_services": _saved_passenger_services(),
		"signals": _saved_signals(),
		"tracks": saved_tracks,
		"switches": _saved_switches(),
		"route_distance": route_distance,
		"state": state,
		"freight": freight_train.save_state(),
		"scenario_stage": scenario_goals.current_index,
		"services": services.duplicate(true),
		"fleet": fleet.duplicate(true),
		"sim": {
			"clock": sim_clock.save_state(),
			"rng": sim_rng.save_state(),
			"events": event_log.save_state(),
			"commands": command_queue.save_state()
		}
	}

	# Prepare the new save before touching the existing one.
	var file := FileAccess.open(SAVE_TEMP_PATH, FileAccess.WRITE)

	if file == null:
		_show_notice("Could not open the temporary save file.")
		return

	file.store_string(JSON.stringify(data, "\t", true, true))
	file.flush()

	var write_error: Error = file.get_error()
	file.close()

	if write_error != OK:
		_show_notice("Saving failed while writing the file.")
		return

	# Preserve the previous manual save.
	if FileAccess.file_exists(SAVE_PATH):
		var backup_error: Error = DirAccess.copy_absolute(
			ProjectSettings.globalize_path(SAVE_PATH),
			ProjectSettings.globalize_path(SAVE_BACKUP_PATH)
		)

		if backup_error != OK:
			_show_notice("Could not create a backup. Save cancelled.")
			return

	# Replace the main save only after writing and backup succeed.
	var rename_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(SAVE_TEMP_PATH),
		ProjectSettings.globalize_path(SAVE_PATH)
	)

	if rename_error != OK:
		_show_notice("Could not replace the previous save.")
		return

	_show_notice("Game saved.")
	
# [[x, y, state], ...] for every switch tile.
func _saved_switches() -> Array:
	var saved: Array = []

	for cell in tracks:
		if TrackGeometry.is_switch(tracks[cell]):
			saved.append([cell.x, cell.y, int(switch_states.get(cell, 0))])

	return saved


# Whole-list check: every entry is a switch tile in `checked_tracks`, with
# state 0 or 1, and no tile appears twice.
func _is_valid_switch_list(value: Variant, checked_tracks: Dictionary) -> bool:
	if not value is Array:
		return false

	var seen: Dictionary = {}

	for entry in value:
		if not entry is Array or entry.size() != 3:
			return false

		for part in entry:
			if not _is_valid_number(part) or float(part) != floor(float(part)):
				return false

		var cell := Vector2i(int(entry[0]), int(entry[1]))

		if seen.has(cell) or not checked_tracks.has(cell) or not TrackGeometry.is_switch(checked_tracks[cell]):
			return false

		if int(entry[2]) != 0 and int(entry[2]) != 1:
			return false

		seen[cell] = true

	return true


func _is_valid_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false

	return is_finite(float(value))


func _is_valid_save(data: Dictionary) -> bool:
	if not ServiceRoutes.is_valid(data.get("services")) or not Fleet.is_valid(data.get("fleet")):
		return false
	if not _valid_service_assignments(data["services"], data["fleet"]): return false
	var extra: Variant = data.get("passenger_services")
	if not extra is Dictionary: return false
	for key in data["services"]:
		if key in ["passenger", "freight"]: continue
		var assigned := Fleet.assigned(data["fleet"], key)
		if PassengerService.from_save(key, extra.get(key), data["services"][key], Fleet.capacity(assigned)) == null: return false
	if extra.size() != data["services"].size() - 2: return false
	var sim: Variant = data.get("sim")
	if not sim is Dictionary:
		return false
	if not SimClock.is_valid_state(sim.get("clock")):
		return false
	if not SimRng.is_valid_state(sim.get("rng")):
		return false
	if not EventLog.is_valid_state(sim.get("events")):
		return false
	# Command queue is required for v17+, optional for v16.
	var saved_version: Variant = data.get("version")
	if not _is_valid_number(saved_version):
		return false
	var version_number: float = float(saved_version)
	if version_number != floor(version_number):
		return false
	var version: int = int(version_number)
	if version >= 17:
		if not CommandQueue.is_valid_state(sim.get("commands")):
			return false

	if version_number != float(SAVE_VERSION):
		return false

	if not RuntimeRoutes.valid_state(data.get("runtime"), data.get("services", {})):
		return false
	if not data.get("signals") is Array:
		return false
	if not data.get("tracks") is Array:
		return false

	if not data.get("state") is Dictionary:
		return false
	if not data.get("freight") is Dictionary:
		return false

	if version >= 3:
		if not _is_valid_number(data.get("route_distance")):
			return false

		if float(data["route_distance"]) < 0.0:
			return false
	else:
		if not _is_valid_number(data.get("train_x")):
			return false

		var train_x: float = float(data["train_x"])

		if train_x < _cell_center(STATION_A).x:
			return false

		if train_x > _cell_center(STATION_B).x:
			return false

	var state: Dictionary = data["state"]

	for field in SAVE_FIELDS:
		if not state.has(field):
			return false

		var current_value: Variant = get(field)
		var saved_value: Variant = state[field]

		if typeof(current_value) == TYPE_BOOL:
			if typeof(saved_value) != TYPE_BOOL:
				return false
		else:
			if not _is_valid_number(saved_value):
				return false

			var number: float = float(saved_value)

			# Keep values within a reasonable range for this prototype.
			if absf(number) > 1_000_000_000.0:
				return false

			if typeof(current_value) == TYPE_INT:
				if number != floor(number):
					return false

			if field != "money" and number < 0.0:
				return false

	if int(state["passenger_stop_index"]) >= data["services"]["passenger"]["stops"].size():
		return false
	var saved_capacity_level: int = int(state["capacity_upgrade_level"])
	var saved_speed_level: int = int(state["speed_upgrade_level"])

	if saved_capacity_level < 0 or saved_capacity_level > MAX_CAPACITY_LEVEL:
		return false

	if saved_speed_level < 0 or saved_speed_level > MAX_SPEED_LEVEL:
		return false

	var saved_passenger: Dictionary = Fleet.assigned(data["fleet"], "passenger")
	var saved_freight: Dictionary = Fleet.assigned(data["fleet"], "freight")
	if int(saved_passenger["capacity_level"]) != saved_capacity_level or int(saved_passenger["speed_level"]) != saved_speed_level:
		return false
	for field in ["capacity_level", "speed_level"]:
		if not _is_valid_number(data["freight"].get(field)) or float(data["freight"][field]) != float(saved_freight[field]):
			return false
	var saved_capacity: int = Fleet.capacity(saved_passenger)

	if float(state["passengers_on_train"]) > saved_capacity:
		return false

	if float(state["wait_remaining"]) > STATION_WAIT:
		return false

	if float(state["passenger_timer"]) >= PASSENGER_INTERVAL:
		return false

	if float(state["operating_timer"]) >= 1.0:
		return false
	if int(state["forest_stock"]) > MAX_FOREST_STOCK:
		return false

	if int(state["logs_produced"]) < int(state["forest_stock"]):
		return false

	if float(state["log_production_timer"]) >= LOG_PRODUCTION_INTERVAL:
		return false

	var checked_tracks: Dictionary = {}

	for entry in data["tracks"]:
		if not entry is Array:
			return false

		if entry.size() != 3:
			return false

		if not _is_valid_number(entry[0]):
			return false

		if not _is_valid_number(entry[1]):
			return false

		if not _is_valid_track_type(entry[2]):
			return false

		var x: float = float(entry[0])
		var y: float = float(entry[1])

		if x != floor(x) or y != floor(y):
			return false

		if x < 0 or x > 10000:
			return false

		if y < 0 or y > 10000:
			return false

		var cell := Vector2i(int(x), int(y))

		if checked_tracks.has(cell):
			return false

		checked_tracks[cell] = entry[2]

	if not _is_valid_signal_list(data["signals"], checked_tracks): return false
	if not _is_valid_switch_list(data.get("switches"), checked_tracks):
		return false

	# Every facility must retain its horizontal platform track.
	for station in [STATION_A, STATION_B, STATION_C, FOREST_SITE, CARGO_TERMINAL]:
		if not checked_tracks.has(station):
			return false

		if checked_tracks[station] != false:
			return false
	if not _is_valid_number(data.get("scenario_stage")):
		return false

	var saved_stage: float = float(data["scenario_stage"])

	if saved_stage != floor(saved_stage):
		return false

	if saved_stage < 0.0 or saved_stage > ScenarioGoals.OBJECTIVES.size():
		return false
	return true
	
func _load_game(save_path: String = SAVE_PATH) -> void:
	if not FileAccess.file_exists(save_path):
		_show_notice("No saved game at this location yet.")
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		_show_notice("Could not open the saved game.")
		return
	var parser := JSON.new()
	var contents: String = file.get_as_text()
	file.close()
	if parser.parse(contents) != OK or not parser.data is Dictionary:
		_show_notice("The save file could not be read.")
		return
	var migration: Dictionary = SaveMigrations.migrate(parser.data)
	if not migration["ok"]:
		_show_notice(migration["error"])
		return
	var data: Dictionary = migration["data"]
	if not _is_valid_save(data):
		_show_notice("The save file is damaged or incompatible.")
		return
	var loaded_tracks: Dictionary = {}
	for entry in data["tracks"]:
		var cell := Vector2i(int(entry[0]), int(entry[1]))
		if not _is_inside_map(cell) or _is_station_space(cell):
			_show_notice("Save contains track outside buildable ground.")
			return
		loaded_tracks[cell] = entry[2]
	var runtime: Dictionary = data["runtime"]
	var saved_passenger := RuntimeRoutes.decode(runtime["passenger_cells"])
	var built: Dictionary = ServiceRoutes.build(loaded_tracks, data["services"]["passenger"]["stops"], float(TILE_SIZE), data["services"]["passenger"].get("waypoints", {}), data["services"]["passenger"].get("mode", "shuttle"), data["services"]["passenger"].get("platforms", {})) if saved_passenger.is_empty() else RuntimeRoutes.passenger_path(saved_passenger, data["services"]["passenger"]["stops"], float(TILE_SIZE), data["services"]["passenger"].get("waypoints", {}), data["services"]["passenger"].get("mode", "shuttle"), data["services"]["passenger"].get("platforms", {}))
	var loaded_cells: Array[Vector2i] = []
	loaded_cells.assign(built["cells"])
	var loaded_path: Curve2D = built["path"]
	var state: Dictionary = data["state"]
	var loaded_distance: float = float(data["route_distance"])
	var stop_index: int = int(state["passenger_stop_index"])
	if loaded_cells.is_empty():
		if loaded_distance > 0.001 or int(state["passengers_on_train"]) > 0 or stop_index != 0:
			_show_notice("Save contains a train without a valid route.")
			return
	else:
		var distances: Array = built["distances"]
		var returning: bool = runtime["passenger_returning"]
		if returning and int(runtime["passenger_return_stop"]) != stop_index:
			_show_notice("Invalid recovery origin.")
			return
		var original_forward: bool = not state["travelling_to_b"] if returning else state["travelling_to_b"]
		if data["services"]["passenger"].get("mode", "shuttle") == "loop" and not original_forward:
			_show_notice("Saved loop train direction is invalid.")
			return
		var next_stop: int = stop_index + (1 if original_forward else -1)
		if next_stop < 0 or next_stop >= distances.size():
			_show_notice("Saved train stop direction is invalid.")
			return
		var lower: float = minf(distances[stop_index], distances[next_stop])
		var upper: float = maxf(distances[stop_index], distances[next_stop])
		if loaded_distance < lower - 0.001 or loaded_distance > upper + 0.001:
			_show_notice("Saved train position is outside its current leg.")
			return
		if (state["train_needs_boarding"] or float(state["wait_remaining"]) > 0.0) and absf(loaded_distance - distances[stop_index]) > 0.001:
			_show_notice("Saved train is waiting away from a station.")
			return
	var loaded_freight_cells: Array[Vector2i] = RuntimeRoutes.decode(runtime["freight_cells"])
	if loaded_freight_cells.is_empty(): loaded_freight_cells = WaypointRouter.find_route(loaded_tracks, FOREST_SITE, CARGO_TERMINAL, data["services"]["freight"].get("waypoints", {}).get("forest>terminal", []))
	var loaded_freight_path: Curve2D = RailRouter.make_path(loaded_freight_cells, float(TILE_SIZE))
	if not FreightTrain.is_valid_state(data["freight"], loaded_freight_path.get_baked_length(), int(Fleet.MODELS[Fleet.assigned(data["fleet"], "freight")["model"]]["capacity"]) + Consists.extra_capacity(Fleet.assigned(data["fleet"], "freight"))):
		_show_notice("Saved freight train state is invalid.")
		return
	var loaded_services := ServiceRoutes.from_save(data["services"])
	var loaded_extra: Dictionary = {}
	for key in data["passenger_services"]:
		loaded_extra[key] = PassengerService.from_save(key, data["passenger_services"][key], loaded_services[key], Fleet.capacity(Fleet.assigned(data["fleet"], key)))
	# Validate full bodies even when only the original passenger/freight pair exists.
	var footprints: Dictionary = {}
	var helper := Reservations.new()
	var positions: Array = [
		{"mode": loaded_services.passenger.get("mode", "shuttle"), "length": Fleet.length(Fleet.assigned(data.fleet, "passenger")), "cells": loaded_cells, "path": _reservation_path(loaded_path, _cell_center(ServiceRoutes.stop_cell(loaded_services.passenger.get("platforms", {}), loaded_services.passenger.stops[0]))), "distance": loaded_distance},
		{"length": Fleet.length(Fleet.assigned(data.fleet, "freight")), "cells": loaded_freight_cells, "path": _reservation_path(loaded_freight_path, _cell_center(FOREST_SITE)), "distance": float(data["freight"]["distance"])}
	]
	for key in loaded_extra: positions.append({"mode": loaded_services[key].get("mode", "shuttle"), "length": Fleet.length(Fleet.assigned(data.fleet, key)), "cells": loaded_extra[key].cells, "path": loaded_extra[key].path, "distance": loaded_extra[key].distance})
	for train in positions:
		var shape_error := Consists.route_shape_error(train.path, train.cells, train.length, train.get("mode", "shuttle"))
		if not shape_error.is_empty():
			_show_notice(shape_error)
			return
		for cell in helper.footprint(train.path, train.distance, float(TILE_SIZE), train.length):
			if footprints.has(cell):
				_show_notice("Save contains overlapping train bodies.")
				return
			footprints[cell] = true
	# Commit only after validating every service and train.
	tracks = loaded_tracks
	track_signals = {}
	for entry in data["signals"]: track_signals[Vector2i(int(entry[0]), int(entry[1]))] = str(entry[2])
	switch_states = {}
	for entry in data["switches"]:
		switch_states[Vector2i(int(entry[0]), int(entry[1]))] = int(entry[2])
	freight_route_cells = loaded_freight_cells
	services = loaded_services
	passenger_services = loaded_extra
	fleet = Fleet.from_save(data["fleet"])
	_apply_fleet_specs()
	route_cells = loaded_cells
	route_path = loaded_path
	stop_distances.assign(built["distances"])
	passenger_route_error = built["error"]
	passenger_returning = runtime["passenger_returning"]
	passenger_return_stop = int(runtime["passenger_return_stop"])
	passenger_held = runtime["passenger_held"]
	for field in SAVE_FIELDS:
		match typeof(get(field)):
			TYPE_INT: set(field, int(state[field]))
			TYPE_FLOAT: set(field, float(state[field]))
			TYPE_BOOL: set(field, state[field])
	route_distance = loaded_distance
	is_dragging = false
	_update_train_transform()
	freight_train.route_cells = loaded_freight_cells.duplicate()
	freight_train.route_path = loaded_freight_path
	freight_train.recovery_returning = runtime["freight_returning"]
	freight_train.held = runtime["freight_held"]
	freight_train.restore_state(data["freight"])
	_refresh_directional_routes(false)
	_reset_traffic_state()
	_rebuild_reservations()
	scenario_goals.current_index = int(data["scenario_stage"])
	sim_clock.restore_state(data["sim"]["clock"])
	sim_rng.restore_state(data["sim"]["rng"])
	event_log.restore_state(data["sim"]["events"])
	notifications.reset()
	construction_plan.clear()
	if train_inspector != null: train_inspector.hide()
	object_pins.clear()
	corridor_pick = 0
	corridor_cells.clear()
	planning_mode = false
	inspection_panel.plan_toggle.set_pressed_no_signal(false)
	traffic_metrics.reset()
	traffic_wait_samples.clear()

	if data["sim"].has("commands") and CommandQueue.is_valid_state(data["sim"]["commands"]):
		command_queue.restore_state(data["sim"]["commands"])
	else:
		command_queue.clear()
	var loaded_notice: String = "Previous save loaded." if save_path == SAVE_BACKUP_PATH else "Game loaded."
	if migration["migrated"]:
		loaded_notice += " Upgraded from save version %d; saving again keeps the new format." % int(migration["from_version"])
	_show_notice(loaded_notice)
	_update_instructions()
	_clear_construction_history()
	_update_history_controls()
	queue_redraw()


func _is_valid_track_type(value: Variant) -> bool:
	var port_count: int = TrackGeometry.connections(value).size()
	return port_count >= 2 and port_count <= 4


func _update_train_transform() -> void:
	if route_path.point_count < 2:
		train_position = _cell_center(ServiceRoutes.stop_cell(services["passenger"].get("platforms", {}), services["passenger"]["stops"][0]))
		train_heading = 0.0
		return

	var route_length: float = route_path.get_baked_length()

	train_position = route_path.sample_baked(route_distance)

	var before: Vector2 = route_path.sample_baked(
		maxf(0.0, route_distance - 1.0)
	)
	var after: Vector2 = route_path.sample_baked(
		minf(route_length, route_distance + 1.0)
	)

	var direction: Vector2 = after - before

	if not travelling_to_b:
		direction = -direction

	train_heading = direction.angle()
func _setup_toolbar() -> void:
	straight_button.pressed.connect(_select_straight_track)
	curve_button.pressed.connect(_select_curved_track)
	rotate_button.hide()
	pause_button.pressed.connect(_toggle_pause)
	save_button.pressed.connect(_save_game)
	load_button.pressed.connect(_load_game)
	folder_button.pressed.connect(_open_save_folder)
	inspect_button.pressed.connect(_toggle_inspect_mode)
	backup_button.pressed.connect(_load_game.bind(SAVE_BACKUP_PATH))
	for button in [straight_button, curve_button, pause_button, save_button, load_button, folder_button, inspect_button, backup_button]:
		button.focus_mode = Control.FOCUS_NONE

	switch_button = Button.new()
	switch_button.text = "Switch"
	switch_button.toggle_mode = true
	switch_button.focus_mode = Control.FOCUS_NONE
	switch_button.tooltip_text = "Switch tool: click a straight track to add a switch (£%d); click it again to cycle its shape, and the last click removes it" % SWITCH_COST
	switch_button.pressed.connect(_toggle_switch_tool)
	$Interface/HeaderBox/Toolbar.add_child(switch_button)
	remove_button = Button.new()
	remove_button.text = "Remove"
	remove_button.toggle_mode = true
	remove_button.focus_mode = Control.FOCUS_NONE
	remove_button.tooltip_text = "Remove track: left-drag. Or right-drag/hold. Shortcut: " + InputActions.key_label(InputActions.SELECT_REMOVE)
	remove_button.pressed.connect(_select_remove_tool)
	$Interface/HeaderBox/Toolbar.add_child(remove_button)
	_update_toolbar()


func _reset_track_tools(keep_right_gesture: bool = false) -> void:
	if not keep_right_gesture:
		right_pending = false
		right_removing = false
	_clear_direct_inspection()
	inspect_mode = false
	switch_tool_mode = false
	signal_tool_mode = false
	waypoint_tool_mode = false
	demolition_mode = false
	draw_track_mode = false
	is_dragging = false
	is_panning = false
	corridor_pick = 0
	build_stroke.clear()
	build_plan.clear()
	demolition_cells.clear()
	demolition_blocked.clear()
	_close_station_inspector()
	for window in [traffic_dialog, train_inspector, route_editor, fleet_editor, problems_dialog, object_browser]:
		if window != null: window.hide()
	_update_toolbar()
	queue_redraw()


func _tool_window_input(event: InputEvent, window: Window) -> void:
	if event.is_action_pressed(InputActions.RESET_TOOL) or event.is_action_released(InputActions.RESET_TOOL):
		_right_mouse_input(event, true)
		window.set_input_as_handled()


func _right_mouse_input(event: InputEvent, in_window: bool = false) -> bool:
	if event.is_action_pressed(InputActions.RESET_TOOL):
		if _modal_open() and not in_window: return false
		_clear_direct_inspection()
		is_dragging = false
		is_panning = false
		build_plan.clear()
		demolition_cells.clear()
		demolition_blocked.clear()
		right_pending = true
		right_removing = false
		right_elapsed = 0.0
		right_map_origin = not in_window and not _mouse_is_over_interface() and _is_inside_map(_mouse_to_cell())
		right_start_point = to_local(_pointer_world())
		right_start_cell = _mouse_to_cell()
		get_viewport().set_input_as_handled()
		return true
	if event.is_action_released(InputActions.RESET_TOOL) and right_pending:
		_advance_right_gesture(0.0)
		if right_removing and not _mouse_is_over_interface() and not _modal_open():
			_finish_demolition(_mouse_to_cell())
		_reset_track_tools()
		get_viewport().set_input_as_handled()
		return true
	if event is InputEventMouseMotion and right_pending:
		_advance_right_gesture(0.0)
		if right_removing: _collect_demolition_cells(_mouse_to_cell())
		get_viewport().set_input_as_handled()
		return true
	return false


func _advance_right_gesture(delta: float) -> void:
	if not right_pending: return
	# Real UI time, independent of pause, game speed and the simulation clock.
	# Dialog/toolbar presses never turn into deletion of the map beneath them.
	right_elapsed += maxf(delta, 0.0)
	if right_map_origin and _modal_open():
		_cancel_right_gesture()
		return
	if right_map_origin and _mouse_is_over_interface():
		_reset_track_tools()
		return
	if right_removing or not right_map_origin: return
	var motion_pixels: float = (to_local(_pointer_world()) - right_start_point).length() * camera.zoom.x * applied_ui_scale
	if right_elapsed < RIGHT_HOLD_SECONDS and motion_pixels < RIGHT_DRAG_PIXELS: return
	_reset_track_tools(true)
	right_removing = true
	demolition_mode = true
	is_dragging = true
	demolition_last_cell = right_start_cell
	_collect_demolition_cells(right_start_cell)
	_collect_demolition_cells(_mouse_to_cell())
	_update_toolbar()


func _cancel_right_gesture() -> void:
	if not right_pending: return
	var removing: bool = right_removing
	right_pending = false
	right_removing = false
	is_dragging = false
	demolition_cells.clear()
	demolition_blocked.clear()
	if removing:
		demolition_mode = false
		_update_toolbar()


func _select_remove_tool() -> void:
	_reset_track_tools()
	demolition_mode = true
	_update_toolbar()


func _select_straight_track() -> void:
	demolition_mode = false
	inspect_mode = false
	switch_tool_mode = false
	signal_tool_mode = false
	waypoint_tool_mode = false
	_close_station_inspector()
	is_dragging = false
	draw_track_mode = false
	build_plan.clear()
	_update_toolbar()


func _select_curved_track() -> void:
	demolition_mode = false
	inspect_mode = false
	switch_tool_mode = false
	signal_tool_mode = false
	waypoint_tool_mode = false
	_close_station_inspector()
	is_dragging = false
	draw_track_mode = true
	build_plan.clear()
	_update_toolbar()


func _toggle_switch_tool() -> void:
	demolition_mode = false
	signal_tool_mode = false
	waypoint_tool_mode = false
	switch_tool_mode = not switch_tool_mode
	inspect_mode = false
	_close_station_inspector()
	is_dragging = false
	demolition_cells.clear()
	demolition_blocked.clear()
	build_plan.clear()
	_update_toolbar()


func _toggle_pause() -> void:
	paused = not paused
	_rebuild_reservations()
	if not paused:
		_clear_construction_history()
	_update_toolbar()


func _open_save_folder() -> void:
	var error: Error = OS.shell_open(
		ProjectSettings.globalize_path("user://")
	)

	if error != OK:
		_show_notice("Could not open the save folder.")


func _update_toolbar() -> void:
	inspect_button.set_pressed_no_signal(inspect_mode)

	straight_button.set_pressed_no_signal(
		not demolition_mode and not inspect_mode and not switch_tool_mode and not signal_tool_mode and not waypoint_tool_mode and not draw_track_mode
	)

	curve_button.set_pressed_no_signal(
		not demolition_mode and not inspect_mode and not switch_tool_mode and not signal_tool_mode and not waypoint_tool_mode and draw_track_mode
	)

	if waypoint_button != null:
		waypoint_button.set_pressed_no_signal(waypoint_tool_mode)
	if signal_button != null:
		signal_button.set_pressed_no_signal(signal_tool_mode)
	if switch_button != null:
		switch_button.set_pressed_no_signal(switch_tool_mode)
	if remove_button != null: remove_button.set_pressed_no_signal(demolition_mode)
	pause_button.set_pressed_no_signal(paused)

	pause_button.text = ""

	if toolbar_icon_textures.size() == 10:
		pause_button.icon = toolbar_icon_textures[5 if paused else 4]

	pause_button.tooltip_text = "%s — %s" % [
		"Resume simulation" if paused else "Pause simulation",
		InputActions.key_label(InputActions.TOGGLE_PAUSE)
	]

	save_button.disabled = is_dragging
	load_button.disabled = is_dragging
	backup_button.disabled = is_dragging
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.BUILD) and right_pending:
		_reset_track_tools()
		get_viewport().set_input_as_handled()
		return
	if _right_mouse_input(event): return
	if _modal_open():
		_clear_direct_inspection()
		return

	if event.is_action_pressed(InputActions.CAMERA_PAN):
		_cancel_right_gesture()
		if not _mouse_is_over_interface():
			_clear_direct_inspection()
			is_panning = true
			is_dragging = false
			get_viewport().set_input_as_handled()

	if event.is_action_released(InputActions.CAMERA_PAN):
		is_panning = false
		get_viewport().set_input_as_handled()

	if event is InputEventMouseButton:
		if event.is_action_released(InputActions.BUILD) and _mouse_is_over_interface(): _clear_direct_inspection()
		# Cancel construction if its drag ends over the interface.
		if (
			event.is_action_released(InputActions.BUILD)
			and is_dragging
			and _mouse_is_over_interface()
		):
			is_dragging = false
			demolition_cells.clear()
			demolition_blocked.clear()
			get_viewport().set_input_as_handled()
			return

		# Avoid building while moving the camera.
		if is_panning:
			get_viewport().set_input_as_handled()
			return

		if event.pressed and not _mouse_is_over_interface():
			if event.is_action_pressed(InputActions.ZOOM_IN):
				if not is_dragging and not right_pending:
					_zoom_camera(ZOOM_STEP)

				get_viewport().set_input_as_handled()

			elif event.is_action_pressed(InputActions.ZOOM_OUT):
				if not is_dragging and not right_pending:
					_zoom_camera(1.0 / ZOOM_STEP)

				get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and is_panning:
		camera.position -= event.relative / camera.zoom.x
		camera.force_update_scroll()
		get_viewport().set_input_as_handled()
func _reset_camera() -> void:
	camera.zoom = Vector2.ONE / applied_ui_scale
	camera.position = get_viewport_rect().size / camera.zoom / 2.0
	camera.force_update_scroll()


func _zoom_camera(factor: float) -> void:
	var mouse_before: Vector2 = get_global_mouse_position()

	# The player's zoom excludes the interface scale, so the map keeps its
	# size on screen when only the interface is enlarged.
	var new_zoom: float = clampf(
		camera.zoom.x * applied_ui_scale * factor,
		MIN_ZOOM,
		MAX_ZOOM
	) / applied_ui_scale

	camera.zoom = Vector2(new_zoom, new_zoom)
	camera.force_update_scroll()

	# Keep the map location beneath the cursor in the same place.
	var mouse_after: Vector2 = get_global_mouse_position()
	camera.position += mouse_before - mouse_after
	camera.force_update_scroll()


func _mouse_is_over_interface() -> bool:
	return get_viewport().gui_get_hovered_control() != null
func _setup_station_inspector() -> void:
	station_panel = PanelContainer.new()
	station_panel.name = "StationInspector"
	$Interface.add_child(station_panel)

	var scale: float = GameSettings.ui_scale
	station_panel.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT
	)
	station_panel.offset_left = -304.0 * scale
	station_panel.offset_right = -16.0 * scale
	station_panel.offset_top = 176.0 * scale
	station_panel.anchor_bottom = 1.0
	station_panel.offset_bottom = -16.0 * scale
	station_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	station_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	station_title = Label.new()
	station_title.add_theme_font_size_override("font_size", 22)
	content.add_child(station_title)

	station_details = Label.new()
	station_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(station_details)
	
	capacity_upgrade_button = Button.new()
	capacity_upgrade_button.focus_mode = Control.FOCUS_NONE
	capacity_upgrade_button.pressed.connect(_upgrade_capacity)
	content.add_child(capacity_upgrade_button)

	speed_upgrade_button = Button.new()
	speed_upgrade_button.focus_mode = Control.FOCUS_NONE
	speed_upgrade_button.pressed.connect(_upgrade_speed)
	content.add_child(speed_upgrade_button)
	freight_rule_label = Label.new()
	freight_rule_label.text = "Freight departure rule"
	content.add_child(freight_rule_label)

	freight_rule_option = OptionButton.new()
	freight_rule_option.focus_mode = Control.FOCUS_NONE

	freight_rule_option.add_item(
		"Depart with any logs",
		FreightTrain.LoadingRule.ANY
	)
	freight_rule_option.add_item(
		"Depart at least half-full",
		FreightTrain.LoadingRule.HALF
	)
	freight_rule_option.add_item(
		"Depart only when full",
		FreightTrain.LoadingRule.FULL
	)

	freight_rule_option.item_selected.connect(
		_on_freight_rule_selected
	)

	content.add_child(freight_rule_option)

	freight_rule_label.hide()
	freight_rule_option.hide()
	service_button = Button.new()
	service_button.focus_mode = Control.FOCUS_NONE
	service_button.pressed.connect(_toggle_selected_service)
	content.add_child(service_button)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_close_station_inspector)
	content.add_child(close_button)

	station_panel.hide()


func _toggle_inspect_mode() -> void:
	demolition_mode = false
	_clear_direct_inspection()
	inspect_mode = not inspect_mode
	switch_tool_mode = false
	signal_tool_mode = false
	waypoint_tool_mode = false
	is_dragging = false

	if not inspect_mode:
		station_panel.hide()
		selected_station = Vector2i(-1, -1)

	_update_toolbar()


func _close_station_inspector() -> void:
	station_panel.hide()
	selected_station = Vector2i(-1, -1)


func _inspect_station_at(cell: Vector2i) -> void:
	for station in [STATION_A, STATION_B, STATION_C, FOREST_SITE, CARGO_TERMINAL]:
		var inside_station_grounds: bool = (
			cell.x >= station.x - 1
			and cell.x <= station.x + 1
			and cell.y >= station.y - 2
			and cell.y < station.y
		)

		if cell == station or inside_station_grounds:
			selected_station = station
			if inspection_button != null: inspection_button.button_pressed = false
			station_panel.show()
			_update_station_inspector()
			return

	_close_station_inspector()


func _update_station_inspector() -> void:
	if not station_panel.visible:
		return
	_update_service_button()
	service_button.show()

	if selected_station == FOREST_SITE or selected_station == CARGO_TERMINAL:
		_update_freight_inspector()
		return

	if not passenger_services.is_empty():
		capacity_upgrade_button.hide()
		speed_upgrade_button.hide()
		service_button.hide()
		freight_rule_label.hide()
		freight_rule_option.hide()
		var key := _station_key(selected_station)
		var serving: PackedStringArray = []
		var states: PackedStringArray = []
		var incoming := 0
		for service in service_keys():
			if service == "freight" or not services[service].stops.has(key): continue
			var train := Fleet.assigned(fleet, service)
			serving.append("#%d %s" % [int(train.id), services[service].name])
			states.append(fleet_train_status(int(train.id)))
			if service == "passenger":
				if route_connected and services[service].stops[_next_passenger_stop()] == key: incoming += passengers_on_train
			else:
				var running = passenger_services[service]
				if running.connected and services[service].stops[running.next_stop()] == key: incoming += running.passengers
		station_title.text = ServiceRoutes.STATIONS[key].name
		station_details.text = "Services: %s\n\nWaiting passengers: %d\nIncoming passengers: %d\n\n%s\n\nManage individual trains and upgrades in Fleet." % [", ".join(serving) if not serving.is_empty() else "None", _waiting(key), incoming, "\n".join(states)]
		station_details.text += "\n\n" + _platform_text(selected_station)
		return
	capacity_upgrade_button.show()
	speed_upgrade_button.show()
	freight_rule_label.hide()
	freight_rule_option.hide()

	var station_key: String = _station_key(selected_station)
	var station_name: String = ServiceRoutes.STATIONS[station_key]["name"]
	var destination_name: String = services["passenger"]["name"]
	if not services["passenger"]["stops"].has(station_key):
		destination_name += " (not served)"
	var waiting: int = _waiting(station_key)
	var incoming: int = 0
	if route_connected and services["passenger"]["stops"][_next_passenger_stop()] == station_key:
		incoming = passengers_on_train

	var train_at_station: bool = (
		train_position.distance_to(_cell_center(selected_station)) < 0.5
	)

	var service_status: String = _passenger_service_status()

	if train_at_station:
		service_status += "\nTrain at platform"

	station_title.text = station_name

	station_details.text = (
		"Route: %s"
		+ "\n\nWaiting passengers: %d"
		+ "\nIncoming passengers: %d"
		+ "\n\nTrain: %s"
		+ "\nCapacity: %d passengers (%d/%d)"
		+ "\nSpeed: %.0f px/s (%d/%d)"
		+ "\n\n%s"
	) % [
		destination_name,
		waiting,
		incoming,
		Fleet.assigned(fleet, "passenger")["name"],
		_get_train_capacity(),
		capacity_upgrade_level,
		MAX_CAPACITY_LEVEL,
		_get_train_speed(),
		speed_upgrade_level,
		MAX_SPEED_LEVEL,
		service_status
	]
	station_details.text += "\n\n" + _platform_text(selected_station)

	_update_upgrade_button(
		capacity_upgrade_button,
		"Capacity",
		capacity_upgrade_level,
		MAX_CAPACITY_LEVEL,
		_get_capacity_upgrade_price(),
		"Adds %d passenger seats." % CAPACITY_PER_UPGRADE
	)

	_update_upgrade_button(
		speed_upgrade_button,
		"Speed",
		speed_upgrade_level,
		MAX_SPEED_LEVEL,
		_get_speed_upgrade_price(),
		"Adds %.0f pixels/second." % SPEED_PER_UPGRADE
	)
			
func _update_upgrade_button(
	button: Button,
	upgrade_name: String,
	level: int,
	maximum_level: int,
	price: int,
	benefit: String
) -> void:
	if level >= maximum_level:
		button.text = upgrade_name + ": fully upgraded"
		button.disabled = true
		button.tooltip_text = "All upgrades of this type are installed."
		return

	if upgrade_name.to_lower() == "speed":
		var service := "freight" if selected_station in [FOREST_SITE, CARGO_TERMINAL] else "passenger"
		var train := Fleet.assigned(fleet, service)
		var speed := freight_train.get_speed() if service == "freight" else _get_train_speed()
		if speed >= Consists.speed_limit(train):
			button.text = "Speed: stock limit"
			button.disabled = true
			button.tooltip_text = "Attached stock caps the speed. Remove it before buying another speed upgrade."
			return
	button.text = "%s + (£%d)" % [upgrade_name, price]
	button.disabled = not paused or money < price

	if not paused:
		button.tooltip_text = "Pause the game to upgrade."
	elif money < price:
		button.tooltip_text = "Requires £%d. %s" % [price, benefit]
	else:
		button.tooltip_text = benefit

func _draw_invalid_build_cell(cell: Vector2i) -> void:
	var origin: Vector2 = Vector2(cell) * TILE_SIZE
	var mark_color: Color = Palette.get_color(Palette.Role.BAD_MARK)
	draw_rect(Rect2(origin, Vector2.ONE * TILE_SIZE), Palette.get_color(Palette.Role.BAD_FILL))
	draw_line(origin + Vector2(6, 6), origin + Vector2(TILE_SIZE - 6, TILE_SIZE - 6), mark_color, 2.0)
	draw_line(origin + Vector2(TILE_SIZE - 6, 6), origin + Vector2(6, TILE_SIZE - 6), mark_color, 2.0)


func _remove_station_space_tracks(track_data: Dictionary) -> int:
	var removed_count: int = 0

	# Clear track from reserved building grounds.
	for cell in track_data.keys():
		if _is_station_space(cell):
			track_data.erase(cell)
			removed_count += 1

	# Install the new permanent horizontal loading tracks.
	for facility in [FOREST_SITE, CARGO_TERMINAL]:
		if track_data.has(facility):
			if track_data[facility] != false:
				track_data.erase(facility)
				removed_count += 1

		track_data[facility] = false

	return removed_count
func _get_train_capacity() -> int:
	return int(Fleet.MODELS[Fleet.assigned(fleet, "passenger")["model"]]["capacity"]) + capacity_upgrade_level * CAPACITY_PER_UPGRADE + Consists.extra_capacity(Fleet.assigned(fleet, "passenger"))


func _get_train_speed() -> float:
	return minf(float(Fleet.MODELS[Fleet.assigned(fleet, "passenger")["model"]]["speed"]) + speed_upgrade_level * SPEED_PER_UPGRADE, Consists.speed_limit(Fleet.assigned(fleet, "passenger")))

func _get_capacity_upgrade_price() -> int:
	return BASE_CAPACITY_UPGRADE_PRICE * (capacity_upgrade_level + 1)


func _get_speed_upgrade_price() -> int:
	return BASE_SPEED_UPGRADE_PRICE * (speed_upgrade_level + 1)


func _upgrade_capacity() -> void:
	if selected_station == FOREST_SITE or selected_station == CARGO_TERMINAL:
		_upgrade_freight_capacity()
		return
	if capacity_upgrade_level >= MAX_CAPACITY_LEVEL:
		_show_notice("Passenger capacity is fully upgraded.")
		return

	if not paused:
		_show_notice("Pause the game before upgrading.")
		return

	var price: int = _get_capacity_upgrade_price()

	if money < price:
		_show_notice("Insufficient funds. Capacity upgrade costs £%d." % price)
		return

	money -= price
	capacity_upgrade_level += 1
	total_vehicle_cost += price
	_sync_fleet_upgrades()
	_record_event(EventLog.UPGRADE_BOUGHT, "passenger", {"kind": "capacity", "level": capacity_upgrade_level, "price": price})

	_show_notice(
		"Capacity upgraded to %d passengers." % _get_train_capacity()
	)

	_update_station_inspector()


func _upgrade_speed() -> void:
	if selected_station == FOREST_SITE or selected_station == CARGO_TERMINAL:
		_upgrade_freight_speed()
		return
	if _get_train_speed() >= Consists.speed_limit(Fleet.assigned(fleet, "passenger")):
		_show_notice("Attached coaches already limit speed. Remove them before buying another speed upgrade.")
		return
	if speed_upgrade_level >= MAX_SPEED_LEVEL:
		_show_notice("Train speed is fully upgraded.")
		return

	if not paused:
		_show_notice("Pause the game before upgrading.")
		return

	var price: int = _get_speed_upgrade_price()

	if money < price:
		_show_notice("Insufficient funds. Speed upgrade costs £%d." % price)
		return

	money -= price
	speed_upgrade_level += 1
	total_vehicle_cost += price
	_sync_fleet_upgrades()
	_record_event(EventLog.UPGRADE_BOUGHT, "passenger", {"kind": "speed", "level": speed_upgrade_level, "price": price})
	_show_notice(
		"Speed upgraded to %.0f pixels/second." % _get_train_speed()
	)

	_update_station_inspector()

func _produce_logs(delta: float) -> void:
	log_production_timer += delta

	while log_production_timer >= LOG_PRODUCTION_INTERVAL:
		log_production_timer -= LOG_PRODUCTION_INTERVAL

		var free_storage: int = MAX_FOREST_STOCK - forest_stock
		var produced: int = mini(LOGS_PER_BATCH, free_storage)

		if produced > 0:
			forest_stock += produced
			logs_produced += produced

func _update_freight_inspector() -> void:
	capacity_upgrade_button.show()
	speed_upgrade_button.show()

	_update_upgrade_button(
		capacity_upgrade_button,
		"Capacity",
		freight_train.capacity_level,
		FreightTrain.MAX_CAPACITY_LEVEL,
		freight_train.get_capacity_upgrade_price(),
		"Adds %d log capacity." % FreightTrain.CAPACITY_PER_UPGRADE
	)

	_update_upgrade_button(
		speed_upgrade_button,
		"Speed",
		freight_train.speed_level,
		FreightTrain.MAX_SPEED_LEVEL,
		freight_train.get_speed_upgrade_price(),
		"Adds %.0f pixels/second." % FreightTrain.SPEED_PER_UPGRADE
	)
	freight_rule_label.show()
	freight_rule_option.show()

	var rule_index: int = freight_rule_option.get_item_index(
		freight_train.loading_rule
	)

	if rule_index >= 0:
		freight_rule_option.select(rule_index)
	var train_status: String = services["freight"]["name"] + " / " + Fleet.assigned(fleet, "freight")["name"] + " — " + freight_train.status_text()

	if paused:
		train_status = "Paused — " + train_status

	if selected_station == FOREST_SITE:
		station_title.text = "Forest"

		var production_status: String = "Producing"

		if forest_stock >= MAX_FOREST_STOCK:
			production_status = "Storage full"
		elif paused:
			production_status = "Paused"

		station_details.text = (
			"Produces: logs"
			+ "\nDestination: cargo terminal"
			+ "\n\nStored: %d / %d"
			+ "\nTotal produced: %d"
			+ "\nOn train: %d / %d"
			+ "\n\nProduction: %s"
			+ "\nFreight train: %s"
		) % [
			forest_stock,
			MAX_FOREST_STOCK,
			logs_produced,
			freight_train.cargo,
			freight_train.get_capacity(),
			production_status,
			train_status
		]
	else:
		station_title.text = "Cargo terminal"

		var operating_profit: int = freight_income - freight_operating_cost

		station_details.text = (
			"Accepts: logs"
			+ "\nPayment: £%d per log"
			+ "\n\nLogs delivered: %d"
			+ "\nFreight income: £%d"
			+ "\nOperating expenses: £%d"
			+ "\nOperating profit: £%d"
			+ "\n\nOn train: %d / %d"
			+ "\nRunning cost: £%d per second"
			+ "\n\nFreight train: %s"
		) % [
			LOG_DELIVERY_PRICE,
			logs_delivered,
			freight_income,
			freight_operating_cost,
			operating_profit,
			freight_train.cargo,
			freight_train.get_capacity(),
			freight_train.running_cost_per_second,
			train_status
		]
		station_details.text += (
		"\n\nCapacity upgrades: %d/%d"
		+ "\nSpeed: %.0f px/s"
		+ "\nSpeed upgrades: %d/%d"
	) % [
		freight_train.capacity_level,
		FreightTrain.MAX_CAPACITY_LEVEL,
		freight_train.get_speed(),
		freight_train.speed_level,
		FreightTrain.MAX_SPEED_LEVEL
	]
		
func _move_camera_with_keyboard(delta: float) -> void:
	if _modal_open():
		return
	# Avoid shifting an unfinished construction preview.
	if is_dragging or is_panning or right_pending:
		return

	var focused_control: Control = get_viewport().gui_get_focus_owner()

	if focused_control is LineEdit or focused_control is TextEdit:
		return

	var direction: Vector2 = Input.get_vector(
		&"camera_left",
		&"camera_right",
		&"camera_up",
		&"camera_down"
	)

	if direction == Vector2.ZERO:
		return

	var speed: float = KEYBOARD_PAN_SPEED

	if Input.is_action_pressed(InputActions.CAMERA_FAST):
		speed *= 2.0

	camera.position += direction * speed * delta / camera.zoom.x
	camera.force_update_scroll()
func _setup_freight_train() -> void:
	freight_train = FreightTrain.new()
	freight_train.name = "FreightTrain"
	freight_train.home_position = _cell_center(FOREST_SITE)
	freight_train.position = freight_train.home_position
	freight_train.delivered.connect(_on_logs_delivered)
	freight_train.operating_expense.connect(_on_freight_operating_expense)
	freight_train.arrived.connect(func(stop: String, _cargo: int) -> void:
		if freight_train.recovery_returning:
			_record_event(EventLog.TRAIN_RECOVERED, str(Fleet.assigned(fleet, "freight")["id"]), {"service": "freight", "stop": stop, "action": "returned to departure stop"}))

	freight_train.movement_guard = _freight_reserved_movement
	add_child(freight_train)
	_refresh_freight_route(route_cells)


func _find_freight_route(
	track_data: Dictionary,
	_passenger_cells: Array[Vector2i]
) -> Array[Vector2i]:
	return WaypointRouter.find_route(track_data, FOREST_SITE, CARGO_TERMINAL, services["freight"].get("waypoints", {}).get("forest>terminal", []))

func _refresh_freight_route(passenger_cells: Array[Vector2i]) -> void:
	if freight_train == null:
		return

	var cells: Array[Vector2i] = _find_freight_route(tracks, passenger_cells)
	var at_home := freight_train.distance_along_route <= 0.001 and not freight_train.recovery_returning
	if freight_train.route_cells.is_empty() or at_home:
		if not cells.is_empty(): freight_train.set_route(cells, float(TILE_SIZE))
	freight_route_cells = freight_train.route_cells.duplicate()



# Drop removed switches; reservation owners set the positions of active ones.
func _refresh_switch_states(_passenger_cells: Array[Vector2i]) -> void:
	var updated: Dictionary = {}
	for cell in tracks:
		if TrackGeometry.is_switch(tracks[cell]):
			updated[cell] = int(switch_states.get(cell, 0))
	switch_states = updated


func _on_logs_delivered(amount: int) -> void:
	var payment: int = amount * LOG_DELIVERY_PRICE

	logs_delivered += amount
	freight_income += payment
	money += payment
	_record_event(EventLog.CARGO_DELIVERED, "freight", {"logs": amount, "payment": payment})
func _on_freight_operating_expense(amount: int) -> void:
	money -= amount
	freight_operating_cost += amount
func _on_freight_rule_selected(index: int) -> void:
	freight_train.loading_rule = freight_rule_option.get_item_id(index)

	_show_notice("Freight departure rule updated.")
	_update_freight_inspector()

func _upgrade_freight_capacity() -> void:
	if freight_train.capacity_level >= FreightTrain.MAX_CAPACITY_LEVEL:
		_show_notice("Freight capacity is fully upgraded.")
		return

	if not paused:
		_show_notice("Pause the game before upgrading.")
		return

	var price: int = freight_train.get_capacity_upgrade_price()

	if money < price:
		_show_notice("Insufficient funds. Capacity upgrade costs £%d." % price)
		return

	money -= price
	freight_train.capacity_level += 1
	total_vehicle_cost += price
	_sync_fleet_upgrades()
	_record_event(EventLog.UPGRADE_BOUGHT, "freight", {"kind": "capacity", "level": freight_train.capacity_level, "price": price})

	_show_notice(
		"Freight capacity increased to %d logs."
		% freight_train.get_capacity()
	)

	_update_freight_inspector()


func _upgrade_freight_speed() -> void:
	if freight_train.get_speed() >= Consists.speed_limit(Fleet.assigned(fleet, "freight")):
		_show_notice("Attached wagons already limit speed. Remove them before buying another speed upgrade.")
		return
	if freight_train.speed_level >= FreightTrain.MAX_SPEED_LEVEL:
		_show_notice("Freight speed is fully upgraded.")
		return

	if not paused:
		_show_notice("Pause the game before upgrading.")
		return

	var price: int = freight_train.get_speed_upgrade_price()

	if money < price:
		_show_notice("Insufficient funds. Speed upgrade costs £%d." % price)
		return

	money -= price
	freight_train.speed_level += 1
	total_vehicle_cost += price
	_sync_fleet_upgrades()
	_record_event(EventLog.UPGRADE_BOUGHT, "freight", {"kind": "speed", "level": freight_train.speed_level, "price": price})

	_show_notice(
		"Freight speed increased to %.0f pixels/second."
		% freight_train.get_speed()
	)

	_update_freight_inspector()
func _record_construction_change(
	before: Dictionary,
	after: Dictionary,
	money_change: int,
	construction_change: int
) -> void:
	if not paused:
		_clear_construction_history()
		return

	construction_undo.append({
		"before": before.duplicate(),
		"after": after.duplicate(),
		"money_change": money_change,
		"construction_change": construction_change
	})

	if construction_undo.size() > MAX_CONSTRUCTION_HISTORY:
		construction_undo.pop_front()

	# A new action replaces any previously available redo path.
	construction_redo.clear()


func _clear_construction_history() -> void:
	construction_undo.clear()
	construction_redo.clear()

func _remove_track_with_history(cell: Vector2i) -> void:
	if not tracks.has(cell):
		return

	var before: Dictionary = {}
	var after: Dictionary = {}

	before[cell] = tracks[cell]
	after[cell] = null

	tracks.erase(cell)
	money += TRACK_REFUND

	_record_construction_change(
		before,
		after,
		TRACK_REFUND,
		0
	)

	_show_notice("Track removed. Refunded £%d." % TRACK_REFUND)
	_check_route()
	queue_redraw()

func _undo_construction() -> void:
	if planning_mode and not construction_plan.is_empty():
		_show_notice("Apply or discard the draft before Undo.")
		return
	if not paused:
		_show_notice("Pause the game to undo construction.")
		return

	if is_dragging or construction_undo.is_empty():
		return

	var change: Dictionary = construction_undo.back()

	if not _apply_construction_history(change, true):
		return

	construction_undo.pop_back()
	construction_redo.append(change)

	_show_notice("Construction undone.")
	_update_history_controls()


func _redo_construction() -> void:
	if planning_mode and not construction_plan.is_empty():
		_show_notice("Apply or discard the draft before Redo.")
		return
	if not paused:
		_show_notice("Pause the game to redo construction.")
		return

	if is_dragging or construction_redo.is_empty():
		return

	var change: Dictionary = construction_redo.back()

	if not _apply_construction_history(change, false):
		return

	construction_redo.pop_back()
	construction_undo.append(change)

	_show_notice("Construction redone.")
	_update_history_controls()


func _apply_construction_history(
	change: Dictionary,
	undo: bool
) -> bool:
	var multiplier: int = -1 if undo else 1
	var money_change: int = int(change["money_change"]) * multiplier
	var construction_change: int = (
		int(change["construction_change"]) * multiplier
	)

	# Some actions require money, such as rebuilding a removed track.
	if money_change < 0 and money + money_change < 0:
		_show_notice(
			"Insufficient funds. This action requires £%d."
			% (-money_change)
		)
		return false

	var target: Dictionary

	if undo:
		target = change["before"]
	else:
		target = change["after"]

	_rebuild_reservations()
	for cell in target:
		if reservations.owners.has(cell):
			_show_notice("Cannot undo or redo reserved track; wait until the train clears.")
			return false

	var signal_target: Dictionary = change.get("signals_before" if undo else "signals_after", {})
	var signal_expected: Dictionary = change.get("signals_after" if undo else "signals_before", {})
	for cell in signal_target:
		if reservations.owners.has(cell):
			_show_notice("Cannot undo/redo a signal on reserved track.")
			return false
	for cell in signal_expected:
		if track_signals.get(cell) != signal_expected[cell]:
			_show_notice("Signal changed since this edit; Undo/Redo cannot overwrite it.")
			return false
	for cell in signal_target:
		if signal_target[cell] == null: track_signals.erase(cell)
		else: track_signals[cell] = signal_target[cell]
	for cell in target:
		if target[cell] == null:
			tracks.erase(cell)
		else:
			tracks[cell] = target[cell]

	money += money_change
	total_construction_cost += construction_change

	_check_route()
	queue_redraw()

	return true

func _setup_history_controls() -> void:
	var controls := HBoxContainer.new()
	controls.name = "ConstructionHistory"
	$Interface.add_child(controls)

	var scale: float = GameSettings.ui_scale
	controls.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT
	)
	controls.offset_left = 24.0 * scale
	controls.offset_right = 224.0 * scale
	controls.offset_top = -48.0 * scale
	controls.offset_bottom = -12.0 * scale
	controls.add_theme_constant_override("separation", 8)

	undo_button = Button.new()
	undo_button.text = "Undo"
	undo_button.focus_mode = Control.FOCUS_NONE
	undo_button.pressed.connect(_undo_construction)
	controls.add_child(undo_button)

	redo_button = Button.new()
	redo_button.text = "Redo"
	redo_button.focus_mode = Control.FOCUS_NONE
	redo_button.pressed.connect(_redo_construction)
	controls.add_child(redo_button)

	_update_history_controls()


func _update_history_controls() -> void:
	var unavailable: bool = not paused or is_dragging

	undo_button.disabled = unavailable or construction_undo.is_empty()
	redo_button.disabled = unavailable or construction_redo.is_empty()

	if not paused:
		undo_button.tooltip_text = "Pause before editing to enable undo."
		redo_button.tooltip_text = "Construction history clears when play resumes."
	else:
		undo_button.tooltip_text = "Undo the latest paused construction action."
		redo_button.tooltip_text = "Repeat the latest undone construction action."
func _passenger_service_is_active() -> bool:
	if passenger_held:
		return false
	if not route_connected:
		return false

	if passenger_returning or passenger_service_enabled:
		return true

	# A withdrawn train completes its round trip before stopping.
	var parked_at_a: bool = (
		route_distance <= 0.001
		and travelling_to_b
	)

	return not parked_at_a


func _passenger_service_status() -> String:
	var title: String = services["passenger"]["name"]
	if not route_connected:
		return title + ": " + passenger_route_error
	if passenger_held:
		return title + ": held by dispatcher at current position"
	if reservation_waits.has("passenger"):
		return title + ": " + reservation_waits["passenger"]
	if passenger_returning:
		return title + ": reversing to " + ServiceRoutes.STATIONS[services["passenger"]["stops"][passenger_return_stop]]["name"]
	var home: String = ServiceRoutes.STATIONS[services["passenger"]["stops"][0]]["name"]
	if not passenger_service_enabled:
		return title + (": withdrawing to " if _passenger_service_is_active() else ": stopped at ") + home
	if wait_remaining > 0.0:
		return "%s: departing %s in %.1f seconds" % [title, ServiceRoutes.STATIONS[services["passenger"]["stops"][passenger_stop_index]]["name"], wait_remaining]
	return title + ": travelling to " + ServiceRoutes.STATIONS[services["passenger"]["stops"][_next_passenger_stop()]]["name"]


func _selected_service_is_freight() -> bool:
	return (
		selected_station == FOREST_SITE
		or selected_station == CARGO_TERMINAL
	)


func _toggle_selected_service() -> void:
	if _selected_service_is_freight():
		freight_train.service_enabled = not freight_train.service_enabled
		_record_event(EventLog.SERVICE_TOGGLED, "freight", {"enabled": freight_train.service_enabled})

		if freight_train.service_enabled:
			freight_train.held = false
			_show_notice("Freight service enabled.")
		else:
			_show_notice("Freight service will stop at the forest.")
	else:
		passenger_service_enabled = not passenger_service_enabled
		_record_event(EventLog.SERVICE_TOGGLED, "passenger", {"enabled": passenger_service_enabled})

		if passenger_service_enabled:
			passenger_held = false
			_show_notice("Passenger service enabled.")
		else:
			_show_notice("Passenger service will stop at its first route stop.")

	_update_station_inspector()


func _update_service_button() -> void:
	if _selected_service_is_freight():
		if freight_train.service_enabled:
			service_button.text = "Withdraw freight service"
			service_button.tooltip_text = (
				"Finish the current round trip, then stop at the forest."
			)
		else:
			service_button.text = "Enable freight service"
			service_button.tooltip_text = (
				"Resume service, or cancel a pending withdrawal."
			)
	else:
		if passenger_service_enabled:
			service_button.text = "Withdraw passenger service"
			service_button.tooltip_text = (
				"Finish the current round trip, then stop at the first route stop."
			)
		else:
			service_button.text = "Enable passenger service"
			service_button.tooltip_text = (
				"Resume service, or cancel a pending withdrawal."
			)
func _can_demolish(cell: Vector2i) -> bool:
	if planning_mode:
		return _is_inside_map(cell) and not _plan_protected(cell) and construction_plan.projected(tracks).has(cell)
	if not _is_inside_map(cell):
		return false

	if reservations.owners.has(cell):
		return false

	if not tracks.has(cell) or _is_station_space(cell):
		return false

	if cell in [STATION_A, STATION_B, STATION_C, FOREST_SITE, CARGO_TERMINAL]:
		return false

	return true


func _collect_demolition_cells(target: Vector2i) -> void:
	var difference: Vector2i = target - demolition_last_cell
	var steps: int = maxi(absi(difference.x), absi(difference.y))

	# Fill gaps between samples when the mouse moves quickly.
	for index in range(steps + 1):
		var cell: Vector2i = demolition_last_cell

		if steps > 0:
			var fraction: float = float(index) / float(steps)
			var point: Vector2 = Vector2(demolition_last_cell).lerp(
				Vector2(target),
				fraction
			)

			cell = Vector2i(point.round())

		if tracks.has(cell) and reservations.owners.has(cell) and not _is_station_space(cell) and cell not in [STATION_A, STATION_B, STATION_C, FOREST_SITE, CARGO_TERMINAL]:
			demolition_blocked[cell] = reservations.owners[cell]
		if _can_demolish(cell):
			demolition_cells[cell] = true

	demolition_last_cell = target


func _finish_demolition(target: Vector2i) -> void:
	_collect_demolition_cells(target)
	is_dragging = false

	var cells: Array = []

	for cell in demolition_cells:
		if _can_demolish(cell):
			cells.append([cell.x, cell.y])

	demolition_cells.clear()
	demolition_blocked.clear()

	if cells.is_empty():
		queue_redraw()
		return

	if planning_mode:
		var removals: Dictionary = {}
		for cell in cells: removals[Vector2i(cell[0], cell[1])] = null
		construction_plan.stage(removals, tracks)
		return
	_submit_command("demolish", {"cells": cells})


func _execute_demolish(data: Dictionary) -> void:
	_rebuild_reservations()
	var before: Dictionary = {}
	var after: Dictionary = {}

	for entry in data["cells"]:
		var cell := Vector2i(int(entry[0]), int(entry[1]))

		if _can_demolish(cell):
			before[cell] = tracks[cell]
			after[cell] = null

	if before.is_empty():
		queue_redraw()
		return

	for cell in before:
		tracks.erase(cell)

	var refund: int = before.size() * TRACK_REFUND
	money += refund

	_record_construction_change(
		before,
		after,
		refund,
		0
	)

	_record_event(EventLog.TRACK_DEMOLISHED, "player", {"tiles": before.size(), "refund": refund})
	_check_route()

	_show_notice(
		"Removed %d tracks. Refunded £%d."
		% [before.size(), refund]
	)

	queue_redraw()


func _draw_demolition_preview() -> void:
	for cell in demolition_cells:
		var origin: Vector2 = Vector2(cell) * TILE_SIZE
		var color := Color(1.0, 0.3, 0.2)

		draw_rect(
			Rect2(origin, Vector2(TILE_SIZE, TILE_SIZE)),
			Color(1.0, 0.1, 0.05, 0.3)
		)

		draw_line(
			origin + Vector2(5, 5),
			origin + Vector2(TILE_SIZE - 5, TILE_SIZE - 5),
			color,
			2.0
		)

		draw_line(
			origin + Vector2(TILE_SIZE - 5, 5),
			origin + Vector2(5, TILE_SIZE - 5),
			color,
			2.0
		)
func _make_ui_style(
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
func _setup_modern_ui_theme() -> void:
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

	# Themes are inherited by the controls inside these UI roots.
	for child in $Interface.get_children():
		if child is Control:
			child.theme = ui_theme

	header_background.color = Color("#111827")
	instructions.add_theme_font_size_override("font_size", 14)

func _setup_toolbar_icons() -> void:
	toolbar_icon_textures.clear()

	var cell_size: float = float(TOOLBAR_ICON_SHEET.get_height())

	for index in range(10):
		var icon := AtlasTexture.new()
		icon.atlas = TOOLBAR_ICON_SHEET
		icon.region = Rect2(
			index * cell_size,
			0.0,
			cell_size,
			cell_size
		)
		icon.filter_clip = true

		toolbar_icon_textures.append(icon)

	var buttons: Array[Button] = [
		straight_button,
		curve_button,
		inspect_button,
		pause_button,
		save_button,
		load_button,
		folder_button,
		backup_button
	]

	var icon_indices: Array[int] = [
		0, 1, 3, 4, 6, 7, 8, 9
	]

	for index in range(buttons.size()):
		var button: Button = buttons[index]

		button.text = ""
		button.icon = toolbar_icon_textures[icon_indices[index]]
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.custom_minimum_size = Vector2(44, 44)
		button.add_theme_constant_override("icon_max_width", 24)

		# Smooth UI icons while the map retains its pixel-art filtering.
		button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	straight_button.tooltip_text = "Connect track — drag between two points; automatic diagonal and platform approaches"
	curve_button.tooltip_text = "Draw track — hold left mouse and change direction; bends are automatic"
	inspect_button.tooltip_text = "Inspect trains, stations and industries — I"
	save_button.tooltip_text = "Save game"
	load_button.tooltip_text = "Load latest save"
	folder_button.tooltip_text = "Open save folder"
	backup_button.tooltip_text = "Load previous save"

	_update_toolbar()
func _setup_settings_dialog() -> void:
	settings_dialog = SettingsDialog.new()
	settings_dialog.configure()
	settings_dialog.settings_applied.connect(_apply_settings)
	$Interface.add_child(settings_dialog)

	settings_button = Button.new()
	settings_button.text = "Settings"
	settings_button.focus_mode = Control.FOCUS_NONE
	settings_button.tooltip_text = "Interface scale, colours and keys"
	settings_button.pressed.connect(_open_settings)
	$Interface/HeaderBox/Toolbar.add_child(settings_button)


func _open_settings() -> void:
	is_dragging = false
	is_panning = false
	demolition_cells.clear()
	demolition_blocked.clear()
	build_plan.clear()
	settings_dialog.open_dialog()


# Pushes the current player settings to everything that shows them.
func _apply_settings() -> void:
	GameSettings.apply(get_window())
	InputActions.apply_bindings(GameSettings.key_bindings)
	InputActions.apply_mouse_bindings(GameSettings.mouse_bindings)

	# Enlarging the interface scales the whole window; the camera cancels that
	# out so the map keeps its on-screen size.
	var player_zoom: float = camera.zoom.x * applied_ui_scale
	applied_ui_scale = GameSettings.ui_scale
	camera.zoom = Vector2.ONE * player_zoom / applied_ui_scale
	camera.force_update_scroll()
	_apply_header_mode()
	_layout_header()
	network_map.facilities = _facility_markers()
	freight_train.queue_redraw()
	_refresh_shortcut_tooltips()
	queue_redraw()


func _facility_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []

	for station in [STATION_A, STATION_B, STATION_C]:
		markers.append({
			"cell": station,
			"color": Palette.get_color(Palette.Role.FACILITY_STATION)
		})

	markers.append({
		"cell": FOREST_SITE,
		"color": Palette.get_color(Palette.Role.FACILITY_FOREST)
	})
	markers.append({
		"cell": CARGO_TERMINAL,
		"color": Palette.get_color(Palette.Role.FACILITY_TERMINAL)
	})
	return markers


func _refresh_shortcut_tooltips() -> void:
	if remove_button != null:
		remove_button.tooltip_text = "Remove track: left-drag. Or right-drag/hold. Shortcut: " + InputActions.key_label(InputActions.SELECT_REMOVE)
	inspect_button.tooltip_text = "Inspect trains, stations and industries — %s" % InputActions.key_label(InputActions.TOGGLE_INSPECT)
	map_button.tooltip_text = "Show or hide the network map — %s" % InputActions.key_label(InputActions.TOGGLE_MAP)
	goals_button.tooltip_text = "Show or hide scenario objectives — %s" % InputActions.key_label(InputActions.TOGGLE_GOALS)
	if speed_selector != null:
		var shortcuts: PackedStringArray = []
		for index in range(GAME_SPEEDS.size()):
			shortcuts.append("%s: %d×" % [InputActions.key_label(InputActions.SPEED_ACTIONS[index]), int(GAME_SPEEDS[index])])
		speed_selector.tooltip_text = "Simulation speed — " + ", ".join(shortcuts) + ". Selecting a speed keeps pause unchanged."
		for index in range(GAME_SPEEDS.size()):
			speed_selector.set_item_tooltip(index, InputActions.key_label(InputActions.SPEED_ACTIONS[index]))


func _setup_network_map() -> void:
	network_map = NetworkMap.new()
	network_map.name = "NetworkMap"
	network_map.map_cells = Vector2i(MAP_WIDTH, MAP_HEIGHT)
	network_map.world_tile_size = float(TILE_SIZE)

	network_map.facilities = [
		{
			"cell": STATION_A,
			"color": Color("#F4D56A")
		},
		{
			"cell": STATION_B,
			"color": Color("#F4D56A")
		},
		{
			"cell": STATION_C,
			"color": Color("#F4D56A")
		},
		{
			"cell": FOREST_SITE,
			"color": Color("#6ED68C")
		},
		{
			"cell": CARGO_TERMINAL,
			"color": Color("#F0A75A")
		}
	]

	$Interface.add_child(network_map)

	var scale: float = GameSettings.ui_scale
	network_map.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT
	)

	network_map.offset_left = 24.0 * scale
	network_map.offset_right = 304.0 * scale
	network_map.offset_top = -264.0 * scale
	network_map.offset_bottom = -64.0 * scale

	network_map.navigation_requested.connect(
		_on_map_navigation_requested
	)

	map_button = Button.new()
	map_button.text = "Map"
	map_button.toggle_mode = true
	map_button.button_pressed = true
	map_button.focus_mode = Control.FOCUS_NONE
	map_button.tooltip_text = "Show or hide the network map — M"
	map_button.pressed.connect(_toggle_network_map)

	$Interface/ConstructionHistory.add_child(map_button)

	_update_network_map()


func _update_network_map() -> void:
	if not network_map.visible:
		return

	network_map.track_data = tracks

	network_map.train_positions = [
		train_position,
		freight_train.position
	]

	for key in additional_service_keys(): network_map.train_positions.append(passenger_services[key].position)
	network_map.train_kinds = ["passenger", "freight"]
	for key in additional_service_keys(): network_map.train_kinds.append("passenger")
	var visible_world_size: Vector2 = (
		get_viewport_rect().size / camera.zoom
	)

	var center: Vector2 = camera.get_screen_center_position()

	network_map.camera_world_rect = Rect2(
		center - visible_world_size / 2.0,
		visible_world_size
	)

	network_map.queue_redraw()


func _on_map_navigation_requested(world_position: Vector2) -> void:
	# Navigation cancels an unfinished construction gesture.
	is_dragging = false
	is_panning = false
	demolition_cells.clear()
	demolition_blocked.clear()

	camera.position = world_position
	camera.force_update_scroll()


func _toggle_network_map() -> void:
	network_map.visible = not network_map.visible
	network_map.cancel_navigation()

	map_button.set_pressed_no_signal(network_map.visible)
func _scenario_metrics() -> Dictionary:
	return {
		"passenger_connected": 1 if route_connected else 0,
		"passengers_delivered": passengers_delivered,
		"freight_connected": (
			0 if freight_train.route_cells.is_empty() else 1
		),
		"logs_delivered": logs_delivered
	}


func _check_scenario_objectives() -> void:
	if scenario_goals.is_complete():
		return

	var result: Dictionary = scenario_goals.advance(
		_scenario_metrics()
	)

	var completed: int = int(result["completed"])
	var reward: int = int(result["reward"])

	if completed == 0:
		return

	money += reward
	_record_event(EventLog.OBJECTIVE_COMPLETED, "player", {"count": completed, "reward": reward, "stage": scenario_goals.current_index})

	if scenario_goals.is_complete():
		_show_notice(
			"Scenario complete! Final objective reward: £%d." % reward
		)
	elif completed == 1:
		_show_notice("Objective completed! Awarded £%d." % reward)
	else:
		_show_notice(
			"%d objectives completed! Awarded £%d."
			% [completed, reward]
		)
func _setup_objective_panel() -> void:
	objective_panel = PanelContainer.new()
	objective_panel.name = "Objectives"
	$Interface.add_child(objective_panel)

	var scale: float = GameSettings.ui_scale
	objective_panel.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_LEFT
	)

	objective_panel.offset_left = 24.0 * scale
	objective_panel.offset_right = 344.0 * scale
	objective_panel.offset_top = 176.0 * scale
	objective_panel.offset_bottom = 316.0 * scale
	objective_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	objective_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	objective_heading = Label.new()
	objective_heading.add_theme_font_size_override("font_size", 14)
	content.add_child(objective_heading)

	objective_description = Label.new()
	objective_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(objective_description)

	objective_progress = ProgressBar.new()
	objective_progress.min_value = 0.0
	objective_progress.show_percentage = false
	objective_progress.custom_minimum_size = Vector2(0, 16)
	content.add_child(objective_progress)

	objective_details = Label.new()
	objective_details.add_theme_font_size_override("font_size", 14)
	content.add_child(objective_details)

	goals_button = Button.new()
	goals_button.text = "Goals"
	goals_button.toggle_mode = true
	goals_button.button_pressed = true
	goals_button.focus_mode = Control.FOCUS_NONE
	goals_button.tooltip_text = "Show or hide scenario objectives — G"
	goals_button.pressed.connect(_toggle_objective_panel)

	$Interface/ConstructionHistory.add_child(goals_button)

	_update_objective_panel()


func _toggle_objective_panel() -> void:
	objective_panel.visible = not objective_panel.visible
	goals_button.set_pressed_no_signal(objective_panel.visible)


func _update_objective_panel() -> void:
	if not objective_panel.visible:
		return

	if scenario_goals.is_complete():
		objective_heading.text = "SCENARIO COMPLETE"
		objective_description.text = (
			"Your passenger and freight services are established."
			+ "\nKeep expanding your railway."
		)

		objective_progress.max_value = 1.0
		objective_progress.value = 1.0

		objective_details.text = "Total objective rewards: £%d" % (
			scenario_goals.earned_rewards()
		)
		return

	var goal: Dictionary = scenario_goals.current_goal()
	var metrics: Dictionary = _scenario_metrics()
	var target: int = int(goal["target"])

	var progress: int = clampi(
		int(metrics.get(goal["metric"], 0)),
		0,
		target
	)

	objective_heading.text = "OBJECTIVE %d OF %d" % [
		scenario_goals.current_index + 1,
		ScenarioGoals.OBJECTIVES.size()
	]

	objective_description.text = goal["title"]

	objective_progress.max_value = float(target)
	objective_progress.value = float(progress)

	objective_details.text = "%d / %d — Reward: £%d" % [
		progress,
		target,
		int(goal["reward"])
	]


func _refresh_build_plan(target: Vector2i, force: bool = false) -> void:
	var working: Dictionary = construction_plan.projected(tracks) if planning_mode else tracks
	# Within the first cell the pointer still determines a single tile's angle.
	if not force and target == build_last_hover and target != drag_start:
		return
	build_last_hover = target
	var fixed: Array[Vector2i] = [STATION_A, STATION_B, STATION_C, FOREST_SITE, CARGO_TERMINAL]
	var cells: Array[Vector2i]
	if draw_track_mode:
		if build_stroke.is_empty():
			build_stroke.append(drag_start)
		if target != build_stroke.back():
			if build_stroke.size() <= 2 and working.has(drag_start):
				# A pointer update on the first new tile must not let the
				# next update turn that tile into a bend.
				build_stroke = TrackBuilder.line(drag_start, target, working, fixed)
			elif working.has(target):
				var addition: Array[Vector2i] = TrackBuilder.line(build_stroke.back(), target, working, fixed)
				for index in range(1, addition.size()):
					TrackBuilder.append_stroke(build_stroke, addition[index])
			else:
				TrackBuilder.append_stroke(build_stroke, target)
		cells = build_stroke
	else:
		cells = TrackBuilder.line(drag_start, target, working, fixed)
	var single_direction := Vector2i.RIGHT
	var short_direction := Vector2i.ZERO
	# An empty starting cell is the first piece of the measured stroke, not an
	# extra piece on top of its length. Existing endpoint tiles are free anchors.
	if cells.size() > 1 and not working.has(drag_start) and not working.has(cells.back()):
		short_direction = cells[1] - cells[0]
		cells = cells.duplicate()
		cells.pop_back()
	if cells.size() == 1 and short_direction != Vector2i.ZERO:
		single_direction = short_direction
	elif cells.size() == 1 and drag_pointer_start.is_finite():
		var offset := to_local(_pointer_world()) - drag_pointer_start
		if offset.length() * camera.zoom.x * applied_ui_scale >= 3.0:
			var angle: float = roundf(offset.angle() / (PI / 4.0)) * (PI / 4.0)
			single_direction = Vector2i(roundi(cos(angle)), roundi(sin(angle)))
	if cells.size() == 1 and not working.has(drag_start):
		# A new piece beside an open rail continues that rail's exit direction.
		for direction in TrackGeometry.DIRECTIONS:
			var neighbor: Vector2i = drag_start - direction
			if working.has(neighbor) and TrackGeometry.connections(working[neighbor]).has(direction):
				single_direction = direction
				break
	build_plan = TrackBuilder.plan(cells, working, Vector2i(MAP_WIDTH, MAP_HEIGHT), _is_station_space, fixed, single_direction)
	var signs: Dictionary = construction_plan.projected_signals(track_signals) if planning_mode else track_signals
	for cell in build_plan.get("changes", {}):
		if signs.has(cell) and not TrackGeometry.is_straight(build_plan.changes[cell]):
			build_plan.invalid[cell] = true
			build_plan.error = "Remove the signal before adding a switch on its tile."

func _waiting(key: String) -> int:
	return int(get("waiting_at_" + key))

func _set_waiting(key: String, count: int) -> void:
	set("waiting_at_" + key, count)

# Platform length is measured from the live track, so laying straight track
# behind a stop lengthens it immediately.
func _platform_text(cell: Vector2i) -> String:
	var key := ""
	for station in ServiceRoutes.STATIONS:
		if ServiceRoutes.STATIONS[station].cell == cell: key = station
	if key.is_empty():
		return Platforms.describe(Platforms.measure(tracks, track_signals, cell, float(TILE_SIZE)), float(TILE_SIZE))
	var lines: PackedStringArray = []
	var platforms := Platforms.for_station(tracks, track_signals, key, cell, float(TILE_SIZE))
	if platforms.is_empty(): return Platforms.describe(Platforms.measure(tracks, track_signals, cell, float(TILE_SIZE)), float(TILE_SIZE))
	for platform in platforms:
		var holder := int(reservations.occupied_owners.get(platform.cell, -1))
		lines.append("Platform %d: %s%s" % [int(platform.number), Platforms.describe(platform, float(TILE_SIZE)).trim_prefix("Platform: "), " — occupied by train #%d" % holder if holder > 0 else ""])
	return "\n".join(lines)

func _station_key(cell: Vector2i) -> String:
	for key in ServiceRoutes.STATIONS:
		if ServiceRoutes.STATIONS[key]["cell"] == cell:
			return key
	return "a"

func _next_passenger_stop() -> int:
	if passenger_returning: return passenger_return_stop
	if _passenger_is_loop(): return (passenger_stop_index + 1) % services["passenger"]["stops"].size()
	return passenger_stop_index + (1 if travelling_to_b else -1)

func _passenger_is_loop() -> bool:
	return services["passenger"].get("mode", "shuttle") == "loop"

func _passenger_target_distance() -> float:
	if _passenger_is_loop() and not passenger_returning:
		return stop_distances[passenger_stop_index + 1]
	return stop_distances[_next_passenger_stop()]

func _return_onboard_passengers() -> void:
	if passengers_on_train > 0:
		var key: String = services["passenger"]["stops"][passenger_stop_index]
		_set_waiting(key, _waiting(key) + passengers_on_train)
	passengers_on_train = 0

func _setup_routes_editor() -> void:
	route_editor = RouteEditor.new()
	route_editor.configure(self)
	$Interface.add_child(route_editor)
	routes_button = Button.new()
	routes_button.text = "Routes"
	routes_button.focus_mode = Control.FOCUS_NONE
	routes_button.tooltip_text = "Name services; edit route mode, ordered stops and pass-through waypoints"
	routes_button.pressed.connect(_open_routes_editor)
	$Interface/HeaderBox/Toolbar.add_child(routes_button)

func _open_routes_editor(cell: Vector2i = Vector2i(-1, -1)) -> void:
	paused = true
	is_dragging = false
	is_panning = false
	demolition_cells.clear()
	demolition_blocked.clear()
	build_plan.clear()
	_close_station_inspector()
	_update_toolbar()
	route_editor.open_editor(cell)

const FIRST_PLATFORM_MESSAGE := "The first stop's platform cannot change while the train stands on its current platform. Choose platforms for the later stops, or move the first stop to another station."

# The train starts each trip on its first stop's platform, so that platform is
# fixed while the same station remains the first stop.
func _first_platform_changed(proposed: Dictionary, current: Dictionary) -> bool:
	if proposed.stops[0] != current.stops[0]: return false
	return ServiceRoutes.stop_cell(proposed.get("platforms", {}), proposed.stops[0]) != ServiceRoutes.stop_cell(current.get("platforms", {}), current.stops[0])

func apply_service_routes(configuration: Dictionary) -> String:
	if not ServiceRoutes.is_valid(configuration):
		return "Use a name of 1–40 characters and at least two different passenger stops."
	if not paused:
		return "Pause before changing routes."
	configuration = ServiceRoutes.from_save(configuration)
	if not _valid_service_assignments(configuration, fleet): return "Create or remove additional services in Fleet before editing their routes."
	for key in configuration:
		var fit := _consist_service_fit(Fleet.assigned(fleet, key), configuration[key])
		if not fit.is_empty(): return str(configuration[key].name) + ": " + fit
	var extra_built: Dictionary = {}
	for key in additional_service_keys():
		var current: Dictionary = services[key]
		var proposed: Dictionary = configuration[key]
		if proposed.stops == current.stops and proposed.get("mode", "shuttle") == current.get("mode", "shuttle") and proposed.get("waypoints", {}) == current.get("waypoints", {}) and proposed.get("platforms", {}) == current.get("platforms", {}): continue
		var running = passenger_services[key]
		if _first_platform_changed(proposed, current): return FIRST_PLATFORM_MESSAGE
		var home: Vector2 = _cell_center(ServiceRoutes.stop_cell(proposed.get("platforms", {}), proposed.stops[0]))
		if running.passengers > 0 or running.returning or running.position.distance_to(home) > 0.1:
			return "%s: finish the trip or reverse back first. Edit with an empty train at its first stop." % current.name
		var built := ServiceRoutes.build(tracks, proposed.stops, float(TILE_SIZE), proposed.get("waypoints", {}), proposed.get("mode", "shuttle"), proposed.get("platforms", {}))
		if built.cells.is_empty(): return "%s: complete the new route before applying." % current.name
		extra_built[key] = built
	var changed: bool = configuration["passenger"].get("mode", "shuttle") != services["passenger"].get("mode", "shuttle") or configuration["passenger"]["stops"] != services["passenger"]["stops"] or configuration["passenger"].get("waypoints", {}) != services["passenger"].get("waypoints", {}) or configuration["passenger"].get("platforms", {}) != services["passenger"].get("platforms", {})
	var freight_changed: bool = configuration["freight"].get("waypoints", {}) != services["freight"].get("waypoints", {})
	if freight_changed:
		if freight_train.distance_along_route > 0.001 or freight_train.recovery_returning:
			return "Freight waypoint edits require the train physically at the forest. Hold or withdraw it first."
		if WaypointRouter.find_route(tracks, FOREST_SITE, CARGO_TERMINAL, configuration["freight"].get("waypoints", {}).get("forest>terminal", [])).is_empty():
			return "Complete a valid freight path through the selected waypoints before applying."
	if changed:
		if _first_platform_changed(configuration["passenger"], services["passenger"]): return FIRST_PLATFORM_MESSAGE
		var new_home: Vector2 = _cell_center(ServiceRoutes.stop_cell(configuration["passenger"].get("platforms", {}), configuration["passenger"]["stops"][0]))
		if passengers_on_train > 0 or passenger_returning or train_position.distance_to(new_home) > 0.1:
			return "Finish the trip or reverse back first. Route mode, stops and waypoints can only change with an empty train at the first stop."
		if ServiceRoutes.build(tracks, configuration["passenger"]["stops"], float(TILE_SIZE), configuration["passenger"].get("waypoints", {}), configuration["passenger"].get("mode", "shuttle"), configuration["passenger"].get("platforms", {}))["cells"].is_empty():
			return "Complete the new route before changing the stop order."
		# Reparameterise a path only when its origin is this exact physical spot.
		route_cells.clear()
		route_path = Curve2D.new()
		route_distance = 0.0
		passenger_stop_index = 0
		passenger_return_stop = 0
	services = configuration.duplicate(true)
	for key in additional_service_keys():
		if extra_built.has(key): passenger_services[key].configure(key, services[key], extra_built[key])
		else: passenger_services[key].configuration = services[key].duplicate(true)
	if changed or freight_changed or not extra_built.is_empty():
		_check_route(true)
	_update_instructions()
	_update_station_inspector()
	queue_redraw()
	return "Routes applied. Close and resume when ready; use Save to keep your changes." if route_connected else "Routes applied. " + passenger_route_error

func _management_window_is_open() -> bool:
	return (train_inspector != null and train_inspector.visible) or (object_browser != null and object_browser.visible) or (problems_dialog != null and problems_dialog.visible) or (route_editor != null and route_editor.visible) or (fleet_editor != null and fleet_editor.visible) or (traffic_dialog != null and traffic_dialog.visible)

func _setup_fleet_editor() -> void:
	fleet_editor = FleetEditor.new()
	fleet_editor.configure(self)
	$Interface.add_child(fleet_editor)
	fleet_button = Button.new()
	fleet_button.text = "Fleet"
	fleet_button.focus_mode = Control.FOCUS_NONE
	fleet_button.tooltip_text = "Buy, name and assign individual trains"
	fleet_button.pressed.connect(_open_fleet_editor)
	$Interface/HeaderBox/Toolbar.add_child(fleet_button)

func _open_fleet_editor() -> void:
	paused = true
	is_dragging = false
	is_panning = false
	demolition_cells.clear()
	demolition_blocked.clear()
	build_plan.clear()
	_close_station_inspector()
	_update_toolbar()
	fleet_editor.open_editor()

func _sync_fleet_upgrades() -> void:
	var passenger: Dictionary = Fleet.assigned(fleet, "passenger")
	passenger["capacity_level"] = capacity_upgrade_level
	passenger["speed_level"] = speed_upgrade_level
	if freight_train != null:
		var freight: Dictionary = Fleet.assigned(fleet, "freight")
		freight["capacity_level"] = freight_train.capacity_level
		freight["speed_level"] = freight_train.speed_level

func _apply_fleet_specs() -> void:
	var passenger: Dictionary = Fleet.assigned(fleet, "passenger")
	capacity_upgrade_level = int(passenger["capacity_level"])
	speed_upgrade_level = int(passenger["speed_level"])
	var freight: Dictionary = Fleet.assigned(fleet, "freight")
	var model: Dictionary = Fleet.MODELS[freight["model"]]
	freight_train.base_capacity = int(model["capacity"]) + Consists.extra_capacity(freight)
	freight_train.base_speed = float(model["speed"])
	freight_train.running_cost_per_second = Fleet.running_cost(freight)
	freight_train.wagon_speed_limit = Consists.speed_limit(freight)
	freight_train.consist_entry = freight
	freight_train.queue_redraw()
	freight_train.capacity_level = int(freight["capacity_level"])
	freight_train.speed_level = int(freight["speed_level"])

func buy_fleet_train(model_id: String) -> Dictionary:
	if not paused:
		return {"ok": false, "message": "Pause before buying trains."}
	if not Fleet.MODELS.has(model_id):
		return {"ok": false, "message": "Unknown train model."}
	if fleet["trains"].size() >= Fleet.MAX_TRAINS:
		return {"ok": false, "message": "The fleet is full."}
	var model: Dictionary = Fleet.MODELS[model_id]
	var price: int = int(model["price"])
	if money < price:
		return {"ok": false, "message": "Insufficient funds: this train costs £%d." % price}
	var id: int = int(fleet["next_id"])
	fleet["next_id"] = id + 1
	fleet["trains"].append(Fleet.make_train(id, model_id))
	money -= price
	total_vehicle_cost += price
	_update_instructions()
	return {"ok": true, "id": id, "message": "Bought %s for £%d. It is stored until assigned." % [model["name"], price]}

func rename_fleet_train(id: int, new_name: String) -> String:
	if not paused:
		return "Pause before editing the fleet."
	var train: Dictionary = Fleet.find(fleet, id)
	var cleaned: String = new_name.strip_edges()
	if train.is_empty() or not Fleet.valid_name(cleaned):
		return "Choose an existing train and a name of 1–40 characters."
	train["name"] = cleaned
	_update_station_inspector()
	return "Train renamed."

func _can_replace_service_train(service: String) -> bool:
	if service == "passenger":
		return route_distance <= 0.001 and travelling_to_b and passenger_stop_index == 0 and passengers_on_train == 0
	if service == "freight":
		return freight_train.distance_along_route <= 0.001 and freight_train.to_terminal and freight_train.cargo == 0
	return passenger_services.has(service) and passenger_services[service].at_home()

func assign_fleet_train(id: int, service: String) -> String:
	if not paused:
		return "Pause before assigning trains."
	var train: Dictionary = Fleet.find(fleet, id)
	if train.is_empty() or not services.has(service):
		return "Choose a valid train and service."
	if Fleet.MODELS[train["model"]]["kind"] != ServiceRoutes.kind(service):
		return "This train cannot carry that service's passengers or cargo."
	if train["service"] != "":
		return "This train is already assigned."
	if not _can_replace_service_train(service):
		return "Withdraw the current train, close this window and resume until it is empty at its first stop. Then pause and assign the replacement."
	var fit := _consist_service_fit(train, services[service])
	if not fit.is_empty(): return fit
	_rebuild_reservations()
	var old_id := int(Fleet.assigned(fleet, service).id)
	var origin := _service_body_origin(service)
	for cell in reservations.footprint(origin.path, origin.distance, float(TILE_SIZE), Fleet.length(train)):
		if reservations.owners.has(cell) and int(reservations.owners[cell]) != old_id: return "Replacement body overlaps reserved or occupied track. Let the other train clear first."
	_sync_fleet_upgrades()
	var old_train: Dictionary = Fleet.assigned(fleet, service)
	old_train["service"] = ""
	train["service"] = service
	_apply_fleet_specs()
	if service == "passenger":
		wait_remaining = 0.0
		train_needs_boarding = true
		passenger_service_enabled = true
		passenger_held = false
	elif service == "freight":
		freight_train.held = false
		freight_train.dwell = 0.0
		freight_train.service_enabled = true
	else:
		passenger_services[service].held = false
		passenger_services[service].dwell = 0
		passenger_services[service].boarding = true
		passenger_services[service].enabled = true
	_reset_traffic_state("Train assignment changed")
	_rebuild_reservations()
	_update_instructions()
	_update_station_inspector()
	return "%s assigned to %s. %s is now stored. Resume to run the new train." % [train["name"], services[service]["name"], old_train["name"]]

func sell_fleet_train(id: int) -> String:
	if not paused:
		return "Pause before selling trains."
	var train: Dictionary = Fleet.find(fleet, id)
	if train.is_empty():
		return "That train no longer exists."
	if train["service"] != "":
		return "Assign a replacement first; only stored trains can be sold."
	var refund: int = Fleet.sale_price(train)
	fleet["trains"].erase(train)
	money += refund
	total_vehicle_cost -= refund
	_update_instructions()
	return "Sold %s for £%d." % [train["name"], refund]

func toggle_fleet_service(id: int) -> String:
	if not paused:
		return "Pause before editing the fleet."
	var train: Dictionary = Fleet.find(fleet, id)
	if train.is_empty() or train["service"] == "":
		return "Assign this train before changing its service."
	var service: String = train["service"]
	var enabled: bool
	if service == "passenger":
		passenger_service_enabled = not passenger_service_enabled
		enabled = passenger_service_enabled
		if enabled: passenger_held = false
	elif passenger_services.has(service):
		var running = passenger_services[service]
		running.enabled = not running.enabled
		enabled = running.enabled
		if enabled: running.held = false
	else:
		freight_train.service_enabled = not freight_train.service_enabled
		enabled = freight_train.service_enabled
		if enabled: freight_train.held = false
	_update_station_inspector()
	return "Service enabled. Close and resume to run." if enabled else "Withdrawal requested. Close and resume: the train will finish its round trip and stop at its first station."

func fleet_train_status(id: int) -> String:
	var train: Dictionary = Fleet.find(fleet, id)
	if train.is_empty():
		return "Unknown train"
	if train["service"] == "":
		return "Stored off-map — no running costs"
	if train["service"] == "passenger":
		return _passenger_service_status()
	if passenger_services.has(train["service"]): return passenger_services[train["service"]].status(self)
	return services["freight"]["name"] + ": " + freight_train.status_text()


func _reservation_path(path: Curve2D, home: Vector2) -> Curve2D:
	if path.point_count >= 2:
		return path
	var parked := Curve2D.new()
	parked.add_point(home)
	parked.add_point(home + Vector2(0.001, 0))
	return parked

func _rebuild_reservations(allow_movement: bool = false) -> void:
	if freight_train == null:
		return
	authority_revision += 1
	authority_tick = sim_clock.tick
	var passenger := Fleet.assigned(fleet, "passenger")
	var freight := Fleet.assigned(fleet, "freight")
	var trains: Array = [
		{"id": int(passenger["id"]), "length": _fleet_length(passenger), "cells": route_cells, "path": _reservation_path(route_path, train_position), "distance": route_distance if route_path.point_count >= 2 else 0.0, "forward": travelling_to_b, "moving": (allow_movement or not paused) and _passenger_service_is_active() and wait_remaining <= 0.0},
		{"id": int(freight["id"]), "length": _fleet_length(freight), "cells": freight_train.route_cells, "path": _reservation_path(freight_train.route_path, freight_train.position), "distance": freight_train.distance_along_route, "forward": freight_train.to_terminal, "moving": (allow_movement or not paused) and freight_train.service_is_active() and freight_train.dwell <= 0.0 and (not freight_train.to_terminal or freight_train.distance_along_route > 0.001 or freight_train.cargo + forest_stock >= freight_train.get_minimum_load())}
	]
	for key in additional_service_keys():
		var running = passenger_services[key]
		trains.append({"id": int(Fleet.assigned(fleet, key).id), "length": _fleet_length(Fleet.assigned(fleet, key)), "cells": running.cells, "path": running.path, "distance": running.distance, "forward": running.forward, "moving": (allow_movement or not paused) and running.active() and running.dwell <= 0})
	reservation_trains.clear()
	for train in trains: reservation_trains[int(train.id)] = train
	reservations.rebuild(trains, tracks, float(TILE_SIZE))
	block_signals.configure(tracks, track_signals)
	block_signals.update(trains, reservations.occupied_owners, float(TILE_SIZE))
	if not track_signals.is_empty():
		# Never lock a switch beyond a red signal: doing so can prevent the
		# departing train from clearing the very block we are waiting to enter.
		var request_ends: Dictionary = {}
		for train in trains:
			if not train.moving: continue
			var direction := 1.0 if train.forward else -1.0
			var end := clampf(train.distance + direction * TILE_SIZE * Reservations.LOOKAHEAD_TILES, 0, train.path.get_baked_length())
			request_ends[int(train.id)] = block_signals.limit(train, end, float(TILE_SIZE)).distance
		reservations.rebuild(trains, tracks, float(TILE_SIZE), request_ends)
	switch_states.merge(reservations.switches, true)

# Whole-train length is derived from validated fleet composition.
func _fleet_length(entry: Dictionary) -> float:
	return Fleet.length(entry)

func _freight_reserved_movement(path: Curve2D, current: float, proposed: float) -> float:
	return _reserved_movement("freight", path, current, proposed)

func _reserved_movement(service: String, path: Curve2D, current: float, proposed: float) -> float:
	var id := int(Fleet.assigned(fleet, service)["id"])
	var signal_check: Dictionary = block_signals.limit(reservation_trains[id], proposed, float(TILE_SIZE))
	var allowed: float = reservations.limit(id, path, current, float(signal_check["distance"]), float(TILE_SIZE), Reservations.train_length(reservation_trains[id]))
	var signal_conflict: Dictionary = signal_check["conflict"]
	if absf(allowed - proposed) > 0.001:
		var conflict: Dictionary = signal_conflict if not signal_conflict.is_empty() else reservations.waits.get(id, {})
		movement_conflicts[id] = conflict.duplicate(true)
		movement_conflicts[id]["revision"] = authority_revision
		var cell: Vector2i = conflict.get("cell", Vector2i(-1, -1))
		var owner := int(conflict.get("owner", -1))
		if absf(allowed - current) < 0.001 and absf(proposed - current) > 0.001 and owner > 0:
			movement_blocks[id] = owner
		var other := Fleet.find(fleet, owner)
		var name: String = str(other.get("name", "another train"))
		var place := "switch" if TrackGeometry.is_switch(tracks.get(cell)) else "track"
		var reason := str(conflict.get("reason", "Waiting for %s at %s %d,%d" % [name, place, cell.x, cell.y]))
		if absf(allowed - current) < 0.001 and absf(proposed - current) > 0.001:
			traffic_wait_samples[id] = {"reason": reason, "cell": cell}
		if reservation_waits.get(service, "") != reason:
			_record_event(EventLog.TRAIN_WAITING, str(id), {"reason": reason, "blocked_by": owner, "x": cell.x, "y": cell.y})
		reservation_waits[service] = reason
	else:
		reservation_waits.erase(service)
	freight_train.reservation_wait = str(reservation_waits.get("freight", ""))
	return allowed

func _setup_reservation_overlay() -> void:
	var button := Button.new()
	reservation_button = button
	button.text = "Reservations"
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "Hatched tiles are owned by the displayed train ID. Occupied and reserved track cannot be changed."
	button.toggled.connect(func(enabled: bool) -> void:
		reservation_overlay = enabled
		queue_redraw())
	$Interface/HeaderBox/Toolbar.add_child(button)

func _draw_reservations() -> void:
	for cell in reservations.owners:
		var origin := Vector2(cell) * TILE_SIZE
		var rect := Rect2(origin, Vector2.ONE * TILE_SIZE)
		draw_rect(rect, Color(1, 1, 1, 0.65), false, 1.0)
		for offset in range(0, TILE_SIZE, 8):
			draw_line(origin + Vector2(offset, 0), origin + Vector2(TILE_SIZE, TILE_SIZE - offset), Color(1, 1, 1, 0.45))
			if offset > 0:
				draw_line(origin + Vector2(0, offset), origin + Vector2(TILE_SIZE - offset, TILE_SIZE), Color(1, 1, 1, 0.45))
		draw_string(ThemeDB.fallback_font, origin + Vector2(2, 13), "#%d" % int(reservations.owners[cell]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _reset_traffic_state(reason: String = "") -> void:
	if not reason.is_empty():
		for cycle in deadlocks.cycles:
			_record_event(EventLog.DEADLOCK_CLEARED, "network", {"trains": cycle.duplicate(), "reason": reason})
	deadlocks.reset()
	movement_conflicts.clear()
	movement_blocks.clear()
	reservation_waits.clear()
	if freight_train != null:
		freight_train.reservation_wait = ""
	if traffic_button != null:
		traffic_button.text = "Traffic"

func _update_deadlocks() -> void:
	deadlocks.update(movement_blocks, sim_clock.tick)
	for cycle in deadlocks.new_cycles:
		_record_event(EventLog.DEADLOCK_DETECTED, "network", {"trains": cycle.duplicate(), "reason": "Trains are waiting on each other; open Traffic for reversal."})
	for cycle in deadlocks.cleared_cycles:
		_record_event(EventLog.DEADLOCK_CLEARED, "network", {"trains": cycle.duplicate()})
	if traffic_button != null:
		traffic_button.text = "Traffic (%d)" % deadlocks.cycles.size() if not deadlocks.cycles.is_empty() else "Traffic"

func traffic_summary() -> String:
	var lines: PackedStringArray = []
	if deadlocks.cycles.is_empty():
		lines.append("No confirmed deadlock. A cycle must stay blocked for three simulation seconds; loading, station dwell and a single wait are not deadlocks.")
	else:
		for cycle in deadlocks.cycles:
			var names: PackedStringArray = []
			for id in cycle:
				var train := Fleet.find(fleet, int(id))
				names.append("#%d %s" % [int(id), train.get("name", "Unknown train")])
			lines.append("Deadlock: " + " ↔ ".join(names))
	for service in service_keys():
		var train := Fleet.assigned(fleet, service)
		lines.append("#%d %s: %s" % [int(train["id"]), train["name"], reservation_waits.get(service, fleet_train_status(int(train["id"])))])
	return "\n\n".join(lines)

func reverse_train_reason(id: int) -> String:
	# Shared preflight for the inspector and command: rejection changes no state.
	if not paused: return "Pause before reversing a train."
	var train := Fleet.find(fleet, id)
	var service: String = str(train.get("service", ""))
	var path: Curve2D
	var distance: float
	var departure: float
	if service == "passenger":
		if passenger_returning: return "This train is already returning to its departure stop."
		if passenger_stop_index < 0 or passenger_stop_index >= stop_distances.size(): return "No retained departure stop."
		path = route_path
		distance = route_distance
		departure = stop_distances[passenger_stop_index]
	elif passenger_services.has(service):
		var state = passenger_services[service]
		if state.returning: return "This train is already returning to its departure stop."
		if state.stop_index < 0 or state.stop_index >= state.distances.size(): return "No retained departure stop."
		path = state.path
		distance = state.distance
		departure = state.distances[state.stop_index]
	elif service == "freight":
		if freight_train.recovery_returning: return "This train is already returning to its departure stop."
		path = freight_train.route_path
		distance = freight_train.distance_along_route
		departure = 0.0 if freight_train.to_terminal else path.get_baked_length()
	else: return "Select an assigned passenger or freight train."
	if path.point_count < 2: return "No retained path to return along."
	if absf(distance - departure) <= 0.001: return "This train is already at its departure stop."
	return ""

func reverse_deadlocked_train(id: int) -> String:
	# Traffic retains its confirmed-deadlock control; the inspector can act earlier.
	if not paused: return "Pause before reversing a train."
	if not deadlocks.contains(id): return "This train is not involved in a confirmed deadlock."
	return reverse_train(id)

func reverse_train(id: int) -> String:
	var reason := reverse_train_reason(id)
	if not reason.is_empty(): return reason
	var train := Fleet.find(fleet, id)
	var service: String = str(train.get("service", ""))
	if service == "passenger":
		if passenger_returning: return "This train is already returning to its departure stop."
		passenger_return_stop = passenger_stop_index
		passenger_returning = true
		passenger_held = false
		travelling_to_b = not travelling_to_b
		wait_remaining = 0.0
		_update_train_transform()
	elif passenger_services.has(service):
		if passenger_services[service].returning: return "This train is already returning to its departure stop."
		passenger_services[service].reverse()
	elif service == "freight":
		if freight_train.recovery_returning: return "This train is already returning to its departure stop."
		freight_train.recovery_returning = true
		freight_train.held = false
		freight_train.to_terminal = not freight_train.to_terminal
		freight_train.dwell = 0.0
		freight_train._update_transform()
	else: return "Select an assigned passenger or freight train."
	_refresh_directional_routes(false)
	# Discard only this train's obsolete movement attempt. Other incidents remain.
	movement_conflicts.erase(id)
	movement_blocks.erase(id)
	reservation_waits.erase(service)
	traffic_wait_samples.erase(id)
	deadlocks.update(movement_blocks, sim_clock.tick)
	freight_train.reservation_wait = str(reservation_waits.get("freight", ""))
	traffic_button.text = "Traffic (%d)" % deadlocks.cycles.size() if not deadlocks.cycles.is_empty() else "Traffic"
	_rebuild_reservations()
	_record_event(EventLog.TRAIN_REVERSED, str(id), {"service": service, "action": "return to departure stop"})
	for cycle in deadlocks.cleared_cycles:
		_record_event(EventLog.DEADLOCK_CLEARED, "network", {"trains": cycle, "reversed": id})
	_update_toolbar()
	queue_redraw()
	return "#%d %s reversed in place. Resume: it returns along its existing route under reservations, then waits at its departure stop." % [id, train["name"]]

func _setup_traffic_dialog() -> void:
	traffic_dialog = TrafficDialog.new()
	traffic_dialog.configure(self)
	$Interface.add_child(traffic_dialog)
	traffic_button = Button.new()
	traffic_button.text = "Traffic"
	traffic_button.focus_mode = Control.FOCUS_NONE
	traffic_button.tooltip_text = "Inspect blocked trains and reverse a train in a confirmed deadlock"
	traffic_button.pressed.connect(_open_traffic_dialog)
	$Interface/HeaderBox/Toolbar.add_child(traffic_button)

func _open_traffic_dialog() -> void:
	paused = true
	is_dragging = false
	is_panning = false
	demolition_cells.clear()
	demolition_blocked.clear()
	build_plan.clear()
	_close_station_inspector()
	_rebuild_reservations()
	_update_toolbar()
	traffic_dialog.open_dialog()


func _saved_runtime_routes() -> Dictionary:
	return {"passenger_cells": RuntimeRoutes.encode(route_cells), "freight_cells": RuntimeRoutes.encode(freight_train.route_cells), "passenger_returning": passenger_returning, "passenger_return_stop": passenger_return_stop, "passenger_held": passenger_held, "freight_returning": freight_train.recovery_returning, "freight_held": freight_train.held}


func _saved_signals() -> Array:
	var result: Array = []
	for cell in track_signals: result.append([cell.x, cell.y, track_signals[cell]])
	return result

func _is_valid_signal_list(value: Array, checked_tracks: Dictionary) -> bool:
	if value.size() > MAP_WIDTH * MAP_HEIGHT: return false
	var seen: Dictionary = {}
	for entry in value:
		if not entry is Array or entry.size() != 3: return false
		if not RuntimeRoutes.valid_cells([[entry[0], entry[1]]]): return false
		var cell := Vector2i(int(entry[0]), int(entry[1]))
		if seen.has(cell) or not checked_tracks.has(cell) or _is_station_space(cell) or cell in [STATION_A, STATION_B, STATION_C, FOREST_SITE, CARGO_TERMINAL]: return false
		if not TrackGeometry.is_straight(checked_tracks[cell]) or entry[2] not in ["auto", "stop"]: return false
		seen[cell] = true
	return true

func _setup_signal_tool() -> void:
	signal_button = Button.new()
	signal_button.text = "Signals"
	signal_button.toggle_mode = true
	signal_button.focus_mode = Control.FOCUS_NONE
	signal_button.tooltip_text = "Click straight track: automatic block signal → manual stop → remove. Signals apply in both directions."
	signal_button.pressed.connect(func() -> void:
		demolition_mode = false
		signal_tool_mode = not signal_tool_mode
		waypoint_tool_mode = false
		switch_tool_mode = false
		inspect_mode = false
		is_dragging = false
		_close_station_inspector()
		_update_toolbar())
	$Interface/HeaderBox/Toolbar.add_child(signal_button)

func _use_signal_tool(cell: Vector2i) -> void:
	if planning_mode:
		var working: Dictionary = construction_plan.projected(tracks)
		if _plan_protected(cell) or not working.has(cell) or not TrackGeometry.is_straight(working[cell]): return
		var signs: Dictionary = construction_plan.projected_signals(track_signals)
		var draft_mode: Variant = null
		if not signs.has(cell): draft_mode = "auto"
		elif signs[cell] == "auto": draft_mode = "stop"
		construction_plan.stage_signals({cell: draft_mode}, track_signals, tracks)
		return
	if not tracks.has(cell) or not TrackGeometry.is_straight(tracks[cell]) or _is_station_space(cell) or cell in [STATION_A, STATION_B, STATION_C, FOREST_SITE, CARGO_TERMINAL]:
		_show_notice("Place a signal on straight track outside station platforms.")
		return
	var old: String = str(track_signals.get(cell, ""))
	var mode := "auto" if old == "" else ("stop" if old == "auto" else "")
	_submit_command("set_signal", {"x": cell.x, "y": cell.y, "mode": mode})

func _execute_set_signal(data: Dictionary) -> void:
	if not RuntimeRoutes.valid_cells([[data.get("x"), data.get("y")]]) or not data.get("mode") is String: return
	var cell := Vector2i(int(data["x"]), int(data["y"]))
	var mode: String = str(data["mode"])
	if not tracks.has(cell) or not TrackGeometry.is_straight(tracks[cell]) or _is_station_space(cell) or cell in [STATION_A, STATION_B, STATION_C, FOREST_SITE, CARGO_TERMINAL] or mode not in ["", "auto", "stop"]: return
	if mode.is_empty(): track_signals.erase(cell)
	else: track_signals[cell] = mode
	_rebuild_reservations()
	_record_event(EventLog.SIGNAL_CHANGED, "player", {"x": cell.x, "y": cell.y, "mode": mode})
	_show_notice("Signal %s at %d,%d." % ["removed" if mode.is_empty() else mode, cell.x, cell.y])
	queue_redraw()

func _draw_signals() -> void:
	for cell in track_signals:
		var center := _cell_center(cell) + Vector2(0, -12)
		var stop: bool = track_signals[cell] == "stop"
		var color := Color(1, 0.35, 0.25) if stop else Color(0.9, 0.95, 1)
		draw_rect(Rect2(center - Vector2(6, 6), Vector2(12, 12)), Color(0.05, 0.08, 0.1))
		if stop: draw_rect(Rect2(center - Vector2(6, 6), Vector2(12, 12)), color, false, 2)
		else: draw_circle(center, 6, color, false, 1.5)
		draw_string(ThemeDB.fallback_font, center + Vector2(-4, 4), "S" if stop else "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)

func set_dispatch_hold(id: int, hold: bool) -> String:
	if not paused: return "Pause before changing dispatch instructions."
	var train := Fleet.find(fleet, id)
	if train.get("service", "") == "passenger":
		passenger_held = hold
		passenger_service_enabled = not hold
	elif passenger_services.has(train.get("service", "")):
		passenger_services[train.service].held = hold
		passenger_services[train.service].enabled = not hold
	elif train.get("service", "") == "freight":
		freight_train.held = hold
		freight_train.service_enabled = not hold
	else: return "Choose an assigned train."
	_reset_traffic_state("Dispatch instruction changed")
	_rebuild_reservations()
	_record_event(EventLog.DISPATCH_CHANGED, str(id), {"hold": hold})
	return "Train held at its current position." if hold else "Train released. Resume to run under reservations and signals."


func _setup_speed_control() -> void:
	speed_selector = OptionButton.new()
	speed_selector.name = "SimulationSpeed"
	speed_selector.focus_mode = Control.FOCUS_NONE
	for speed in GAME_SPEEDS:
		speed_selector.add_item("%d×" % int(speed))
	speed_selector.select(0)
	speed_selector.item_selected.connect(_set_game_speed)
	var toolbar: Node = $Interface/HeaderBox/Toolbar
	toolbar.add_child(speed_selector)
	toolbar.move_child(speed_selector, pause_button.get_index() + 1)

func _set_game_speed(index: int) -> void:
	if index < 0 or index >= GAME_SPEEDS.size() or _modal_open(): return
	sim_clock.speed = GAME_SPEEDS[index]
	speed_selector.select(index)
	_show_notice("Simulation speed %d×%s." % [int(sim_clock.speed), " — still paused" if paused else ""])


func _refresh_directional_routes(notify: bool = true) -> void:
	var passenger_was_clear := route_connected
	var next_stop := _next_passenger_stop()
	route_connected = next_stop >= 0 and next_stop < stop_distances.size() and passenger_travel.is_clear(route_cells, route_path, route_distance, _passenger_target_distance(), tracks, float(TILE_SIZE))
	if route_connected and Fleet.length(Fleet.assigned(fleet, "passenger")) > Reservations.VEHICLE_LENGTH:
		route_connected = Consists.stop_clearance(route_path, _passenger_target_distance(), Fleet.length(Fleet.assigned(fleet, "passenger")), tracks, float(TILE_SIZE), track_signals).is_empty()
	passenger_route_error = "" if route_connected else "Route incomplete ahead — stopped here. Repair the path to the next destination."
	for key in additional_service_keys(): passenger_services[key].check_route(self, notify)
	if freight_train == null: return
	var freight_was_clear: bool = freight_train.route_valid
	var target: float = freight_train.route_path.get_baked_length() if freight_train.to_terminal else 0.0
	freight_train.route_valid = freight_travel.is_clear(freight_train.route_cells, freight_train.route_path, freight_train.distance_along_route, target, tracks, float(TILE_SIZE))
	if freight_train.route_valid and Fleet.length(Fleet.assigned(fleet, "freight")) > Reservations.VEHICLE_LENGTH:
		freight_train.route_valid = Consists.stop_clearance(freight_train.route_path, target, Fleet.length(Fleet.assigned(fleet, "freight")), tracks, float(TILE_SIZE), track_signals).is_empty()
	if notify:
		if passenger_was_clear and not route_connected:
			_show_notice("Passenger train stopped: track incomplete ahead. Repair its path to continue.")
		if freight_was_clear and not freight_train.route_valid:
			_show_notice("Freight train stopped: track incomplete ahead. Repair its path to continue.")


func can_place_waypoint(cell: Vector2i) -> bool:
	return tracks.has(cell) and not _is_station_space(cell) and cell not in [STATION_A, STATION_B, STATION_C, FOREST_SITE, CARGO_TERMINAL]

func _setup_waypoint_tool() -> void:
	waypoint_button = Button.new()
	waypoint_button.text = "Waypoint"
	waypoint_button.toggle_mode = true
	waypoint_button.focus_mode = Control.FOCUS_NONE
	waypoint_button.tooltip_text = "Select a track cell, then assign it to a service leg in Routes."
	waypoint_button.pressed.connect(func() -> void:
		demolition_mode = false
		waypoint_tool_mode = not waypoint_tool_mode
		signal_tool_mode = false
		switch_tool_mode = false
		inspect_mode = false
		is_dragging = false
		_close_station_inspector()
		_update_toolbar())
	$Interface/HeaderBox/Toolbar.add_child(waypoint_button)

func _use_waypoint_tool(cell: Vector2i) -> void:
	if not can_place_waypoint(cell):
		_show_notice("Choose existing track outside station/industry platforms.")
		return
	_open_routes_editor(cell)

func _draw_waypoints() -> void:
	for service in service_keys():
		var directives: Dictionary = services[service].get("waypoints", {})
		for leg in directives:
			for index in range(directives[leg].size()):
				var point: Array = directives[leg][index]
				var center := _cell_center(Vector2i(int(point[0]), int(point[1]))) + Vector2(0, 11)
				var diamond := PackedVector2Array([center + Vector2(0, -5), center + Vector2(5, 0), center + Vector2(0, 5), center + Vector2(-5, 0), center + Vector2(0, -5)])
				draw_polyline(diamond, Color(1, 0.9, 0.5), 1.5)
				draw_string(ThemeDB.fallback_font, center + Vector2(7, 4), "%s%d" % ["P" if ServiceRoutes.is_passenger_key(service) else "F", index + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.9, 0.5))


func additional_service_keys() -> Array:
	var keys := passenger_services.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(Fleet.assigned(fleet, a).id) < int(Fleet.assigned(fleet, b).id))
	return keys

func service_keys() -> Array:
	return ["passenger", "freight"] + additional_service_keys()

func _saved_passenger_services() -> Dictionary:
	var result: Dictionary = {}
	for key in additional_service_keys(): result[key] = passenger_services[key].save_state()
	return result

func _valid_service_assignments(configuration: Dictionary, owned: Dictionary) -> bool:
	for key in configuration:
		if Fleet.assigned(owned, key).is_empty(): return false
	for train in owned.trains:
		if train.service != "" and not configuration.has(train.service): return false
	return true

func start_passenger_service(id: int, home: String = "a") -> String:
	if not paused: return "Pause before starting a service."
	var train := Fleet.find(fleet, id)
	if train.is_empty() or train.service != "" or Fleet.MODELS[train.model].kind != "passenger": return "Choose a stored passenger train."
	if not ServiceRoutes.STATIONS.has(home): return "Choose a passenger starting station."
	if services.size() >= ServiceRoutes.MAX_PASSENGER_SERVICES + 1: return "This prototype supports up to eight active passenger services."
	var service_id := id
	# Replacement can leave the original service attached to a different train.
	while services.has("passenger_%d" % service_id): service_id = service_id % 999999999 + 1
	var key := "passenger_%d" % service_id
	var configuration := {"name": "Passenger Service %d" % id, "stops": [home, "b" if home == "a" else "a"], "mode": "shuttle", "waypoints": {}}
	var built := ServiceRoutes.build(tracks, configuration.stops, float(TILE_SIZE))
	if built.cells.is_empty(): return "Complete track from the starting station to %s first." % ServiceRoutes.STATIONS[configuration.stops[1]].name
	var fit := _consist_service_fit(train, configuration)
	if not fit.is_empty(): return fit
	_rebuild_reservations()
	for cell in reservations.footprint(built.path, 0, float(TILE_SIZE), _fleet_length(train)):
		if reservations.owners.has(cell): return "Starting platform is occupied or reserved. Let the other train clear it, then pause and try again."
	var running := PassengerService.new()
	running.configure(key, configuration, built)
	train.service = key
	services[key] = configuration
	passenger_services[key] = running
	running.check_route(self, false)
	_reset_traffic_state("Passenger service added")
	_rebuild_reservations()
	_record_event(EventLog.ROUTE_CHANGED, str(id), {"service": key, "action": "created"})
	queue_redraw()
	return "%s started at %s. Choose it in Routes to edit stops, mode and waypoints." % [configuration.name, ServiceRoutes.STATIONS[home].name]

func remove_passenger_service(id: int) -> String:
	if not paused: return "Pause before removing a service."
	var train := Fleet.find(fleet, id)
	var key: String = str(train.get("service", ""))
	if not passenger_services.has(key): return "Only additional passenger services can be removed."
	var running = passenger_services[key]
	if running.enabled or not running.at_home(): return "Withdraw this service and let it finish its trip, returning empty to its first station. Then pause and store it."
	passenger_services.erase(key)
	services.erase(key)
	train.service = ""
	_reset_traffic_state("Passenger service removed")
	_rebuild_reservations()
	_record_event(EventLog.ROUTE_CHANGED, str(id), {"service": key, "action": "removed"})
	queue_redraw()
	return "Service removed. Its train is stored off-map and can be sold or reassigned."

func service_enabled(key: String) -> bool:
	if key == "passenger": return passenger_service_enabled
	if key == "freight": return freight_train.service_enabled
	return passenger_services[key].enabled

func upgrade_fleet_train(id: int, kind: String) -> String:
	if not paused: return "Pause before buying upgrades."
	var train := Fleet.find(fleet, id)
	if train.is_empty() or kind not in ["capacity", "speed"]: return "Choose an owned train and upgrade."
	_sync_fleet_upgrades()
	if kind == "speed" and Fleet.speed(train) >= Consists.speed_limit(train): return "Attached stock already limits speed; remove it before buying another speed upgrade."
	var field := kind + "_level"
	var level := int(train[field])
	if level >= 3: return "This upgrade is already at maximum level."
	var passenger: bool = Fleet.MODELS[train.model].kind == "passenger"
	var base: int = (250 if passenger else 300) if kind == "capacity" else (200 if passenger else 250)
	var price := base * (level + 1)
	if money < price: return "Insufficient funds: upgrade costs £%d." % price
	money -= price
	total_vehicle_cost += price
	train[field] = level + 1
	_apply_fleet_specs()
	_record_event(EventLog.UPGRADE_BOUGHT, str(id), {"kind": kind, "level": level + 1, "price": price})
	return "%s upgrade bought for £%d." % [kind.capitalize(), price]


# Snapshots intentionally expose retained geometry, including broken track.
func inspection_trains() -> Array:
	var result: Array = []
	for key in service_keys():
		var assigned: Dictionary = Fleet.assigned(fleet, key)
		if assigned.is_empty(): continue
		var cells: Array[Vector2i]
		var path: Curve2D
		var distance: float
		var target: float
		if key == "passenger":
			cells = route_cells
			path = route_path
			distance = route_distance
			target = _passenger_target_distance() if not stop_distances.is_empty() else 0.0
		elif key == "freight":
			cells = freight_train.route_cells
			path = freight_train.route_path
			distance = freight_train.distance_along_route
			target = path.get_baked_length() if freight_train.to_terminal else 0.0
		else:
			var running = passenger_services[key]
			cells = running.cells
			path = running.path
			distance = running.distance
			target = running.target_distance() if not running.distances.is_empty() else 0.0
		result.append({"key": key, "id": int(assigned.id), "name": str(services[key].name), "cells": cells, "path": path, "distance": distance, "target": target})
	return result

func _setup_inspection() -> void:
	inspection_panel = InspectionPanel.new()
	inspection_panel.name = "InspectionPanel"
	$Interface.add_child(inspection_panel)
	inspection_panel.anchor_left = 1.0
	inspection_panel.anchor_right = 1.0
	inspection_panel.offset_left = -300
	inspection_panel.offset_right = -12
	inspection_panel.hide()
	inspection_panel.changed.connect(queue_redraw)
	inspection_panel.planning_changed.connect(_set_planning_mode)
	inspection_panel.apply_plan.connect(_apply_draft)
	inspection_panel.discard_plan.connect(_discard_draft)
	inspection_panel.pick_corridor.connect(func(which: int) -> void:
		corridor_pick = which
		_show_notice("Click track to choose corridor %s." % ("start" if which == 1 else "end")))
	inspection_panel.draft_corridor.connect(_draft_corridor_signals)
	inspection_panel.pick_blueprint.connect(func(which: int) -> void:
		corridor_pick = which + 2
		_show_notice("Click the map to choose blueprint corner %d." % which))
	inspection_panel.save_blueprint.connect(_save_blueprint)
	inspection_panel.import_blueprints.connect(_open_blueprint_file.bind(false))
	inspection_panel.export_blueprint.connect(_open_blueprint_file.bind(true))
	blueprint_file_dialog = FileDialog.new()
	blueprint_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	blueprint_file_dialog.filters = PackedStringArray(["*.json ; Track blueprint libraries"])
	blueprint_file_dialog.exclusive = true
	blueprint_file_dialog.file_selected.connect(func(path: String) -> void:
		if blueprint_file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE: _export_blueprint(path)
		else: _import_blueprints(path))
	$Interface.add_child(blueprint_file_dialog)
	inspection_panel.place_blueprint.connect(func() -> void:
		if inspection_panel.selected_blueprint().is_empty():
			_show_notice("Select a saved blueprint first.")
			return
		corridor_pick = 5
		_show_notice("Click the map for the blueprint's top-left corner. Escape cancels."))
	inspection_button = Button.new()
	inspection_button.text = "Overlays"
	inspection_button.toggle_mode = true
	inspection_button.focus_mode = Control.FOCUS_NONE
	inspection_button.tooltip_text = "Actual service paths, signal blocks and construction impact. Reservations has its own hatched toggle."
	inspection_button.toggled.connect(func(enabled: bool) -> void:
		inspection_panel.visible = enabled
		if enabled: station_panel.hide())
	$Interface/HeaderBox/Toolbar.add_child(inspection_button)

func _update_inspection() -> void:
	inspection_panel.refresh_blueprints(blueprints)
	var trains := inspection_trains()
	var changes: Dictionary = construction_plan.changes.duplicate() if planning_mode else {}
	if is_dragging:
		if demolition_mode:
			for cell in demolition_cells: changes[cell] = null
		else:
			changes.merge(build_plan.get("changes", {}), true)
	construction_feedback = construction_analyzer.analyze(tracks, changes, trains, reservations.owners, float(TILE_SIZE)) if not changes.is_empty() else {"affected": [], "blocked": {}}
	if planning_mode:
		for cell in construction_plan.signal_changes:
			if reservations.owners.has(cell): construction_feedback.blocked[cell] = reservations.owners[cell]
		for train in trains:
			var touched := false
			for cell in train.cells:
				if construction_plan.signal_changes.has(cell): touched = true
			if touched and construction_feedback.affected.filter(func(row: Dictionary) -> bool: return row.id == train.id).is_empty():
				construction_feedback.affected.append({"key": train.key, "id": train.id, "name": train.name, "effect": "Signal authority changes on this route; inspect block boundaries"})
	if is_dragging and demolition_mode:
		for cell in demolition_blocked:
			if reservations.owners.has(cell): construction_feedback.blocked[cell] = reservations.owners[cell]
	if inspection_panel == null or not inspection_panel.visible: return
	inspection_panel.plan_controls.visible = planning_mode
	if planning_mode:
		var quote: Dictionary = construction_plan.quote()
		var error: String = construction_plan.validate(tracks, reservations.owners, track_signals, Vector2i(MAP_WIDTH, MAP_HEIGHT), _plan_protected, money)
		inspection_panel.plan_summary.text = "Draft: %d tracks / %d signals\nBuild £%d | Refund £%d | Net £%d\n%s" % [construction_plan.changes.size(), construction_plan.signal_changes.size(), quote.cost, quote.refund, quote.net, "Ready to apply as one action." if error.is_empty() else error]
	inspection_panel.corridor_label.text = "Signal corridor: %s → %s\n%d selected route tiles" % [str(corridor_start), str(corridor_end), corridor_cells.size()]
	var lines: PackedStringArray = ["Paths: retained train routes; gaps remain visible. Squares mark route origins; circles mark the next destination. Labels use permanent train IDs.", "Reservations: use the toolbar toggle for hatched ownership."]
	if inspection_panel.blocks:
		lines.append("Blocks: dotted outlines, B = block ID. Authority includes reservations; it does not mean every tile is occupied.")
	lines.append("Cell %d,%d" % [hovered_cell.x, hovered_cell.y])
	if inspection_panel.congestion:
		lines.append("Waiting here: %.1f train-seconds in the last ~60 simulation seconds. Bar length and text represent observed stopped traffic, not a forecast." % (float(traffic_metrics.window_cells.get(hovered_cell, 0)) / 60.0))
	if reservations.occupied_owners.has(hovered_cell):
		lines.append("Occupied by train #%d" % int(reservations.occupied_owners[hovered_cell]))
	elif reservations.owners.has(hovered_cell):
		lines.append("Reserved by train #%d" % int(reservations.owners[hovered_cell]))
	if block_signals.cell_blocks.has(hovered_cell):
		var block: int = block_signals.cell_blocks[hovered_cell]
		var ids: PackedStringArray = []
		for id in block_signals.block_owners.get(block, {}): ids.append("#%d" % int(id))
		lines.append("Block B%d authority: %s" % [block, ", ".join(ids) if not ids.is_empty() else "none"])
	if is_dragging or (planning_mode and not construction_plan.is_empty()):
		lines.append("Preview only; traffic may change before release.")
		for affected in construction_feedback.affected:
			lines.append("#%d %s: %s" % [affected.id, affected.name, affected.effect])
		for cell in construction_feedback.blocked:
			lines.append("%d,%d reserved by #%d; cannot edit" % [cell.x, cell.y, int(construction_feedback.blocked[cell])])
		if construction_feedback.affected.is_empty(): lines.append("No retained service path crosses this edit.")
	inspection_panel.refresh(trains, "\n\n".join(lines))

func _draw_inspection_paths() -> void:
	if inspection_panel == null: return
	if inspection_panel.blocks:
		for cell in block_signals.cell_blocks:
			var origin := Vector2(cell) * TILE_SIZE
			var block: int = block_signals.cell_blocks[cell]
			for edge in [Vector2.RIGHT, Vector2.DOWN]:
				var start: Vector2 = origin + edge * TILE_SIZE
				var along: Vector2 = Vector2.DOWN if edge == Vector2.RIGHT else Vector2.RIGHT
				for offset in range(0, TILE_SIZE, 8):
					draw_line(start + along * offset, start + along * (offset + 4), Color.WHITE, 1.0)
			draw_string(ThemeDB.fallback_font, origin + Vector2(2, 29), "B%d" % block, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	if inspection_panel.congestion:
		for cell in traffic_metrics.window_cells:
			var seconds: float = float(traffic_metrics.window_cells[cell]) / 60.0
			var origin := Vector2(cell) * TILE_SIZE
			var length := minf(seconds / 10.0, 1.0) * (TILE_SIZE - 4)
			draw_rect(Rect2(origin + Vector2(2, TILE_SIZE - 5), Vector2(length, 3)), Color.WHITE)
			draw_string(ThemeDB.fallback_font, origin + Vector2(2, TILE_SIZE - 7), "%.1fs" % seconds, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	if not inspection_panel.routes: return
	for train in inspection_trains():
		if not inspection_panel.selected_service.is_empty() and train.key != inspection_panel.selected_service: continue
		var path: Curve2D = train.path
		if path.point_count < 2: continue
		var length := path.get_baked_length()
		var tint: Color = Palette.get_color(Palette.Role.HOVER_OK)
		# Dash patterns differ by permanent ID, so colour is never the sole key.
		var spacing := 12.0 + float(int(train.id) % 3) * 4.0
		var distance := 0.0
		while distance < length:
			draw_line(path.sample_baked(distance), path.sample_baked(minf(distance + spacing * 0.6, length)), tint, 3.0)
			distance += spacing
		var origin := path.sample_baked(0.0)
		draw_rect(Rect2(origin - Vector2(5, 5), Vector2(10, 10)), Color.WHITE, false, 2.0)
		draw_arc(path.sample_baked(train.target), 7, 0, TAU, 16, Color.WHITE, 2.0)
		var label := path.sample_baked(train.distance) + Vector2(8, -12 - int(train.id) % 3 * 12)
		draw_string(ThemeDB.fallback_font, label, "#%d %s" % [train.id, train.name], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


func _setup_problems() -> void:
	problems_dialog = ProblemsDialog.new()
	problems_dialog.configure(self)
	$Interface.add_child(problems_dialog)
	problems_button = Button.new()
	problems_button.text = "Problems"
	problems_button.focus_mode = Control.FOCUS_NONE
	problems_button.tooltip_text = "Current waiting, incomplete routes, holds and deadlocks; searchable incident history. Opens paused."
	problems_button.pressed.connect(_open_problems)
	$Interface/HeaderBox/Toolbar.add_child(problems_button)

func _open_problems() -> void:
	paused = true
	is_dragging = false
	is_panning = false
	demolition_cells.clear()
	demolition_blocked.clear()
	build_plan.clear()
	_update_toolbar()
	problems_dialog.open_dialog()

func problem_rows() -> Array:
	var rows: Array = []
	if freight_train == null: return rows
	for train in inspection_trains():
		var key: String = train.key
		var incomplete: bool
		var held: bool
		if key == "passenger":
			incomplete = not route_connected
			held = passenger_held
		elif key == "freight":
			incomplete = not freight_train.route_valid
			held = freight_train.held
		else:
			incomplete = not passenger_services[key].connected
			held = passenger_services[key].held
		var stats: Dictionary = traffic_metrics.statistics(train.id)
		var level := "Warning"
		var issue := ""
		var explanation := ""
		if deadlocks.contains(train.id):
			level = "Urgent"
			issue = "Confirmed deadlock"
			explanation = "Trains are waiting on each other. Check signal boundaries and the passing-loop route. Open Traffic for physical reversal if needed."
		elif incomplete:
			issue = "Route incomplete"
			explanation = "Complete or repair the track and waypoint path to the next destination. A missing route does not teleport this train."
		elif held:
			level = "Info"
			issue = "Dispatcher hold"
			explanation = "This is an intentional hold, not measured congestion. Resume the train in Traffic when ready."
		elif stats.continuous_seconds > 0.0:
			issue = "Waiting %.1fs" % float(stats.continuous_seconds)
			explanation = stats.reason + ". Automatic signals release when their block clears. Check Overlays for ownership; loops need boundaries on both branches."
		if issue.is_empty(): continue
		var owned: Dictionary = Fleet.find(fleet, train.id)
		var title := "#%d %s — %s — %s" % [train.id, str(owned.get("name", "Train")), train.name, issue]
		var details := "%s\n%s\nMeasured traffic waiting: %.1fs continuous, %.1fs recent (~60s), %.1fs since measurement began. Station dwell, loading and dispatcher holds are excluded. Measurements restart after loading; incident history is saved." % [title, explanation, float(stats.continuous_seconds), float(stats.recent_seconds), float(stats.total_seconds)]
		rows.append({"key": "train:%d" % train.id, "id": train.id, "severity": level, "title": title, "details": details, "cell": Vector2i(-1, -1)})
	return rows

func incident_rows() -> Array:
	var rows: Array = []
	var events: Array = event_log.recent(200)
	events.reverse()
	for event in events:
		if event.type not in [EventLog.TRAIN_WAITING, EventLog.DEADLOCK_DETECTED, EventLog.DEADLOCK_CLEARED, EventLog.DISPATCH_CHANGED, EventLog.TRAIN_REVERSED, EventLog.TRAIN_RECOVERED]: continue
		var severity := "Warning" if event.type == EventLog.TRAIN_WAITING else "Info"
		if event.type == EventLog.DEADLOCK_DETECTED: severity = "Urgent"
		var id := int(event.subject) if str(event.subject).is_valid_int() else -1
		if id < 0 and event.data.has("trains") and not event.data.trains.is_empty(): id = int(event.data.trains[0])
		var train := Fleet.find(fleet, id)
		var name: String = str(train.get("name", ""))
		var title := "%.1fs: %s %s" % [float(event.tick) / 60.0, EventLog.summary(event), name]
		var cell := Vector2i(int(event.data.get("x", -1)), int(event.data.get("y", -1)))
		rows.append({"key": "event:%d" % int(event.id), "id": id, "severity": severity, "title": title, "details": "Historical incident; it may already be resolved.\n" + title + "\nLocate follows the train's current position if it is still active, otherwise the recorded track location.", "cell": cell})
	return rows

func can_locate_problem(row: Dictionary) -> bool:
	var train := Fleet.find(fleet, int(row.get("id", -1)))
	return (not train.is_empty() and services.has(str(train.service))) or _is_inside_map(row.get("cell", Vector2i(-1, -1)))

func locate_problem(row: Dictionary) -> bool:
	if not can_locate_problem(row): return false
	var train := Fleet.find(fleet, int(row.get("id", -1)))
	var key: String = str(train.get("service", ""))
	if key == "passenger": camera.position = train_position
	elif key == "freight": camera.position = freight_train.position
	elif passenger_services.has(key): camera.position = passenger_services[key].position
	else: camera.position = _cell_center(row.cell)
	camera.force_update_scroll()
	return true


func _flush_notifications() -> void:
	var alert: Dictionary = notifications.take()
	if alert.is_empty(): return
	if alert.pause:
		paused = true
		_show_notice("Paused by alert: " + str(alert.text) + ". Resume with " + InputActions.key_label(InputActions.TOGGLE_PAUSE) + ".")
	else:
		_show_notice(str(alert.text))


func _plan_protected(cell: Vector2i) -> bool:
	return _is_station_space(cell) or cell in [STATION_A, STATION_B, STATION_C, FOREST_SITE, CARGO_TERMINAL]

func _set_planning_mode(enabled: bool) -> void:
	_clear_direct_inspection()
	if not enabled and not construction_plan.is_empty():
		inspection_panel.plan_toggle.set_pressed_no_signal(true)
		_show_notice("Apply or discard the draft before leaving planning mode.")
		return
	planning_mode = enabled
	corridor_pick = 0
	is_dragging = false
	build_plan.clear()
	if enabled:
		paused = true
		for command in command_queue.drain(sim_clock.tick + 1): _execute_command(command)
		inspect_mode = false
		waypoint_tool_mode = false
		signal_tool_mode = false
		_update_toolbar()
	queue_redraw()

func _discard_draft() -> void:
	corridor_pick = 0
	corridor_cells.clear()
	construction_plan.clear()
	is_dragging = false
	build_plan.clear()
	_show_notice("Construction draft discarded.")
	queue_redraw()

func _apply_draft() -> bool:
	paused = true
	is_dragging = false
	_rebuild_reservations()
	var error: String = construction_plan.validate(tracks, reservations.owners, track_signals, Vector2i(MAP_WIDTH, MAP_HEIGHT), _plan_protected, money)
	if not error.is_empty():
		_show_notice(error)
		return false
	var quote: Dictionary = construction_plan.quote()
	var before: Dictionary = construction_plan.before.duplicate()
	var after: Dictionary = construction_plan.changes.duplicate()
	var signals_before: Dictionary = {}
	var signals_after: Dictionary = {}
	for cell in after:
		signals_before[cell] = track_signals.get(cell)
		signals_after[cell] = track_signals.get(cell) if after[cell] != null and TrackGeometry.is_straight(after[cell]) else null
	signals_before.merge(construction_plan.signal_before, true)
	signals_after.merge(construction_plan.signal_changes, true)
	for cell in signals_after:
		if signals_after[cell] == null: track_signals.erase(cell)
		else: track_signals[cell] = signals_after[cell]
	for cell in after:
		if after[cell] == null: tracks.erase(cell)
		else: tracks[cell] = after[cell]
	money -= int(quote.net)
	total_construction_cost += int(quote.cost)
	_record_construction_change(before, after, -int(quote.net), int(quote.cost))
	construction_undo.back()["signals_before"] = signals_before
	construction_undo.back()["signals_after"] = signals_after
	_record_event(EventLog.CONSTRUCTION_APPLIED, "player", {"tracks": after.size(), "signals": signals_after.size(), "cost": quote.cost, "refund": quote.refund})
	construction_plan.clear()
	corridor_pick = 0
	_check_route()
	_show_notice("Applied %d tracks and %d signals; net cost £%d. Undo treats the plan as one action." % [after.size(), signals_after.size(), quote.net])
	_update_toolbar()
	queue_redraw()
	return true

func _draw_construction_draft() -> void:
	if not planning_mode: return
	if _is_inside_map(blueprint_first) and _is_inside_map(blueprint_last):
		var origin := Vector2i(mini(blueprint_first.x, blueprint_last.x), mini(blueprint_first.y, blueprint_last.y))
		var size := Vector2i(absi(blueprint_first.x - blueprint_last.x) + 1, absi(blueprint_first.y - blueprint_last.y) + 1)
		draw_rect(Rect2(Vector2(origin) * TILE_SIZE, Vector2(size) * TILE_SIZE).grow(-1), Color.WHITE, false, 2.0)
	for cell in corridor_cells:
		draw_rect(Rect2(Vector2(cell) * TILE_SIZE, Vector2.ONE * TILE_SIZE).grow(-2), Color.WHITE, false, 1.0)
	for cell in construction_plan.signal_changes:
		var mode: Variant = construction_plan.signal_changes[cell]
		draw_string(ThemeDB.fallback_font, _cell_center(cell) + Vector2(-8, -16), "P×" if mode == null else "PA" if mode == "auto" else "PS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	for cell in construction_plan.changes:
		var tile: Variant = construction_plan.changes[cell]
		var center := _cell_center(cell)
		if tile != null: _draw_track(cell, tile, true)
		else:
			draw_line(center - Vector2(10, 10), center + Vector2(10, 10), Color.WHITE, 2.0)
			draw_line(center - Vector2(10, -10), center + Vector2(10, -10), Color.WHITE, 2.0)
		draw_string(ThemeDB.fallback_font, center + Vector2(-13, -8), "P", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)


func _pick_corridor_cell(cell: Vector2i) -> void:
	if not planning_mode or not _is_inside_map(cell): return
	if corridor_pick == 5:
		if _place_blueprint(cell): corridor_pick = 0
		return
	if corridor_pick in [3, 4]:
		if corridor_pick == 3: blueprint_first = cell
		else: blueprint_last = cell
		corridor_pick = 0
		inspection_panel.blueprint_status.text = "Rectangle %s → %s. Save copies built track and signals; facilities are omitted." % [str(blueprint_first), str(blueprint_last)]
		queue_redraw()
		return
	var working: Dictionary = construction_plan.projected(tracks)
	if not working.has(cell):
		_show_notice("Choose existing or drafted track for the corridor endpoint.")
		return
	if corridor_pick == 1: corridor_start = cell
	else: corridor_end = cell
	corridor_pick = 0
	corridor_cells = RailRouter.find_route(working, corridor_start, corridor_end)
	queue_redraw()

func _draft_corridor_signals() -> bool:
	if not planning_mode: return false
	var working: Dictionary = construction_plan.projected(tracks)
	var modes: Array[String] = ["auto", "stop", ""]
	var result: Dictionary = SignalCorridor.plan(working, corridor_start, corridor_end, int(inspection_panel.corridor_spacing.value), modes[inspection_panel.corridor_mode.selected], _plan_protected)
	if not result.error.is_empty():
		_show_notice(result.error)
		return false
	corridor_cells.assign(result.cells)
	construction_plan.stage_signals(result.updates, track_signals, tracks)
	_show_notice("Corridor signals drafted; inspect block boundaries before Apply plan.")
	queue_redraw()
	return true

func _load_blueprints() -> void:
	var result: Dictionary = TrackBlueprints.load_library(BLUEPRINT_PATH)
	blueprints = result.designs
	blueprint_library_error = result.error
	inspection_panel.refresh_blueprints(blueprints)
	inspection_panel.blueprint_status.text = result.error if not result.error.is_empty() else "%d saved layouts. Pick two map corners to capture a built layout." % blueprints.size()

func _save_blueprint() -> bool:
	if not planning_mode: return false
	if not blueprint_library_error.is_empty():
		_show_notice(blueprint_library_error + " Preserve or repair track_blueprints.json before saving designs.")
		return false
	if not _is_inside_map(blueprint_first) or not _is_inside_map(blueprint_last):
		_show_notice("Choose both rectangle corners first.")
		return false
	var name: String = inspection_panel.blueprint_name.text.strip_edges()
	for design in blueprints:
		if design.name == name:
			_show_notice("That blueprint name already exists. Choose a different name.")
			return false
	var data: Dictionary = TrackBlueprints.capture(tracks, track_signals, blueprint_first, blueprint_last, name, _plan_protected)
	if data.is_empty():
		_show_notice("Enter a name and select built track outside platforms or facility grounds.")
		return false
	var proposed := blueprints.duplicate()
	proposed.append(data)
	if not TrackBlueprints.save_library(BLUEPRINT_PATH, proposed):
		_show_notice("Could not save the blueprint library (maximum 50 designs).")
		return false
	blueprints = proposed
	inspection_panel.blueprint_search.clear()
	inspection_panel.refresh_blueprints(blueprints)
	inspection_panel.blueprint_choice.select(inspection_panel.blueprint_names.find(name))
	inspection_panel.blueprint_status.text = "Saved %s: %d×%d tiles, %d tracks and %d signals." % [name, data.width, data.height, data.tiles.size(), data.signals.size()]
	_show_notice("Blueprint saved locally; its prior library is kept as a backup.")
	return true

func _place_blueprint(anchor: Vector2i) -> bool:
	if not planning_mode: return false
	var name: String = inspection_panel.selected_blueprint()
	var data: Dictionary = {}
	for design in blueprints:
		if design.name == name: data = design
	if data.is_empty():
		_show_notice("Select a saved blueprint first.")
		return false
	var proposal: Dictionary = TrackBlueprints.place(data, anchor, construction_plan.projected(tracks), construction_plan.projected_signals(track_signals), Vector2i(MAP_WIDTH, MAP_HEIGHT), _plan_protected)
	if not proposal.error.is_empty():
		_show_notice(proposal.error)
		return false
	construction_plan.stage(proposal.tracks, tracks)
	construction_plan.stage_signals(proposal.signals, track_signals, tracks)
	_show_notice("Blueprint drafted. Review price, reservations and service impact before Apply plan.")
	queue_redraw()
	return true

func _open_blueprint_file(exporting: bool) -> void:
	if exporting and inspection_panel.selected_blueprint().is_empty():
		_show_notice("Select a saved blueprint to export.")
		return
	corridor_pick = 0
	blueprint_file_dialog.title = "Export selected blueprint" if exporting else "Import blueprint library"
	blueprint_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if exporting else FileDialog.FILE_MODE_OPEN_FILE
	if exporting: blueprint_file_dialog.current_file = "track-design.json"
	blueprint_file_dialog.popup_centered_clamped(Vector2i(700, 500), 0.95)

func _import_blueprints(path: String) -> bool:
	if not blueprint_library_error.is_empty():
		_show_notice("Repair the local blueprint library before importing.")
		return false
	var loaded: Dictionary = TrackBlueprints.load_library(path)
	if not FileAccess.file_exists(path) or not loaded.error.is_empty() or loaded.designs.is_empty():
		_show_notice("No valid designs to import. " + str(loaded.error))
		return false
	var proposed := blueprints.duplicate()
	var names: Dictionary = {}
	for design in blueprints: names[design.name] = true
	for design in loaded.designs:
		if names.has(design.name):
			_show_notice("Import refused: blueprint '%s' already exists. No designs were changed." % design.name)
			return false
		names[design.name] = true
		proposed.append(design)
	if not TrackBlueprints.save_library(BLUEPRINT_PATH, proposed):
		_show_notice("Import could not be saved (maximum 50 designs).")
		return false
	blueprints = proposed
	inspection_panel.blueprint_search.clear()
	inspection_panel.refresh_blueprints(blueprints)
	inspection_panel.blueprint_status.text = "Imported %d designs; %d total saved layouts." % [loaded.designs.size(), blueprints.size()]
	_show_notice(inspection_panel.blueprint_status.text)
	return true

func _export_blueprint(path: String) -> bool:
	if ProjectSettings.globalize_path(path) in [ProjectSettings.globalize_path(BLUEPRINT_PATH), ProjectSettings.globalize_path(BLUEPRINT_PATH + ".backup")]:
		_show_notice("Choose an export filename outside the active library and its backup.")
		return false
	var name: String = inspection_panel.selected_blueprint()
	for design in blueprints:
		if design.name != name: continue
		if TrackBlueprints.save_library(path, [design]):
			_show_notice("Exported '%s' as a versioned JSON design." % name)
			return true
		_show_notice("Could not write the exported blueprint.")
		return false
	_show_notice("Select a saved blueprint to export.")
	return false

func _setup_object_browser() -> void:
	object_browser = ObjectBrowser.new()
	object_browser.configure(self)
	$Interface.add_child(object_browser)
	var find_button := Button.new()
	find_button.text = "Find"
	find_button.focus_mode = Control.FOCUS_NONE
	find_button.tooltip_text = "Search objects, locate trains and facilities, and pin a session watchlist. Opens paused."
	find_button.pressed.connect(func() -> void:
		paused = true
		is_dragging = false
		is_panning = false
		corridor_pick = 0
		demolition_cells.clear()
		build_plan.clear()
		_update_toolbar()
		object_browser.open_dialog())
	$Interface/HeaderBox/Toolbar.add_child(find_button)

func object_rows() -> Array:
	var result: Array = []
	var trains: Array = fleet.trains.duplicate()
	trains.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.id) < int(b.id))
	for train in trains:
		var service: String = str(train.service)
		var service_name: String = str(services[service].name) if services.has(service) else "Stored off-map"
		var status: String = fleet_train_status(int(train.id))
		var title := "#%d %s" % [int(train.id), str(train.name)]
		result.append({"key": "train:%d" % int(train.id), "kind": "Train", "id": int(train.id), "service": service, "title": title, "details": "%s\n%s — %s\n%s\nCapacity %d | Speed %.0f px/s\nStored trains have no map position." % [title, str(Fleet.MODELS[train.model].name), service_name, status, Fleet.capacity(train), Fleet.speed(train)], "cell": Vector2i(-1, -1)})
	for service in service_keys():
		var train: Dictionary = Fleet.assigned(fleet, service)
		var id := int(train.get("id", -1))
		var stops: PackedStringArray = []
		for stop in services[service].stops:
			stops.append(str(ServiceRoutes.STATIONS[stop].name) if ServiceRoutes.STATIONS.has(stop) else "Forest" if stop == "forest" else "Cargo Terminal")
		var title: String = str(services[service].name)
		result.append({"key": "service:" + service, "kind": "Service", "id": id, "service": service, "title": title, "details": "%s\n%s: %s\nAssigned train #%d\n%s" % [title, str(services[service].get("mode", "shuttle")).capitalize(), " → ".join(stops), id, fleet_train_status(id)], "cell": Vector2i(-1, -1)})
	for key in ServiceRoutes.STATIONS:
		var station: Dictionary = ServiceRoutes.STATIONS[key]
		result.append({"key": "station:" + key, "kind": "Station", "id": -1, "service": "", "title": station.name, "details": "%s\n%d passengers waiting\nMap cell %d,%d" % [station.name, _waiting(key), station.cell.x, station.cell.y], "cell": station.cell})
	result.append({"key": "industry:forest", "kind": "Industry", "id": -1, "service": "", "title": "Forest", "details": "Forest — produces logs\n%d logs in stock\nMap cell %d,%d" % [forest_stock, FOREST_SITE.x, FOREST_SITE.y], "cell": FOREST_SITE})
	result.append({"key": "industry:terminal", "kind": "Industry", "id": -1, "service": "", "title": "Cargo Terminal", "details": "Cargo Terminal — accepts logs\n%d logs delivered\nMap cell %d,%d" % [logs_delivered, CARGO_TERMINAL.x, CARGO_TERMINAL.y], "cell": CARGO_TERMINAL})
	return result

func locate_object(row: Dictionary) -> bool:
	if not locate_problem(row): return false
	var service: String = str(row.get("service", ""))
	if services.has(service):
		inspection_panel.show_service(service)
		inspection_button.button_pressed = true
		_update_inspection()
	queue_redraw()
	return true

func _consist_service_fit(train: Dictionary, service: Dictionary) -> String:
	var body := Fleet.length(train)
	if body <= Reservations.VEHICLE_LENGTH: return ""
	var path: Curve2D
	var stops: Array
	var cells: Array
	if Fleet.MODELS[train.model].kind == "freight":
		cells = WaypointRouter.find_route(tracks, FOREST_SITE, CARGO_TERMINAL, service.get("waypoints", {}).get("forest>terminal", []))
		path = RailRouter.make_path(cells, float(TILE_SIZE))
		stops = [0.0, path.get_baked_length()]
	else:
		var built := ServiceRoutes.build(tracks, service.stops, float(TILE_SIZE), service.get("waypoints", {}), service.get("mode", "shuttle"), service.get("platforms", {}))
		path = built.path
		stops = built.distances
		cells = built.cells
	var shape_error := Consists.route_shape_error(path, cells, body, service.get("mode", "shuttle"))
	if not shape_error.is_empty(): return shape_error
	for distance in stops:
		var error := Consists.stop_clearance(path, float(distance), body, tracks, float(TILE_SIZE), track_signals)
		if not error.is_empty(): return error
	return ""

func _service_body_origin(service: String) -> Dictionary:
	if service == "passenger": return {"path": _reservation_path(route_path, train_position), "distance": route_distance}
	if service == "freight": return {"path": _reservation_path(freight_train.route_path, freight_train.position), "distance": freight_train.distance_along_route}
	return {"path": passenger_services[service].path, "distance": passenger_services[service].distance}

func edit_consist(id: int, wagon: String, remove: bool = false) -> String:
	if not paused: return "Pause before changing a consist."
	_sync_fleet_upgrades()
	var train: Dictionary = Fleet.find(fleet, id)
	if train.is_empty(): return "Choose an existing train."
	if not Consists.STOCK.has(wagon) or Consists.STOCK[wagon].kind != Fleet.MODELS[train.model].kind: return "Choose stock compatible with this train's passengers or cargo."
	var service: String = str(train.service)
	if not service.is_empty() and not _can_replace_service_train(service): return "Withdraw the train and wait until it is empty at its first stop before changing the consist."
	var candidate := train.duplicate(true)
	var wagons: Array = candidate.get("wagons", []).duplicate()
	if remove:
		var index := wagons.rfind(wagon)
		if index < 0: return "No matching wagon to remove."
		wagons.remove_at(index)
	else:
		if wagons.size() >= Consists.MAX_WAGONS: return "Maximum four attached vehicles."
		if money < int(Consists.STOCK[wagon].price): return "Insufficient funds for this wagon."
		wagons.append(wagon)
	candidate["wagons"] = wagons
	if not service.is_empty():
		var fit := _consist_service_fit(candidate, services[service])
		if not fit.is_empty(): return fit
		_rebuild_reservations()
		var origin := _service_body_origin(service)
		for cell in reservations.footprint(origin.path, origin.distance, float(TILE_SIZE), Fleet.length(candidate)):
			if reservations.owners.has(cell) and int(reservations.owners[cell]) != id: return "The longer body would overlap reserved or occupied track. Let the other train clear first."
	var cost := int(Consists.STOCK[wagon].price)
	if remove: cost = -int(cost / 2.0)
	train["wagons"] = wagons
	money -= cost
	total_vehicle_cost += cost
	_apply_fleet_specs()
	_rebuild_reservations()
	_update_station_inspector()
	queue_redraw()
	return "%s %s. Capacity %d, length %.0f px, speed %.0f px/s, running £%d/s." % ["Removed" if remove else "Attached", Consists.STOCK[wagon].name, Fleet.capacity(train), Fleet.length(train), Fleet.speed(train), Fleet.running_cost(train)]

func _draw_passenger_consist(service: String, path: Curve2D, distance: float, position_at: Vector2, heading: float, forward: bool) -> void:
	var train := Fleet.assigned(fleet, service)
	var offsets := Consists.offsets(train)
	if offsets.size() == 1 or path.point_count < 2:
		_draw_passenger_vehicle(position_at, heading, int(train.id))
		return
	for index in range(offsets.size()):
		var pose := Consists.pose(path, distance + offsets[index])
		var angle: float = pose.angle + (0.0 if forward else PI)
		if index == 0:
			_draw_passenger_vehicle(pose.position, angle, int(train.id))
		else:
			draw_set_transform(pose.position, angle)
			draw_rect(Rect2(Vector2(-12, -7), Vector2(24, 14)), Palette.get_color(Palette.Role.TRAIN_PASSENGER))
			draw_rect(Rect2(Vector2(-12, -7), Vector2(24, 14)), Color.WHITE, false, 1.0)
			for x in [-8, -2, 4]: draw_rect(Rect2(Vector2(x, -4), Vector2(4, 8)), Color(0.65, 0.85, 0.95))
			draw_set_transform(Vector2.ZERO, 0.0)

func _setup_train_inspector() -> void:
	train_inspector = TrainInspector.new()
	train_inspector.configure(self)
	$Interface.add_child(train_inspector)

func inspect_train(id: int) -> bool:
	if Fleet.find(fleet, id).is_empty(): return false
	paused = true
	is_dragging = false
	is_panning = false
	corridor_pick = 0
	build_plan.clear()
	demolition_cells.clear()
	demolition_blocked.clear()
	_close_station_inspector()
	# Preserve the last allocation; a paused rebuild would replace lookahead grants.
	_update_toolbar()
	train_inspector.open_train(id)
	return true

func _inspect_train_at(cell: Vector2i) -> bool:
	for train in inspection_trains():
		var path: Curve2D = _reservation_path(train.path, _cell_center(ServiceRoutes.stop_cell(services[train.key].get("platforms", {}), services[train.key].stops[0])) if train.key != "freight" else freight_train.position)
		if reservations.footprint(path, train.distance, float(TILE_SIZE), Fleet.length(Fleet.find(fleet, train.id))).has(cell): return inspect_train(train.id)
	return false

func train_diagnostics(id: int) -> Dictionary:
	return TrainDiagnostics.snapshot(self, id)

func train_inspector_action(action: String, data: Dictionary) -> void:
	train_inspector.hide()
	var id := int(data.get("id", -1))
	if action == "blocker":
		locate_problem({"id": int(data.get("blocker", -1)), "cell": Vector2i(-1, -1)})
	elif action == "conflict":
		var cell: Vector2i = data.get("cell", Vector2i(-1, -1))
		if _is_inside_map(cell):
			camera.position = _cell_center(cell)
			camera.force_update_scroll()
	elif action == "route":
		var train := Fleet.find(fleet, id)
		if not train.is_empty() and services.has(str(train.service)):
			inspection_panel.show_authority(train.service)
			reservation_button.button_pressed = true
			inspection_button.button_pressed = true
			locate_problem({"id": id, "cell": Vector2i(-1, -1)})
	elif action == "traffic":
		_open_traffic_dialog()
		for index in range(traffic_dialog.train_choice.item_count):
			if int(traffic_dialog.train_choice.get_item_metadata(index)) == id: traffic_dialog.train_choice.select(index)
		traffic_dialog.refresh()
	elif action == "fleet":
		fleet_editor.selected_id = id
		_open_fleet_editor()
	queue_redraw()

func _pointer_world() -> Vector2:
	return get_global_mouse_position()

func _clear_direct_inspection() -> void:
	direct_inspect_train = -1
	direct_inspect_station = Vector2i(-1, -1)
	direct_inspect_cell = Vector2i(-1, -1)

func _begin_direct_inspection(cell: Vector2i, point: Vector2) -> void:
	direct_inspect_cell = cell
	# Precise vehicle hit testing leaves the rest of an occupied platform clickable.
	for train in inspection_trains():
		var entry := Fleet.find(fleet, train.id)
		for offset in Consists.offsets(entry):
			var pose: Dictionary
			if train.path.point_count >= 2: pose = Consists.pose(train.path, train.distance + offset)
			else:
				var position_at: Vector2 = train_position if train.key == "passenger" else freight_train.position if train.key == "freight" else passenger_services[train.key].position
				pose = {"position": position_at, "angle": 0.0}
			if Rect2(Vector2(-16, -10), Vector2(32, 20)).has_point((point - Vector2(pose.position)).rotated(-float(pose.angle))):
				direct_inspect_train = int(train.id)
				return
	for station in [STATION_A, STATION_B, STATION_C, FOREST_SITE, CARGO_TERMINAL]:
		if cell == station or (cell.x >= station.x - 1 and cell.x <= station.x + 1 and cell.y >= station.y - 2 and cell.y < station.y):
			direct_inspect_station = station
			return
	_clear_direct_inspection()

func _cancel_direct_inspection_if_dragged(cell: Vector2i) -> void:
	if direct_inspect_cell != Vector2i(-1, -1) and cell != direct_inspect_cell: _clear_direct_inspection()

func _finish_direct_inspection(cell: Vector2i) -> bool:
	_cancel_direct_inspection_if_dragged(cell)
	var id := direct_inspect_train
	var station := direct_inspect_station
	_clear_direct_inspection()
	if id < 0 and station == Vector2i(-1, -1): return false
	is_dragging = false
	build_plan.clear()
	if id >= 0: return inspect_train(id)
	_inspect_station_at(station)
	return true
