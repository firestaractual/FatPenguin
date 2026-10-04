class_name Predator
extends CharacterBody3D
## A predator in the water (GDD §5): everything predators share. What kind it is comes from its
## PredatorTuning (how fast, how far it sees, how it lunges, how hungry it gets, whether it lies in
## ambush) and its scene (the model). The leopard seal is this script with leopard_seal.tres; the
## orca is this script with orca.tres, swimming in a PredatorPod that runs the pod's group attacks
## (PodAttack: the wave, the ram, the cut-off, the carousel).
## Spawning is data-driven: a level lists PredatorSpawn entries and a PredatorSpawner places them.
##
## States
##   PATROL  - swims a loop around the ice, patrol_offset out from its edge, swinging past
##             schools now and then.
##   CHASE   - locked on to the most tempting penguin in sight. A ring marks the target.
##   WARN    - in lunge range: it lines up its strike. The ring flashes and a line marks exactly
##             where the lunge will go, for lunge_warning s. Get off the line (turn or boost).
##   LUNGE   - a fast, straight dash along that line. Catches any penguin within catch_radius
##             of its jaws.
##   RECOVER - out of breath after a lunge: slower, and no lunging until the cooldown ends.
##   FEED    - starving: off to the nearest school to eat fish until it's fed. It still lunges
##             at a penguin that comes within lunge range.
##   SATED   - just ate a penguin: slow and harmless for a while (GDD §5.2).
##   ORDERED - swimming where its pod tells it (formation, lining up, charging). It still breaks
##             off to eat when starving, and still goes after a penguin in the water within
##             detect_range, unless the order says to hold (a pod herding a penguin).
##   AMBUSH  - lying in wait under the ice edge where a penguin on the ice would go in (or come
##             back out): it swims there and holds still, a dark shape under the edge. It lets
##             penguins in the water come to it; anyone who comes within ambush_strike_range (going
##             in, or swimming up to get out) gets a lunge with a shorter warning (ambush_warning).
##             It gives up after waiting ambush_seconds, or when nobody's near that edge any more.
##
## Hunting: it only notices penguins in the water within detect_range, and penguins out of the
## water (on the ice edge, or in the air) within edge_detect_range, and only with a clear line of
## sight (no hunting through ice). It picks the most tempting by size, noise and closeness
## (GDD §5.1), and only switches when another is clearly more tempting.
##
## Like a penguin, the body is a sphere that never rotates; only the Model node turns.
## It collides with the world (ice, seafloor) and dives under ice that's in its way.
## The lock-on ring and strike line are built here, so a predator scene only needs a body and a
## Model node.

signal state_changed(new_state: State)
signal locked_on(target: Penguin)
signal lunged(toward: Vector3)
signal caught_penguin(penguin: Penguin)
signal ate_fish

enum State { PATROL, CHASE, WARN, LUNGE, RECOVER, FEED, SATED, ORDERED, AMBUSH }

## Physics layer 3: predators collide with the world only. Catches are by distance.
const PREDATOR_LAYER := 4
## The body centre stays at least this far below the surface (m), except mid-lunge.
const MIN_DEPTH := 0.35
## Seafloor safety: never deeper than this (m).
const MAX_DEPTH := 25.0
## How often it re-scores the penguins in sight (s).
const SCAN_INTERVAL := 0.25
## Eyes sit this far above the body centre (for line of sight).
const EYE_HEIGHT := 0.6
## Within this depth of the surface it can peek over the ice edge, from this high above the
## water, at penguins standing on the ice (m).
const PEEK_DEPTH := 1.5
const PEEK_HEIGHT := 1.2
## Blocked by ice on the way somewhere: dive under it for this long (s).
const DIVE_SECONDS := 1.5
## Close enough to a patrol waypoint to pick the next one (m).
const WAYPOINT_REACHED := 2.5
## Within this of an ordered spot, it eases off and holds there (m).
const HOLD_DISTANCE := 1.0
## Lying in ambush, it looks for a better spot this often (s).
const AMBUSH_RETHINK := 2.0
## Near the surface it shows as a dark shadow on the water above it (docs/ART_DIRECTION.md:
## predators under the surface read as shadows): darkest down to SHADOW_FULL_DEPTH, fading out by
## SHADOW_DEPTH (m).
const SHADOW_DEPTH := 3.0
const SHADOW_FULL_DEPTH := 1.5
const SHADOW_DARKNESS := 0.6

