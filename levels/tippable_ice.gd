class_name TippableIce
extends Node3D
## A piece of ice that predators can tip (RamAttack). Put this node at the middle of the piece, at
## the waterline, and list the bodies that make it up: they tip together around this point (the
## berg is several bodies: the ice, the plateau, the ramp).
##
## Penguins standing on it feel the slope. Steeper than they can stand on (walk_max_slope_deg),
## they slip onto their bellies and slide off the low side, unless they dig in (pull back) and
## hold on until it rights itself. A gentle rock just speeds up anyone already sliding.

## The bodies that make up this piece of ice.
@export var bodies: Array[NodePath] = []
## How far the piece reaches from its middle (m). Bigger ice tips less (RamAttackTuning).
@export var radius := 4.0

## Every tippable piece, by the instance id of each of its bodies.
static var _by_body := {}

## Each body's transform relative to this node, at rest.
var _rest := {}
var _axis := Vector3.RIGHT
var _amplitude := 0.0
var _angle := 0.0
var _time := 0.0
var _in := 0.3
var _hold := 2.0
var _out := 1.0
var _tipping := false


func _ready() -> void:
	add_to_group(&"tippable_ice")
	for path in bodies:
		var body := get_node_or_null(path) as Node3D
		if body == null:
			continue
		_rest[body] = global_transform.affine_inverse() * body.global_transform
		_by_body[body.get_instance_id()] = self


func _exit_tree() -> void:
	for body: Variant in _rest.keys():
		if is_instance_valid(body):
			_by_body.erase((body as Node3D).get_instance_id())


## The tippable piece of ice right under `point`, or null.
static func under(world: World3D, point: Vector3) -> TippableIce:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.5, point + Vector3.DOWN * 3.0, Penguin.WORLD_LAYER)
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var collider := hit["collider"] as Object
	return _by_body.get(collider.get_instance_id()) if collider != null else null


## Tips the piece so its edge in direction `toward` goes down by `degrees`: over `in_seconds`,
## then it stays tipped for `hold_seconds` and rights itself over `out_seconds`. Ignored while
## it's already tipping.
func tip(toward: Vector3, degrees: float, in_seconds: float, hold_seconds: float, out_seconds: float) -> void:
	var flat := Vector3(toward.x, 0.0, toward.z)
	if _tipping or flat.length() < 0.01:
		return
	_axis = Vector3.UP.cross(flat.normalized()).normalized()
	_amplitude = deg_to_rad(degrees)
	_in = maxf(in_seconds, 0.01)
	_hold = hold_seconds
	_out = maxf(out_seconds, 0.01)
	_time = 0.0
	_tipping = true


func is_tipping() -> bool:
	return _tipping


## How far it's tipped right now (degrees).
func tilt_degrees() -> float:
	return rad_to_deg(_angle)


func _physics_process(delta: float) -> void:
	if not _tipping:
		return
	_time += delta
	if _time < _in:
		_angle = _amplitude * smoothstep(0.0, 1.0, _time / _in)
	elif _time < _in + _hold:
		_angle = _amplitude
	elif _time < _in + _hold + _out:
		_angle = _amplitude * (1.0 - smoothstep(0.0, 1.0, (_time - _in - _hold) / _out))
	else:
		_angle = 0.0
		_tipping = false
	var turn := Transform3D(Basis(_axis, _angle), Vector3.ZERO)
	for body: Node3D in _rest:
		body.global_transform = global_transform * turn * _rest[body]
