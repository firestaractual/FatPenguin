class_name Penguin
extends CharacterBody3D
## The player penguin (Prototype 0: movement toy).
##
## States
##   SWIM  - under or along the water surface. Always moving forward; stick steers yaw/pitch.
##   AIR   - thrown out of the water (breach/porpoise) or falling off the ice.
##   WALK  - slow, precise waddling on ice (called "walk" so it isn't confused with the waddle safe zone).
##   SLIDE - belly-slide (tobogganing): fast, slippery, hard to steer.
##
## Food is energy: energy pays for boosts, drains over time, and makes the penguin fat.
## Fat = more fuel, faster in a straight line, but slower to turn, slower to accelerate, lower launches.
## The body itself never rotates (sphere collider); only the Model node turns and stretches.

signal state_changed(new_state: State)
signal ate_fish(energy_gained: float)
signal boosted
signal boost_denied
signal splashed(at: Vector3, strength: float)

enum State { SWIM, AIR, WALK, SLIDE }

const WATER_LEVEL := 0.0
## Swimming along the top, the body centre sits this far below the surface.
const SURFACE_DEPTH := 0.25
## Shallower than this, the penguin can breathe.
const BREATH_DEPTH := 0.45
## On ice, sinking deeper than this means you're in the water now.
const WATER_ENTRY_DEPTH := 0.5
## While swimming, touching a walkable surface shallower than this climbs you out.
const WATER_EXIT_DEPTH := 0.4
## Grace time before walking off an edge counts as falling.
const COYOTE_TIME := 0.12

@export var tuning: PenguinTuning

var state: State = State.AIR
var energy := 50.0
var air := 25.0
var infinite_energy := false

var _yaw := 0.0
var _pitch := 0.0
var _speed := 0.0
var _boost_time := 0.0
var _boost_cooldown := 0.0
var _slide_push_cooldown := 0.0
var _off_floor_time := 0.0
var _spawn_position := Vector3.ZERO
var _spawn_yaw := 0.0
var _base_radius := 0.32

@onready var _model: Node3D = $Model
var _shape: SphereShape3D
@onready var _bubbles: CPUParticles3D = $Bubbles
@onready var _splash: CPUParticles3D = $Splash


func _ready() -> void:
	add_to_group(&"player")
	if tuning == null:
		tuning = PenguinTuning.new()
	# Each penguin gets its own collision shape so fat can resize it.
	var col: CollisionShape3D = $CollisionShape3D
	_shape = (col.shape as SphereShape3D).duplicate()
	col.shape = _shape
	_base_radius = _shape.radius

	_spawn_position = global_position
	_spawn_yaw = rotation.y
	_yaw = rotation.y
	rotation = Vector3.ZERO # only the model rotates
	energy = tuning.starting_energy
	air = tuning.air_seconds
	_splash.top_level = true
	_set_state(State.SWIM if global_position.y < WATER_LEVEL else State.AIR)


func _physics_process(delta: float) -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_down", &"move_up")
	_boost_cooldown = maxf(_boost_cooldown - delta, 0.0)
	_slide_push_cooldown = maxf(_slide_push_cooldown - delta, 0.0)

	match state:
		State.SWIM:
			_swim(delta, input)
		State.AIR:
			_air(delta, input)
		State.WALK:
			_walk(delta, input)
		State.SLIDE:
			_slide(delta, input)

	_update_air(delta)
	_update_energy(delta)
	_update_body(delta)
	_debug_input()


# --- Public API -------------------------------------------------------------

## 0.0 = starving, 1.0 = stuffed.
func fatness() -> float:
	return clampf(energy / tuning.max_energy, 0.0, 1.0)


func eat_fish() -> void:
	var before := energy
	energy = minf(energy + tuning.fish_value, tuning.max_energy)
	ate_fish.emit(energy - before)


func is_boosting() -> bool:
	return state == State.SWIM and _boost_time > 0.0


## Horizontal facing, for the camera.
func get_facing() -> Vector3:
	return Vector3(-sin(_yaw), 0.0, -cos(_yaw))


