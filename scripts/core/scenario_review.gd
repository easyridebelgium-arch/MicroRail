extends RefCounted
## Immutable completion counters, separate from changing company totals.
const Reports = preload("res://scripts/core/progress_reports.gd")
const Numbers = preload("res://scripts/core/arrival_targets.gd")
const FIELDS := ["delivered", "fares", "freight", "running", "cash", "primary", "secondary"]

static func capture(values: Dictionary, primary: int, secondary: int) -> Dictionary:
	var result := {"primary": primary, "secondary": secondary}
	for field in ["delivered", "fares", "freight", "running", "cash"]: result[field] = int(values[field])
	return result

static func valid(value: Dictionary, completed: int, definition: Dictionary, evidence: Dictionary, data: Dictionary) -> bool:
	if value.is_empty(): return true # Older completions have no reconstructable snapshot.
	if completed < 0 or definition.is_empty() or value.size() != FIELDS.size(): return false
	for field in FIELDS:
		if not Numbers.whole(value.get(field), -Reports.MAX_VALUE if field == "cash" else 0, Reports.MAX_VALUE): return false
	var current := Reports.from_save(data)
	if current.is_empty(): return false
	for field in ["delivered", "fares", "freight", "running"]:
		if int(value[field]) > int(current[field]): return false
	if definition.has("shared_track"):
		return value.primary == evidence.direct_finals and value.secondary == evidence.bypass_finals and int(value.delivered) >= int(value.primary) + int(value.secondary)
	if definition.has("contract"):
		var contracts: Variant = data.get("freight_contracts")
		if not contracts is Dictionary or not contracts.get(definition.contract) is Dictionary: return false
		var count: Variant = contracts[definition.contract].get("delivered")
		return Numbers.whole(count, 20, 20) and int(value.primary) == 20 and int(value.secondary) == 0
	var primary := 0
	var served := 0
	for id in data.city_service.cities:
		var count: int = int(data.city_service.cities[id].totals.delivered)
		if definition.get("origin", "") == "" or id == definition.origin: primary += count
		if count >= 5: served += 1
	return int(value.primary) >= int(definition.deliveries) and int(value.primary) <= primary and int(value.primary) <= int(value.delivered) and int(value.secondary) >= int(definition.served) and int(value.secondary) <= served

static func describe(state: Dictionary, definition: Dictionary, current: Dictionary) -> String:
	if state.id == "" or int(state.completed_tick) < 0: return "Complete a seeded scenario to review its results."
	var lines: PackedStringArray = ["Scenario complete — " + str(definition.name), "Elapsed company time at completion: %.1f game hours." % (float(state.completed_tick) / 3600.0)]
	var recorded: Dictionary = state.review
	if recorded.is_empty():
		lines.append("This older completion has no saved result snapshot. Figures below are CURRENT company totals, not historical completion figures.")
		recorded = current
	else:
		lines.append("Saved company totals at completion — includes all activity since company start.")
		if definition.has("shared_track"): lines.append("Measured attempt: main service %d / 10 new final journeys; loop service %d / 10." % [recorded.primary, recorded.secondary])
		elif definition.has("contract"): lines.append("Timber order: %d / 20 delivered to Terminal." % recorded.primary)
		else: lines.append(("Town 3 resident cross-river final journeys: %d / %d; cities with 5+ resident completions: %d / %d." if definition.has("origin") else "Qualifying final city journeys: %d / %d; cities with 5+ resident completions: %d / %d.") % [recorded.primary, definition.deliveries, recorded.secondary, definition.served])
	lines.append("Company final passenger journeys: %d\nPassenger fares: £%d\nFreight receipts: £%d\nRunning costs: £%d\nOperating contribution: £%d\nCash balance: £%d" % [recorded.delivered, recorded.fares, recorded.freight, recorded.running, int(recorded.fares) + int(recorded.freight) - int(recorded.running), recorded.cash])
	lines.append("Operating contribution = fares + freight receipts − running costs. Construction, fleet purchases, rewards, contract bonuses, loans and interest affect cash separately. Boarding and transfers do not add final journeys. Close and keep playing; Results remains available.")
	return "\n\n".join(lines)
