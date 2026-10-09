class_name Penguin
extends CharacterBody3D
## A penguin: the player, a computer penguin (with a PenguinBrain child), or a dummy to bump into.
## This script is the body and its movement rules. Its parts:
##   input  - where its stick and button come from (PenguinInput): a player's controls
##            (PlayerInput, one per player in local coop), a brain (BrainInput, via wish_dir), or
##            nobody (a dummy). Every penguin moves by the same rules whoever is steering.
##   vitals - energy and air, and the rules for both (PenguinVitals). energy, air, drain_mult and
##            infinite_energy on this node are the same numbers.
##   Model  - how it looks (PenguinLook, the script on the Model node): reads the body, never
##            moves it.
## What a catch does is up to the level's GameMode.
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
## Predators (actors/predators) do the killing: get_caught(), then the level's GameMode decides
## (in the movement toy you're eaten and respawn on the ice).
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
## Dazed for `seconds` (a whale's body bumped it: disorient()).
signal dazed(seconds: float)
## Ate a sick fish: queasy for `seconds` (no boost, no belly-slide, slow and wobbly).
signal sickened(seconds: float)
## Threw a sick fish back up, from its beak at `at`.
signal threw_up(at: Vector3)
## Feathers flew (a bump, at the contact point, or a catch). For the look: PenguinLook puffs.
signal feathers_flew(at: Vector3, strength: float)
## Its body_tint changed (it joined a family, say).
signal tinted(colour: Color)

enum State { SWIM, AIR, WALK, SLIDE }

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

## A drop deeper than this below your feet counts as an edge you can teeter on.
const EDGE_DROP := 0.6
## Walking up to an edge, it looks this far across for more ice (m). Ice that close is a gap: you
## hop it if you can, or stop at the edge if you can't. Farther than that it's open water, and
## you walk off into it as usual.
const GAP_SENSE := 3.0
## ...and this far to either side of straight ahead (degrees).
const GAP_SIDE_DEG := 25.0
## Ledges are measured up to this high; anything taller is a wall.
const LEDGE_PROBE_HEIGHT := 1.6
## Hops clear the ledge by this much.
const HOP_CLEARANCE := 0.15
## Knockback on your feet stronger than this takes away control until it fades.
const SKID_CONTROL_LOSS := 0.6
## The same two penguins can't bump again this soon (stops one contact counting twice).
const PAIR_COOLDOWN := 0.25
## turning(): how quickly it reads a change of turn (per second), and the fastest it reports (rad/s).
const TURNING_SMOOTHING := 8.0
const MAX_TURNING := 4.0

const FISH_SCENE := preload("res://actors/fish/fish.tscn")

@export var tuning: PenguinTuning
## Off for dummies: they ignore input and just get knocked around.
@export var player_controlled := true
## Which player steers it (1 to 4; see PlayerInput). Only used when player_controlled.
@export_range(1, 4) var player_number := 1
## Energy to start (and reset) with. Negative = tuning.starting_energy.
@export var start_energy := -1.0
## No drain and no costs (F2 toggles it for the player).
@export var infinite_energy := false:
	get:
		return vitals.infinite
	set(value):
		vitals.infinite = value
## Tints the body so dummies (and families) are easy to tell from the player. Alpha 0 = leave it
## alone. Changing it later retints it (the tinted signal).
@export var body_tint := Color(0, 0, 0, 0):
	set(value):
		body_tint = value
		tinted.emit(value)

var state: State = State.AIR
## Energy and air, and their rules. The properties below are shortcuts to its numbers.
var vitals := PenguinVitals.new()
var energy: float:
	get:
		return vitals.energy
	set(value):
		vitals.energy = value
## Seconds of breath left.
var air: float:
	get:
		return vitals.air
	set(value):
		vitals.air = value
## Energy drains this many times as fast as normal (1). A computer penguin sheltered in a huddle
## drains slower (GDD §4.6, PenguinBrain).
var drain_mult: float:
	get:
		return vitals.drain_mult
	set(value):
		vitals.drain_mult = value