## Full 3D travel direction (includes pitch while swimming).
func get_heading() -> Vector3:
	match state:
		State.SWIM:
			return _heading_dir()
		State.AIR:
			return velocity.normalized() if velocity.length() > 0.5 else get_facing()
	return get_facing()


func get_speed() -> float:
	return velocity.length()


func reset() -> void:
	global_position = _spawn_position
	velocity = Vector3.ZERO
	_yaw = _spawn_yaw
	_pitch = 0.0
	_speed = 0.0
	_boost_time = 0.0
	energy = tuning.starting_energy
	air = tuning.air_seconds
	_set_state(State.AIR)
	reset_physics_interpolation()


# --- States -----------------------------------------------------------------

func _swim(delta: float, input: Vector2) -> void:
	var turn := deg_to_rad(tuning.swim_turn_rate_deg) * _turn_mult()
	_yaw -= input.x * turn * delta

	var pitch_input := -input.y if tuning.invert_pitch else input.y
	if air <= 0.0:
		pitch_input = 1.0 # out of breath: forced up to the surface
	_pitch += pitch_input * turn * delta
	if is_zero_approx(pitch_input):
		_pitch = move_toward(_pitch, 0.0, deg_to_rad(tuning.swim_pitch_return_deg) * delta)

	var depth := WATER_LEVEL - global_position.y
	var max_pitch := deg_to_rad(tuning.swim_max_pitch_deg)
	if depth <= SURFACE_DEPTH + 0.05 and _speed < tuning.porpoise_min_speed:
		# Cruising along the top: nose can only tilt up so far (aiming a launch).
		max_pitch = minf(max_pitch, deg_to_rad(tuning.surface_max_pitch_deg))
	_pitch = clampf(_pitch, -deg_to_rad(tuning.swim_max_pitch_deg), max_pitch)

	if Input.is_action_just_pressed(&"action"):
		_try_boost()

	var cruise := tuning.swim_cruise_speed * _fat(tuning.fat_cruise_speed_mult)
	if _boost_time > 0.0:
		_boost_time -= delta
	elif _speed > cruise:
		_speed = move_toward(_speed, cruise, tuning.swim_drag * delta)
	else:
		_speed = move_toward(_speed, cruise, tuning.swim_acceleration * _accel_mult() * delta)

	velocity = _heading_dir() * _speed

	if depth < SURFACE_DEPTH + 0.05 and velocity.y > 0.0:
		if _speed >= tuning.porpoise_min_speed:
			_breach()
			return
		velocity.y = 0.0
	if depth < SURFACE_DEPTH:
		# Pushed above the cruise line (e.g. by a ramp): settle back down.
		velocity.y = minf(velocity.y, -(SURFACE_DEPTH - depth) * 5.0)

	move_and_slide()

	# Touching a walkable surface near the top? Climb out onto the ice.
	if WATER_LEVEL - global_position.y < WATER_EXIT_DEPTH:
		for i in get_slide_collision_count():
			if get_slide_collision(i).get_normal().y > 0.7:
				velocity = get_facing() * minf(_speed, tuning.walk_speed)
				_set_state(State.WALK)
				return


func _air(delta: float, input: Vector2) -> void:
	velocity.y -= tuning.gravity * delta
	var turn := -input.x * deg_to_rad(tuning.air_turn_rate_deg) * delta
	if not is_zero_approx(turn):
		var h := Vector3(velocity.x, 0.0, velocity.z).rotated(Vector3.UP, turn)
		velocity.x = h.x
		velocity.z = h.z
	var horizontal := Vector2(velocity.x, velocity.z)
	if horizontal.length() > 0.5:
		_yaw = atan2(-velocity.x, -velocity.z)

	move_and_slide()

	# Only re-enter on the way down: a breach starts just below the surface while still rising.
	if global_position.y < WATER_LEVEL and velocity.y <= 0.0:
		_enter_water()
	elif is_on_floor():
		_land()


