extends SceneTree
const Summary = preload("res://scripts/core/network_summary.gd")
const Contracts = preload("res://scripts/core/freight_contracts.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: run.call_deferred()
func row(data: Dictionary) -> Dictionary:
	for item in Summary.build(data):
		if item.action == "contract": return item
	return {}
func select_contract(dialog: Node) -> bool:
	for index in range(dialog.rows.size()):
		if dialog.rows[index].action == "contract":
			dialog.items.select(index)
			dialog.describe()
			return true
	return false
func run() -> void:
	var data := {"problems": [], "stations": [], "cities": [], "vehicles": [], "contract": {"kind": "logs", "target": 40, "progress": 5, "bonus": 200, "deadline": 43200, "remaining": 10801, "duration": 43200, "cell": Vector2i(28, 24), "issue": ""}}
	var before := data.duplicate(true)
	check(row(data).severity == "Info" and row(data).rank == 6, "healthy order has routine visibility before final quarter")
	check(data == before, "summary leaves contract input unchanged")
	data.contract.remaining = 10800
	check(row(data).severity == "Warning" and row(data).rank == 1, "exact 25 percent time boundary warns")
	check(row(data).details.contains("not an arrival forecast") and row(data).details.contains("25%"), "warning describes its actual threshold without inventing ETA")
	data.problems.append({"key": "train:1", "cause": "deadlock", "id": 1, "title": "Deadlock", "details": "Blocked", "cell": Vector2i(1, 1)})
	check(Summary.build(data)[0].key == "train:1", "confirmed deadlocks remain ahead of contract warnings")
	data.contract.remaining = 40000
	data.contract.issue = "Terminal cargo changed to goods"
	check(row(data).severity == "Warning" and row(data).details.contains("Terminal cargo changed to goods"), "cargo mismatch warns even before deadline threshold")
	data.contract.remaining = 0
	data.contract.issue = ""
	check(row(data).title.contains("Deadline reached"), "exact deadline is labelled without negative remaining time")
	check(Contracts.time_left(1) == "less than one game minute" and Contracts.time_left(0) == "no time", "near deadlines never round positive remaining time to zero")
	check(Contracts.time_left(60) == "1.0 game minutes" and Contracts.time_left(3600) == "1.0 game hours", "remaining-time units match simulation game clock")
	var model := Contracts.new()
	check(model.summary(0).is_empty(), "unused offers never become company warnings")
	model.accept("logs", 0, {})
	var saved := model.save_state()
	check(model.summary(100).remaining == 43100 and model.save_state() == saved, "derived model snapshot reads remaining time without advancing contract")
	model.advance(43201)
	check(model.summary(43201).is_empty(), "expired contract is removed from current-action summary")
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	game.paused = true
	game.accept_freight_contract("logs")
	var snapshot: String = JSON.stringify(game._save_snapshot(), "", true, true)
	game.open_network_summary()
	check(select_contract(game.network_summary) and game.network_summary.headline.text.contains("Active freight order: Logs 0/40"), "active order is discoverable in headline and actionable list")
	check(game.network_summary.details.text.contains("Freight route incomplete"), "live incomplete freight path is explained: " + game.network_summary.details.text)
	check(not game.network_summary.get_ok_button().disabled and game.network_summary.selected().id == -1, "contract locates actual terminal without inventing a train")
	game.network_summary.act()
	for frame in range(2): await process_frame
	check(not game.network_summary.visible and game.contracts_dialog.visible and game.contracts_dialog.selected_order == "logs", "review hands off modal ownership to the correct active order")
	check(snapshot == JSON.stringify(game._save_snapshot(), "", true, true), "summary and contract navigation never change saved state, RNG or progress")
	game._reset_track_tools()
	check(not game.contracts_dialog.visible, "right-click reset closes contract window consistently")
	for x in range(8, 29): game.tracks[Vector2i(x, 24)] = false
	game._check_route()
	game.freight_train.held = true
	check(game.network_summary_data().contract.issue.contains("held"), "intentional hold is distinguished from incomplete track")
	game.freight_train.held = false
	check(game.network_summary_data().contract.issue.is_empty(), "working route is not labelled obstructed while dwelling or loading")
	check(game._save_game(1) and game._load_slot(1), "active contract saves without additional summary state")
	game.open_network_summary()
	check(select_contract(game.network_summary), "load reconstructs active contract summary")
	game.network_summary.locate()
	check(game.camera.position == game._cell_center(game.CARGO_TERMINAL) and not game.network_summary.visible, "Locate jumps to real terminal without moving trains")
	game.GameSettings.ui_scale = 2.0
	game._apply_settings()
	game.open_network_summary()
	for frame in range(4): await process_frame
	check(Rect2(Vector2.ZERO, Vector2(game.network_summary.size)).encloses(game.network_summary.get_ok_button().get_global_rect()), "active-contract summary footer remains reachable at 200 percent scale")
	select_contract(game.network_summary)
	game.network_summary.act()
	for frame in range(4): await process_frame
	check(Rect2(Vector2.ZERO, Vector2(game.contracts_dialog.size)).encloses(game.contracts_dialog.get_ok_button().get_global_rect()), "direct contract window footer remains reachable at 200 percent scale")
	game.GameSettings.ui_scale = 1.0
	game._apply_settings()
	game.queue_free()
	await process_frame
	print("Contract summary: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
