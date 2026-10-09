class_name Chick
extends Node3D
## A chick in a waddle (GDD §4.12; WaddleMatch lays, feeds and raises them). It belongs to the family
## of the penguin that laid it, wherever it was laid (a chick laid in a rival's waddle is still
## yours: a cuckoo). It starts as an egg that wobbles and cracks open, then it potters about near
## where it hatched and waddles over to beg from anyone who would feed it (`would_feed`) with energy
## to spare. Standing beside it feeds it (the match does the feeding); every few feedings it grows a
## size: tiny, fluffy, then a big fat fledgling, which is full grown and stops begging, and after a
## while grows up (fledged: the match swaps it for a young adult). Its weight counts toward its
## berg's waddle. If the berg breaks up, it's lost (lose()).
##
## It isn't a physics body and nothing hunts it: it stands on whatever ice is under it (a ray down
## on the world layer, so it never mistakes a penguin for ice), never walks off the edge, and rides
## along with its parent node (ride()).
##
## The look is built here in code: grey down (with a hint of its family's colour), a black cap, a
## white face mask, a black beak; more down tufts when it's fluffy, a fat white front when it's a
## fledgling. Its front is -Z, like a penguin's model. Numbers are in WaddleTuning (Chicks, Growing
## up).

## The egg cracked open.
signal hatched
## It grew to `new_size` (1 fluffy, 2 fledgling).
signal grew(new_size: int)
## It was fed.
signal ate
## Full grown for fledge_seconds: time to grow up.
signal fledged
## It was lost (its berg broke up).
signal lost

const DOWN := Color(0.66, 0.68, 0.7)
const DOWN_DARK := Color(0.52, 0.54, 0.57)
const CAP := Color(0.07, 0.08, 0.1)
const FACE := Color(0.97, 0.97, 0.95)
const FEET := Color(0.3, 0.31, 0.33)
const EGG := Color(0.94, 0.92, 0.85)
## Close enough to the parent it's begging from (m, × its size), and to a spot it's walking to.
const BEG_STOP := 0.75
const ARRIVED := 0.15
## How often it looks for a parent to beg from (s).
const LOOK_INTERVAL := 0.4

@export var tuning: WaddleTuning

## Feedings so far (all sizes).
var feedings := 0
## The penguin it's begging from, or null.
var begging_from: Penguin = null
## Its family (WaddleMatch's id; -1 none), its colour (tints its down; alpha 0: none), and the
## berg whose waddle it's in. Set before it's added.
var family := -1
var tint := Color(0, 0, 0, 0)
var berg: IceBerg = null
## Who it begs from: called with a penguin standing on the ice, true if that one would feed it now.
## Unset: any player with energy to spare.
var would_feed: Callable
## How long it's been full grown (s).
var grown_for := 0.0

var _size := 0
var _hatched := false
var _hatch_left := 0.0
## Where it hatched, in its parent node's space (it wanders round this).
var _home := Vector3.ZERO
var _goal := Vector3.ZERO
var _wander_left := 0.0
var _look_left := 0.0
var _clock := 0.0
var _yaw := 0.0
var _walking := false
## A hop's height right now (m), and the pop when it hatches or grows (× its size).
var _hop := 0.0
var _pop := 1.0
var _gulp := 0.0
var _flap := 0.0

var _model: Node3D
var _body: Node3D
var _egg: Node3D
var _tufts: Node3D
var _front: Node3D
var _flippers: Array[Node3D] = []
var _shell: CPUParticles3D
var _lost := false
var _fledge_sent := false

static var _materials := {}


func _ready() -> void:
	add_to_group(&"chicks")
	if tuning == null:
		tuning = preload("res://tuning/waddle.tres")
	_home = position
	_goal = position
	_yaw = randf() * TAU
	_build_model()
	_build_egg()
	_hatch_left = tuning.hatch_seconds
	_model.visible = false
	_snap_to_ice()


