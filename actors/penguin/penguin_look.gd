class_name PenguinLook
extends Node3D
## How a penguin looks: the script on its Model node. The body (a sphere that never rotates) does
## the physics; this node only shows it. Each physics frame, right after the penguin moves, it
## turns the model to match what the penguin is doing (standing, lying belly-down to slide or
## swim, hopping, windmilling at an edge, spinning out, dazed, queasy, flailing), widens it with fat
## and keeps its feet on the ice as the collider grows. It plays the bubbles, splashes and feather puffs from the
## penguin's signals (and a sick fish coming back up).
##
## It only reads the penguin (its state, its public getters and signals), so a real model can
## bring its own look script (with an AnimationTree, say) without touching the physics.
##
## The placeholder model is built standing: head = +Y, belly faces -Z.

## How fast the model turns to where it should face (per second; higher is snappier).
const TURN_SMOOTHING := 12.0
## How fast the feet settle as the collider grows or shrinks.
const DROP_SMOOTHING := 10.0
## Spinning out: turns per second (rad/s).
const SPIN_SPEED := 18.0
## Flailing: head over heels this fast in the air (rad/s), and the flippers beat this fast (rad/s)
## and this far (rad).
const FLAIL_TUMBLE := 9.0
const FLAP_SPEED := 30.0
const FLAP_ANGLE := 0.9

@export var bubbles_path := ^"../Bubbles"
@export var splash_path := ^"../Splash"
@export var puff_path := ^"../Puff"
## The mesh that body_tint colours.
@export var body_path := ^"Body"
## The flippers, which flap when it flails (rotating about their top end).
@export var flipper_paths: Array[NodePath] = [^"FlipperL", ^"FlipperR"]

var _penguin: Penguin
var _spin_angle := 0.0
var _bubbles: CPUParticles3D
var _splash: CPUParticles3D
var _puff: CPUParticles3D
var _sick: CPUParticles3D
var _tumble := 0.0
var _flippers: Array[Node3D] = []
var _flipper_rest: Array[Transform3D] = []


func _ready() -> void:
	_penguin = get_parent() as Penguin
	_bubbles = get_node_or_null(bubbles_path) as CPUParticles3D
	_splash = get_node_or_null(splash_path) as CPUParticles3D
	_puff = get_node_or_null(puff_path) as CPUParticles3D
	# Splashes and puffs stay where they happened.
	for particles in [_splash, _puff]:
		if particles != null:
			(particles as CPUParticles3D).top_level = true
	if _penguin == null:
		return
	_tint(_penguin.body_tint)
	_penguin.tinted.connect(_tint)
	_penguin.splashed.connect(_on_splashed)
	_penguin.feathers_flew.connect(_on_feathers_flew)
	_penguin.threw_up.connect(_on_threw_up)
	_sick = _make_sick_spray()
	for path in flipper_paths:
		var flipper := get_node_or_null(path) as Node3D
		if flipper != null:
			_flippers.append(flipper)
			_flipper_rest.append(flipper.transform)


