class_name Predator
extends CharacterBody3D
## A leopard seal (Prototype 1). Patrols the water around the berg and past the schools, hunts
## the most tempting penguin it can see, and lunges only after a clear warning (GDD §5).
##
## States
##   PATROL  - swims a loop around the ice edge, swinging past schools now and then.
##   CHASE   - locked on to the most tempting penguin in sight. A ring marks the target.
##   WARN    - in lunge range: it lines up its strike. The ring flashes and a line marks exactly
##             where the lunge will go, for lunge_warning s. Get off the line (turn or boost).
##   LUNGE   - a fast, straight dash along that line. Catches any penguin within catch_radius
##             of its jaws.
##   RECOVER - out of breath after a lunge: slower, and no lunging until the cooldown ends.
##   FEED    - starving: off to the nearest school to eat fish until it's fed. It still lunges
##             at a penguin that comes within lunge range.
##   SATED   - just ate a penguin: slow and harmless for a while (GDD §5.2).
##
## Hunting: it only notices penguins in the water within detect_range, and penguins out of the
## water (on the ice edge, or in the air) within edge_detect_range, and only with a clear line of
## sight (no hunting through ice). It picks the most tempting by size, noise and closeness
## (GDD §5.1), and only switches when another is clearly more tempting.
##
## Like a penguin, the body is a sphere that never rotates; only the Model node turns.
## It collides with the world (ice, seafloor) and dives under ice that's in its way.

signal state_changed(new_state: State)
signal locked_on(target: Penguin)
signal lunged(toward: Vector3)
signal caught_penguin(penguin: Penguin)
signal ate_fish

enum State { PATROL, CHASE, WARN, LUNGE, RECOVER, FEED, SATED }

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
## The jaws are this far ahead of the body centre (m). Catches are measured from them, so a
## lunge at the ice edge reaches a little way onto the ice.
const JAW_REACH := 1.0

@export var tuning: PredatorTuning
## The patrol loop runs around this point, patrol_offset outside ice_radius. The level sets both.
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

@onready var _model: Node3D = $Model
@onready var _ring: MeshInstance3D = $LockOnRing
@onready var _line: MeshInstance3D = $LungeLine


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
	_ring.top_level = true
	_line.top_level = true
	_ring.visible = false
	_line.visible = false
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


# --- States -----------------------------------------------------------------

func _patrol(delta: float) -> void:
	_swim_toward(_waypoint, tuning.patrol_speed, delta)
	if global_position.distance_to(_waypoint) < WAYPOINT_REACHED or _state_time > 25.0:
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
	# Coiled along the strike line: it stops re-aiming, and it shadows the target instead of
	# closing in, so the warning is a fair chance to get off the line.
	var speed := tuning.chase_speed
	if global_position.distance_to(target.global_position) < tuning.warn_hold_distance:
		speed = minf(speed, target.get_speed())
	_swim_toward(global_position + _lunge_dir * 10.0, speed, delta)
	if _state_time >= tuning.lunge_warning:
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
	if _lunge_cooldown <= 0.0:
		for node in get_tree().get_nodes_in_group(&"penguins"):
			var p := node as Penguin
			if p != null and not _ignored.has(p) and _huntable(p, tuning.detect_range) and _in_lunge_range(p):
				_lock_on(p)
				_start_warning()
				return


func _sated(delta: float) -> void:
	_swim_toward(_waypoint, tuning.sated_speed, delta)
	if global_position.distance_to(_waypoint) < WAYPOINT_REACHED:
		_next_waypoint()
	if _state_time >= tuning.sated_seconds:
		_set_state(State.PATROL)


# --- Hunting ----------------------------------------------------------------

## The most tempting penguin in sight, or null.
func _best_target() -> Penguin:
	var best: Penguin = null
	var best_score := -1.0
	for node in get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p == null or _ignored.has(p) or not _huntable(p, tuning.detect_range):
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
	var jaws := global_position + _heading * JAW_REACH
	for node in get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p != null and jaws.distance_to(p.global_position) <= tuning.catch_radius and _can_see(p):
			return p
	return null


## Lines up a strike at the target: the lunge will go straight along this line.
func _start_warning() -> void:
	_lunge_dir = (target.global_position - global_position).normalized()
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
	if target != null:
		_ignored[target] = tuning.give_up_ignore_seconds
	target = null
	_set_state(State.PATROL)
	_next_waypoint()


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
## off to the side, which tightens its turns.
func _swim_toward(point: Vector3, speed: float, delta: float, slow_to_turn := false) -> void:
	var to := point - global_position
	if _dive_time > 0.0:
		to.y = minf(to.y, 0.0) - 3.0 # ice in the way: go under it
	var want := to.normalized() if to.length() > 0.01 else _heading
	if slow_to_turn:
		speed *= clampf(_heading.dot(want), 0.25, 1.0)
	_heading = _turn_toward(_heading, want, deg_to_rad(tuning.turn_rate_deg) * delta)
	_speed = move_toward(_speed, speed, tuning.acceleration * delta)
	velocity = _heading * _speed
	_move(MIN_DEPTH)
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


## The lock-on ring around its target, and the lunge line during the warning.
## Both use the reserved danger colour (docs/ART_DIRECTION.md).
func _update_markers() -> void:
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