const DANGER_MATERIAL := preload("res://art/materials/danger.tres")

@export var tuning: PredatorTuning
## The patrol loop runs around this point, patrol_offset outside ice_radius. The spawner sets both.
@export var patrol_centre := Vector3.ZERO
@export var ice_radius := 30.0

var state: State = State.PATROL
var hunger := 0.0
## The penguin it's locked on to, if any.
var target: Penguin = null

var _speed := 0.0
var _heading := Vector3.FORWARD
var _waypoint := Vector3.ZERO
var _patrol_dir := 1.0
var _state_time := 0.0
var _chase_time := 0.0
var _scan := 0.0
var _lunge_dir := Vector3.ZERO
var _lunge_cooldown := 0.0
var _dive_time := 0.0
var _hit_wall := false
## Penguins it gave up on, and for how much longer it ignores them.
var _ignored := {}
var _meal: Fish = null
## Orders from a pod: where to swim, how fast, how shallow it may go, and which way to face
## while holding its spot.
var _order_point := Vector3.ZERO
var _order_speed := 0.0
var _order_depth := MIN_DEPTH
var _order_face := Vector3.ZERO
var _order_hunts := true
## The lunge warning under way lasts this long (s): lunge_warning, or ambush_warning from an ambush.
var _warning_time := 0.0
## Lying in ambush: where it waits, which way it faces (toward the ice), and who it's waiting for.
var _ambush_spot := Vector3.ZERO
var _ambush_face := Vector3.ZERO
var _ambush_for: Penguin = null
var _ambush_rethink := 0.0
## How long it's been waiting still at its spot (s).
var _ambush_waited := 0.0

@onready var _model: Node3D = $Model
var _ring: MeshInstance3D
var _line: MeshInstance3D
var _shadow: MeshInstance3D
var _shadow_material: StandardMaterial3D
var _shadow_size := Vector3.ONE


func _ready() -> void:
	add_to_group(&"predators")
	if tuning == null:
		tuning = PredatorTuning.new()
	collision_layer = PREDATOR_LAYER
	collision_mask = Penguin.WORLD_LAYER
	motion_mode = MOTION_MODE_FLOATING
	hunger = randf_range(tuning.start_hunger.x, tuning.start_hunger.y)
	_patrol_dir = 1.0 if randf() < 0.5 else -1.0
	var out := global_position - patrol_centre
	_heading = Vector3(-out.z, 0.0, out.x).normalized() * _patrol_dir if out.length() > 0.1 else Vector3.FORWARD
	_make_markers()
	_next_waypoint()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		target = null # it left the level
	_state_time += delta
	_lunge_cooldown = maxf(_lunge_cooldown - delta, 0.0)
	_dive_time = maxf(_dive_time - delta, 0.0)
	_tick_ignored(delta)
	if state != State.SATED:
		hunger = minf(hunger + tuning.hunger_rate * delta, 100.0)

	match state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_chase(delta)
		State.WARN:
			_warn(delta)
		State.LUNGE:
			_lunge(delta)
		State.RECOVER:
			_recover(delta)
		State.FEED:
			_feed(delta)
		State.SATED:
			_sated(delta)
		State.ORDERED:
			_ordered(delta)
		State.AMBUSH:
			_ambush(delta)

	_update_model(delta)
	_update_markers()


# --- Public API -------------------------------------------------------------

func is_starving() -> bool:
	return hunger >= tuning.starving_hunger


## True while it's a threat to `p`: locked on and hunting it.
func is_hunting(p: Penguin) -> bool:
	return target == p and state in [State.CHASE, State.WARN, State.LUNGE, State.RECOVER]


