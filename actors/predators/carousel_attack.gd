class_name CarouselAttack
extends PodAttack
## The carousel (numbers in CarouselAttackTuning). A penguin out in open water, far from the ice,
## is the target.
##   Line up: the orcas spread out around it, dark shapes circling a few metres down.
##   Warn: they blow a wall of bubbles as they circle. The bubbles stop anyone swimming out
##         through them (a boost still gets through) and lift anyone inside up to the surface,
##         so there's no diving out. The ring squeezes in, and the middle, where the slap will
##         land, is ringed in the danger colour.
##   Charge: one orca rises to the middle and tail-slaps it: anyone there near the surface is
##         stunned (no boost, slow turns). Then another lunges through the middle, with the
##         usual warning and strike line.
## To beat it: get out before the bubbles go up, boost out through them early (the bigger the ring,
## the less there is to cross later), or keep out of the slap zone and dodge the lunge.

## How close to the middle the slapper has to get (m).
const SLAP_REACH := 2.5

## The middle of the ring (on the water) and how wide it is now.
var centre := Vector3.ZERO
var radius := 10.0

var _spin := 1.0
var _angle := 0.0
var _wall: BubbleWall = null
var _wall_on := false
var _slapper: Predator = null


func find_target(lead: Predator) -> float:
	var world := pod.get_world_3d()
	var far := _t().open_water_distance
	return best_swimmer(lead, func(p: Penguin) -> bool: return IceEdges.shore_distance(world, p.global_position, far) >= far)


func begin() -> void:
	centre = _flat(target.global_position)
	radius = _t().ring_start_radius
	_spin = 1.0 if randf() < 0.5 else -1.0
	_wall_on = false
	# Round the ring in the order they already are around the penguin, and turned so each one's
	# spot is close to where it is: nobody has to swim round the far side.
	var angle_of := func(m: Predator) -> float: return atan2(m.global_position.z - centre.z, m.global_position.x - centre.x)
	attackers.sort_custom(func(a: Predator, b: Predator) -> bool: return angle_of.call(a) < angle_of.call(b))
	var n := attackers.size()
	var offset := Vector2.ZERO
	for i in n:
		var a: float = angle_of.call(attackers[i]) - TAU * i / maxf(n, 1)
		offset += Vector2(cos(a), sin(a))
	_angle = offset.angle()
	_slapper = attackers[0] if not attackers.is_empty() else null


func steer(phase: PredatorPod.Phase, phase_time: float) -> void:
	var delta := pod.get_physics_process_delta_time()
	var t := _t()
	match phase:
		PredatorPod.Phase.LINE_UP:
			_follow(t.follow_speed, delta)
		PredatorPod.Phase.WARN:
			_follow(t.squeeze_follow_speed, delta)
			radius = lerpf(t.ring_start_radius, t.ring_end_radius, clampf(phase_time / settings.warning_seconds, 0.0, 1.0))
	_angle += _spin * _circling() * delta
	var n := attackers.size()
	for i in n:
		var member := attackers[i]
		if phase == PredatorPod.Phase.CHARGE and member == _slapper:
			member.order_move(centre + Vector3.DOWN * Predator.MIN_DEPTH, settings.charge_speed, Predator.MIN_DEPTH, Vector3.ZERO, false)
		else:
			member.order_move(ring_spot(i, n), member.tuning.chase_speed, t.ring_depth, Vector3.ZERO, false)
	if _wall_on:
		_wall.set_ring(centre, radius)
		var closing := (t.ring_start_radius - t.ring_end_radius) / maxf(settings.warning_seconds, 0.01)
		_hold_in(delta, closing if phase == PredatorPod.Phase.WARN else 0.0)


## Round the ring (or close enough), or out of time.
func lined_up(phase_time: float) -> bool:
	return all_in_place(ring_spot, IN_PLACE * 1.6) or phase_time >= settings.lineup_max_seconds


## The slapper has reached the middle (or should have by now).
func charged(phase_time: float) -> bool:
	if not is_instance_valid(_slapper):
		return true
	return _flat(_slapper.global_position).distance_to(centre) <= SLAP_REACH or phase_time >= 3.0


## Gone, out of the water, or out through the bubbles.
func escaped() -> bool:
	if not is_instance_valid(target) or target.state != Penguin.State.SWIM:
		return true
	return _flat(target.global_position).distance_to(centre) > radius + _t().wall_thickness + 2.0


func begin_warning() -> void:
	_wall = BubbleWall.new()
	pod.add_child(_wall)
	_wall.set_ring(centre, radius)
	_wall_on = true


func update_warning(progress: float) -> void:
	if progress >= settings.zone_shows_at:
		show_zone_ring(centre, _t().slap_radius)


