class_name Penguin
extends CharacterBody3D
## A penguin (Prototype 0: movement toy). The player, or a dummy to bump into.
##
## States
##   SWIM  - under or along the water surface. Always moving forward; stick steers yaw/pitch.
##   AIR   - thrown out of the water (breach/porpoise), falling off the ice, or hopping up a ledge.
##   WALK  - on its feet: slow, precise, with grip. Walk into a low ledge to hop up it.
##           (Called "walk" so it isn't confused with the waddle safe zone.)
##   SLIDE - on its belly (tobogganing): fast and slippery. Slopes speed it up. It's also how you bump.
##           Pull the stick back to dig your feet in and brake.
##
## Food is energy: energy pays for boosts and flops, drains over time, and makes the penguin fat.
## Fat = more fuel, faster in a straight line, heavier in a bump, but slower to turn, slower to
## accelerate, lower launches and lower hops.
##
## Bumping (GDD §4.5): penguins are bumper cars. On its feet a penguin has grip, skids a short way
## when hit and teeters at the ice edge; on its belly it's a puck. Bumps never kill, they just move
## you toward whatever does. They also make noise, which draws predators (GDD §5.1).
##
## Predators (actors/predators) do the killing: a caught penguin is eaten and respawns on the ice.
##
## The body itself never rotates (sphere collider); only the Model node turns and stretches.

signal state_changed(new_state: State)
signal ate_fish(energy_gained: float)
signal boosted
signal boost_denied
signal splashed(at: Vector3, strength: float)
signal hopped(ledge_height: float, cleared: bool)
signal bumped(other: Penguin, closing_speed: float, hard: bool)
signal spilled_fish(at: Vector3)
signal teetered
signal scrambled
signal caught(by: Node3D)

enum State { SWIM, AIR, WALK, SLIDE }

const WATER_LEVEL := 0.0
## Swimming along the top, the body centre sits this far below the surface: shallow enough
## that the back and head stay above the water, the way a resting penguin floats.
const SURFACE_DEPTH := 0.1
## Shallower than this, the penguin can breathe.
const BREATH_DEPTH := 0.45
## On ice, sinking deeper than this means you're in the water now.
const WATER_ENTRY_DEPTH := 0.5
## While swimming, touching a walkable surface shallower than this climbs you out.
const WATER_EXIT_DEPTH := 0.4
## Grace time before walking off an edge counts as falling.
const COYOTE_TIME := 0.12

## Physics layers: the world (ice, seafloor) and penguins.
const WORLD_LAYER := 1
const PENGUIN_LAYER := 2
## A drop deeper than this below your feet counts as an edge you can teeter on.
const EDGE_DROP := 0.6
## Ledges are measured up to this high; anything taller is a wall.
const LEDGE_PROBE_HEIGHT := 1.6
## Hops clear the ledge by this much.
const HOP_CLEARANCE := 0.15
## Knockback on your feet stronger than this takes away control until it fades.
const SKID_CONTROL_LOSS := 0.6
## The same two penguins can't bump again this soon (stops one contact counting twice).
const PAIR_COOLDOWN := 0.25

const FISH_SCENE := preload("res://actors/fish/fish.tscn")

@export var tuning: PenguinTuning
## Off for dummies: they ignore input and just get knocked around.
@export var player_controlled := true
## Energy to start (and reset) with. Negative = tuning.starting_energy.
@export var start_energy := -1.0
## No drain and no costs (F2 toggles it for the player).
@export var infinite_energy := false
## Tints the body so dummies are easy to tell from the player. Alpha 0 = leave it alone.
@export var body_tint := Color(0, 0, 0, 0)

var state: State = State.AIR
var energy := 50.0
var air := 25.0
## How much attention this penguin has drawn lately, 0 to 1. Bumps make noise; it fades.
var noise := 0.0

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