## How tempting a penguin is right now (GDD §5.1): body size, noise and closeness, weighted.
func temptation(p: Penguin) -> float:
	var closeness := clampf(1.0 - global_position.distance_to(p.global_position) / tuning.detect_range, 0.0, 1.0)
	return tuning.size_weight * p.fatness() + tuning.noise_weight * p.noise + tuning.closeness_weight * closeness


## The way it's swimming (unit vector).
func heading() -> Vector3:
	return _heading


## Free to take orders from its pod: patrolling, or already under orders. Not while it's
## hunting, eating or sated.
func is_available() -> bool:
	return state == State.PATROL or state == State.ORDERED


## Tells it to swim to `point` at up to `speed` (call every frame to steer it). `min_depth` is
## how close to the surface it may come (lower it to bring fins up). Once there it holds its
## spot, facing `face` if given. With `may_hunt` off it won't break off after a penguin in the
## water (a pod herding one wants it to hold its place). Returns false (and does nothing) if it's
## busy.
func order_move(point: Vector3, speed: float, min_depth := MIN_DEPTH, face := Vector3.ZERO, may_hunt := true) -> bool:
	if not is_available():
		return false
	_order_point = point
	_order_speed = speed
	_order_depth = min_depth
	_order_face = face
	_order_hunts = may_hunt
	if state != State.ORDERED:
		_set_state(State.ORDERED)
	return true


## Tells it to go for `p` now (a pod's strike): it locks on and lunges with its usual warning,
## from wherever it is. Returns false if it's busy or still out of breath from its last lunge.
func order_strike(p: Penguin) -> bool:
	if not is_available() or _lunge_cooldown > 0.0 or not is_instance_valid(p):
		return false
	_ignored.erase(p)
	_lock_on(p)
	if _in_lunge_range(p):
		_start_warning()
	return true


## Could its pod call it back right now? Yes if it's free, or just chasing (not mid-lunge, not
## eating, not sated).
func can_be_recalled() -> bool:
	return is_available() or state == State.CHASE


## Drops a chase so its pod can give it orders.
func recall() -> void:
	if state == State.CHASE:
		target = null
		_set_state(State.PATROL)


## Back to its own patrol.
func release() -> void:
	if state == State.ORDERED:
		_next_waypoint()
		_set_state(State.PATROL)


# --- States -----------------------------------------------------------------

func _patrol(delta: float) -> void:
	_swim_toward(_waypoint, tuning.patrol_speed, delta)
	if global_position.distance_to(_waypoint) < WAYPOINT_REACHED or _state_time > 25.0:
		# End of a leg: lie in wait at the ice edge now and then, if a penguin is near one.
		if randf() < tuning.ambush_chance and _start_ambush():
			return
		_next_waypoint()
		_state_time = 0.0
	_scan -= delta
	if _scan > 0.0:
		return
	_scan = SCAN_INTERVAL
	if is_starving() and _find_meal():
		_set_state(State.FEED)
		return
	var best := _best_target()
	if best != null:
		_lock_on(best)


func _chase(delta: float) -> void:
	_chase_time += delta
	if not _huntable(target, tuning.lose_range) or _chase_time > tuning.chase_give_up_seconds:
		_give_up()
		return
	# Aim a little ahead of where it's going.
	var lead := clampf(global_position.distance_to(target.global_position) / tuning.chase_speed, 0.0, 1.0)
	_swim_toward(target.global_position + target.velocity * lead, tuning.chase_speed, delta)
	if _lunge_cooldown <= 0.0 and _in_lunge_range(target):
		_start_warning()
		return
	_scan -= delta
	if _scan > 0.0:
		return
	_scan = SCAN_INTERVAL
	if is_starving() and _find_meal():
		target = null
		_set_state(State.FEED)
		return
	# Only switch for a clearly more tempting penguin, so the lock-on doesn't flicker.
	var best := _best_target()
	if best != null and best != target and temptation(best) > temptation(target) * tuning.switch_threshold:
		_lock_on(best)


