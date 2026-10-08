class_name KrillSwarm
extends Node3D
## A swarm of krill (GDD §4.11): a pink cloud of tiny snacks near the surface. A penguin that
## swims into it eats krill as long as its beak is in the cloud (eat_rate a second, krill_energy
## each), so a swarm is a big meal for whoever stays in it, or a few mouthfuls in passing. Eaten
## out, it forms again a little way off after regrow_seconds.
##
## Thousands of krill are drawn as one MultiMesh, so a swarm costs about one fish.

## Krill eaten from it: by `penguin`, `count` of them.
signal eaten(penguin: Penguin, count: int)

const DEFAULT_TUNING := preload("res://tuning/krill.tres")
## Swarms farther than this from the camera (m) only move their krill every FAR_STEP frames.
const FAR_DISTANCE := 45.0
const FAR_STEP := 4
## Pink, well clear of the danger colour's orange.
const KRILL_COLOR := Color(0.92, 0.36, 0.55)

@export var tuning: KrillTuning = DEFAULT_TUNING

## Where it formed: it drifts about here.
var home := Vector3.ZERO

var _left := 0
var _drift_to := Vector3.ZERO
var _regrow := 0.0
var _clock := 0.0
## Krill eaten this frame by each penguin, still to swallow (fractions add up).
var _mouthfuls := {}
## Each krill's spot in the cloud (a point in a ball), and how fast and which way it circles.
var _spots: PackedVector3Array = []
var _spins: PackedFloat32Array = []
var _multimesh: MultiMesh
var _mesh_instance: MultiMeshInstance3D
var _frame_offset := 0


func _ready() -> void:
	home = global_position
	_drift_to = home
	_left = tuning.count
	_frame_offset = randi() % FAR_STEP
	_build()


func _physics_process(delta: float) -> void:
	_clock += delta
	if _left <= 0:
		_regrow -= delta
		if _regrow <= 0.0:
			_form_again()
		return
	# Drift about home.
	if global_position.distance_to(_drift_to) < 0.5:
		var off := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf_range(0.0, tuning.wander)
		_drift_to = home + off
	global_position = global_position.move_toward(_drift_to, tuning.drift_speed * delta)
	_feed_penguins(delta)
	_place_krill()


# --- Public API ---------------------------------------------------------------

## Krill left in it.
func remaining() -> int:
	return _left


## Is `point` inside the cloud (a beak in it can eat)?
func contains(point: Vector3) -> bool:
	return _left > 0 and global_position.distance_to(point) <= tuning.radius


# --- Inside -------------------------------------------------------------------

## Penguins with their beaks in the cloud eat krill.
func _feed_penguins(delta: float) -> void:
	for node in get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p == null or p.state != Penguin.State.SWIM:
			continue
		var beak := p.global_position + p.get_facing() * p.body_radius()
		if global_position.distance_to(beak) > tuning.radius + p.body_radius() * 0.5:
			_mouthfuls.erase(p)
			continue
		var owed: float = _mouthfuls.get(p, 0.0) + tuning.eat_rate * delta
		var whole := mini(int(owed), _left)
		_mouthfuls[p] = owed - whole
		if whole > 0:
			_left -= whole
			p.eat(tuning.krill_energy * whole)
			eaten.emit(p, whole)
			if _left <= 0:
				_regrow = tuning.regrow_seconds
				_mesh_instance.visible = false
				_mouthfuls.clear()
				return
	_multimesh.visible_instance_count = _left


func _form_again() -> void:
	var off := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf_range(0.0, tuning.wander)
	global_position = home + off
	_drift_to = global_position
	_left = tuning.count
	_multimesh.visible_instance_count = _left
	_mesh_instance.visible = true
	reset_physics_interpolation()


## Each krill circles its spot in the cloud, bobbing. Far from the camera, only now and then.
func _place_krill() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var far := camera != null and camera.global_position.distance_to(global_position) > FAR_DISTANCE
	if far and (Engine.get_physics_frames() + _frame_offset) % FAR_STEP != 0:
		return
	for i in _left:
		var spot := _spots[i]
		var spin := _spins[i]
		var at := spot.rotated(Vector3.UP, _clock * spin) + Vector3(0.0, 0.12 * sin(_clock * 3.0 + spin * 7.0), 0.0)
		var facing := Basis(Vector3.UP, _clock * spin + PI * 0.5 * signf(spin))
		_multimesh.set_instance_transform(i, Transform3D(facing, at))


func _build() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = KRILL_COLOR
	mat.emission_enabled = true
	mat.emission = KRILL_COLOR * 0.25
	mat.roughness = 0.8
	var krill := BoxMesh.new()
	krill.size = Vector3(0.04, 0.035, 0.12)
	krill.material = mat
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.mesh = krill
	_multimesh.instance_count = tuning.count
	_spots.resize(tuning.count)
	_spins.resize(tuning.count)
	for i in tuning.count:
		# A ball, a bit flattened: denser in the middle.
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6), randf_range(-1.0, 1.0)).normalized()
		_spots[i] = dir * tuning.radius * pow(randf(), 0.6) * Vector3(1.0, 0.6, 1.0)
		_spins[i] = randf_range(0.4, 1.2) * (1.0 if randf() < 0.5 else -1.0)
	_mesh_instance = MultiMeshInstance3D.new()
	_mesh_instance.name = &"Krill"
	_mesh_instance.multimesh = _multimesh
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)
	_place_krill()