var _move_input := Vector2.ZERO
var _action_pressed := false
## Walking velocity from the stick (horizontal). Knockback is kept separately in _knock.
var _walk_vel := Vector3.ZERO
## Knockback still to burn off: skidding on your feet, or drifting in the water.
var _knock := Vector3.ZERO
## Knocked while on the belly: tumbles with more friction and no steering until it stops.
var _tumbling := false
var _getup_time := 0.0
var _hopping := false
var _hop_dir := Vector3.ZERO
var _hop_cooldown := 0.0
var _immune_time := 0.0
var _spin_time := 0.0
var _spin_angle := 0.0
var _stun_time := 0.0
var _teeter_time := 0.0
var _teeter_dir := Vector3.ZERO
var _recent_bumps := {}
var _floor_normal := Vector3.UP

@onready var _model: Node3D = $Model
var _shape: SphereShape3D
@onready var _bubbles: CPUParticles3D = $Bubbles
@onready var _splash: CPUParticles3D = $Splash
@onready var _puff: CPUParticles3D = $Puff


func _ready() -> void:
	add_to_group(&"penguins")
	if player_controlled:
		add_to_group(&"player")
	if tuning == null:
		tuning = PenguinTuning.new()
	collision_layer = PENGUIN_LAYER
	collision_mask = WORLD_LAYER | PENGUIN_LAYER
	# Each penguin gets its own collision shape so fat can resize it.
	var col: CollisionShape3D = $CollisionShape3D
	_shape = (col.shape as SphereShape3D).duplicate()
	col.shape = _shape
	_base_radius = _shape.radius
	if body_tint.a > 0.0:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = body_tint
		($Model/Body as MeshInstance3D).material_override = mat

	_spawn_position = global_position
	_spawn_yaw = rotation.y
	_yaw = rotation.y
	rotation = Vector3.ZERO # only the model rotates
	energy = _starting_energy()
	air = tuning.air_seconds
	_splash.top_level = true
	_puff.top_level = true
	_set_state(State.SWIM if global_position.y < WATER_LEVEL else State.AIR)


func _physics_process(delta: float) -> void:
	_read_input()
	_tick_timers(delta)

	match state:
		State.SWIM:
			_swim(delta, _move_input)
		State.AIR:
			_air(delta, _move_input)
		State.WALK:
			_walk(delta, _move_input)
		State.SLIDE:
			_slide(delta, _move_input)

	_update_air(delta)
	_update_energy(delta)
	_update_body(delta)
	if player_controlled:
		_debug_input()


# --- Public API -------------------------------------------------------------

## 0.0 = starving, 1.0 = stuffed.
func fatness() -> float:
	return clampf(energy / tuning.max_energy, 0.0, 1.0)


## 1.0 thin, up to tuning.fat_mass_mult when stuffed.
func mass() -> float:
	return _fat(tuning.fat_mass_mult)


## How high this penguin can hop right now.
func hop_height() -> float:
	return tuning.hop_height * _fat(tuning.fat_hop_height_mult)


func eat_fish() -> void:
	var before := energy
	energy = minf(energy + tuning.fish_value, tuning.max_energy)
	ate_fish.emit(energy - before)


func is_boosting() -> bool:
	return state == State.SWIM and _boost_time > 0.0


func is_skidding() -> bool:
	return state == State.WALK and _knock.length() > SKID_CONTROL_LOSS


func is_tumbling() -> bool:
	return state == State.SLIDE and _tumbling


func is_teetering() -> bool:
	return _teeter_time > 0.0


func is_spun_out() -> bool:
	return _spin_time > 0.0


## Dazed by a tail slap (stun()): no boost, slow turns, slow swimming.
func is_stunned() -> bool:
	return _stun_time > 0.0


func is_immune() -> bool:
	return _immune_time > 0.0


## Sliding with the stick pulled back: feet dug in, slowing hard.
func is_braking() -> bool:
	return state == State.SLIDE and not _tumbling and _move_input.y < -0.5


## Horizontal facing, for the camera.
func get_facing() -> Vector3:
	return Vector3(-sin(_yaw), 0.0, -cos(_yaw))


