class_name Humpback
extends Swimmer
## A humpback whale (GDD §5.5): a gentle giant, and not an enemy. Twice an orca's length, it
## cruises slowly round the ice, comes up to blow, feeds on fish schools with a bubble net, and
## drives orcas off a penguin they're hunting. It never eats a penguin.
##
## From afar, at the surface, it looks like an orca: a dark back, a fin, a dark shadow. The tells
## (docs/ART_DIRECTION.md) are its size, its little fin on a hump, its long white flippers, its
## slow pace, its bushy blow and its flukes going up as it dives.
##
## What it does, as states:
##   TRAVEL   - cruises between waypoints round the ice, at travel_depth. Every so often it comes
##              up to breathe, or goes to feed.
##   SURFACE  - rolls along the top, its back out of the water, blowing (blew), then
##   DIVE     - goes down nose first, flukes up.
##   APPROACH - swims to a fish school in open water, under and to one side of it, then
##   NET      - circles it, deep, blowing a ring of bubbles that closes in (a BubbleWall): the fish
##              in it are herded into a ball at the surface (Fish.herd());
##   AIM      - the ring closed, it turns up under the middle (the water boils with fish in the
##              middle of the ring: the last tell), and
##   LUNGE    - lunges up through it, mouth open: every fish within gulp_radius is gone for
##              fish_gone_seconds (gulped), and any penguin in the water there is scooped up and
##              tossed out, dazed and a fish lighter, never eaten (scooped);
##   FALL     - falls back in with a splash, then
##   REST     - lies at the surface a while.
##   MOB      - orcas hunting a penguin nearby (a pod's attack, or one orca after a penguin): it
##              goes to break it up. Once the penguin is within its shelter_radius, the pod's
##              attack is called off (PredatorPod.call_off()) and the orcas back off (drove_off),
##              then
##   GUARD    - stays by that penguin a while.
## Any penguin within shelter_radius of a humpback is off limits to orcas (shelters(); orcas are
## PredatorTuning.shy_of_humpbacks), so a hunted penguin can hide by one: if it can tell it from
## an orca in time. Its body dazes a penguin that bumps into it, like any whale's (Swimmer),
## except the one it's guarding.

signal state_changed(new_state: State)
## It blew: a spout at its blowhole.
signal blew(at: Vector3)
## It started a bubble net round `centre` (on the water).
signal net_started(centre: Vector3)
## It lunged up through its net and swallowed `fish` fish.
signal gulped(centre: Vector3, fish: int)
## It scooped `penguin` up and tossed it out.
signal scooped(penguin: Penguin)
## It reached `penguin`, which orcas were hunting, and drove them off.
signal drove_off(penguin: Penguin)

enum State { TRAVEL, SURFACE, DIVE, APPROACH, NET, AIM, LUNGE, FALL, REST, MOB, GUARD }

## How often it looks for orca hunts to break up (s).
const SCAN_INTERVAL := 0.5
## Close enough to a waypoint (m).
const WAYPOINT_REACHED := 6.0
## Close enough to where its net starts (m).
const NET_START_REACHED := 3.0
## How long it may take to come up to breathe before it gives up (ice overhead) (s).
const SURFACE_TIMEOUT := 20.0
## How often it re-herds the fish while netting (s), and how long each herding lasts (s).
const HERD_REFRESH := 0.4
const HERD_HOLD := 1.0
## The netted fish are driven up to this depth (m)...
const BALL_DEPTH := 1.2
## ...into a ball this big, as a share of the ring.
const BALL_SHARE := 0.55
## Turning up under the middle of the net (rad/s).
const AIM_TURN := 2.5
## Mobbing: it blows (trumpets) this often (s).
const MOB_BLOW_INTERVAL := 2.5
## Gravity when it's out of the water after a lunge (m/s²).
const AIR_GRAVITY := 9.8
## Its throat balloons this much with a mouthful (scale, across and down), this fast (per second).
const GULP_SWELL := Vector2(1.15, 1.8)
## The netted fish boil at the surface for this long before the ring closes, and while it aims (s).
const BOIL_SECONDS := 1.5
const SWELL_RATE := 3.0
## Nothing to feed on nearby: looks again this soon (s).
const FEED_RETRY := 10.0
## How many schools it considers when choosing where to feed.
const FEED_CHOICES := 6