## How much attention this penguin has drawn lately, 0 to 1. Bumps make noise; it fades.
var noise := 0.0
## Where its stick and button come from. Set when it's ready (a PlayerInput or nobody) unless
## something set it first; a PenguinBrain sets a BrainInput.
var input: PenguinInput = null
## The camera following it: on the ice a player steers relative to it. FollowCamera sets it.
var camera: Camera3D = null

## Steering from a PenguinBrain (computer penguins), read by its BrainInput: where it wants to go
## (world space; on the ice only the flat part counts), whether it presses action this frame
## (cleared after each frame), and whether it pulls back to brake a slide.
var wish_dir := Vector3.ZERO
var wish_action := false
var wish_brake := false
## On: it's steered by wish_dir (a BrainInput). Off again: back to its own controls.
var brain_controlled: bool:
	get:
		return input is BrainInput
	set(value):
		input = BrainInput.new() if value else _own_input()

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
var _hop_speed := 1.6
var _hop_cooldown := 0.0
var _immune_time := 0.0
var _spin_time := 0.0
var _stun_time := 0.0
## Dazed: how long the heading keeps wandering, and where in its wander it is.
var _daze_time := 0.0
var _daze_clock := 0.0
## Queasy (a sick fish): how long it lasts, how long it lasted from the start, where in its wobble
## it is, and how long until the fish comes back up (negative: it has).
var _queasy_time := 0.0
var _queasy_length := 0.0
var _queasy_clock := 0.0
var _throw_up_in := -1.0
## Flailing (thrown off the ice when the waddle broke through): how much longer (s).
var _flail_time := 0.0
## How fast its path is curving (turning()), and which way it moved last frame (NAN: not moving).
var _turning := 0.0
var _moved_yaw := NAN
var _teeter_time := 0.0
var _teeter_dir := Vector3.ZERO
var _recent_bumps := {}
var _floor_normal := Vector3.UP

var _shape: SphereShape3D


func _ready() -> void:
	add_to_group(&"penguins")
	if player_controlled:
		add_to_group(&"player")
	if tuning == null:
		tuning = PenguinTuning.new()
	vitals.tuning = tuning
	if input == null:
		input = _own_input()
	collision_layer = GameWorld.PENGUIN_LAYER
	collision_mask = GameWorld.WORLD_LAYER | GameWorld.PENGUIN_LAYER
	# Each penguin gets its own collision shape so fat can resize it.
	var col: CollisionShape3D = $CollisionShape3D
	_shape = (col.shape as SphereShape3D).duplicate()
	col.shape = _shape
	_base_radius = _shape.radius

	_spawn_position = global_position
	_spawn_yaw = rotation.y
	_yaw = rotation.y
	rotation = Vector3.ZERO # only the model rotates
	vitals.refill(_starting_energy())
	_set_state(State.SWIM if global_position.y < GameWorld.WATER_LEVEL else State.AIR)


func _physics_process(delta: float) -> void:
	_read_input()
	_tick_timers(delta)
	# Thrown flailing through the air, it passes other penguins by (they're all flying).
	var mask := GameWorld.WORLD_LAYER if is_flailing() and state == State.AIR \
			else GameWorld.WORLD_LAYER | GameWorld.PENGUIN_LAYER
	if collision_mask != mask:
		collision_mask = mask

	match state:
		State.SWIM:
			_swim(delta, _move_input)
		State.AIR:
			_air(delta, _move_input)
		State.WALK:
			_walk(delta, _move_input)
		State.SLIDE:
			_slide(delta, _move_input)

	var underwater := state == State.SWIM and GameWorld.WATER_LEVEL - global_position.y > BREATH_DEPTH
	vitals.tick(delta, underwater)
	_update_collider()
	_track_turning(delta)


# --- Public API -------------------------------------------------------------

## 0.0 = starving, 1.0 = stuffed.
func fatness() -> float:
	return vitals.fatness()


## 1.0 thin, up to tuning.fat_mass_mult when stuffed.
func mass() -> float:
	return _fat(tuning.fat_mass_mult)