## Full 3D travel direction (includes pitch while swimming).
func get_heading() -> Vector3:
	match state:
		State.SWIM:
			return _heading_dir()
		State.AIR:
			if _hopping:
				return get_facing()
			return velocity.normalized() if velocity.length() > 0.5 else get_facing()
	return get_facing()


func get_speed() -> float:
	return velocity.length()


## An outside shove (an orca's wave, GDD §5.3). It works like the knockback from a bump: on your
## feet grip halves it and you skid (and teeter if it takes you to the edge); on your belly you
## take all of it. It stacks with any knockback you already have.
func push(dv: Vector3) -> void:
	_take_knock(dv * _knock_share(), true)


## Stunned for `seconds` (an orca's tail slap): you can't boost, and you turn and swim slowly
## (stun_turn_mult, stun_speed_mult). A longer stun replaces a shorter one.
func stun(seconds: float) -> void:
	_stun_time = maxf(_stun_time, seconds)


## A current in the water (an orca pod's bubble wall): adds `dv` to your drift. Unlike push(),
## it isn't a bump, and it only works while you're swimming.
func drift(dv: Vector3) -> void:
	if state == State.SWIM:
		_knock += dv


## A predator got you. In the movement toy you're eaten: a puff of feathers, a splash, and you're
## back at your spawn point on the ice with starting energy, as if you'd pressed reset.
func get_caught(by: Node3D) -> void:
	_emit_puff(global_position, 8.0)
	_emit_splash(6.0)
	caught.emit(by)
	reset()


func reset() -> void:
	global_position = _spawn_position
	velocity = Vector3.ZERO
	_yaw = _spawn_yaw
	_pitch = 0.0
	_speed = 0.0
	_boost_time = 0.0
	_immune_time = 0.0
	_spin_time = 0.0
	_stun_time = 0.0
	_knock = Vector3.ZERO
	_recent_bumps.clear()
	noise = 0.0
	energy = _starting_energy()
	air = tuning.air_seconds
	_set_state(State.AIR)
	reset_physics_interpolation()


# --- States -----------------------------------------------------------------

func _swim(delta: float, input: Vector2) -> void:
	var turn := deg_to_rad(tuning.swim_turn_rate_deg) * _turn_mult()
	if _stun_time > 0.0:
		turn *= tuning.stun_turn_mult
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

	if _action_pressed:
		_try_boost()

	var cruise := tuning.swim_cruise_speed * _fat(tuning.fat_cruise_speed_mult)
	if _stun_time > 0.0:
		cruise *= tuning.stun_speed_mult
	if _boost_time > 0.0:
		_boost_time -= delta
	elif _speed > cruise:
		_speed = move_toward(_speed, cruise, tuning.swim_drag * delta)
	else:
		_speed = move_toward(_speed, cruise, tuning.swim_acceleration * _accel_mult() * delta)

	# Water soaks up knockback fast.
	_knock = _knock.move_toward(Vector3.ZERO, tuning.water_knock_drag * delta)
	velocity = _heading_dir() * _speed + _knock

	if depth < SURFACE_DEPTH + 0.05 and velocity.y > 0.0:
		if _speed >= tuning.porpoise_min_speed:
			_breach()
			return
		velocity.y = 0.0
	if depth < SURFACE_DEPTH:
		# Pushed above the cruise line (e.g. by a ramp): settle back down.
		velocity.y = minf(velocity.y, -(SURFACE_DEPTH - depth) * 5.0)

	_move()

	# Touching a walkable surface near the top? Climb out onto the ice.
	if WATER_LEVEL - global_position.y < WATER_EXIT_DEPTH:
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			if c.get_collider() is Penguin:
				continue
			if c.get_normal().y > 0.7:
				velocity = get_facing() * minf(_speed, tuning.walk_speed)
				_set_state(State.WALK)
				return