const SPLASH_MATERIAL := preload("res://art/materials/splash.tres")

## Every humpback in the scene: how orcas find out who's sheltered.
static var _all: Array[Humpback] = []

@export var tuning: HumpbackTuning
## What it roams round (set by whoever spawns it): the middle of the ice and its radius.
@export var roam_centre := Vector3.ZERO
@export var ice_radius := 30.0

var state: State = State.TRAVEL
var _state_time := 0.0
var _waypoint := Vector3.ZERO
var _roam_dir := 1.0
var _breath_in := 0.0
var _feed_in := 0.0
var _blows_left := 0
var _blow_in := 0.0
var _surfaced_for := 0.0
var _scan := 0.0
# The bubble net: its middle (on the water), the angle it circles from and which way, the depth
# it circles at, and the curtain.
var _net_centre := Vector3.ZERO
var _net_angle := 0.0
var _net_spin := 1.0
var _net_y := -8.0
var _wall: BubbleWall = null
var _herd_in := 0.0
var _lunge_dir := Vector3.UP
## Where AIM takes it from (its spot on the ring) and to (under the middle, lined up to lunge).
var _aim_from := Vector3.ZERO
var _aim_to := Vector3.ZERO
var _gulped := false
var _splashed := false
# The penguin it's going to help, or guarding.
var _protege: Penguin = null

var _spout: CPUParticles3D
var _splash: CPUParticles3D
## The water boiling with netted fish in the middle of the ring, just before the lunge.
var _boil: CPUParticles3D
## The throat (its pleats balloon in a lunge), and its resting scale.
var _throat: Node3D
var _throat_scale := Vector3.ONE


func _enter_tree() -> void:
	_all.append(self)


func _exit_tree() -> void:
	_all.erase(self)


func _ready() -> void:
	super()
	add_to_group(&"humpbacks")
	_spout = _make_spray(&"Spout", 60, 1.4, 6.0, 9.0, 18.0, Vector3(0.0, -5.0, 0.0), 0.12)
	_splash = _make_spray(&"Splash", 90, 1.3, 4.0, 8.0, 50.0, Vector3(0.0, -9.8, 0.0), 0.18)
	_boil = _make_spray(&"Boil", 48, 0.6, 1.5, 3.0, 25.0, Vector3(0.0, -9.8, 0.0), 0.08)
	_boil.one_shot = false
	_boil.explosiveness = 0.0
	_boil.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_boil.emission_sphere_radius = tuning.net_radius.y * BALL_SHARE
	_throat = get_node_or_null(^"Model/Throat") as Node3D
	if _throat != null:
		_throat_scale = _throat.basis.get_scale()
	_breath_in = randf_range(tuning.breath_interval.x, tuning.breath_interval.y) * randf_range(0.2, 1.0)
	_feed_in = randf_range(tuning.feed_interval.x, tuning.feed_interval.y) * randf_range(0.3, 1.0)
	_roam_dir = 1.0 if randf() < 0.5 else -1.0
	_next_waypoint()


func swim_tuning() -> SwimmerTuning:
	return tuning


func _think(delta: float) -> void:
	_state_time += delta
	_breath_in -= delta
	_feed_in -= delta
	_tick_blows(delta)
	if state in [State.TRAVEL, State.SURFACE, State.DIVE, State.APPROACH, State.REST]:
		_scan -= delta
		if _scan <= 0.0:
			_scan = SCAN_INTERVAL
			var hunted := _hunted_penguin()
			if hunted != null:
				_start_mob(hunted)
	match state:
		State.TRAVEL:
			_travel(delta)
		State.SURFACE:
			_surface(delta)
		State.DIVE:
			_dive(delta)
		State.APPROACH:
			_approach(delta)
		State.NET:
			_net(delta)
		State.AIM:
			_aim(delta)
		State.LUNGE:
			_lunge(delta)
		State.FALL:
			_fall(delta)
		State.REST:
			_rest(delta)
		State.MOB:
			_mob(delta)
		State.GUARD:
			_guard(delta)
	_swell_throat(delta)
	var boiling := state == State.AIM or (state == State.NET and _state_time > tuning.net_seconds - BOIL_SECONDS)
	if boiling != _boil.emitting:
		_boil.global_position = Vector3(_net_centre.x, GameWorld.WATER_LEVEL, _net_centre.z)
		_boil.emitting = boiling