## How wide a gap this penguin can hop across right now (m): a full belly is a bad jumper.
func hop_distance() -> float:
	return tuning.hop_distance * _fat(tuning.fat_hop_distance_mult)


## How high a ledge this penguin can hop up right now (m).
func hop_height() -> float:
	return tuning.hop_height * _fat(tuning.fat_hop_height_mult)


func eat_fish() -> void:
	eat(tuning.fish_value)


## Eats something worth `energy` (a fish, krill, a squid).
func eat(energy: float) -> void:
	ate_fish.emit(vitals.gain(energy))


## Ate a sick fish (diseased, or full of parasites): queasy for queasy_seconds, and it comes back
## up soon after, so it's worth nothing (sick_fish_cost lost instead).
func eat_sick_fish() -> void:
	sicken(tuning.queasy_seconds)
	_throw_up_in = tuning.throw_up_delay


## Queasy for `seconds`: you can't boost or belly-slide, you're slow, you turn slowly and your
## heading wanders. A longer spell replaces a shorter one.
func sicken(seconds: float) -> void:
	if _queasy_time <= 0.0:
		_queasy_clock = randf() * 10.0
		_queasy_length = seconds
	else:
		_queasy_length += maxf(seconds - _queasy_time, 0.0)
	_queasy_time = maxf(_queasy_time, seconds)
	sickened.emit(seconds)


func is_queasy() -> bool:
	return _queasy_time > 0.0


## How queasy it is right now, 0 to 1: it comes on over half a second and wears off over the
## last second and a half (what the screen and the look show).
func queasiness() -> float:
	if _queasy_time <= 0.0:
		return 0.0
	var since := _queasy_length - _queasy_time
	return clampf(minf(since / 0.5, _queasy_time / 1.5), 0.0, 1.0)


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


## The way it faces as an angle about +Y (rad; 0 faces -Z).
func facing_yaw() -> float:
	return _yaw


## Its swim pitch (rad; up is positive).
func swim_pitch() -> float:
	return _pitch


## Hopping up a ledge or across a gap (in the air, on its feet).
func is_hopping() -> bool:
	return state == State.AIR and _hopping


## Teetering at the edge: the flat direction it's about to fall.
func teeter_direction() -> Vector3:
	return _teeter_dir


## Its collider's radius right now (it grows with fat), and when thin.
func body_radius() -> float:
	return _shape.radius if _shape != null else _base_radius


func base_radius() -> float:
	return _base_radius


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


## How fast its path is curving, seen from above (rad/s, smoothed; positive = to its left): read
## from how it really moved, so pushing at ice or being shoved counts as it looks. Predators lead
## their lunges round the curve.
func turning() -> float:
	return _turning


## An outside shove (an orca's wave, GDD §5.3). It works like the knockback from a bump: on your
## feet grip halves it and you skid (and teeter if it takes you to the edge); on your belly you
## take all of it. It stacks with any knockback you already have.
func push(dv: Vector3) -> void:
	_take_knock(dv * _knock_share(), true)


## Stunned for `seconds` (an orca's tail slap): you can't boost, and you turn and swim slowly
## (stun_turn_mult, stun_speed_mult). A longer stun replaces a shorter one.
func stun(seconds: float) -> void:
	_stun_time = maxf(_stun_time, seconds)


## Dazed for `seconds` (a whale's body bumped you, or a humpback scooped you up): stunned (no
## boost, slow turns, slow swimming), and your heading wanders (daze_drift_deg), as if the whale's
## wake spun you round. A longer daze replaces a shorter one.
func disorient(seconds: float) -> void:
	stun(seconds)
	if _daze_time <= 0.0:
		_daze_clock = randf() * 10.0
	_daze_time = maxf(_daze_time, seconds)
	dazed.emit(seconds)


func is_dazed() -> bool:
	return _daze_time > 0.0


## Thrown into the air at `launch` (a humpback's lunge scooped it up): out of the water as if it
## had breached, landing wherever that takes it.
func toss(launch: Vector3) -> void:
	_boost_time = 0.0
	_knock = Vector3.ZERO
	_set_state(State.AIR)
	_hopping = false
	velocity = launch