func _air(delta: float, input: Vector2) -> void:
	velocity.y -= tuning.gravity * delta
	if _hopping:
		# Keep pressing forward so we land on the ledge once we're above it.
		velocity.x = _hop_dir.x * tuning.hop_forward_speed
		velocity.z = _hop_dir.z * tuning.hop_forward_speed
	var turn := -input.x * deg_to_rad(tuning.air_turn_rate_deg) * delta
	if not is_zero_approx(turn) and not _hopping:
		var h := Vector3(velocity.x, 0.0, velocity.z).rotated(Vector3.UP, turn)
		velocity.x = h.x
		velocity.z = h.z
	var horizontal := Vector2(velocity.x, velocity.z)
	if horizontal.length() > 0.5 and not _hopping:
		_yaw = atan2(-velocity.x, -velocity.z)

	_move()

	# Only re-enter on the way down: a breach starts just below the surface while still rising.
	if global_position.y < WATER_LEVEL and velocity.y <= 0.0:
		_enter_water()
	elif is_on_floor():
		_land()


func _walk(delta: float, input: Vector2) -> void:
	if _teeter_time > 0.0:
		_teeter(delta, input)
		return

	var skidding := _knock.length() > SKID_CONTROL_LOSS
	var target_vel := Vector3.ZERO
	if not skidding:
		var move := _camera_relative(input)
		if move.length() > 0.05:
			var target_yaw := atan2(-move.x, -move.z)
			_yaw = rotate_toward(_yaw, target_yaw, deg_to_rad(tuning.walk_turn_rate_deg) * _turn_mult() * delta)
		# Penguins walk where they face, so a fat (slow-turning) penguin really feels clumsy.
		target_vel = get_facing() * tuning.walk_speed * minf(move.length(), 1.0)
	_walk_vel = _walk_vel.move_toward(target_vel, tuning.walk_acceleration * _accel_mult() * delta)
	# Knocked while on your feet: grip skids you to a stop.
	_knock = _knock.move_toward(Vector3.ZERO, tuning.foot_skid_friction * delta)

	var h := _walk_vel + _knock
	if skidding and is_on_floor() and _edge_ahead(_knock):
		_start_teeter(_knock)
		return

	velocity.x = h.x
	velocity.z = h.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - tuning.gravity * delta

	if _action_pressed and not skidding and _try_flop(h):
		return

	_move()
	if _check_ground_transitions(delta):
		return
	# Too steep to stand on: slip onto your belly.
	if is_on_floor() and rad_to_deg(get_floor_angle()) > tuning.walk_max_slope_deg:
		_set_state(State.SLIDE)
		return
	if not skidding:
		_try_hop()