func _warn(delta: float) -> void:
	_chase_time += delta
	if not _huntable(target, tuning.lose_range):
		_set_state(State.CHASE)
		return
	# Coiled along the strike line: it stops re-aiming and matches the target's speed instead of
	# closing in, so the warning is a fair chance to get off the line however fast it chased.
	_speed = minf(_speed, target.get_speed())
	_swim_toward(global_position + _lunge_dir * 10.0, _speed, delta)
	if _state_time >= _warning_time:
		lunged.emit(global_position + _lunge_dir * _lunge_reach())
		_set_state(State.LUNGE)


func _lunge(delta: float) -> void:
	_heading = _lunge_dir
	_speed = tuning.lunge_speed
	velocity = _lunge_dir * _speed
	_move(-tuning.lunge_rise) # can rear up out of the water at the ice edge
	var caught := _penguin_in_reach()
	if caught != null:
		_eat_penguin(caught)
		return
	if _state_time >= tuning.lunge_seconds:
		_lunge_cooldown = tuning.lunge_cooldown
		_set_state(State.RECOVER)


func _recover(delta: float) -> void:
	_chase_time += delta
	var still_there := _huntable(target, tuning.lose_range)
	_swim_toward(target.global_position if still_there else _waypoint, tuning.recover_speed, delta)
	if _lunge_cooldown > 0.0:
		return
	if still_there:
		_set_state(State.CHASE)
	else:
		target = null
		_set_state(State.PATROL)


func _feed(delta: float) -> void:
	if _meal == null or not is_instance_valid(_meal) or not _meal.visible:
		if not _find_meal():
			_set_state(State.PATROL)
			return
	# Slows into tight turns so it doesn't just circle a fish it's trying to snap up.
	_swim_toward(_meal.global_position, tuning.chase_speed, delta, true)
	if global_position.distance_to(_meal.global_position) <= tuning.fish_bite_radius:
		_meal.get_eaten()
		_meal = null
		hunger = maxf(hunger - tuning.fish_hunger, 0.0)
		ate_fish.emit()
		if hunger <= tuning.fed_hunger:
			_set_state(State.PATROL)
			return
	# Starving, but it won't pass up a penguin that swims right up to it.
	_snap_at_close_penguin()


func _sated(delta: float) -> void:
	_swim_toward(_waypoint, tuning.sated_speed, delta)
	if global_position.distance_to(_waypoint) < WAYPOINT_REACHED:
		_next_waypoint()
	if _state_time >= tuning.sated_seconds:
		_set_state(State.PATROL)


func _ordered(delta: float) -> void:
	var to := _order_point - global_position
	var aim := _order_point
	# Slows as it arrives, and into tight turns, so a big, wide-turning predator doesn't circle
	# its spot.
	var speed := minf(_order_speed, 2.5 + to.length() * 1.5)
	if to.length() < HOLD_DISTANCE:
		# Holding its spot: ease off, and face the way it was told.
		speed = minf(speed, to.length() * 2.0)
		if _order_face != Vector3.ZERO:
			aim = global_position + _order_face * 5.0
	_swim_toward(aim, speed, delta, true, _order_depth)
	_scan -= delta
	if _scan > 0.0:
		return
	_scan = SCAN_INTERVAL
	if is_starving() and _find_meal():
		_set_state(State.FEED)
		return
	if not _order_hunts:
		return
	var best := _best_target()
	if best != null:
		_lock_on(best)


