extends SceneTree
const Policy = preload("res://scripts/core/notification_policy.gd")
const Events = preload("res://scripts/core/event_log.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func event(id: int, type: String) -> Dictionary:
	return {"id": id, "tick": id, "type": type, "subject": "1", "data": {"reason": "Signal block occupied"}}
func _initialize() -> void:
	var policy := Policy.new()
	var rules := Policy.defaults()
	policy.consume(event(1, Events.TRAIN_WAITING), rules)
	check(policy.take().is_empty(), "routine waits should be quiet by default")
	policy.consume(event(2, Events.DEADLOCK_DETECTED), rules)
	var alert := policy.take()
	check(not alert.pause and alert.text.contains("Deadlock"), "default deadlock should give a notice without automatic pause")
	policy.consume(event(2, Events.DEADLOCK_DETECTED), rules)
	check(policy.take().is_empty(), "the same event must not alert twice after display")
	rules.waiting = Policy.PAUSE
	policy.consume(event(3, Events.TRAIN_WAITING), rules)
	check(policy.take().pause, "configured wait incident should request pause")
	policy.consume(event(4, Events.TRAIN_WAITING), rules)
	check(not policy.take(false).pause, "a mode that disallows automatic pause must retain notice without pause")
	policy.consume(event(5, Events.TRACK_BUILT), rules)
	check(policy.take().is_empty(), "operational alert rules must leave construction feedback alone")
	policy.consume(event(6, Events.DEADLOCK_DETECTED), rules)
	policy.consume(event(7, Events.TRAIN_WAITING), rules)
	alert = policy.take()
	check(alert.pause and alert.text.begins_with("Deadlock") and alert.text.contains("other alerts"), "a batch should preserve severe text and any pause request")
	for id in range(8, 108):
		var unique := event(id, Events.DEADLOCK_DETECTED)
		unique.subject = str(id)
		policy.consume(unique, rules)
	check(policy._pending.size() == Policy.MAX_PENDING, "pending notification memory must stay bounded")
	policy.consume(event(108, Events.TRAIN_WAITING), rules)
	check(policy.take().pause, "a pause request must survive even if its low-priority message is dropped from a full queue")
	policy.consume(event(109, Events.TRAIN_WAITING), rules)
	policy.reset()
	check(policy.take().is_empty(), "load/reset must discard stale pending alerts")
	policy.consume(event(1, Events.TRAIN_WAITING), rules)
	check(policy.take().pause, "a new event stream must be accepted after reset")
	policy.consume(event(2, Events.TRAIN_WAITING), rules)
	policy.consume(event(3, Events.TRAIN_WAITING), rules)
	check(policy._pending.size() == 1, "identical conditions coalesce despite distinct event IDs")
	alert = policy.take()
	check(alert.pause and not alert.text.contains("other alerts"), "coalesced conditions retain pause without duplicate chatter")
	var cleaned := Policy.normalize({"waiting": true, "deadlocks": -1, "recovery": 2, "unknown": 2})
	check(cleaned == {"waiting": Policy.OFF, "deadlocks": Policy.NOTICE, "recovery": Policy.PAUSE}, "invalid preferences must safely use known defaults")
	check(Policy.normalize("invalid") == Policy.defaults(), "malformed settings section must fall back to defaults")
	print("Notification policy: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