func _walk(delta: float, input: Vector2) -> void:
	var move := _camera_relative(input)
	if move.length() > 0.05:
		var target_yaw := atan2(-move.x, -move.z)
		_yaw = rotate_toward(_yaw, target_yaw, deg_to_rad(tuning.walk_turn_rate_deg) * _turn_mult() * delta)
	# Penguins walk where they face, so a fat (slow-turning) penguin really feels clumsy.
	var target_vel := get_facing() * tuning.walk_speed * minf(move.length(), 1.0)
	var h := Vector3(velocity.x, 0.0, velocity.z).move_toward(target_vel, tuning.walk_acceleration * _accel_mult() * delta)
	velocity.x = h.x
	velocity.z = h.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - tuning.gravity * delta

	if Input.is_action_just_pressed(&"action"):
		var speed := maxf(tuning.slide_start_speed, h.length())
		velocity = get_facing() * speed
		_set_state(State.SLIDE)
		return

	move_and_slide()
	_check_ground_transitions(delta)


func _slide(delta: float, input: Vector2) -> void:
	_yaw -= input.x * deg_to_rad(tuning.slide_turn_rate_deg) * _turn_mult() * delta
	var h := Vector3(velocity.x, 0.0, velocity.z)
	var speed := maxf(h.length() - tuning.slide_friction * delta, 0.0)
	var dir := h.normalized() if h.length() > 0.01 else get_facing()
	dir = dir.slerp(get_facing(), clampf(tuning.slide_grip * delta, 0.0, 1.0)).normalized()

	if Input.is_action_just_pressed(&"action") and _slide_push_cooldown <= 0.0:
		speed = minf(speed + tuning.slide_push_speed, maxf(tuning.slide_start_speed, speed))
		_slide_push_cooldown = tuning.slide_push_cooldown

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - tuning.gravity * delta
	move_and_slide()

	if _check_ground_transitions(delta):
		return
	if speed < tuning.slide_stop_speed:
		_set_state(State.WALK)


## Shared by WALK and SLIDE. Returns true if the state changed.
func _check_ground_transitions(delta: float) -> bool:
	if WATER_LEVEL - global_position.y > WATER_ENTRY_DEPTH:
		_enter_water()
		return true
	if is_on_floor():
		_off_floor_time = 0.0
	else:
		_off_floor_time += delta
		if _off_floor_time > COYOTE_TIME:
			_set_state(State.AIR)
			return true
	return false


# --- Transitions ------------------------------------------------------------

func _try_boost() -> void:
	if _boost_cooldown > 0.0 or air <= 0.0:
		return
	if not infinite_energy and energy < tuning.boost_energy_cost:
		boost_denied.emit()
		return
	if not infinite_energy:
		energy -= tuning.boost_energy_cost
	_speed = maxf(_speed, tuning.boost_peak_speed * _fat(tuning.fat_boost_speed_mult))
	_boost_time = tuning.boost_duration
	_boost_cooldown = tuning.boost_duration + tuning.boost_cooldown
	boosted.emit()


func _breach() -> void:
	velocity = _heading_dir() * _speed
	velocity.y *= sqrt(_fat(tuning.fat_launch_height_mult)) * tuning.breach_vertical_mult
	_boost_time = 0.0
	_emit_splash(_speed)
	_set_state(State.AIR)
	move_and_slide()


func _enter_water() -> void:
	var v := velocity
	_speed = v.length() * tuning.water_entry_speed_keep
	var horizontal := Vector2(v.x, v.z).length()
	if horizontal > 0.1:
		_yaw = atan2(-v.x, -v.z)
	var max_pitch := deg_to_rad(tuning.swim_max_pitch_deg)
	_pitch = clampf(atan2(v.y, horizontal), -max_pitch, max_pitch)
	_emit_splash(v.length())
	_set_state(State.SWIM)


func _land() -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	velocity.y = 0.0
	if horizontal.length() > tuning.slide_land_min_speed:
		_set_state(State.SLIDE) # belly-flop landing
	else:
		_set_state(State.WALK)