## Flailing for `seconds`, flippers going and tumbling head over heels in the air (thrown off the
## ice when the waddle broke through: WaddleIce). It moves as usual, except that in the air it
## passes other penguins by instead of bumping them (everyone's flying).
func flail(seconds: float) -> void:
	_flail_time = maxf(_flail_time, seconds)


func is_flailing() -> bool:
	return _flail_time > 0.0


## A fish comes back up and floats off to one side (it costs one fish's worth of energy): what a
## hard bump does to an overfed penguin, and a humpback's gulp to anyone.
func lose_fish() -> void:
	var side := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	_spill_fish(side.normalized() if side.length() > 0.01 else Vector3.FORWARD)


## A current in the water (an orca pod's bubble wall): adds `dv` to your drift. Unlike push(),
## it isn't a bump, and it only works while you're swimming.
func drift(dv: Vector3) -> void:
	if state == State.SWIM:
		_knock += dv


## A predator got you: a puff of feathers, a splash, the caught signal, and then whatever the
## level's GameMode says. With none, the movement toy's rule: you're eaten and come back at your
## spawn point with starting energy, as if you'd pressed reset.
func get_caught(by: Node3D) -> void:
	feathers_flew.emit(global_position, 8.0)
	_make_splash(6.0)
	caught.emit(by)
	var mode := GameMode.current(get_tree()) if is_inside_tree() else null
	if mode != null:
		mode.penguin_caught(self, by)
	else:
		reset()


## Boosts now, if it can (what pressing action does in the water). False if it couldn't: not
## swimming, out of breath, stunned, short of energy or still cooling down.
func boost() -> bool:
	if state != State.SWIM:
		return false
	return _try_boost()


## Turn rate right now as a share of a thin penguin's (fat turns slower).
func turn_rate_mult() -> float:
	return _turn_mult()


## Where it respawns (reset(), getting caught in the movement toy).
func spawn_point() -> Vector3:
	return _spawn_position


## Moves where it respawns to `point`, facing `yaw` (0 faces -Z; leave it out to keep the old
## facing): the ice it started on is gone (the waddle broke through it), say.
func set_spawn_point(point: Vector3, yaw := NAN) -> void:
	_spawn_position = point
	if not is_nan(yaw):
		_spawn_yaw = yaw


# --- Placing and steering by hand -------------------------------------------
# For levels, cutscenes and tests: these skip the movement rules, so gameplay code (brains
# included) shouldn't use them. Brains steer through wish_dir.

## Puts it at `pos` in `new_state`, facing `yaw` (0 faces -Z) with swim pitch `pitch` (rad) and
## swim speed `speed`, with no other motion. Put it in AIR to drop it onto the ice: it lands and
## stands up by itself.
func place(pos: Vector3, yaw: float, new_state: State, pitch := 0.0, speed := 0.0) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_yaw = yaw
	_pitch = pitch
	_speed = speed
	_walk_vel = Vector3.ZERO
	_knock = Vector3.ZERO
	_set_state(new_state)
	reset_physics_interpolation()


## Puts it in `new_state` where it is, keeping its motion.
func force_state(new_state: State) -> void:
	_set_state(new_state)


## Flops it onto its belly, sliding along `dir` at `speed`.
func start_slide(dir: Vector3, speed: float) -> void:
	_yaw = atan2(-dir.x, -dir.z)
	velocity = dir * speed
	_set_state(State.SLIDE)


## Turns it to face `yaw` (0 faces -Z) straight away.
func set_facing(yaw: float) -> void:
	_yaw = yaw


## Pitches it (swimming; rad, up is positive) straight away.
func set_pitch(pitch: float) -> void:
	_pitch = pitch


## Its swimming speed along its heading (m/s), boost included.
func swim_speed() -> float:
	return _speed


