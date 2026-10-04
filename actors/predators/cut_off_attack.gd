class_name CutOffAttack
extends PodAttack
## The cut-off (numbers in CutOffAttackTuning). A penguin in the water near the ice is the target.
## The pod races to get between it and the nearest ice, and forms a wall of fins there, facing
## it. Then the wall closes in, pushing it out to sea. Anyone who comes within snap_range of an
## orca in the wall (trying to slip through) gets lunged at, with the usual warning.
##
## How it ends: pushed out into open water, the penguin is handed on to the next attack of the
## trap (the carousel). Still near the ice when the warning runs out, the nearest orca lunges.
## Back on the ice, or past the wall, it got away.
##
## To beat it: see the fins heading for the gap between you and the ice and race them home;
## swim around the end of the wall (they're faster than you cruising, slower than a boost); or
## dive under it.
##
## Warning: fins racing to cut you off, the wall lining up, then the line you mustn't cross
## marked on the water in the danger colour.

## How often it looks again for the way home (s).
const RETHINK := 0.25

## The flat direction from the penguin toward the nearest ice, and how far that is.
var home := Vector3.FORWARD
var shore_distance := 10.0

var _rethink := 0.0
var _gap := 6.0
var _line: MeshInstance3D = null


func find_target(lead: Predator) -> float:
	var t := _t()
	var world := pod.get_world_3d()
	var score := best_swimmer(lead, func(p: Penguin) -> bool:
		var d := IceEdges.shore_distance(world, p.global_position, t.open_water_distance)
		return d >= t.home_distance and d < t.open_water_distance)
	if score >= 0.0:
		_look_home()
	return score


func begin() -> void:
	_gap = _t().wall_gap_start
	_rethink = 0.0


func steer(phase: PredatorPod.Phase, phase_time: float) -> void:
	_rethink -= pod.get_physics_process_delta_time()
	if _rethink <= 0.0:
		_rethink = RETHINK
		_look_home()
	if phase == PredatorPod.Phase.WARN:
		_gap = lerpf(_t().wall_gap_start, _t().wall_gap_end, clampf(phase_time / settings.warning_seconds, 0.0, 1.0))
	var n := attackers.size()
	for i in n:
		var member := attackers[i]
		member.order_move(wall_spot(i, n), member.tuning.chase_speed, _t().wall_depth, -home, false)


## In the wall, or close enough, or out of time.
func lined_up(phase_time: float) -> bool:
	return all_in_place(wall_spot, IN_PLACE * 1.5) or phase_time >= settings.lineup_max_seconds


## The warning ends early if the penguin comes too close to the wall (a lunge is coming), or once
## it's been pushed out into open water.
func warned(phase_time: float) -> bool:
	return phase_time >= settings.warning_seconds or _closest_snapper() != null or shore_distance >= _t().open_water_distance


## Back on the ice (or gone), or made it to the ice edge (close enough to launch out), or slipped
## past the wall to the ice side of it.
func escaped() -> bool:
	if not is_instance_valid(target) or target.state != Penguin.State.SWIM:
		return true
	if shore_distance < _t().wall_shore_margin + 0.5:
		return true
	return _past_wall() and shore_distance < _t().home_distance


func update_warning(progress: float) -> void:
	if progress >= settings.zone_shows_at:
		_show_line()


## Out in open water: nothing to do here, the trap moves on. Otherwise the closest orca in the
## wall lunges at the penguin.
func strike() -> Array[Penguin]:
	hide_zone()
	if shore_distance >= _t().open_water_distance:
		return []
	var snapper := _closest_snapper()
	if snapper == null:
		snapper = _closest_attacker()
	if snapper != null:
		snapper.order_strike(target)
	return [target]


## The wall holds between the penguin and the ice while the others go after it.
func hunt(_phase_time: float) -> void:
	if is_instance_valid(target) and target.state == Penguin.State.SWIM:
		_look_home()
	var n := attackers.size()
	for i in n:
		var member := attackers[i]
		if is_instance_valid(member) and member.is_available():
			member.order_move(wall_spot(i, n), member.tuning.chase_speed, _t().wall_depth, -home)


func seconds_to_strike(phase: PredatorPod.Phase, phase_time: float) -> float:
	if phase == PredatorPod.Phase.WARN:
		return maxf(settings.warning_seconds - phase_time, 0.0)
	return -1.0


func cancel() -> void:
	hide_zone()


func hide_zone() -> void:
	super.hide_zone()
	if _line != null:
		_line.visible = false


## Spot `i` of `n` in the wall: side by side across the penguin's way home, _gap from it (but
## never right up against the ice).
func wall_spot(i: int, n: int) -> Vector3:
	var at := target.global_position if is_instance_valid(target) else attackers_centre()
	var gap := minf(_gap, maxf(shore_distance - _t().wall_shore_margin, 1.0))
	var side := home.cross(Vector3.UP).normalized()
	var spot := at + home * gap + side * (i - (n - 1) * 0.5) * _t().wall_spacing
	spot.y = Penguin.WATER_LEVEL - _t().wall_depth
	return spot


## Which way home is for the target now, and how far.
func _look_home() -> void:
	if not is_instance_valid(target):
		return
	var shore := IceEdges.nearest_shore(pod.get_world_3d(), target.global_position, _t().open_water_distance + 15.0)
	if shore.is_empty():
		shore_distance = INF
		return
	home = shore["dir"]
	shore_distance = shore["distance"]


## The orca in the wall the penguin is trying to slip past, or null: an orca in its place in the
## wall, within snap_range while the penguin swims toward the ice, or right on top of it.
func _closest_snapper() -> Predator:
	if not is_instance_valid(target):
		return null
	var heading_home := target.velocity.dot(home) > 0.5
	var best: Predator = null
	var best_d := _t().snap_range if heading_home else _t().snap_range * 0.6
	var n := attackers.size()
	for i in n:
		var member := attackers[i]
		# Only an orca that's in its place in the wall (not one still swimming round to it).
		if member.global_position.distance_to(wall_spot(i, n)) > IN_PLACE * 1.5:
			continue
		var d := member.global_position.distance_to(target.global_position)
		if d <= best_d:
			best_d = d
			best = member
	return best


func _closest_attacker() -> Predator:
	var best: Predator = null
	var best_d := INF
	for member in attackers:
		var d := member.global_position.distance_to(target.global_position)
		if d < best_d:
			best_d = d
			best = member
	return best


## Is the penguin on the ice side of the wall?
func _past_wall() -> bool:
	if attackers.is_empty():
		return false
	var rel := target.global_position - attackers_centre()
	rel.y = 0.0
	return rel.dot(home) > 1.0


## The line across the water, through the wall, that the penguin mustn't cross.
func _show_line() -> void:
	if _line == null:
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 0.04, 0.25)
		_line = make_marker(&"DangerLine", box)
	var n := attackers.size()
	var length := maxf(n - 1, 0) * _t().wall_spacing + _t().snap_range * 2.0
	var centre := (wall_spot(0, n) + wall_spot(n - 1, n)) * 0.5
	centre.y = Penguin.WATER_LEVEL + 0.03
	var side := home.cross(Vector3.UP).normalized()
	_line.global_transform = Transform3D(Basis(side, Vector3.UP, side.cross(Vector3.UP)), centre).scaled_local(Vector3(length, 1.0, 1.0))
	_line.visible = true


func _t() -> CutOffAttackTuning:
	return settings as CutOffAttackTuning