## Lying in wait under the ice edge. It swims to its spot and holds still there, facing the ice,
## until someone comes into the water close by (then a quick lunge), or it gives up.
func _ambush(delta: float) -> void:
	var to := _ambush_spot - global_position
	if to.length() > HOLD_DISTANCE:
		var speed := minf(tuning.patrol_speed, 1.0 + to.length() * 1.5)
		_swim_toward(_ambush_spot, speed, delta, true, tuning.ambush_depth)
	else:
		# Still and dark under the edge: it eases to a stop and turns to face the ice.
		_ambush_waited += delta
		_speed = move_toward(_speed, 0.0, tuning.acceleration * delta)
		_heading = _turn_toward(_heading, _ambush_face, deg_to_rad(tuning.turn_rate_deg) * delta)
		velocity = _heading * _speed + to * 2.0
		_move(tuning.ambush_depth)
	_scan -= delta
	if _scan > 0.0:
		return
	_scan = SCAN_INTERVAL
	if is_starving() and _find_meal():
		_set_state(State.FEED)
		return
	var close := _ambush_victim()
	if close != null:
		# Coiled and lined up already: it strikes from as far as its lunge carries.
		_lock_on(close)
		if _lunge_cooldown <= 0.0:
			_start_warning(tuning.ambush_warning)
		return
	# Anyone farther off it lets come closer: it's lying in wait.
	if _ambush_waited >= tuning.ambush_seconds:
		_end_ambush()
		return
	_ambush_rethink -= SCAN_INTERVAL
	if _ambush_rethink <= 0.0 and not _pick_ambush_spot():
		_end_ambush()


## Starts an ambush if there's a penguin on the ice near an edge to wait for. False if not.
func _start_ambush() -> bool:
	if tuning.ambush_chance <= 0.0 or is_starving() or not _pick_ambush_spot():
		return false
	_set_state(State.AMBUSH)
	return true


## Finds the edge to wait under: where the most tempting penguin on the ice within
## ambush_edge_reach of an edge (and ambush_scan_range of here) would go in. It moves along the
## edge as that penguin does. False if there's nobody to wait for.
func _pick_ambush_spot() -> bool:
	_ambush_rethink = AMBUSH_RETHINK
	var picks: Array[Penguin] = []
	for node in get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p == null or _ignored.has(p) or not (p.state == Penguin.State.WALK or p.state == Penguin.State.SLIDE):
			continue
		if p.global_position.y > Penguin.WATER_LEVEL + 1.6:
			continue # up on the plateau: nowhere near the water
		if global_position.distance_to(p.global_position) > tuning.ambush_scan_range:
			continue
		picks.append(p)
	# Most tempting first; the first one near an edge wins.
	picks.sort_custom(func(a: Penguin, b: Penguin) -> bool: return _ambush_appeal(a) > _ambush_appeal(b))
	for p in picks:
		var edge := IceEdges.nearest_edge(get_world_3d(), p.global_position, tuning.ambush_edge_reach)
		if edge.is_empty():
			continue
		var out: Vector3 = edge["out"]
		var spot: Vector3 = edge["point"] + out * tuning.ambush_offset
		spot.y = Penguin.WATER_LEVEL - tuning.ambush_depth
		if _spot_taken(spot):
			continue
		# Only swim off to a new spot if it's really moved (not every little step it takes).
		if p != _ambush_for or spot.distance_to(_ambush_spot) > tuning.ambush_reposition:
			_ambush_spot = spot
			_ambush_face = -out
			_ambush_waited = 0.0
		_ambush_for = p
		return true
	_ambush_for = null
	return false