## Sets its swimming speed straight away. Hold it at 0 every frame to keep it still.
func set_swim_speed(speed: float) -> void:
	_speed = speed


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
	_daze_time = 0.0
	_queasy_time = 0.0
	_throw_up_in = -1.0
	_flail_time = 0.0
	_turning = 0.0
	_moved_yaw = NAN
	_knock = Vector3.ZERO
	_recent_bumps.clear()
	noise = 0.0
	vitals.refill(_starting_energy())
	_set_state(State.AIR)
	reset_physics_interpolation()


# --- States -----------------------------------------------------------------

func _swim(delta: float, stick: Vector2) -> void:
	var turn := deg_to_rad(tuning.swim_turn_rate_deg) * _turn_mult()
	if _stun_time > 0.0:
		turn *= tuning.stun_turn_mult
	if _queasy_time > 0.0:
		turn *= tuning.queasy_turn_mult
	_yaw -= stick.x * turn * delta
	if _queasy_time > 0.0:
		_yaw += _queasy_wander() * delta

	var pitch_input := stick.y
	if air <= 0.0:
		pitch_input = 1.0 # out of breath: forced up to the surface
	_pitch += pitch_input * turn * delta
	if is_zero_approx(pitch_input):
		_pitch = move_toward(_pitch, 0.0, deg_to_rad(tuning.swim_pitch_return_deg) * delta)
	if _daze_time > 0.0:
		# Spun round in a whale's wake: the heading wanders.
		_yaw += _daze_drift(0.0) * delta
		_pitch += _daze_drift(1.7) * 0.35 * delta

	var depth := GameWorld.WATER_LEVEL - global_position.y
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
	if _queasy_time > 0.0:
		cruise *= tuning.queasy_speed_mult
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
	if GameWorld.WATER_LEVEL - global_position.y < WATER_EXIT_DEPTH:
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			if c.get_collider() is Penguin:
				continue
			if c.get_normal().y > 0.7:
				velocity = get_facing() * minf(_speed, tuning.walk_speed)
				_set_state(State.WALK)
				return


func _air(delta: float, stick: Vector2) -> void:
	velocity.y -= tuning.gravity * delta
	if _hopping:
		# Keep pressing forward so we land on the ledge (or across the gap) once we're over it.
		velocity.x = _hop_dir.x * _hop_speed
		velocity.z = _hop_dir.z * _hop_speed
	var turn := -stick.x * deg_to_rad(tuning.air_turn_rate_deg) * delta
	if not is_zero_approx(turn) and not _hopping:
		var h := Vector3(velocity.x, 0.0, velocity.z).rotated(Vector3.UP, turn)
		velocity.x = h.x
		velocity.z = h.z
	var horizontal := Vector2(velocity.x, velocity.z)
	if horizontal.length() > 0.5 and not _hopping:
		_yaw = atan2(-velocity.x, -velocity.z)

	_move()

	# Only re-enter on the way down: a breach starts just below the surface while still rising.
	if global_position.y < GameWorld.WATER_LEVEL and velocity.y <= 0.0:
		_enter_water()
	elif is_on_floor():
		_land()


func _walk(delta: float, stick: Vector2) -> void:
	if _teeter_time > 0.0:
		_teeter(delta, stick)
		return

	var skidding := _knock.length() > SKID_CONTROL_LOSS
	var target_vel := Vector3.ZERO
	if not skidding:
		var move := _ground_dir(stick)
		if move.length() > 0.05:
			var target_yaw := atan2(-move.x, -move.z)
			var walk_turn := deg_to_rad(tuning.walk_turn_rate_deg) * _turn_mult() * (tuning.queasy_turn_mult if _queasy_time > 0.0 else 1.0)
			_yaw = rotate_toward(_yaw, target_yaw, walk_turn * delta)
		if _daze_time > 0.0:
			_yaw += _daze_drift(0.0) * delta # staggering
		if _queasy_time > 0.0:
			_yaw += _queasy_wander() * delta
		# Penguins walk where they face, so a fat (slow-turning) penguin really feels clumsy.
		target_vel = get_facing() * tuning.walk_speed * minf(move.length(), 1.0) * (tuning.queasy_speed_mult if _queasy_time > 0.0 else 1.0)
	_walk_vel = _walk_vel.move_toward(target_vel, tuning.walk_acceleration * _accel_mult() * delta)
	# Knocked while on your feet: grip skids you to a stop.
	_knock = _knock.move_toward(Vector3.ZERO, tuning.foot_skid_friction * delta)

	var h := _walk_vel + _knock
	if skidding and is_on_floor() and _edge_ahead(_knock):
		_start_teeter(_knock)
		return

	if not skidding and is_on_floor() and _move_input.length() >= 0.3:
		match _gap_ahead():
			GapAhead.HOP:
				return
			GapAhead.TOO_FAR:
				# A gap you can't clear: you stop at the edge (on your feet you can).
				var out := get_facing()
				var toward := _walk_vel.dot(out)
				if toward > 0.0:
					_walk_vel -= out * toward
					h = _walk_vel + _knock

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


