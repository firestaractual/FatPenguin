class_name EdgeAttack
extends PodAttack
## An attack on penguins standing near an ice edge (WaveAttack, RamAttack). The pod lines up side
## by side off the edge where its target stands, warns, charges straight at the edge and strikes
## when it gets there. A kind of edge attack fills in how far out and how deep it lines up and
## strikes, its warning visuals and the strike itself.

## Where it strikes: a spot on the ice edge, at the height of the ice...
var impact := Vector3.ZERO
## ...and the flat direction from there out toward the pod.
var out := Vector3.ZERO

var _strip: MeshInstance3D = null


# --- What each kind of edge attack fills in ---------------------------------
# (Every kind overrides these with numbers from its tuning; the values here are placeholders.)

## How far out from the edge they line up, and strike (m).
func lineup_distance() -> float:
	return 10.0


func strike_distance() -> float:
	return 2.0


## Spot `i` of `n` while lining up and warning, and how close to the surface they may come.
func lineup_spot(i: int, n: int) -> Vector3:
	return line_spot(i, n, lineup_distance(), Predator.MIN_DEPTH)


func lineup_depth() -> float:
	return Predator.MIN_DEPTH


## Spot `i` of `n` to charge at, and how close to the surface they may come.
func charge_spot(i: int, n: int) -> Vector3:
	return line_spot(i, n, strike_distance(), Predator.MIN_DEPTH)


func charge_depth() -> float:
	return Predator.MIN_DEPTH


## Where they wait while hunting the water after the strike.
func hunt_spot(i: int, n: int) -> Vector3:
	return line_spot(i, n, strike_distance() + 1.5, Predator.MIN_DEPTH)


## Each frame of the charge, with how far along it is (0 to 1).
func update_charge_progress(_progress: float) -> void:
	pass


# --- The steps --------------------------------------------------------------

func steer(phase: PredatorPod.Phase, _phase_time: float) -> void:
	var n := attackers.size()
	for i in n:
		var member := attackers[i]
		if phase == PredatorPod.Phase.CHARGE:
			member.order_move(charge_spot(i, n), settings.charge_speed, charge_depth())
		else:
			member.order_move(lineup_spot(i, n), member.tuning.chase_speed, lineup_depth(), -out)


func lined_up(phase_time: float) -> bool:
	return all_in_place(lineup_spot) or phase_time >= settings.lineup_max_seconds


## They strike when they reach strike_distance from the edge (or a little after they should
## have, if something's in the way).
func charged(phase_time: float) -> bool:
	return _charge_left() <= 0.5 or phase_time >= _run() / settings.charge_speed + 2.0


func update_charge(_phase_time: float) -> void:
	update_charge_progress(1.0 - clampf(_charge_left() / _run(), 0.0, 1.0))


func hunt(_phase_time: float) -> void:
	var n := attackers.size()
	for i in n:
		var member := attackers[i]
		if is_instance_valid(member) and member.is_available():
			member.order_move(hunt_spot(i, n), member.tuning.patrol_speed, Predator.MIN_DEPTH, -out)


func seconds_to_strike(phase: PredatorPod.Phase, phase_time: float) -> float:
	match phase:
		PredatorPod.Phase.WARN:
			return settings.warning_seconds - phase_time + _run() / settings.charge_speed
		PredatorPod.Phase.CHARGE:
			return maxf(_charge_left(), 0.0) / settings.charge_speed
	return -1.0


func cancel() -> void:
	hide_zone()


# --- Shared parts -----------------------------------------------------------

## Picks the most tempting penguin standing on the ice within `reach` of the edge that faces the
## leader, and within scan range of it, on ice no higher than `max_height` above the water.
## `accept` can rule penguins out (it gets the penguin). Sets target, impact and out; returns the
## score, or -1.
func best_target_near_edge(lead: Predator, reach: float, accept := Callable(), max_height := INF) -> float:
	var best_score := -1.0
	for node in pod.get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p == null or not (p.state == Penguin.State.WALK or p.state == Penguin.State.SLIDE):
			continue
		var to_pod := lead.global_position - p.global_position
		to_pod.y = 0.0
		if to_pod.length() > settings.scan_range:
			continue
		if accept.is_valid() and not accept.call(p):
			continue
		var dir := to_pod.normalized()
		var edge := IceEdges.edge_toward(pod.get_world_3d(), p.global_position, dir, reach)
		if edge.is_empty() or (edge["point"] as Vector3).y > GameWorld.WATER_LEVEL + max_height:
			continue
		var score := lead.temptation(p)
		if score > best_score:
			best_score = score
			target = p
			impact = edge["point"]
			out = dir
	return best_score


## Spot `i` of `n` in a line side by side, `distance` out from the edge and `depth` down.
func line_spot(i: int, n: int, distance: float, depth: float) -> Vector3:
	var side := out.cross(Vector3.UP).normalized()
	var spot := impact + out * distance + side * (i - (n - 1) * 0.5) * pod.tuning.spacing
	spot.y = GameWorld.WATER_LEVEL - depth
	return spot


## How far out from the edge `point` is (m).
func distance_out(point: Vector3) -> float:
	var rel := point - impact
	rel.y = 0.0
	return rel.dot(out)


## Penguins out of the water in a strip of ice running `width` along the edge and `reach` in.
func penguins_in_strip(reach: float, width: float) -> Array[Penguin]:
	var side := out.cross(Vector3.UP).normalized()
	var found: Array[Penguin] = []
	for node in pod.get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p == null or p.global_position.y < GameWorld.WATER_LEVEL:
			continue
		var rel := p.global_position - impact
		rel.y = 0.0
		var inland := -rel.dot(out)
		if inland < -1.0 or inland > reach + ZONE_MARGIN or absf(rel.dot(side)) > width * 0.5 + ZONE_MARGIN:
			continue
		found.append(p)
	return found


## Marks the strip of ice from the edge `reach` in and `width` along, in the danger colour.
func show_zone_strip(reach: float, width: float) -> void:
	if _strip == null:
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 0.04, 1.0)
		_strip = make_marker(&"DangerStrip", box)
	if not _strip.visible:
		var centre := impact - out * reach * 0.5 + Vector3.UP * 0.03
		_strip.global_transform = Transform3D(Basis.looking_at(out, Vector3.UP), centre).scaled_local(Vector3(width, 1.0, reach))
		_strip.visible = true


func hide_zone() -> void:
	super.hide_zone()
	if _strip != null:
		_strip.visible = false


func _run() -> float:
	return maxf(lineup_distance() - strike_distance(), 0.1)


func _charge_left() -> float:
	return distance_out(attackers_centre()) - strike_distance()