# --- Public API -------------------------------------------------------------

## Is `point` sheltered by a humpback (within its shelter_radius of one)?
static func shelters(point: Vector3) -> bool:
	return sheltering(point) != null


## The humpback sheltering `point`, or null.
static func sheltering(point: Vector3) -> Humpback:
	for whale in _all:
		if whale.is_inside_tree() and whale.distance_to_body(point) <= whale.tuning.shelter_radius:
			return whale
	return null


## The humpback whose bubble net `point` is inside, about to be lunged through (a penguin there
## should swim clear), or null.
static func net_closing_on(point: Vector3) -> Humpback:
	for whale in _all:
		if whale.is_inside_tree() and whale.state in [State.NET, State.AIM]:
			var flat := Vector2(point.x - whale._net_centre.x, point.z - whale._net_centre.z)
			if flat.length() <= whale.net_radius() + 1.0:
				return whale
	return null


## The middle of its bubble net (on the water), while it's netting or lunging.
func net_centre() -> Vector3:
	return _net_centre


## The radius of its bubble net right now (m); 0 if it isn't netting.
func net_radius() -> float:
	match state:
		State.NET:
			return lerpf(tuning.net_radius.x, tuning.net_radius.y, _net_progress())
		State.AIM:
			return tuning.net_radius.y
	return 0.0


## The penguin it's on its way to help, or guarding (null if none).
func protege() -> Penguin:
	return _protege if is_instance_valid(_protege) else null


## Seconds until it next comes up to breathe, and next goes looking for a meal (for testers).
func next_breath_in() -> float:
	return maxf(_breath_in, 0.0)


func next_feed_in() -> float:
	return maxf(_feed_in, 0.0)


## Comes up to breathe now (levels, tests).
func breathe_now() -> void:
	_breath_in = 0.0
	if state in [State.TRAVEL, State.REST]:
		_set_state(State.SURFACE)


## Feeds on `fish`'s school now (levels, tests): returns false if it's busy (feeding, or helping a
## penguin) or the school isn't in open water.
func feed_on(fish: Fish) -> bool:
	if not (state in [State.TRAVEL, State.SURFACE, State.DIVE, State.REST]) or fish == null:
		return false
	if not _net_spot_ok(fish.home):
		return false
	_plan_net(fish.home)
	_set_state(State.APPROACH)
	return true


# --- Travelling and breathing ------------------------------------------------

func _travel(delta: float) -> void:
	if _breath_in <= 0.0:
		_set_state(State.SURFACE)
		return
	if _feed_in <= 0.0:
		var school := _pick_school()
		if school != null:
			_plan_net(school.home)
			_set_state(State.APPROACH)
			return
		_feed_in = FEED_RETRY
	var to := _waypoint - global_position
	if Vector2(to.x, to.z).length() < WAYPOINT_REACHED:
		_next_waypoint()
	_swim_toward(_waypoint, tuning.travel_speed, delta)


## The next spot on its slow loop round the ice: farther round, at a random distance out and depth.
func _next_waypoint() -> void:
	var from := global_position - roam_centre
	var angle := atan2(from.z, from.x) + _roam_dir * randf_range(0.5, 1.1)
	var d := ice_radius + randf_range(tuning.roam_offset.x, tuning.roam_offset.y)
	var depth := randf_range(tuning.travel_depth.x, tuning.travel_depth.y)
	_waypoint = roam_centre + Vector3(cos(angle) * d, GameWorld.WATER_LEVEL - depth, sin(angle) * d)


func _surface(delta: float) -> void:
	# Up at a slant, pressing against the surface (it can't come higher than surface_depth).
	var ahead := global_position + _flat_heading() * 8.0
	ahead.y = GameWorld.WATER_LEVEL - tuning.surface_depth + 2.0
	_swim_toward(ahead, tuning.travel_speed, delta, false, tuning.surface_depth)
	if _depth() <= tuning.surface_depth + 0.3:
		if _surfaced_for == 0.0:
			_start_blowing(tuning.blows)
		_surfaced_for += delta
	if _surfaced_for >= tuning.surface_seconds or _state_time > SURFACE_TIMEOUT:
		_set_state(State.DIVE)