func _slide(delta: float, stick: Vector2) -> void:
	if not _tumbling:
		_yaw -= stick.x * deg_to_rad(tuning.slide_turn_rate_deg) * _turn_mult() * delta
		if _daze_time > 0.0:
			_yaw += _daze_drift(0.0) * 0.5 * delta
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
func _teeter(delta: float, stick: Vector2) -> void:
	_teeter_time -= delta
	var back := _ground_dir(stick)
	if back.dot(-_teeter_dir) > 0.5 and vitals.spend(tuning.scramble_energy_cost):
		_teeter_time = 0.0
		_yaw = atan2(_teeter_dir.x, _teeter_dir.z) # turn away from the edge
		_knock = Vector3.ZERO
		_walk_vel = -_teeter_dir * tuning.walk_speed
		scrambled.emit()
		return
	velocity = Vector3(0.0, 0.0 if is_on_floor() else velocity.y - tuning.gravity * delta, 0.0)
	_move()
	if _teeter_time <= 0.0:
		# Over you go.
		_teeter_time = 0.0
		velocity = _teeter_dir * 3.0 + Vector3.UP * 1.2
		_set_state(State.AIR)


# --- Transitions ------------------------------------------------------------

func _try_boost() -> bool:
	if _boost_cooldown > 0.0 or air <= 0.0:
		return false
	if _stun_time > 0.0 or _queasy_time > 0.0:
		boost_denied.emit()
		return false
	if not vitals.spend(tuning.boost_energy_cost):
		boost_denied.emit()
		return false
	_speed = maxf(_speed, tuning.boost_peak_speed * _fat(tuning.fat_boost_speed_mult))
	_boost_time = tuning.boost_duration
	_boost_cooldown = tuning.boost_duration + tuning.boost_cooldown
	boosted.emit()
	return true


## Dive onto your belly. Costs a little energy; returns false if you can't afford it.
func _try_flop(h: Vector3) -> bool:
	if _queasy_time > 0.0 or not vitals.spend(tuning.slide_energy_cost):
		boost_denied.emit()
		return false
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
	_hop_speed = tuning.hop_forward_speed
	_set_state(State.AIR)
	hopped.emit(ledge, cleared)


enum GapAhead { NONE, HOP, TOO_FAR }