func _slide(delta: float, input: Vector2) -> void:
	if not _tumbling:
		_yaw -= input.x * deg_to_rad(tuning.slide_turn_rate_deg) * _turn_mult() * delta
	var on_floor := is_on_floor()
	if on_floor:
		_floor_normal = get_floor_normal()
	# Contact flickers for a frame now and then on flat ice; treat a brief gap as still sliding.
	var grounded := on_floor or _off_floor_time < COYOTE_TIME
	var n := _floor_normal if on_floor else Vector3.UP
	var v := velocity

	if on_floor and n.y > 0.05:
		# move_and_slide keeps only the horizontal part of a downhill velocity, so rebuild the
		# part along the slope from it (same horizontal motion, lying flat on the surface).
		v.y = -(v.x * n.x + v.z * n.z) / n.y
		# Gravity pulls a slide down slopes, and slows it going up them.
		var g := Vector3.DOWN * tuning.gravity * tuning.slide_slope_gravity_mult
		v += (g - n * g.dot(n)) * delta
	elif not on_floor:
		v.y -= tuning.gravity * delta

	if grounded:
		# Work on the motion along the surface (just the horizontal part if we're between contacts).
		var along := v if on_floor else Vector3(v.x, 0.0, v.z)
		var friction := tuning.tumble_friction if _tumbling else tuning.slide_friction
		if is_braking():
			friction += tuning.slide_brake_decel
		var speed := maxf(along.length() - friction * delta, 0.0)
		var face := get_facing() - n * get_facing().dot(n)
		face = face.normalized() if face.length() > 0.01 else get_facing()
		var dir := along.normalized() if along.length() > 0.01 else face
		if not _tumbling:
			# The belly grips along the body's line, forwards or backwards.
			var line := face if dir.dot(face) >= 0.0 else -face
			var steered := dir.lerp(line, clampf(tuning.slide_grip * delta, 0.0, 1.0))
			if steered.length() > 0.01:
				dir = steered.normalized()
			if _action_pressed and _slide_push_cooldown <= 0.0:
				speed = minf(speed + tuning.slide_push_speed, maxf(tuning.slide_start_speed, speed))
				_slide_push_cooldown = tuning.slide_push_cooldown
				if speed > 0.0 and dir.dot(face) < 0.0:
					dir = face # a flipper push always goes the way you face
		along = dir * minf(speed, tuning.slide_max_speed)
		if on_floor:
			# A little press into the ice keeps contact steady (move_and_slide drops it again).
			v = along + Vector3.DOWN * 0.5
		else:
			v = Vector3(along.x, v.y, along.z)

	velocity = v
	_move()

	if _check_ground_transitions(delta):
		return
	var steep := is_on_floor() and rad_to_deg(get_floor_angle()) > tuning.walk_max_slope_deg
	if velocity.length() < tuning.slide_stop_speed and not steep and is_on_floor():
		# Stopped, but still a puck until it's back on its feet.
		_getup_time += delta
		if _getup_time >= tuning.slide_getup_seconds * _fat(tuning.fat_getup_mult):
			_set_state(State.WALK)
	else:
		_getup_time = 0.0


## Knocked to the ice edge on its feet: wobble, then fall in unless the player pulls back.
func _teeter(delta: float, input: Vector2) -> void:
	_teeter_time -= delta
	var back := _camera_relative(input)
	var can_pay := infinite_energy or energy >= tuning.scramble_energy_cost
	if back.dot(-_teeter_dir) > 0.5 and can_pay:
		if not infinite_energy:
			energy -= tuning.scramble_energy_cost
		_teeter_time = 0.0
		_yaw = atan2(_teeter_dir.x, _teeter_dir.z) # turn away from the edge
		_knock = Vector3.ZERO
		_walk_vel = -_teeter_dir * tuning.walk_speed
		scrambled.emit()
		return
	velocity = Vector3(0.0, 0.0 if is_on_floor() else velocity.y - tuning.gravity * delta, 0.0)
	move_and_slide()
	if _teeter_time <= 0.0:
		# Over you go.
		_teeter_time = 0.0
		velocity = _teeter_dir * 3.0 + Vector3.UP * 1.2
		_set_state(State.AIR)


# --- Transitions ------------------------------------------------------------

func _try_boost() -> void:
	if _boost_cooldown > 0.0 or air <= 0.0:
		return
	if _stun_time > 0.0:
		boost_denied.emit()
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


## Dive onto your belly. Costs a little energy; returns false if you can't afford it.
func _try_flop(h: Vector3) -> bool:
	if not infinite_energy and energy < tuning.slide_energy_cost:
		boost_denied.emit()
		return false
	if not infinite_energy:
		energy -= tuning.slide_energy_cost
	var speed := maxf(tuning.slide_start_speed, h.length())
	velocity = get_facing() * speed
	_set_state(State.SLIDE)
	return true