func _physics_process(delta: float) -> void:
	if _penguin == null or _penguin.tuning == null:
		return
	var p := _penguin
	var target: Basis
	match p.state:
		Penguin.State.WALK:
			target = Basis(Vector3.UP, p.facing_yaw())
			if p.is_teetering():
				# Windmilling at the edge, leaning out over the water.
				var lean := 0.35 + 0.25 * sin(Time.get_ticks_msec() * 0.02)
				target = Basis(Vector3.UP.cross(p.teeter_direction()).normalized(), lean) * target
		Penguin.State.SLIDE:
			var up := p.get_floor_normal() if p.is_on_floor() else Vector3.UP
			var facing := p.get_facing()
			var along := facing - up * facing.dot(up)
			target = _belly_down_basis(along if along.length() > 0.01 else facing, up)
		Penguin.State.AIR:
			target = Basis(Vector3.UP, p.facing_yaw()) if p.is_hopping() else _belly_down_basis(p.get_heading())
		_:
			target = _belly_down_basis(p.get_heading())
	if p.is_flailing():
		var t := Time.get_ticks_msec() * 0.001
		if p.state == Penguin.State.AIR and not p.is_hopping():
			# Thrown up off the ice: head over heels.
			_tumble += FLAIL_TUMBLE * delta
			target = Basis(Vector3.UP, p.facing_yaw()) * Basis(Vector3.RIGHT, _tumble)
		elif p.state == Penguin.State.SWIM:
			# Splashed down: bolt upright in the water, flapping, rocking back.
			target = Basis(Vector3.UP, p.facing_yaw()) * Basis(Vector3.RIGHT, 0.45 + 0.2 * sin(t * 7.0))
	else:
		_tumble = 0.0
	_flap(p.is_flailing())
	if p.is_spun_out():
		_spin_angle += SPIN_SPEED * delta
		target = Basis(Vector3.UP, _spin_angle) * target
	else:
		_spin_angle = 0.0
	if p.is_dazed():
		# Spun round by a whale: a big, lolling roll, and the head bobbing about.
		var t := Time.get_ticks_msec() * 0.001
		target = target * Basis(Vector3.UP, 0.9 * sin(t * 9.0)) * Basis(Vector3.RIGHT, 0.25 * sin(t * 6.3))
	elif p.is_queasy():
		# Queasy: hunched, swaying slowly, head nodding.
		var q := p.queasiness()
		var t := Time.get_ticks_msec() * 0.001
		target = target * Basis(Vector3.UP, 0.35 * q * sin(t * 2.2)) * Basis(Vector3.RIGHT, 0.18 * q * (1.0 + sin(t * 3.4)))
	elif p.is_stunned():
		# Stunned: a slow, woozy roll from side to side.
		var roll := 0.5 * sin(Time.get_ticks_msec() * 0.012)
		target = target * Basis(Vector3.UP, roll)
	var current := basis.get_rotation_quaternion()
	var rot := current.slerp(target.get_rotation_quaternion(), clampf(TURN_SMOOTHING * delta, 0.0, 1.0))
	var width := lerpf(1.0, p.tuning.fat_body_width_mult, p.fatness())
	basis = Basis(rot) * Basis.from_scale(Vector3(width, 1.0, width))
	# Keep the feet on the ice when the collider grows.
	var drop := -(p.body_radius() - p.base_radius()) if p.state == Penguin.State.WALK else 0.0
	position.y = lerpf(position.y, drop, clampf(DROP_SMOOTHING * delta, 0.0, 1.0))

	if _bubbles != null:
		_bubbles.emitting = p.state == Penguin.State.SWIM and (p.is_boosting() or p.swim_speed() > p.tuning.porpoise_min_speed)


## Colours the body `colour` (alpha 0: its own colour).
func _tint(colour: Color) -> void:
	var body := get_node_or_null(body_path) as MeshInstance3D
	if body == null:
		return
	if colour.a <= 0.0:
		body.material_override = null
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	body.material_override = mat


## Flippers beating while it flails; at rest otherwise.
func _flap(flailing: bool) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in _flippers.size():
		var rest := _flipper_rest[i]
		if not flailing:
			_flippers[i].transform = rest
			continue
		var side := signf(rest.origin.x) if absf(rest.origin.x) > 0.001 else 1.0
		var angle := side * FLAP_ANGLE * (0.5 + 0.5 * sin(t * FLAP_SPEED + float(i) * 0.6))
		# Turn about the flipper's top end, where it meets the body.
		var pivot := rest.origin + rest.basis.y * 0.15
		_flippers[i].transform = Transform3D(Basis(Vector3.BACK, angle), pivot) * Transform3D(Basis.IDENTITY, -pivot) * rest


## Lays the model belly-down with its head along `dir` (`up` is the way its back faces).
func _belly_down_basis(dir: Vector3, up: Vector3 = Vector3.UP) -> Basis:
	var y := dir.normalized()
	if absf(y.dot(up)) > 0.98:
		up = _penguin.get_facing()
	var z := (up - y * y.dot(up)).normalized()
	var x := y.cross(z)
	return Basis(x, y, z)


func _on_splashed(at: Vector3, strength: float) -> void:
	if _splash == null:
		return
	_splash.global_position = at
	_splash.amount = clampi(int(strength * 4.0), 8, 48)
	_splash.restart()


func _on_threw_up(at: Vector3) -> void:
	_sick.global_position = at
	_sick.direction = _penguin.get_facing() + Vector3.UP * 0.4
	_sick.restart()


## A sick fish coming back up: a spurt of sickly green-yellow bits. Built here, so the penguin
## scene doesn't need it.
func _make_sick_spray() -> CPUParticles3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.62, 0.74, 0.22)
	var bit := SphereMesh.new()
	bit.radius = 0.05
	bit.height = 0.1
	bit.radial_segments = 6
	bit.rings = 3
	bit.material = mat
	var spray := CPUParticles3D.new()
	spray.name = &"SickSpray"
	spray.emitting = false
	spray.one_shot = true
	spray.explosiveness = 0.85
	spray.amount = 18
	spray.lifetime = 0.8
	spray.mesh = bit
	spray.spread = 25.0
	spray.gravity = Vector3(0.0, -6.0, 0.0)
	spray.initial_velocity_min = 1.5
	spray.initial_velocity_max = 3.0
	spray.top_level = true
	add_child(spray)
	return spray


func _on_feathers_flew(at: Vector3, strength: float) -> void:
	if _puff == null:
		return
	_puff.global_position = at
	_puff.amount = clampi(int(strength * 4.0), 6, 32)
	_puff.restart()