## The tail slap: anyone in the middle near the surface is stunned and shoved out a little. Then
## another orca lunges at the target.
func strike() -> Array[Penguin]:
	var t := _t()
	var stunned: Array[Penguin] = []
	for node in pod.get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p == null or p.state != Penguin.State.SWIM:
			continue
		var flat := _flat(p.global_position) - centre
		if flat.length() > t.slap_radius + ZONE_MARGIN or GameWorld.WATER_LEVEL - p.global_position.y > t.slap_depth:
			continue
		p.stun(t.stun_seconds)
		p.push((flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD) * t.slap_push)
		stunned.append(p)
	_splash(centre)
	hide_zone()
	var striker := _striker()
	if striker != null:
		striker.order_strike(target)
	return stunned


## The others keep circling, and the bubbles linger a moment, while the striker goes in.
func hunt(phase_time: float) -> void:
	var delta := pod.get_physics_process_delta_time()
	_angle += _spin * _circling() * delta
	var n := attackers.size()
	for i in n:
		var member := attackers[i]
		if is_instance_valid(member) and member.is_available():
			member.order_move(ring_spot(i, n), member.tuning.patrol_speed, _t().ring_depth)
	if _wall_on:
		if phase_time < _t().wall_linger_seconds:
			_hold_in(delta, 0.0)
		else:
			_drop_wall()


func seconds_to_strike(phase: PredatorPod.Phase, phase_time: float) -> float:
	match phase:
		PredatorPod.Phase.WARN:
			return maxf(settings.warning_seconds - phase_time, 0.0) + radius / settings.charge_speed
		PredatorPod.Phase.CHARGE:
			if is_instance_valid(_slapper):
				return maxf(_flat(_slapper.global_position).distance_to(centre) - SLAP_REACH, 0.0) / settings.charge_speed
	return -1.0


func cancel() -> void:
	hide_zone()
	_drop_wall()


## Spot `i` of `n` round the ring, turning as they circle.
func ring_spot(i: int, n: int) -> Vector3:
	var a := _angle + TAU * i / maxf(n, 1)
	var spot := centre + Vector3(cos(a), 0.0, sin(a)) * radius
	spot.y = GameWorld.WATER_LEVEL - _t().ring_depth
	return spot


## Is the bubble wall up right now?
func wall_up() -> bool:
	return _wall_on


## The bubbles at work on every penguin swimming inside the ring (or in the wall itself): no
## swimming out through it (the wall sweeps you in as it closes at `closing` m/s; a boost still
## breaks through), and no diving below lift_depth.
func _hold_in(delta: float, closing: float) -> void:
	var t := _t()
	var half := t.wall_thickness * 0.5
	for node in pod.get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p == null or p.state != Penguin.State.SWIM:
			continue
		var flat := _flat(p.global_position) - centre
		var r := flat.length()
		if r > radius + half:
			continue
		if r > radius - half and r > 0.1:
			var outward := flat / r
			# Allowed outward speed: minus the speed the wall is closing in at.
			var excess := p.velocity.dot(outward) + closing
			if excess > 0.0:
				p.drift(-outward * minf(excess, t.wall_push * delta))
		if GameWorld.WATER_LEVEL - p.global_position.y > t.lift_depth:
			var short := t.lift_speed - p.velocity.y
			if short > 0.0:
				p.drift(Vector3.UP * minf(short, t.lift_push * delta))


## How fast they go round (rad/s): circle_speed, but no tighter than a big orca can turn.
func _circling() -> float:
	var turn := deg_to_rad(attackers[0].tuning.turn_rate_deg) * 0.7 if not attackers.is_empty() and is_instance_valid(attackers[0]) else 1.0
	return minf(_t().circle_speed / maxf(radius, 1.0), turn)


## While it gets into place the ring's middle drifts toward the target, so it stays inside.
func _follow(speed: float, delta: float) -> void:
	if is_instance_valid(target):
		centre = centre.move_toward(_flat(target.global_position), speed * delta)


## The one that lunges after the slap: the closest to the target that isn't the slapper.
func _striker() -> Predator:
	var best: Predator = null
	var best_d := INF
	for member in attackers:
		if member == _slapper or not is_instance_valid(member):
			continue
		var d := member.global_position.distance_to(target.global_position)
		if d < best_d:
			best_d = d
			best = member
	return best if best != null else _slapper


func _drop_wall() -> void:
	if _wall != null:
		_wall.fade()
		_wall = null
	_wall_on = false


## A burst of spray where the tail comes down.
func _splash(at: Vector3) -> void:
	var drop := SphereMesh.new()
	drop.radius = 0.12
	drop.height = 0.24
	drop.material = preload("res://art/materials/wave.tres")
	var spray := CPUParticles3D.new()
	spray.mesh = drop
	spray.amount = 60
	spray.lifetime = 1.0
	spray.one_shot = true
	spray.explosiveness = 0.95
	spray.direction = Vector3.UP
	spray.spread = 40.0
	spray.initial_velocity_min = 3.0
	spray.initial_velocity_max = 7.0
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	spray.emission_sphere_radius = 1.5
	spray.top_level = true
	pod.add_child(spray)
	spray.global_position = Vector3(at.x, GameWorld.WATER_LEVEL, at.z)
	spray.emitting = true
	spray.finished.connect(spray.queue_free)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _t() -> CarouselAttackTuning:
	return settings as CarouselAttackTuning