## Walking up to the edge of the ice: is there more ice just across (a gap)? If you can clear it,
## you hop it now (HOP). If it's there but too wide or too high, TOO_FAR. Open water (or no edge),
## NONE.
func _gap_ahead() -> GapAhead:
	if _hop_cooldown > 0.0:
		return GapAhead.NONE
	var dir := get_facing()
	if not _edge_ahead(dir):
		return GapAhead.NONE
	var feet := global_position.y - _shape.radius
	var reach := hop_distance()
	var top := hop_height()
	# Where our ice ends...
	var edge := _shape.radius + 0.2
	var d := 0.0
	while d <= _shape.radius + 0.25:
		var probe := global_position + dir * d
		if _ray(Vector3(probe.x, feet + 0.3, probe.z), Vector3(probe.x, feet - EDGE_DROP, probe.z)).is_empty():
			edge = d
			break
		d += 0.1
	# ...and where the next ice starts: straight ahead (you hop that way), or a little to either
	# side (still a gap, not open water, so you stop rather than walk off).
	d = edge + 0.1
	while d <= GAP_SENSE:
		var probe := global_position + dir * d
		var hit := _ray(Vector3(probe.x, feet + LEDGE_PROBE_HEIGHT, probe.z), Vector3(probe.x, feet - 1.0, probe.z))
		if not hit.is_empty() and (hit.position as Vector3).y > GameWorld.WATER_LEVEL + 0.05:
			var gap := d - edge
			var rise: float = (hit.position as Vector3).y - feet
			if gap > reach or rise > top - 0.05:
				return GapAhead.TOO_FAR
			_hop_across(dir, d + _shape.radius + 0.3, maxf(rise, 0.0))
			return GapAhead.HOP
		d += 0.1
	# (Off to the side, the ice you're standing on doesn't count: walking off a round floe at a
	# slant, the side probe runs back over the same floe.)
	var under := _ray(global_position, global_position + Vector3.DOWN * (_shape.radius + EDGE_DROP))
	var standing_on: Object = under.get("collider")
	for side in [-1.0, 1.0]:
		var aside := dir.rotated(Vector3.UP, side * deg_to_rad(GAP_SIDE_DEG))
		d = edge + 0.1
		while d <= GAP_SENSE:
			var probe := global_position + aside * d
			var hit := _ray(Vector3(probe.x, feet + LEDGE_PROBE_HEIGHT, probe.z), Vector3(probe.x, feet - 1.0, probe.z))
			if not hit.is_empty() and hit.get("collider") != standing_on and (hit.position as Vector3).y > GameWorld.WATER_LEVEL + 0.05:
				return GapAhead.TOO_FAR
			d += 0.2
	return GapAhead.NONE


## Hops `distance` along `dir`, clearing `rise`.
func _hop_across(dir: Vector3, distance: float, rise: float) -> void:
	var up := sqrt(2.0 * tuning.gravity * (rise + HOP_CLEARANCE + 0.15))
	var down := sqrt(maxf(up * up - 2.0 * tuning.gravity * rise, 0.0))
	var flight := (up + down) / tuning.gravity
	_hop_dir = dir
	_hop_speed = distance / maxf(flight, 0.1)
	velocity = dir * _hop_speed + Vector3.UP * up
	_hopping = true
	_set_state(State.AIR)
	hopped.emit(distance, true)


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
	_make_splash(_speed)
	_set_state(State.AIR)
	_move()


func _enter_water() -> void:
	var v := velocity
	_speed = v.length() * tuning.water_entry_speed_keep
	var horizontal := Vector2(v.x, v.z).length()
	if horizontal > 0.1:
		_yaw = atan2(-v.x, -v.z)
	var max_pitch := deg_to_rad(tuning.swim_max_pitch_deg)
	_pitch = clampf(atan2(v.y, horizontal), -max_pitch, max_pitch)
	_make_splash(v.length())
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
	if GameWorld.WATER_LEVEL - global_position.y > WATER_ENTRY_DEPTH:
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
		dv_me *= t.bump_knock_mult
		dv_them *= t.bump_knock_mult
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
	feathers_flew.emit(global_position + n * _shape.radius, closing)
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
		if vitals.is_overfed():
			_spill_fish(toward)
	if dv.length() > 0.5 or not was_immune:
		_immune_time = tuning.knock_immunity_seconds
	bumped.emit(other, closing, hard)


## A fish pops out to one side of the hit. Anyone can grab it, except the penguin that lost it
## (for a moment), so it can't just skid back over it.
func _spill_fish(toward_hit: Vector3) -> void:
	vitals.lose(tuning.fish_value)
	var fish := FISH_SCENE.instantiate() as Fish
	fish.circle_radius = 0.0
	fish.one_shot = true
	fish.pickup_delay = 0.3
	fish.ignore_body = self
	fish.ignore_seconds = 2.0
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
	var query := PhysicsRayQueryParameters3D.create(from, to, GameWorld.WORLD_LAYER, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)


# --- Per-frame upkeep -------------------------------------------------------