## Another predator is already lying in wait there.
func _spot_taken(spot: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group(&"predators"):
		var other := node as Predator
		if other != null and other != self and other.state == State.AMBUSH and other._ambush_spot.distance_to(spot) < tuning.ambush_reposition:
			return true
	return false


## How tempting a penguin on the ice is to wait for: like temptation(), with closeness measured
## over the ambush scan range.
func _ambush_appeal(p: Penguin) -> float:
	var closeness := clampf(1.0 - global_position.distance_to(p.global_position) / tuning.ambush_scan_range, 0.0, 1.0)
	return tuning.size_weight * p.fatness() + tuning.noise_weight * p.noise + tuning.closeness_weight * closeness


## Someone it can grab from its hiding spot: in the water within ambush_strike_range, or right at
## the edge (or jumping in) within reach of its jaws.
func _ambush_victim() -> Penguin:
	var best: Penguin = null
	var best_score := -1.0
	var grab := tuning.jaw_reach + tuning.catch_radius
	for node in get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p == null or _ignored.has(p):
			continue
		var in_water := p.state == Penguin.State.SWIM or p.global_position.y < Penguin.WATER_LEVEL
		var reach := tuning.ambush_strike_range if in_water else grab
		if global_position.distance_to(p.global_position) > reach or not _can_see(p):
			continue
		var score := temptation(p)
		if score > best_score:
			best_score = score
			best = p
	return best


func _end_ambush() -> void:
	_ambush_for = null
	_next_waypoint()
	_set_state(State.PATROL)


# --- Hunting ----------------------------------------------------------------

## The most tempting penguin in sight (only those in the water, with `only_in_water`), or null.
func _best_target(only_in_water := false) -> Penguin:
	var best: Penguin = null
	var best_score := -1.0
	for node in get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p == null or _ignored.has(p) or not _huntable(p, tuning.detect_range):
			continue
		if only_in_water and not (p.state == Penguin.State.SWIM or p.global_position.y < Penguin.WATER_LEVEL):
			continue
		var score := temptation(p)
		if score > best_score:
			best_score = score
			best = p
	return best


## Can it go after `p` from here? In the water: within max_range. Out of the water (on the ice
## edge, or in the air): only up close. Never up on the plateau, and never through ice.
func _huntable(p: Penguin, max_range: float) -> bool:
	if p == null or not is_instance_valid(p) or not p.is_inside_tree():
		return false
	var at := p.global_position
	if at.y > Penguin.WATER_LEVEL + 1.6:
		return false
	var in_water := p.state == Penguin.State.SWIM or at.y < Penguin.WATER_LEVEL
	var reach := max_range if in_water else minf(max_range, tuning.edge_detect_range)
	if global_position.distance_to(at) > reach:
		return false
	return _can_see(p)


func _in_lunge_range(p: Penguin) -> bool:
	return global_position.distance_to(p.global_position) <= tuning.lunge_range


## A clear line of sight, with no ice in the way. Near the surface it peeks over the ice edge.
func _can_see(p: Penguin) -> bool:
	var at := p.global_position
	var eye := global_position + Vector3.UP * EYE_HEIGHT
	if at.y > Penguin.WATER_LEVEL and global_position.y > Penguin.WATER_LEVEL - PEEK_DEPTH:
		eye.y = Penguin.WATER_LEVEL + PEEK_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(eye, at, Penguin.WORLD_LAYER, [get_rid()])
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Any penguin in reach of the jaws, or null. A lunge catches whoever is in the way.
func _penguin_in_reach() -> Penguin:
	var jaws := global_position + _heading * tuning.jaw_reach
	for node in get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p != null and jaws.distance_to(p.global_position) <= tuning.catch_radius and _can_see(p):
			return p
	return null


## Busy with something else, but a penguin in the water right in front of it gets a lunge.
func _snap_at_close_penguin() -> void:
	if _lunge_cooldown > 0.0:
		return
	for node in get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p != null and not _ignored.has(p) and _huntable(p, tuning.detect_range) and _in_lunge_range(p):
			_lock_on(p)
			_start_warning()
			return


## Lines up a strike at the target: the lunge will go straight along this line, after a warning
## of `seconds` (lunge_warning unless given).
func _start_warning(seconds := -1.0) -> void:
	_lunge_dir = (target.global_position - global_position).normalized()
	_warning_time = seconds if seconds >= 0.0 else tuning.lunge_warning
	_set_state(State.WARN)


## How far a lunge carries (m).
func _lunge_reach() -> float:
	return tuning.lunge_speed * tuning.lunge_seconds


func _lock_on(p: Penguin) -> void:
	target = p
	_chase_time = 0.0
	_set_state(State.CHASE)
	locked_on.emit(p)


func _give_up() -> void:
	var lost := target
	if target != null:
		_ignored[target] = tuning.give_up_ignore_seconds
	target = null
	_set_state(State.PATROL)
	_next_waypoint()
	# It got out onto the ice? Wait for it to come back in.
	if lost != null and is_instance_valid(lost) and lost.state in [Penguin.State.WALK, Penguin.State.SLIDE]:
		_ignored.erase(lost)
		_start_ambush()


func _eat_penguin(p: Penguin) -> void:
	hunger = 0.0
	target = null
	_lunge_cooldown = tuning.lunge_cooldown
	caught_penguin.emit(p)
	p.get_caught(self)
	_next_waypoint()
	_set_state(State.SATED)


## The nearest fish in a school, within search range. False if there isn't one.
func _find_meal() -> bool:
	_meal = Fish.nearest_in_school(global_position, tuning.school_search_range)
	return _meal != null


func _tick_ignored(delta: float) -> void:
	for p: Variant in _ignored.keys():
		_ignored[p] -= delta
		if _ignored[p] <= 0.0 or not is_instance_valid(p):
			_ignored.erase(p)


# --- Movement ---------------------------------------------------------------

## Next patrol leg: on along the ice edge, or now and then past a nearby school.
func _next_waypoint() -> void:
	var depth := randf_range(tuning.patrol_depth.x, tuning.patrol_depth.y)
	if randf() < tuning.school_visit_chance:
		var fish := Fish.random_in_school_near(global_position, tuning.school_visit_range)
		if fish != null:
			_waypoint = fish.home
			_waypoint.y = minf(_waypoint.y, Penguin.WATER_LEVEL - MIN_DEPTH)
			return
	var out := global_position - patrol_centre
	var angle := atan2(out.z, out.x) + _patrol_dir * randf_range(0.5, 0.9)
	var radius := ice_radius + tuning.patrol_offset + randf_range(-1.0, 1.0)
	_waypoint = patrol_centre + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	_waypoint.y = Penguin.WATER_LEVEL - depth


## Steers toward `point` at up to `speed`. With slow_to_turn it slows down while the point is
## off to the side, which tightens its turns. It comes no closer to the surface than min_depth.
func _swim_toward(point: Vector3, speed: float, delta: float, slow_to_turn := false, min_depth := MIN_DEPTH) -> void:
	var to := point - global_position
	if _dive_time > 0.0:
		to.y = minf(to.y, 0.0) - 3.0 # ice in the way: go under it
	var want := to.normalized() if to.length() > 0.01 else _heading
	if slow_to_turn:
		speed *= clampf(_heading.dot(want), 0.25, 1.0)
	_heading = _turn_toward(_heading, want, deg_to_rad(tuning.turn_rate_deg) * delta)
	_speed = move_toward(_speed, speed, tuning.acceleration * delta)
	velocity = _heading * _speed
	_move(min_depth)
	# Bumped into ice on the way somewhere farther off? Dive under it. (Not while lining up a
	# strike: pressed against the ice edge is exactly where an edge ambush happens.)
	var flat := Vector2(to.x, to.z).length()
	if _hit_wall and state != State.WARN and flat > tuning.lunge_range + 1.0:
		_dive_time = DIVE_SECONDS


## move_and_slide, kept in the water (no shallower than min_depth below the surface).
func _move(min_depth: float) -> void:
	move_and_slide()
	_hit_wall = false
	for i in get_slide_collision_count():
		if absf(get_slide_collision(i).get_normal().y) < 0.5:
			_hit_wall = true
	var p := global_position
	var top := Penguin.WATER_LEVEL - min_depth
	if p.y > top or p.y < -MAX_DEPTH:
		p.y = clampf(p.y, -MAX_DEPTH, top)
		global_position = p
		_heading.y = minf(_heading.y, 0.0) if p.y >= top else maxf(_heading.y, 0.0)
		if _heading.length() < 0.01:
			_heading = Vector3.FORWARD
		_heading = _heading.normalized()


static func _turn_toward(from: Vector3, to: Vector3, max_angle: float) -> Vector3:
	var angle := from.angle_to(to)
	if angle <= max_angle:
		return to
	var axis := from.cross(to)
	if axis.length() < 0.0001:
		axis = Vector3.UP # dead behind: turn sideways
	return from.rotated(axis.normalized(), max_angle).normalized()


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	_state_time = 0.0
	_scan = 0.0
	state_changed.emit(state)


# --- Looks ------------------------------------------------------------------

func _update_model(delta: float) -> void:
	var dir := velocity if velocity.length() > 0.3 else _heading
	if absf(dir.normalized().y) > 0.98:
		return
	var want := Basis.looking_at(dir, Vector3.UP).get_rotation_quaternion()
	var current := _model.global_basis.get_rotation_quaternion()
	_model.global_basis = Basis(current.slerp(want, clampf(8.0 * delta, 0.0, 1.0)))


## The lock-on ring and the strike line, in the reserved danger colour (docs/ART_DIRECTION.md).
## Every predator gets the same ones, so the warnings read the same whoever is attacking.
func _make_markers() -> void:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.65
	ring_mesh.outer_radius = 0.8
	ring_mesh.material = DANGER_MATERIAL
	_ring = _make_marker(&"LockOnRing", ring_mesh)
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(0.08, 0.04, 1.0)
	line_mesh.material = DANGER_MATERIAL
	_line = _make_marker(&"StrikeLine", line_mesh)
	# The shadow on the water: dark, not the danger colour. Sized from the body.
	var body := get_node_or_null("CollisionShape3D") as CollisionShape3D
	var r := (body.shape as SphereShape3D).radius if body != null and body.shape is SphereShape3D else 0.6
	_shadow_material = StandardMaterial3D.new()
	_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_material.albedo_color = Color(0.02, 0.06, 0.1, 0.0)
	var blob := CylinderMesh.new()
	blob.top_radius = 1.0
	blob.bottom_radius = 1.0
	blob.height = 0.02
	blob.material = _shadow_material
	_shadow = MeshInstance3D.new()
	_shadow.name = &"Shadow"
	_shadow.mesh = blob
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	_shadow_size = Vector3(r * 1.6, 1.0, r * 3.5)
	_shadow.visible = false
	add_child(_shadow)


func _make_marker(marker_name: StringName, mesh: Mesh) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = marker_name
	marker.mesh = mesh
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.top_level = true
	marker.visible = false
	add_child(marker)
	return marker


## The lock-on ring around its target, the strike line during the warning, and its shadow on
## the water when it's near the surface.
func _update_markers() -> void:
	var depth := Penguin.WATER_LEVEL - global_position.y
	var dark := clampf((SHADOW_DEPTH - depth) / (SHADOW_DEPTH - SHADOW_FULL_DEPTH), 0.0, 1.0) * SHADOW_DARKNESS
	_shadow.visible = dark > 0.01
	if _shadow.visible:
		_shadow_material.albedo_color.a = dark
		var flat := Vector3(_heading.x, 0.0, _heading.z)
		var facing := Basis.looking_at(flat, Vector3.UP) if flat.length() > 0.05 else Basis.IDENTITY
		_shadow.global_transform = Transform3D(facing * Basis.from_scale(_shadow_size), Vector3(global_position.x, Penguin.WATER_LEVEL + 0.015, global_position.z))
	var locked := is_instance_valid(target) and is_hunting(target)
	_ring.visible = locked
	_line.visible = locked and state == State.WARN
	if not locked:
		return
	var at := target.global_position
	var warning := state == State.WARN
	var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * (0.025 if warning else 0.006))
	_ring.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * pulse * (1.3 if warning else 1.0)), at)
	if _line.visible and absf(_lunge_dir.y) < 0.98:
		# The strike line: exactly where the lunge will go.
		var reach := _lunge_reach()
		_line.global_transform = Transform3D(Basis.looking_at(_lunge_dir, Vector3.UP), global_position + _lunge_dir * reach * 0.5) \
			.scaled_local(Vector3(1.0, 1.0, reach))