func _dive(delta: float) -> void:
	var pitch := deg_to_rad(tuning.dive_pitch_deg)
	var down := _flat_heading() * cos(pitch) + Vector3.DOWN * sin(pitch)
	_swim_toward(global_position + down * 10.0, tuning.travel_speed, delta, false, tuning.surface_depth)
	if _state_time >= tuning.dive_seconds:
		_breath_in = randf_range(tuning.breath_interval.x, tuning.breath_interval.y)
		_next_waypoint()
		_set_state(State.TRAVEL)


func _rest(delta: float) -> void:
	var ahead := global_position + _flat_heading() * 12.0
	ahead.y = GameWorld.WATER_LEVEL - tuning.surface_depth + 1.0
	_swim_toward(ahead, tuning.travel_speed * 0.3, delta, false, tuning.surface_depth)
	if _state_time >= tuning.rest_seconds:
		_breath_in = randf_range(tuning.breath_interval.x, tuning.breath_interval.y)
		_feed_in = randf_range(tuning.feed_interval.x, tuning.feed_interval.y)
		_next_waypoint()
		_set_state(State.TRAVEL)


func _start_blowing(count: int) -> void:
	_blows_left = count
	_blow_in = 0.0


func _tick_blows(delta: float) -> void:
	if _blows_left <= 0:
		return
	_blow_in -= delta
	if _blow_in > 0.0 or _depth() > tuning.surface_depth + 0.6:
		return
	_blows_left -= 1
	_blow_in = tuning.blow_interval
	var at := global_position + _flat_heading() * tuning.body_length * 0.28
	at.y = GameWorld.WATER_LEVEL + 0.2
	_spout.global_position = at
	_spout.restart()
	blew.emit(at)


# --- Feeding: the bubble net -------------------------------------------------

## Of the fish schools within feed_range, the nearest of a few in open water, or null.
func _pick_school() -> Fish:
	var best: Fish = null
	var best_d := INF
	for i in FEED_CHOICES:
		var fish := Fish.random_in_school_near(global_position, tuning.feed_range)
		if fish == null:
			return null
		var d := global_position.distance_to(fish.home)
		if d < best_d and _net_spot_ok(fish.home):
			best = fish
			best_d = d
	return best


## Room for a net round `spot`: no ice within the net's first radius plus net_clearance.
func _net_spot_ok(spot: Vector3) -> bool:
	var clear := tuning.net_radius.x + tuning.net_clearance
	return IceEdges.shore_distance(get_world_3d(), Vector3(spot.x, 0.0, spot.z), clear) == INF


## Sets up a net round `school_home`: centred on it, starting on its own side, circling the way
## it's already turning.
func _plan_net(school_home: Vector3) -> void:
	_net_centre = Vector3(school_home.x, GameWorld.WATER_LEVEL, school_home.z)
	var from := global_position - _net_centre
	_net_angle = atan2(from.z, from.x)
	var tangent := Vector3(-sin(_net_angle), 0.0, cos(_net_angle))
	_net_spin = 1.0 if tangent.dot(_flat_heading()) >= 0.0 else -1.0
	_net_y = minf(school_home.y - 2.0, GameWorld.WATER_LEVEL - tuning.net_depth)
	_net_y = maxf(_net_y, GameWorld.WATER_LEVEL - MAX_DEPTH + 2.0)


## Where it should be on its net at `progress` (0 to 1).
func _net_point(progress: float) -> Vector3:
	var angle := _net_angle + _net_spin * TAU * tuning.net_turns * progress
	var r := lerpf(tuning.net_radius.x, tuning.net_radius.y, clampf(progress, 0.0, 1.0))
	return Vector3(_net_centre.x + cos(angle) * r, _net_y, _net_centre.z + sin(angle) * r)


func _net_progress() -> float:
	return clampf(_state_time / tuning.net_seconds, 0.0, 1.0) if state == State.NET else 1.0


func _approach(delta: float) -> void:
	var start := _net_point(0.0)
	_swim_toward(start, tuning.travel_speed * 1.4, delta, true)
	if global_position.distance_to(start) <= NET_START_REACHED:
		_wall = BubbleWall.new()
		_wall.name = &"BubbleNet"
		add_child(_wall)
		_wall.set_ring(_net_centre, tuning.net_radius.x)
		_herd_in = 0.0
		_set_state(State.NET)
		net_started.emit(_net_centre)
	elif _state_time > tuning.approach_seconds:
		_end_feeding(FEED_RETRY)


