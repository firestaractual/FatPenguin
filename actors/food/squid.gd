class_name Squid
extends Area3D
## A squid (GDD §4.11): a big meal that won't sit still. It drifts about where it lives; a penguin
## in the water that comes close makes it jet away, mantle first, squirting a puff of ink. It
## can only jet so often, and after a few in a row it's spent for a while, so you catch it by
## chasing it down or with a well-timed boost. Swim into it to eat it; another turns up at its
## home a while later.
##
## It builds its own model and ink in code, so it needs no scene.

## Eaten by `penguin`.
signal eaten(penguin: Penguin)
## It jetted away (from a penguin).
signal jetted

const DEFAULT_TUNING := preload("res://tuning/squid.tres")
const BODY_COLOR := Color(0.8, 0.56, 0.7)
const INK_COLOR := Color(0.12, 0.08, 0.16, 0.8)
## How fast a jet bleeds back down to cruising (m/s²).
const JET_DRAG := 10.0

@export var tuning: SquidTuning = DEFAULT_TUNING

## Where it lives: it drifts about here.
var home := Vector3.ZERO
var velocity := Vector3.ZERO

var _wander_to := Vector3.ZERO
var _jet_time := 0.0
var _jet_ready := 0.0
var _jets_left := 0
var _spent := 0.0
var _gone := 0.0
var _model: Node3D
var _ink: CPUParticles3D


func _ready() -> void:
	home = global_position
	_wander_to = home
	_jets_left = tuning.jets
	collision_layer = 0
	collision_mask = GameWorld.PENGUIN_LAYER
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.55
	shape.shape = sphere
	add_child(shape)
	_build_model()
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if not visible:
		_gone -= delta
		if _gone <= 0.0:
			_come_back()
		return
	_jet_ready = maxf(_jet_ready - delta, 0.0)
	if _spent > 0.0:
		_spent -= delta
		if _spent <= 0.0:
			_jets_left = tuning.jets
	if _jet_time > 0.0:
		_jet_time -= delta
	else:
		var chaser := _nearest_penguin()
		if chaser != null and _jet_ready <= 0.0 and _jets_left > 0:
			_jet_from(chaser)
		else:
			_cruise(delta)
	var pos := global_position + velocity * delta
	pos.y = clampf(pos.y, GameWorld.WATER_LEVEL - Swimmer.MAX_DEPTH, GameWorld.WATER_LEVEL - 0.4)
	var facing := global_basis
	if velocity.length() > 0.2:
		facing = Basis.looking_at(velocity, Vector3.UP)
	global_transform = Transform3D(facing, pos)


# --- Public API ---------------------------------------------------------------

## Out of jets for a while (chase it now)?
func is_spent() -> bool:
	return _jets_left <= 0


## Jetting away right now?
func is_jetting() -> bool:
	return _jet_time > 0.0


# --- Inside -------------------------------------------------------------------

## The nearest penguin in the water within flee_range, or null.
func _nearest_penguin() -> Penguin:
	var best: Penguin = null
	var best_d := tuning.flee_range
	for node in get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p == null or p.state != Penguin.State.SWIM:
			continue
		var d := p.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


## Away from `p`, a little to one side, mantle first, with a puff of ink where it was.
func _jet_from(p: Penguin) -> void:
	var away := global_position - p.global_position
	away.y *= 0.3
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	away = away.rotated(Vector3.UP, randf_range(-0.6, 0.6))
	velocity = away * tuning.jet_speed
	_jet_time = tuning.jet_seconds
	_jet_ready = tuning.jet_cooldown
	_jets_left -= 1
	if _jets_left <= 0:
		_spent = tuning.spent_seconds
	_ink.global_position = global_position
	_ink.restart()
	jetted.emit()


## Drifts about home, slowing back down after a jet.
func _cruise(delta: float) -> void:
	if global_position.distance_to(_wander_to) < 1.0:
		var off := Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3), randf_range(-1.0, 1.0)).normalized()
		_wander_to = home + off * randf_range(0.0, tuning.roam_radius)
		_wander_to.y = clampf(_wander_to.y, GameWorld.WATER_LEVEL - tuning.depth.y, GameWorld.WATER_LEVEL - tuning.depth.x)
	var want := (_wander_to - global_position).normalized() * tuning.cruise_speed
	velocity = velocity.move_toward(want, JET_DRAG * delta)


func _on_body_entered(body: Node3D) -> void:
	var p := body as Penguin
	if p == null or not visible:
		return
	p.eat(tuning.energy)
	eaten.emit(p)
	visible = false
	set_deferred(&"monitoring", false)
	_gone = tuning.respawn_seconds


func _come_back() -> void:
	global_position = home
	velocity = Vector3.ZERO
	_jets_left = tuning.jets
	_spent = 0.0
	visible = true
	set_deferred(&"monitoring", true)
	reset_physics_interpolation()


## A mauve mantle with two fins, and arms trailing behind (it swims mantle first, along -Z).
func _build_model() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BODY_COLOR
	mat.roughness = 0.4
	mat.emission_enabled = true
	mat.emission = BODY_COLOR * 0.25
	_model = Node3D.new()
	_model.name = &"Model"
	add_child(_model)
	var mantle := CapsuleMesh.new()
	mantle.radius = 0.16
	mantle.height = 0.75
	mantle.material = mat
	var body := MeshInstance3D.new()
	body.mesh = mantle
	body.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_model.add_child(body)
	var fin := BoxMesh.new()
	fin.size = Vector3(0.45, 0.02, 0.18)
	fin.material = mat
	var fins := MeshInstance3D.new()
	fins.mesh = fin
	fins.position = Vector3(0.0, 0.0, -0.28)
	_model.add_child(fins)
	var arm := BoxMesh.new()
	arm.size = Vector3(0.03, 0.03, 0.45)
	arm.material = mat
	for i in 8:
		var a := TAU * i / 8.0
		var tentacle := MeshInstance3D.new()
		tentacle.mesh = arm
		tentacle.position = Vector3(cos(a) * 0.07, sin(a) * 0.07, 0.55)
		tentacle.rotation = Vector3(sin(a) * 0.15, cos(a) * 0.15, 0.0)
		_model.add_child(tentacle)
	var ink_mat := StandardMaterial3D.new()
	ink_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink_mat.albedo_color = INK_COLOR
	var blob := SphereMesh.new()
	blob.radius = 0.25
	blob.height = 0.5
	blob.radial_segments = 8
	blob.rings = 4
	blob.material = ink_mat
	_ink = CPUParticles3D.new()
	_ink.name = &"Ink"
	_ink.emitting = false
	_ink.one_shot = true
	_ink.explosiveness = 0.7
	_ink.amount = 14
	_ink.lifetime = 1.6
	_ink.mesh = blob
	_ink.spread = 180.0
	_ink.gravity = Vector3.ZERO
	_ink.initial_velocity_min = 0.2
	_ink.initial_velocity_max = 0.8
	_ink.damping_min = 0.5
	_ink.damping_max = 1.0
	_ink.scale_amount_min = 0.8
	_ink.scale_amount_max = 2.2
	_ink.top_level = true
	add_child(_ink)
