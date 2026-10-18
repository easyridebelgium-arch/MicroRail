extends SceneTree
const Reservations = preload("res://scripts/core/track_reservations.gd")
const Signals = preload("res://scripts/core/block_signals.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const Router = preload("res://scripts/rail_router.gd")
## Regression for a coach train at switch 31,8 and signal 30,7.
## Coarse two-pixel claims missed a transient clearance tile on the diagonal.
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
func _initialize() -> void:
	var cells:Array[Vector2i]=[]
	for x in range(36,30,-1):cells.append(Vector2i(x,8))
	cells.append_array([Vector2i(30,7),Vector2i(29,6),Vector2i(28,5),Vector2i(27,4),Vector2i(26,4),Vector2i(25,4)])
	var tracks:Dictionary={}
	for i in range(1,cells.size()-1):tracks[cells[i]]=Geometry.from_ports(cells[i-1]-cells[i],cells[i+1]-cells[i])
	tracks[Vector2i(31,8)]="junction_2_6_7"
	tracks[cells[0]]=false
	tracks[cells.back()]=false
	var path=Router.make_path(cells,32)
	var table=Reservations.new()
	var signals=Signals.new()
	signals.configure(tracks,{Vector2i(30,7):"auto"})
	# Known fractional poses at which the coarse scan stranded each consist.
	# Movement uses the coach speed cap of 100 px/s at the fixed 60 Hz tick.
	for body in [60.0,92.0,124.0,156.0]:
		for forward in [true,false]:
			var t={"id":3,"length":body,"cells":cells,"path":path,"distance": (198.333333333333 - (body - 60.0) * 0.625) if forward else (minf(346.882822672525, 302.882822672525 + (body - 60.0) * 0.625)),"forward":forward,"moving":true}
			var end=path.get_baked_length() if forward else 0.0
			var initial: float = t.distance
			var blocked := false
			for step in range(8):
				table.rebuild([t],tracks,32)
				signals.update([t],table.occupied_owners,32)
				var ahead=clampf(t.distance+(96 if forward else -96),0,path.get_baked_length())
				var red=signals.limit(t,ahead,32)
				table.rebuild([t],tracks,32,{3:red.distance})
				var proposed=move_toward(t.distance,end,100.0/60.0)
				var checked=signals.limit(t,proposed,32)
				var allowed=table.limit(3,path,t.distance,checked.distance,32,body)
				if absf(allowed-t.distance)<0.001:
					blocked = true
					break
				t.distance=allowed
				if absf(t.distance-end)<0.001:break
			check(not blocked and absf(t.distance - initial) > 10.0, "Consist %.0f traverses diagonal clearance in direction %s" % [body, str(forward)])
	# A refused movement must carry the actual tile and cause, even when no
	# competing-owner wait was recorded during lookahead allocation.
	var current := 200.0
	table.rebuild([{"id":3,"length":60.0,"cells":cells,"path":path,"distance":current,"forward":true,"moving":true}],tracks,32)
	var denied: Vector2i = table.footprint(path,current+1.0,32,60.0)[0]
	table.owners.erase(denied)
	table.waits.clear()
	check(table.limit(3,path,current,current+1.0,32,60.0)==current, "Missing authority refuses motion")
	check(table.waits[3].cell == denied and table.waits[3].owner == -1 and table.waits[3].reason.contains("track authority"), "Missing authority names the tile without inventing another train")
	table.owners[denied]=4
	table.limit(3,path,current,current+1.0,32,60.0)
	check(table.waits[3].owner == 4 and table.waits[3].cell == denied, "Competing owner is reported at the actual refusal")
	print("Long diagonal reservations: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