func _net(delta: float) -> void:
	# It follows the spiral: its speed is whatever keeps it on it.
	var next := _net_point(minf((_state_time + delta) / tuning.net_seconds, 1.0))
	var step := next - global_position
	velocity = step / delta if step.length() / delta <= tuning.lunge_speed else step.normalized() * tuning.lunge_speed
	if velocity.length() > 0.1:
		_heading = velocity.normalized()
		_speed = velocity.length()
	_move(MIN_DEPTH)
	var r := net_radius()
	if _wall != null:
		_wall.set_ring(_net_centre, r + 0.5)
	_herd_in -= delta
	if _herd_in <= 0.0:
		_herd_in = HERD_REFRESH
		var ball := Vector3(_net_centre.x, GameWorld.WATER_LEVEL - BALL_DEPTH, _net_centre.z)
		Fish.herd_near(ball, tuning.herd_reach, r * BALL_SHARE, HERD_HOLD)
	if _state_time >= tuning.net_seconds:
		_line_up_lunge()
		_set_state(State.AIM)


func _aim(delta: float) -> void:
	# Drops under the middle of the ring and turns its nose up at the fish packed at the surface:
	# the last tell before it lunges.
	var t := smoothstep(0.0, 1.0, minf(_state_time / tuning.aim_seconds, 1.0))
	var before := global_position
	velocity = (_aim_from.lerp(_aim_to, t) - before) / delta
	_move(MIN_DEPTH)
	_heading = _turn_toward(_heading, _lunge_dir, AIM_TURN * delta)
	_speed = velocity.length()
	var ball := Vector3(_net_centre.x, GameWorld.WATER_LEVEL - BALL_DEPTH, _net_centre.z)
	Fish.herd_near(ball, tuning.herd_reach, tuning.net_radius.y * BALL_SHARE, HERD_HOLD)
	if _state_time >= tuning.aim_seconds:
		_gulped = false
		_splashed = false
		if _wall != null:
			_wall.fade(1.0)
			_wall = null
		_set_state(State.LUNGE)


## Lines up the lunge: straight up through the middle of the net at lunge_pitch_deg, from its own
## side, its mouth starting at the depth it circled at.
func _line_up_lunge() -> void:
	var inward := Vector3(_net_centre.x - global_position.x, 0.0, _net_centre.z - global_position.z)
	inward = inward.normalized() if inward.length() > 0.1 else _flat_heading()
	var pitch := deg_to_rad(tuning.lunge_pitch_deg)
	_lunge_dir = inward * cos(pitch) + Vector3.UP * sin(pitch)
	var top := _net_centre + Vector3.UP * tuning.lunge_height
	var mouth_start := top - _lunge_dir * ((top.y - _net_y) / sin(pitch))
	_aim_from = global_position
	_aim_to = mouth_start - _lunge_dir * tuning.body_length * 0.5
	_aim_to.y = maxf(_aim_to.y, GameWorld.WATER_LEVEL - MAX_DEPTH + 1.0)


func _lunge(delta: float) -> void:
	_heading = _lunge_dir
	_speed = tuning.lunge_speed
	velocity = _lunge_dir * _speed
	_move(-(tuning.lunge_height + tuning.body_length))
	var head := _head()
	if not _gulped and head.y > GameWorld.WATER_LEVEL - 1.0:
		_gulp()
	if head.y >= GameWorld.WATER_LEVEL + tuning.lunge_height or _state_time > 3.0:
		_set_state(State.FALL)