## Pressing into a ledge low enough to hop? Up you go (or you try, and fall short if you're too fat).
func _try_hop() -> void:
	if _hop_cooldown > 0.0 or _move_input.length() < 0.3:
		return
	var wall := Vector3.ZERO
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_collider() is Penguin:
			continue
		if c.get_normal().y < 0.3:
			wall = c.get_normal()
			break
	if wall == Vector3.ZERO:
		return
	var into := Vector3(-wall.x, 0.0, -wall.z)
	if into.length() < 0.1:
		return
	into = into.normalized()
	if get_facing().dot(into) < 0.6:
		return

	var feet := global_position.y - _shape.radius
	var probe := global_position + into * (_shape.radius + 0.25)
	var hit := _ray(Vector3(probe.x, feet + LEDGE_PROBE_HEIGHT, probe.z), Vector3(probe.x, feet, probe.z))
	if hit.is_empty():
		return # a wall too tall to measure: no point trying
	var ledge: float = hit.position.y - feet
	if ledge < 0.1:
		return
	var reach := hop_height()
	var cleared := ledge + 0.05 <= reach
	var rise := minf(ledge + HOP_CLEARANCE, reach)
	velocity = into * tuning.hop_forward_speed + Vector3.UP * sqrt(2.0 * tuning.gravity * rise)
	_hopping = true
	_hop_dir = into
	_set_state(State.AIR)
	hopped.emit(ledge, cleared)


func _start_teeter(toward: Vector3) -> void:
	_teeter_dir = Vector3(toward.x, 0.0, toward.z).normalized()
	_teeter_time = tuning.teeter_seconds
	_knock = Vector3.ZERO
	_walk_vel = Vector3.ZERO
	velocity = Vector3.ZERO
	teetered.emit()


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
	if _hopping:
		_hop_cooldown = tuning.hop_cooldown
	if horizontal.length() > tuning.slide_land_min_speed:
		_set_state(State.SLIDE) # belly-flop landing
	else:
		_set_state(State.WALK)


func _set_state(new_state: State) -> void:
	_off_floor_time = 0.0
	# Swimming is free-floating 3D movement; everything else is grounded.
	motion_mode = MOTION_MODE_FLOATING if new_state == State.SWIM else MOTION_MODE_GROUNDED
	# A slide should run down slopes and hug their crests; feet should stay put.
	floor_stop_on_slope = new_state != State.SLIDE
	floor_snap_length = 0.3 if new_state == State.SLIDE else 0.1
	if new_state == state:
		return
	if new_state == State.WALK:
		_walk_vel = Vector3(velocity.x, 0.0, velocity.z)
	_knock = Vector3.ZERO
	_tumbling = false
	_getup_time = 0.0
	_teeter_time = 0.0
	if new_state != State.AIR:
		_hopping = false
	state = new_state
	state_changed.emit(state)


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


# --- Bumping ----------------------------------------------------------------

## move_and_slide, then turn any penguin we ran into into a bump.
func _move() -> void:
	var before := velocity
	move_and_slide()
	for i in get_slide_collision_count():
		var other := get_slide_collision(i).get_collider() as Penguin
		if other != null and other != self:
			_bump(other, before)


## Bumper-car collision between this penguin (the one that moved) and `other`.
## Momentum decides: knockback = (1 + bounciness) × closing speed shared by mass,
## then scaled by grip (feet), water drag, immunity and the knockback cap.
func _bump(other: Penguin, my_velocity: Vector3) -> void:
	if _recent_bumps.has(other) or other._recent_bumps.has(self):
		return
	var n := other.global_position - global_position
	n.y = 0.0
	if n.length() < 0.01:
		return
	n = n.normalized()
	var mine := Vector3(my_velocity.x, 0.0, my_velocity.z)
	var theirs := Vector3(other.velocity.x, 0.0, other.velocity.z)
	var closing := (mine - theirs).dot(n)
	if closing <= 0.0:
		return

	var t := tuning
	var is_bump := closing >= t.bump_min_speed
	var hard := closing >= t.hard_bump_speed
	# Below bump speed it's just a shove: no bounce, velocities even out.
	var bounce := t.bump_bounciness if is_bump else 0.0
	var m1 := mass()
	var m2 := other.mass()
	var impulse := (1.0 + bounce) * closing / (1.0 / m1 + 1.0 / m2)
	if is_bump and is_immune():
		impulse *= t.chain_transfer # already knocked: passes on part of the hit

	var dv_me := -n * (impulse / m1) * _knock_share()
	var dv_them := n * (impulse / m2) * other._knock_share()
	if is_bump:
		if is_immune():
			dv_me = Vector3.ZERO
		if other.is_immune():
			dv_them = Vector3.ZERO
	dv_me = dv_me.limit_length(t.max_knockback_speed)
	dv_them = dv_them.limit_length(t.max_knockback_speed)

	# Undo move_and_slide's flattening of our own velocity, then apply the hit to both.
	if state == State.SLIDE or state == State.AIR:
		velocity = Vector3(my_velocity.x, velocity.y, my_velocity.z)
	_take_knock(dv_me, is_bump)
	other._take_knock(dv_them, is_bump)
	if not is_bump:
		return

	_recent_bumps[other] = PAIR_COOLDOWN
	other._recent_bumps[self] = PAIR_COOLDOWN
	_emit_puff(global_position + n * _shape.radius, closing)
	_after_bump(other, n, closing, hard, dv_me)
	other._after_bump(self, -n, closing, hard, dv_them)