func _physics_process(delta: float) -> void:
	_clock += delta
	if _lost:
		return
	if not _hatched:
		_hatch_left -= delta
		# The egg rocks, harder as it's about to go.
		var k := 1.0 - clampf(_hatch_left / maxf(tuning.hatch_seconds, 0.01), 0.0, 1.0)
		_egg.rotation = Vector3(0.0, 0.0, sin(_clock * (10.0 + 14.0 * k)) * (0.08 + 0.3 * k))
		if _hatch_left <= 0.0:
			hatch_now()
		_snap_to_ice()
		return
	if _size >= max_size():
		grown_for += delta
		if grown_for >= tuning.fledge_seconds and not _fledge_sent:
			_fledge_sent = true
			fledged.emit()
	_look_left -= delta
	if begging_from != null and not is_instance_valid(begging_from):
		begging_from = null # eaten
		_look_left = 0.0
	if _look_left <= 0.0:
		_look_left = LOOK_INTERVAL
		begging_from = _find_parent()
	var target := _goal_global()
	var to := target - global_position
	to.y = 0.0
	var stop := ARRIVED if begging_from == null else BEG_STOP * (0.6 + 0.4 * _scale())
	_walking = false
	if to.length() > stop:
		var step := minf(_walk_speed() * delta, to.length() - stop)
		var next := global_position + to.normalized() * step
		if _ice_under(next):
			global_position = next
			_walking = true
		elif begging_from == null:
			_wander_left = 0.0 # the edge: pick somewhere else
		_yaw = rotate_toward(_yaw, atan2(-to.x, -to.z), 8.0 * delta)
	elif begging_from != null:
		var face := begging_from.global_position - global_position
		_yaw = rotate_toward(_yaw, atan2(-face.x, -face.z), 6.0 * delta)
	if begging_from == null:
		_wander_left -= delta
		if _wander_left <= 0.0 or to.length() <= stop:
			_pick_wander_spot()
	_snap_to_ice()
	_pose(delta)


# --- What it answers ------------------------------------------------------------

## 0 tiny, 1 fluffy, 2 a big fat fledgling (full grown).
func size() -> int:
	return _size


## The biggest size it grows to.
func max_size() -> int:
	return mini(tuning.size_weights.size(), tuning.size_scales.size()) - 1


## What it adds to the waddle's weight (nothing while it's still an egg).
func weight() -> float:
	return tuning.size_weights[_size] if _hatched else 0.0


func is_hatched() -> bool:
	return _hatched


## Hungry: hatched and not full grown.
func wants_food() -> bool:
	return _hatched and not _lost and _size < max_size()


## Lost (its berg broke up), or on the way to it.
func is_lost() -> bool:
	return _lost


## Feedings until it grows next.
func feedings_to_grow() -> int:
	return maxi(tuning.feedings_per_size * (_size + 1) - feedings, 0) if wants_food() else 0


## Where its beak is, for a meal to go into.
func beak_position() -> Vector3:
	return _model.to_global(Vector3(0.0, 0.62, -0.22))


## Where it wanders round, in world space.
func home_spot() -> Vector3:
	var parent := get_parent() as Node3D
	return parent.to_global(_home) if parent != null else _home


# --- Doing things ---------------------------------------------------------------