## Mouth open at the surface: the netted fish are gone, and penguins there are thrown out.
func _gulp() -> void:
	_gulped = true
	var eaten := Fish.gulp_near(_net_centre, tuning.gulp_radius, GameWorld.WATER_LEVEL - 4.0, tuning.fish_gone_seconds)
	_spray(_splash, _net_centre)
	for node in get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p == null or not (p.state == Penguin.State.SWIM or p.global_position.y < GameWorld.WATER_LEVEL):
			continue
		var flat := Vector3(p.global_position.x - _net_centre.x, 0.0, p.global_position.z - _net_centre.z)
		if flat.length() > tuning.scoop_radius or p.global_position.y < GameWorld.WATER_LEVEL - 4.0:
			continue
		var out := flat.normalized() if flat.length() > 0.1 else Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
		p.toss(out * tuning.scoop_out_speed + Vector3.UP * tuning.scoop_up_speed)
		p.disorient(tuning.scoop_daze_seconds)
		p.lose_fish()
		_bumped[p] = BUMP_COOLDOWN * 2.0 # no body bump on top of the scoop
		scooped.emit(p)
	gulped.emit(_net_centre, eaten)


func _fall(delta: float) -> void:
	# Up and over: its weight brings it down nose first, and back in the water levels it out.
	var in_water := global_position.y < GameWorld.WATER_LEVEL - tuning.surface_depth
	if in_water and velocity.y < 0.0:
		if not _splashed:
			_splashed = true
			_spray(_splash, Vector3(global_position.x, GameWorld.WATER_LEVEL, global_position.z))
		velocity = velocity.move_toward(_flat_heading() * 1.0, 10.0 * delta)
	else:
		velocity.y -= AIR_GRAVITY * delta
	if velocity.length() > 0.3:
		_heading = velocity.normalized()
		_speed = velocity.length()
	_move(-(tuning.lunge_height + tuning.body_length))
	if _state_time >= tuning.fall_seconds and _splashed:
		_heading = _flat_heading()
		_start_blowing(1)
		_set_state(State.REST)
	elif _state_time > tuning.fall_seconds * 3.0:
		_heading = _flat_heading()
		_set_state(State.REST)


## Gives up on feeding (or finishes): back to cruising, looking again in `retry` seconds.
func _end_feeding(retry: float) -> void:
	if _wall != null:
		_wall.fade(0.8)
		_wall = null
	_feed_in = retry
	_next_waypoint()
	_set_state(State.TRAVEL)


# --- Driving off orcas -------------------------------------------------------

## The nearest penguin within mob_range that orcas (predators shy of humpbacks) are hunting: a
## pod's attack target, or the target of an orca chasing or striking. Null if none.
func _hunted_penguin() -> Penguin:
	var best: Penguin = null
	var best_d := tuning.mob_range
	for p in _hunted_penguins():
		var d := global_position.distance_to(p.global_position)
		if d <= best_d:
			best_d = d
			best = p
	return best


func _hunted_penguins() -> Array[Penguin]:
	var hunted: Array[Penguin] = []
	for node in get_tree().get_nodes_in_group(&"pods"):
		var pod := node as PredatorPod
		if pod == null or pod.attack == null or not is_instance_valid(pod.attack.target):
			continue
		var lead := pod.leader()
		if lead != null and lead.tuning.shy_of_humpbacks and not hunted.has(pod.attack.target):
			hunted.append(pod.attack.target)
	for node in get_tree().get_nodes_in_group(&"predators"):
		var predator := node as Predator
		if predator == null or not predator.tuning.shy_of_humpbacks or not is_instance_valid(predator.target):
			continue
		if predator.state in [Predator.State.CHASE, Predator.State.WARN, Predator.State.LUNGE] and not hunted.has(predator.target):
			hunted.append(predator.target)
	return hunted


func _start_mob(p: Penguin) -> void:
	if state in [State.APPROACH]:
		_end_feeding(FEED_RETRY)
	_protege = p
	_start_blowing(1)
	_blow_in = 0.0
	_set_state(State.MOB)


func _mob(delta: float) -> void:
	var p: Penguin = _protege if is_instance_valid(_protege) else null # it may have been eaten
	if not _penguin_ok(p):
		_end_mob()
		return
	if distance_to_body(p.global_position) <= tuning.shelter_radius:
		# There: the penguin's sheltered, and the orcas give it up.
		_drive_off(p)
		_set_state(State.GUARD)
		return
	if _state_time > tuning.mob_seconds or not _hunted_penguins().has(p):
		_end_mob()
		return
	_swim_toward(_guard_spot(p), tuning.mob_speed, delta, false, tuning.surface_depth)
	if _blows_left <= 0 and fmod(_state_time, MOB_BLOW_INTERVAL) < delta:
		_start_blowing(1)