func _take_knock(dv: Vector3, is_bump: bool) -> void:
	if dv == Vector3.ZERO:
		return
	match state:
		State.WALK:
			if _teeter_time > 0.0:
				if is_bump:
					_teeter_time = 0.0001 # bumped while teetering: straight in
				return # a gentle shove doesn't decide it either way
			_knock += dv
		State.SWIM:
			_knock += dv
		State.SLIDE:
			velocity += dv
			if is_bump and dv.length() > 0.5:
				_tumbling = true
				_getup_time = 0.0
		State.AIR:
			velocity += dv


## Spin-outs, fish spills, immunity and effects. `toward` points at the other penguin.
func _after_bump(other: Penguin, toward: Vector3, closing: float, hard: bool, dv: Vector3) -> void:
	var was_immune := is_immune()
	noise = minf(noise + (tuning.bump_noise_hard if hard else tuning.bump_noise_soft), 1.0)
	if hard and not was_immune:
		# Hit from the side (or hitting sideways): spin out.
		if absf(get_facing().dot(toward)) < 0.6:
			_spin_time = tuning.spin_out_seconds
		# Overfed: a fish comes back up.
		if energy > tuning.overfill_threshold:
			_spill_fish(toward)
	if dv.length() > 0.5 or not was_immune:
		_immune_time = tuning.knock_immunity_seconds
	bumped.emit(other, closing, hard)


## A fish pops out to one side of the hit. Anyone can grab it, except the penguin that lost it
## (for a moment), so it can't just skid back over it.
func _spill_fish(toward_hit: Vector3) -> void:
	energy = maxf(energy - tuning.fish_value, 0.0)
	var fish := FISH_SCENE.instantiate()
	fish.set(&"circle_radius", 0.0)
	fish.set(&"one_shot", true)
	fish.set(&"pickup_delay", 0.3)
	fish.set(&"ignore_body", self)
	fish.set(&"ignore_seconds", 2.0)
	var side := toward_hit.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
	var spot := global_position + side * (_shape.radius + 1.0)
	spot.y = global_position.y - _shape.radius + 0.25
	fish.position = spot
	get_parent().add_child.call_deferred(fish)
	spilled_fish.emit(spot)


func _knock_share() -> float:
	match state:
		State.WALK:
			return tuning.feet_grip_mult
		State.SWIM:
			return tuning.water_knockback_mult
	return 1.0


## Ice ahead of us in this direction, or a drop?
func _edge_ahead(dir: Vector3) -> bool:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.1:
		return false
	var probe := global_position + flat.normalized() * (_shape.radius + 0.2)
	var feet := global_position.y - _shape.radius
	return _ray(Vector3(probe.x, feet + 0.3, probe.z), Vector3(probe.x, feet - EDGE_DROP, probe.z)).is_empty()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)


# --- Per-frame upkeep -------------------------------------------------------

func _read_input() -> void:
	if player_controlled:
		_move_input = Input.get_vector(&"move_left", &"move_right", &"move_down", &"move_up")
		_action_pressed = Input.is_action_just_pressed(&"action")
	else:
		_move_input = Vector2.ZERO
		_action_pressed = false
	if _spin_time > 0.0:
		# Spun out: no steering, no dodging.
		_move_input = Vector2.ZERO
		_action_pressed = false