func _read_input() -> void:
	if input != null:
		input.read(self)
		_move_input = input.move
		_action_pressed = input.action
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
	_daze_time = maxf(_daze_time - delta, 0.0)
	if _daze_time > 0.0:
		_daze_clock += delta
	_flail_time = maxf(_flail_time - delta, 0.0)
	_queasy_time = maxf(_queasy_time - delta, 0.0)
	if _queasy_time > 0.0:
		_queasy_clock += delta
	if _throw_up_in >= 0.0:
		_throw_up_in -= delta
		if _throw_up_in < 0.0:
			vitals.lose(tuning.sick_fish_cost)
			threw_up.emit(global_position + get_facing() * _shape.radius)
	noise = maxf(noise - delta / tuning.noise_fade_seconds, 0.0)
	for other: Variant in _recent_bumps.keys():
		if not is_instance_valid(other):
			_recent_bumps.erase(other)
			continue
		_recent_bumps[other] -= delta
		if _recent_bumps[other] <= 0.0:
			_recent_bumps.erase(other)


## Fat changes the collision size (the look widens the model to match).
func _update_collider() -> void:
	var radius := _base_radius * _fat(tuning.fat_collision_radius_mult)
	if not is_equal_approx(_shape.radius, radius):
		_shape.radius = radius


# --- Helpers ----------------------------------------------------------------

## A player's own controls, or nobody's (a dummy).
func _own_input() -> PenguinInput:
	return PlayerInput.new(player_number) if player_controlled else PenguinInput.new()


## Which way `stick` points on the ice (flat, world space), for whoever is steering.
func _ground_dir(stick: Vector2) -> Vector3:
	return input.ground_dir(self, stick) if input != null else Vector3.ZERO


## Dazed: how fast the heading is wandering right now (rad/s). A smooth, wobbling drift that
## eases off at the end of the daze. `offset` gives a second, different wobble (for the pitch).
func _daze_drift(offset: float) -> float:
	var c := _daze_clock + offset
	var wobble := (sin(c * 2.1) + 0.6 * sin(c * 4.7 + 1.3)) / 1.6
	return deg_to_rad(tuning.daze_drift_deg) * wobble * clampf(_daze_time / 0.5, 0.0, 1.0)


## Queasy: how fast the heading is wandering right now (rad/s), a slow, rolling sway.
func _queasy_wander() -> float:
	var c := _queasy_clock
	return deg_to_rad(tuning.queasy_wander_deg) * (sin(c * 1.3) + 0.5 * sin(c * 3.1 + 0.7)) / 1.5 * queasiness()


func _starting_energy() -> float:
	return start_energy if start_energy >= 0.0 else tuning.starting_energy


func _fat(mult_at_full: float) -> float:
	return lerpf(1.0, mult_at_full, fatness())


func _track_turning(delta: float) -> void:
	var going := get_real_velocity()
	var flat := Vector2(going.x, going.z)
	if flat.length() < 0.5:
		_turning = move_toward(_turning, 0.0, MAX_TURNING * TURNING_SMOOTHING * delta)
		_moved_yaw = NAN
		return
	var yaw := atan2(-flat.x, -flat.y)
	if not is_nan(_moved_yaw):
		var rate := clampf(angle_difference(_moved_yaw, yaw) / maxf(delta, 0.001), -MAX_TURNING, MAX_TURNING)
		_turning = lerpf(_turning, rate, clampf(TURNING_SMOOTHING * delta, 0.0, 1.0))
	_moved_yaw = yaw


func _turn_mult() -> float:
	return _fat(tuning.fat_turn_rate_mult)


func _accel_mult() -> float:
	return _fat(tuning.fat_acceleration_mult)


func _heading_dir() -> Vector3:
	return Vector3(-sin(_yaw) * cos(_pitch), sin(_pitch), -cos(_yaw) * cos(_pitch))


## A splash on the water where it is (PenguinLook plays it). Predators hear it (noise).
func _make_splash(strength: float) -> void:
	noise = maxf(noise, tuning.splash_noise)
	splashed.emit(Vector3(global_position.x, GameWorld.WATER_LEVEL, global_position.z), strength)