## Breaks up whatever orca hunt `p` is in: a pod attacking it calls the attack off. Single orcas
## lose interest by themselves now that it's sheltered.
func _drive_off(p: Penguin) -> void:
	for node in get_tree().get_nodes_in_group(&"pods"):
		var pod := node as PredatorPod
		if pod != null and pod.attack != null and pod.attack.target == p:
			var lead := pod.leader()
			if lead != null and lead.tuning.shy_of_humpbacks:
				pod.call_off()
	drove_off.emit(p)


func _guard(delta: float) -> void:
	var p: Penguin = _protege if is_instance_valid(_protege) else null # it may have been eaten
	if not _penguin_ok(p) or _state_time > tuning.guard_seconds:
		_end_mob()
		return
	var spot := _guard_spot(p)
	var speed := clampf(global_position.distance_to(spot), 0.0, tuning.mob_speed)
	_swim_toward(spot, speed, delta, true, tuning.surface_depth)
	if _hunted_penguins().has(p) and distance_to_body(p.global_position) <= tuning.shelter_radius:
		_drive_off(p)


func _end_mob() -> void:
	_protege = null
	_next_waypoint()
	_set_state(State.TRAVEL)


## Beside `p`, on the side it's already on, near the surface.
func _guard_spot(p: Penguin) -> Vector3:
	var side := global_position - p.global_position
	side.y = 0.0
	side = side.normalized() if side.length() > 0.1 else Vector3.RIGHT
	var spot := p.global_position + side * (tuning.guard_offset + tuning.body_radius)
	spot.y = GameWorld.WATER_LEVEL - tuning.surface_depth
	return spot


func _penguin_ok(p: Penguin) -> bool:
	return p != null and is_instance_valid(p) and p.is_inside_tree()


func _dazes(p: Penguin) -> bool:
	return p != _protege


# --- Helpers -------------------------------------------------------------------

## A mouthful from the lunge balloons its throat; it shrinks back as it rests.
func _swell_throat(delta: float) -> void:
	if _throat == null:
		return
	var full := state in [State.LUNGE, State.FALL] or (state == State.REST and _state_time < 2.0)
	# (The throat is a capsule lying along the body: its own y runs nose to tail, its z is down.)
	var want := _throat_scale * (Vector3(GULP_SWELL.x, 1.0, GULP_SWELL.y) if full else Vector3.ONE)
	var now := _throat.basis.get_scale()
	var scale_now := now.lerp(want, clampf(SWELL_RATE * delta, 0.0, 1.0))
	_throat.basis = _throat.basis.orthonormalized().scaled_local(scale_now)


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	_state_time = 0.0
	_surfaced_for = 0.0
	state_changed.emit(new_state)


## Its heading, flattened (unit vector).
func _flat_heading() -> Vector3:
	var flat := Vector3(_heading.x, 0.0, _heading.z)
	return flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD


## Where its mouth is.
func _head() -> Vector3:
	return global_position + _heading * tuning.body_length * 0.5


func _depth() -> float:
	return GameWorld.WATER_LEVEL - global_position.y


## The blow and the splash: white spray, no scene needed.
func _make_spray(spray_name: StringName, amount: int, lifetime: float, speed_min: float, speed_max: float, spread: float, gravity: Vector3, size: float) -> CPUParticles3D:
	var drop := SphereMesh.new()
	drop.radius = size
	drop.height = size * 2.0
	drop.radial_segments = 6
	drop.rings = 3
	drop.material = SPLASH_MATERIAL
	var spray := CPUParticles3D.new()
	spray.name = spray_name
	spray.emitting = false
	spray.one_shot = true
	spray.explosiveness = 0.8
	spray.amount = amount
	spray.lifetime = lifetime
	spray.mesh = drop
	spray.direction = Vector3.UP
	spray.spread = spread
	spray.gravity = gravity
	spray.initial_velocity_min = speed_min
	spray.initial_velocity_max = speed_max
	spray.scale_amount_min = 0.6
	spray.scale_amount_max = 1.6
	spray.damping_min = 0.5
	spray.damping_max = 1.5
	spray.top_level = true
	add_child(spray)
	return spray


func _spray(spray: CPUParticles3D, at: Vector3) -> void:
	spray.global_position = at
	spray.restart()