## Feeds it (a parent's beakful): it gulps it down, and every feedings_per_size feedings it grows
## a size. False if it isn't hungry (an egg, or full grown).
func feed() -> bool:
	if not wants_food():
		return false
	feedings += 1
	ate.emit()
	var gulp := create_tween()
	gulp.tween_property(self, "_gulp", 1.0, 0.1)
	gulp.tween_property(self, "_gulp", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if feedings >= tuning.feedings_per_size * (_size + 1):
		_size += 1
		_dress()
		_pop = 0.8
		create_tween().tween_property(self, "_pop", 1.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		grew.emit(_size)
	return true


## Hatches straight away (the egg is skipped; for levels and tests).
func hatch_now() -> void:
	if _hatched:
		return
	_hatched = true
	_egg.visible = false
	_model.visible = true
	_shell.global_position = global_position + Vector3.UP * 0.15
	_shell.restart()
	_pop = 0.05
	create_tween().tween_property(self, "_pop", 1.0, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	hatched.emit()


## Falling into the sea, `t` of the way (0 to 1): up, over and down under the water.
func _tumble(t: float, from: Vector3, to: Vector3) -> void:
	var at := from.lerp(to, t)
	at.y = lerpf(from.y, to.y, t * t) + sin(t * PI) * 1.2
	global_position = at
	rotation = Vector3(0.0, 0.0, t * TAU * 1.5)
	if _hatched:
		_pose(get_physics_process_delta_time())


## A bounce `height` high (m) over `seconds`, flippers going (the ice burst under it).
func hop(height: float, seconds: float) -> void:
	var up := create_tween()
	up.tween_property(self, "_hop", height, seconds * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	up.tween_property(self, "_hop", 0.0, seconds * 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_flap = seconds


## Lost: the ice gives way under it and it tumbles into the sea, flapping, and is gone (it can't swim
## yet). Emits lost straight away; the chick frees itself once it's gone under.
func lose() -> void:
	if _lost:
		return
	_lost = true
	begging_from = null
	lost.emit()
	var a := randf() * TAU
	var from := global_position
	var to := from + Vector3(cos(a), 0.0, sin(a)) * randf_range(1.0, 3.0)
	to.y = GameWorld.WATER_LEVEL - 1.0
	_flap = 1.2
	var fall := create_tween()
	fall.tween_method(_tumble.bind(from, to), 0.0, 1.0, 1.1)
	fall.tween_callback(queue_free)


## Rides `ice` from now on (a piece of the broken berg): it moves with it and wanders round where
## it is now, on it.
func ride(ice: Node3D) -> void:
	reparent(ice)
	_home = position
	_goal = position


# --- Inside ----------------------------------------------------------------------

## The nearest penguin standing on the ice within beg_range that would feed it now, if it's
## hungry.
func _find_parent() -> Penguin:
	if not wants_food():
		return null
	var best: Penguin = null
	var best_d := tuning.beg_range
	var group := &"penguins" if would_feed.is_valid() else &"player"
	for node in get_tree().get_nodes_in_group(group):
		var p := node as Penguin
		if p == null or not p.is_inside_tree() or p.state != Penguin.State.WALK:
			continue
		var d := p.global_position.distance_to(global_position)
		if d >= best_d:
			continue
		if would_feed.is_valid():
			if not would_feed.call(p):
				continue
		elif p.energy < tuning.feed_min_energy + tuning.feed_energy and not p.infinite_energy:
			continue
		if d < best_d:
			best_d = d
			best = p
	return best


func _goal_global() -> Vector3:
	if begging_from != null and is_instance_valid(begging_from):
		return begging_from.global_position
	var parent := get_parent() as Node3D
	return parent.to_global(_goal) if parent != null else _goal


func _pick_wander_spot() -> void:
	_wander_left = randf_range(2.5, 6.0)
	var a := randf() * TAU
	_goal = _home + Vector3(cos(a), 0.0, sin(a)) * randf_range(0.0, tuning.wander)


func _walk_speed() -> float:
	# Bigger legs, a little quicker.
	return tuning.walk_speed * (0.75 + 0.25 * _size)


func _scale() -> float:
	return tuning.size_scales[_size]


## Ice under `point` (world), close below it (m), or not.
func _ice_under(point: Vector3) -> bool:
	return not _ground(point).is_empty()


func _ground(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.2, point + Vector3.DOWN * 1.5, GameWorld.WORLD_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit["position"] as Vector3).y < GameWorld.WATER_LEVEL - 0.05:
		return {}
	return hit


## Feet on the ice under it (or bobbing at the surface, if there's none).
func _snap_to_ice() -> void:
	var hit := _ground(global_position)
	var y := (hit["position"] as Vector3).y if not hit.is_empty() else GameWorld.WATER_LEVEL
	global_position.y = y


## Waddling, begging, gulping, hopping.
func _pose(delta: float) -> void:
	_flap = maxf(_flap - delta, 0.0)
	var s := _scale() * _pop
	var bob := 0.0
	var rock := 0.0
	var lean := 0.0
	if _walking:
		rock = sin(_clock * 13.0) * 0.16
		bob = absf(sin(_clock * 13.0)) * 0.025
	elif begging_from != null:
		# Peep peep: little bounces, head up, flippers going.
		bob = maxf(sin(_clock * 9.0), 0.0) * 0.06
		lean = -0.25
		_flap = maxf(_flap, 0.1)
	lean -= 0.3 * _gulp
	_model.position = Vector3(0.0, bob * s + _hop, 0.0)
	_model.basis = Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, lean) * Basis(Vector3.BACK, rock) \
			* Basis.from_scale(Vector3(s * (1.0 + 0.12 * _gulp), s * (1.0 + 0.1 * _gulp), s * (1.0 + 0.12 * _gulp)))
	var flap := 0.0 if _flap <= 0.0 else 0.5 + 0.5 * sin(_clock * 26.0)
	for i in _flippers.size():
		var side := -1.0 if i == 0 else 1.0
		_flippers[i].rotation = Vector3(0.0, 0.0, side * (0.25 + 0.9 * flap))


# --- The look --------------------------------------------------------------------

func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	_body = _sphere(_model, "Body", 0.3, Vector3(0.0, 0.3, 0.0), _down(), Vector3(1.0, 1.0, 0.95))
	_sphere(_model, "Head", 0.19, Vector3(0.0, 0.66, 0.0), CAP)
	_sphere(_model, "Face", 0.16, Vector3(0.0, 0.645, -0.085), FACE, Vector3(1.05, 0.72, 0.6))
	for side: float in [-1.0, 1.0]:
		_sphere(_model, "Eye", 0.028, Vector3(0.065 * side, 0.675, -0.18), CAP)
		_box(_model, "Foot", Vector3(0.08, 0.025, 0.11), Vector3(0.08 * side, 0.012, -0.06), FEET)
		var pivot := Node3D.new()
		pivot.name = "Flipper"
		pivot.position = Vector3(0.27 * side, 0.44, 0.0)
		_model.add_child(pivot)
		_box(pivot, "Mesh", Vector3(0.04, 0.2, 0.09), Vector3(0.0, -0.1, 0.0), DOWN_DARK)
		_flippers.append(pivot)
	var beak := MeshInstance3D.new()
	beak.name = "Beak"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.035
	cone.height = 0.1
	cone.radial_segments = 8
	cone.material = _material(CAP)
	beak.mesh = cone
	beak.position = Vector3(0.0, 0.62, -0.2)
	beak.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_model.add_child(beak)
	# Fluffy: tufts of down sticking out. Fledgling: a fat white front coming through.
	_tufts = Node3D.new()
	_tufts.name = "Tufts"
	_model.add_child(_tufts)
	for spot: Vector3 in [Vector3(0.0, 0.84, 0.02), Vector3(-0.2, 0.42, 0.1), Vector3(0.21, 0.36, 0.08), Vector3(0.0, 0.5, 0.24), Vector3(-0.12, 0.15, -0.2)]:
		_sphere(_tufts, "Tuft", 0.07, spot, _down())
	_front = _sphere(_model, "Front", 0.24, Vector3(0.0, 0.3, -0.1), FACE, Vector3(1.0, 1.1, 0.8))
	_shell = _make_shell_burst()
	_dress()


## Its tufts and front for its size.
func _dress() -> void:
	_tufts.visible = _size == 1
	_front.visible = _size >= 2
	_body.scale = Vector3(1.0, 1.0, 0.95) * (Vector3(1.32, 1.08, 1.32) if _size >= 2 else Vector3.ONE)


func _build_egg() -> void:
	_egg = Node3D.new()
	_egg.name = "Egg"
	add_child(_egg)
	_sphere(_egg, "Shell", 0.14, Vector3(0.0, 0.17, 0.0), EGG.lerp(tint, 0.2) if tint.a > 0.0 else EGG, Vector3(0.82, 1.15, 0.82))


## Bits of shell flying off as it hatches.
func _make_shell_burst() -> CPUParticles3D:
	var bit := BoxMesh.new()
	bit.size = Vector3(0.05, 0.012, 0.04)
	bit.material = _material(EGG)
	var burst := CPUParticles3D.new()
	burst.name = "Shell"
	burst.emitting = false
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.amount = 14
	burst.lifetime = 0.8
	burst.mesh = bit
	burst.direction = Vector3.UP
	burst.spread = 60.0
	burst.gravity = Vector3(0.0, -7.0, 0.0)
	burst.initial_velocity_min = 1.0
	burst.initial_velocity_max = 2.2
	burst.angular_velocity_min = -400.0
	burst.angular_velocity_max = 400.0
	burst.top_level = true
	add_child(burst)
	return burst


func _sphere(parent: Node3D, node_name: String, radius: float, at: Vector3, colour: Color, stretch := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = _material(colour)
	var view := MeshInstance3D.new()
	view.name = node_name
	view.mesh = mesh
	view.position = at
	view.scale = stretch
	parent.add_child(view)
	return view


func _box(parent: Node3D, node_name: String, box_size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = _material(colour)
	var view := MeshInstance3D.new()
	view.name = node_name
	view.mesh = mesh
	view.position = at
	parent.add_child(view)
	return view


## Its down: grey, with a hint of its family's colour.
func _down() -> Color:
	return DOWN.lerp(Color(tint, 1.0), 0.45) if tint.a > 0.0 else DOWN


static func _material(colour: Color) -> StandardMaterial3D:
	if not _materials.has(colour):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colour
		mat.roughness = 0.95
		_materials[colour] = mat
	return _materials[colour]
