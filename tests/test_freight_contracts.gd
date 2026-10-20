extends SceneTree
const Contracts = preload("res://scripts/core/freight_contracts.gd")
const Migrations = preload("res://scripts/core/save_migrations.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var model := Contracts.new()
	check(Contracts.valid(model.save_state(), 0, {}), "fresh offers validate")
	check(model.deliver("logs", 99, 0) == 0 and model.state.logs.delivered == 0, "pre-acceptance deliveries cannot earn credit")
	check(not model.accept("bad", 0, {}) and model.accept("logs", 100, {"logs": 80}), "accept only known unused offer")
	check(not model.accept("timber", 100, {}) and not model.accept("logs", 100, {}), "only one active contract and no repeated acceptance")
	check(model.deliver("timber", 100, 101) == 0 and model.state.logs.delivered == 0, "other cargo cannot substitute")
	check(model.deliver("logs", 20, 101) == 0 and model.state.logs.delivered == 20, "partial terminal delivery advances progress without reward")
	check(model.deliver("logs", 20, int(model.state.logs.deadline)) == 200 and model.earned() == 200, "delivery exactly at deadline qualifies")
	check(model.deliver("logs", 20, int(model.state.logs.deadline)) == 0 and not model.accept("logs", 50000, {}), "completed offer pays once and is never reusable")
	var restored := Contracts.new()
	restored.restore_state(JSON.parse_string(JSON.stringify(model.save_state())))
	check(restored.earned() == 200 and restored.deliver("logs", 50, 50000) == 0, "JSON restore cannot replay the payout")
	check(Contracts.valid(restored.save_state(), 50000, {"logs": 120}), "baseline plus actual post-acceptance deliveries validates")
	check(not Contracts.valid(restored.save_state(), 50000, {"logs": 119}), "fake completed quantity exceeding real deliveries is rejected")
	check(model.accept("timber", 50000, {"timber": 0}), "next unused offer available after completion")
	var deadline: int = model.state.timber.deadline
	check(model.advance(deadline) == "" and model.deliver("timber", 20, deadline + 1) == 0, "exact deadline remains active but late delivery does not qualify")
	check(model.advance(deadline + 1) == "timber" and model.earned() == 200 and model.state.timber.status == "expired", "expiry has no payout and closes order")
	check(model.advance(deadline + 2) == "" and not model.accept("timber", deadline + 2, {}), "expired order cannot be reset or repeatedly expire")
	check(Contracts.valid(model.save_state(), deadline + 2, {"logs": 120}), "completed and expired orders remain valid saved states")
	var simultaneous := Contracts.defaults()
	simultaneous.logs = {"status": "active", "accepted": 0, "deadline": 43200, "finished": -1, "delivered": 0, "baseline": 0, "warned_tick": -1}
	simultaneous.timber = {"status": "active", "accepted": 0, "deadline": 64800, "finished": -1, "delivered": 0, "baseline": 0, "warned_tick": -1}
	check(not Contracts.valid(simultaneous, 0, {}), "save cannot bypass one-active-order rule")
	var malformed := model.save_state()
	malformed.goods.status = "active"
	check(not Contracts.valid(malformed, deadline + 2, {"logs": 120}), "forged active timestamps rejected")
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main/main.tscn").instantiate()
	game.startup_allow_cli = false
	root.add_child(game)
	game.set_process(false)
	for frame in range(4): await process_frame
	for x in range(8, 29): game.tracks[Vector2i(x, 24)] = false
	game._check_route()
	game.paused = false
	check(game.accept_freight_contract("logs").contains("Pause"), "live acceptance cannot skip fixed-tick discipline")
	game.contracts_dialog.open_dialog()
	check(game.paused and game._modal_open() and not game.contracts_dialog.offers.logs.disabled, "Accounts contract dialog pauses and offers clear acceptance")
	check(game.contracts_dialog.offers.timber.disabled and game.contracts_dialog.offers.timber.tooltip_text.contains("Terminal currently receives logs"), "unavailable cargo offers explain their chain requirement")
	var cash: int = game.money
	game.contracts_dialog._accept("logs")
	check(game.freight_contracts.active() == "logs" and game.money == cash and game.contracts_dialog.offers.timber.disabled, "acceptance costs nothing and disables competing offers")
	game.contracts_dialog.hide()
	check(game._save_game(2) and game._load_slot(2) and game.freight_contracts.active() == "logs", "active contract survives actual save/load")
	for batch in range(240):
		for tick in range(60):
			game.sim_clock.begin_tick()
			game._simulation_step(1.0 / 60.0)
		if game.freight_contracts.state.logs.status == "completed": break
	check(game.freight_contracts.state.logs.status == "completed" and game.logs_delivered >= 40, "physical train terminal deliveries complete the order")
	check(game.freight_income == game.logs_delivered * game.Sawmill.LOGS.terminal_price and game.freight_contracts.earned() == 200, "bonus is separate from normal haulage income")
	cash = game.money
	game._credit_freight_contract("logs", 40)
	check(game.money == cash, "completed contract hook cannot pay twice")
	check(game._save_game(2), "completed contract saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.SaveSlots.path(2)))
	check(saved.version == 53 and game._is_valid_save(saved) and game._load_slot(2) and game.freight_contracts.earned() == 200, "version 53 validates and restores completed order")
	var bad := saved.duplicate(true)
	bad.freight_contracts.logs.baseline = game.logs_delivered
	check(not game._is_valid_save(bad), "save validator rejects retroactive delivery credit")
	var old := saved.duplicate(true)
	old.version = 49
	old.erase("freight_contracts")
	var migrated: Dictionary = Migrations.migrate(old).data
	check(migrated.version == 53 and migrated.freight_contracts == Contracts.defaults() and migrated.state == old.state and migrated.sim == old.sim, "v49 migration adds unused offers without retroactive rewards or physical changes")
	game.header_controls.open_accounts()
	game.header_controls.refresh()
	check(game.header_controls.accounts_text.text.contains("contract bonuses: £200"), "Accounts reports bonuses separately")
	game.queue_free()
	await process_frame
	for kind in ["timber", "goods"]:
		game = load("res://scenes/main/main.tscn").instantiate()
		game.startup_allow_cli = false
		root.add_child(game)
		game.set_process(false)
		for frame in range(4): await process_frame
		game.paused = true
		game.money = 10000
		for x in range(7, 30): game.tracks[Vector2i(x, 24)] = false
		game._check_route()
		check(game.build_sawmill().contains("installed"), "contract fixture installs actual sawmill")
		if kind == "goods": check(game.build_factory().contains("installed"), "goods contract fixture installs actual factory")
		check(game.accept_freight_contract("logs").contains("Terminal currently receives"), "obsolete raw-cargo order cannot be accepted after upgrade")
		check(game.accept_freight_contract(kind).contains("accepted"), "matching processed cargo contract can be accepted")
		var intermediate_seen := false
		var premature_credit := false
		for batch in range(300):
			for tick in range(60):
				game.sim_clock.begin_tick()
				game._simulation_step(1.0 / 60.0)
				var received: int = game.factory.state.received if kind == "goods" else game.sawmill.state.received
				var sold: int = game.factory.state.sold if kind == "goods" else game.sawmill.state.sold
				if received > 0 and sold == 0:
					intermediate_seen = true
					premature_credit = premature_credit or game.freight_contracts.state[kind].delivered > 0
			if game.freight_contracts.state[kind].status == "completed": break
		check(intermediate_seen and not premature_credit, "intermediate industry receipts do not credit " + kind + " order")
		check(game.freight_contracts.state[kind].status == "completed" and game.freight_contracts.earned() == Contracts.DEFINITIONS[kind].bonus, "physical processed-cargo journeys complete " + kind + " order")
		check(game._save_game(3) and game._load_slot(3), "processed-cargo contract conserves valid saved chain inventories")
		game.queue_free()
		await process_frame
	print("Freight contracts: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