func _tick_timers(delta: float) -> void:
	_boost_cooldown = maxf(_boost_cooldown - delta, 0.0)
	_slide_push_cooldown = maxf(_slide_push_cooldown - delta, 0.0)
	_hop_cooldown = maxf(_hop_cooldown - delta, 0.0)
	_immune_time = maxf(_immune_time - delta, 0.0)
	_spin_time = maxf(_spin_time - delta, 0.0)
	_stun_time = maxf(_stun_time - delta, 0.0)
	noise = maxf(noise - delta / tuning.noise_fade_seconds, 0.0)
	for other: Variant in _recent_bumps.keys():
		if not is_instance_valid(other):
			_recent_bumps.erase(other)
			continue
		_recent_bumps[other] -= delta
		if _recent_bumps[other] <= 0.0:
			_recent_bumps.erase(other)


func _update_air(delta: float) -> void:
	var underwater := state == State.SWIM and WATER_LEVEL - global_position.y > BREATH_DEPTH
	if underwater:
		air = maxf(air - delta, 0.0)
	else:
		air = minf(air + tuning.air_seconds / tuning.air_refill_seconds * delta, tuning.air_seconds)


func _update_energy(delta: float) -> void:
	if infinite_energy or not tuning.energy_drain_enabled:
		return
	if energy < tuning.energy_floor:
		# Spent below the floor: get your breath back, up to the floor.
		energy = minf(energy + tuning.floor_recovery * delta, tuning.energy_floor)
		return
	var rate := tuning.base_drain
	if energy > tuning.overfill_threshold:
		rate *= tuning.overfill_drain_mult
	# The cold never takes you below the floor (a stand-in until there's a real exhausted state).
	energy = maxf(energy - rate * delta, tuning.energy_floor)


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
			if _teeter_time > 0.0:
				# Windmilling at the edge, leaning out over the water.
				var lean := 0.35 + 0.25 * sin(Time.get_ticks_msec() * 0.02)
				target = Basis(Vector3.UP.cross(_teeter_dir).normalized(), lean) * target
		State.SLIDE:
			var up := get_floor_normal() if is_on_floor() else Vector3.UP
			var along := get_facing() - up * get_facing().dot(up)
			target = _belly_down_basis(along if along.length() > 0.01 else get_facing(), up)
		State.AIR:
			target = Basis(Vector3.UP, _yaw) if _hopping else _belly_down_basis(get_heading())
		_:
			target = _belly_down_basis(get_heading())
	if _spin_time > 0.0:
		_spin_angle += 18.0 * delta
		target = Basis(Vector3.UP, _spin_angle) * target
	else:
		_spin_angle = 0.0
	if _stun_time > 0.0:
		# Dazed: a slow, woozy roll from side to side.
		var roll := 0.5 * sin(Time.get_ticks_msec() * 0.012)
		target = target * Basis(Vector3.UP, roll)
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

func _starting_energy() -> float:
	return start_energy if start_energy >= 0.0 else tuning.starting_energy


func _fat(mult_at_full: float) -> float:
	return lerpf(1.0, mult_at_full, fatness())


func _turn_mult() -> float:
	return _fat(tuning.fat_turn_rate_mult)


func _accel_mult() -> float:
	return _fat(tuning.fat_acceleration_mult)


func _heading_dir() -> Vector3:
	return Vector3(-sin(_yaw) * cos(_pitch), sin(_pitch), -cos(_yaw) * cos(_pitch))


## Model is built standing: head = +Y, belly faces -Z. This lays it belly-down with the head along `dir`.
func _belly_down_basis(dir: Vector3, up: Vector3 = Vector3.UP) -> Basis:
	var y := dir.normalized()
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


func _emit_puff(at: Vector3, strength: float) -> void:
	_puff.global_position = at
	_puff.amount = clampi(int(strength * 4.0), 6, 32)
	_puff.restart()