func _set_state(new_state: State) -> void:
	_off_floor_time = 0.0
	# Swimming is free-floating 3D movement; everything else is grounded.
	motion_mode = MOTION_MODE_FLOATING if new_state == State.SWIM else MOTION_MODE_GROUNDED
	if new_state == state:
		return
	state = new_state
	state_changed.emit(state)


# --- Per-frame upkeep -------------------------------------------------------

func _update_air(delta: float) -> void:
	var underwater := state == State.SWIM and WATER_LEVEL - global_position.y > BREATH_DEPTH
	if underwater:
		air = maxf(air - delta, 0.0)
	else:
		air = minf(air + tuning.air_seconds / tuning.air_refill_seconds * delta, tuning.air_seconds)


func _update_energy(delta: float) -> void:
	if infinite_energy or not tuning.energy_drain_enabled:
		return
	var rate := tuning.base_drain
	if energy > tuning.overfill_threshold:
		rate *= tuning.overfill_drain_mult
	energy = maxf(energy - rate * delta, 0.0)


func _update_body(delta: float) -> void:
	# Fat changes the collision size...
	var radius := _base_radius * _fat(tuning.fat_collision_radius_mult)
	if not is_equal_approx(_shape.radius, radius):
		_shape.radius = radius

	# ...and the model's orientation and girth.
	var target: Basis
	match state:
		State.WALK:
			target = Basis(Vector3.UP, _yaw)
		State.SLIDE:
			target = _belly_down_basis(get_facing())
		_:
			target = _belly_down_basis(get_heading())
	var current := _model.basis.get_rotation_quaternion()
	var rot := current.slerp(target.get_rotation_quaternion(), clampf(12.0 * delta, 0.0, 1.0))
	var width := _fat(tuning.fat_body_width_mult)
	_model.basis = Basis(rot) * Basis.from_scale(Vector3(width, 1.0, width))
	# Keep feet on the ice when the collider grows.
	var drop := -(radius - _base_radius) if state == State.WALK else 0.0
	_model.position.y = lerpf(_model.position.y, drop, clampf(10.0 * delta, 0.0, 1.0))

	_bubbles.emitting = state == State.SWIM and (_boost_time > 0.0 or _speed > tuning.porpoise_min_speed)


func _debug_input() -> void:
	if Input.is_action_just_pressed(&"debug_energy_up"):
		energy = minf(energy + 10.0, tuning.max_energy)
	if Input.is_action_just_pressed(&"debug_energy_down"):
		energy = maxf(energy - 10.0, 0.0)
	if Input.is_action_just_pressed(&"debug_toggle_drain"):
		infinite_energy = not infinite_energy
	if Input.is_action_just_pressed(&"reset"):
		reset()


# --- Helpers ----------------------------------------------------------------

func _fat(mult_at_full: float) -> float:
	return lerpf(1.0, mult_at_full, fatness())


func _turn_mult() -> float:
	return _fat(tuning.fat_turn_rate_mult)


func _accel_mult() -> float:
	return _fat(tuning.fat_acceleration_mult)


func _heading_dir() -> Vector3:
	return Vector3(-sin(_yaw) * cos(_pitch), sin(_pitch), -cos(_yaw) * cos(_pitch))


## Model is built standing: head = +Y, belly faces -Z. This lays it belly-down with the head along `dir`.
func _belly_down_basis(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var up := Vector3.UP
	if absf(y.dot(up)) > 0.98:
		up = get_facing()
	var z := (up - y * y.dot(up)).normalized()
	var x := y.cross(z)
	return Basis(x, y, z)


func _camera_relative(input: Vector2) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null or input.length() < 0.05:
		return Vector3.ZERO
	var forward := -cam.global_basis.z
	forward.y = 0.0
	var right := cam.global_basis.x
	right.y = 0.0
	var move := right.normalized() * input.x + forward.normalized() * input.y
	return move.limit_length(1.0)


func _emit_splash(strength: float) -> void:
	_splash.global_position = Vector3(global_position.x, WATER_LEVEL, global_position.z)
	_splash.amount = clampi(int(strength * 4.0), 8, 48)
	_splash.restart()
	splashed.emit(_splash.global_position, strength)
