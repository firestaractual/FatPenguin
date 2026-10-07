@tool
class_name FloeChain
extends Node3D
## A line of small floes (pack ice: bits of sea ice, growlers and bergy bits) from `start` to
## `end`, with gaps between them to hop. Each floe is its own body, so a ram can tip each one. Thin
## penguins hop every gap (1.5 m); fat ones only the narrow ones (0.6 m when stuffed), so the
## chain is a thin penguin's shortcut, as GDD §4.10 has it.
##
## Local space: the waterline is y = 0.

const ICE := preload("res://art/materials/ice.tres")
const KEEL := preload("res://art/materials/ice_keel.tres")

## Where the chain starts and ends (local, on the waterline).
@export var start := Vector3.ZERO:
	set(value):
		start = value
		_queue_rebuild()
@export var end := Vector3(40.0, 0.0, 0.0):
	set(value):
		end = value
		_queue_rebuild()
## The gaps between floes, in order (m). Floes are sized to fill the distance between them.
@export var gaps: PackedFloat32Array = [0.5, 0.9, 1.2, 0.6, 1.4, 0.8]:
	set(value):
		gaps = value
		_queue_rebuild()
## How high each floe stands above the water (m), in order; the last one repeats.
@export var heights: PackedFloat32Array = [0.6, 0.5, 0.8, 0.4, 0.7, 0.5, 0.6]:
	set(value):
		heights = value
		_queue_rebuild()
## Sea ice: a few times as thick below the water as it stands above (m).
@export var draft := 2.0:
	set(value):
		draft = value
		_queue_rebuild()

var _floes: Array[StaticBody3D] = []
var _rebuild_queued := false


func _ready() -> void:
	_rebuild()


## The floes, in order from start to end.
func floes() -> Array[StaticBody3D]:
	return _floes


## Every floe's radius (they're all the same size, to fill the distance).
func floe_radius() -> float:
	return _radius()


func _radius() -> float:
	var length := Vector2(end.x - start.x, end.z - start.z).length()
	var gap_total := 0.0
	for g in gaps:
		gap_total += g
	var count := gaps.size() + 1
	return maxf((length - gap_total) / (2.0 * count), 1.0)


func _queue_rebuild() -> void:
	if not is_node_ready() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	for floe in _floes:
		if is_instance_valid(floe):
			remove_child(floe)
			floe.queue_free()
	_floes.clear()
	var flat := Vector3(end.x - start.x, 0.0, end.z - start.z)
	if flat.length() < 0.1:
		return
	var dir := flat.normalized()
	var r := _radius()
	var at := Vector3(start.x, 0.0, start.z) + dir * r
	for i in gaps.size() + 1:
		var h := heights[mini(i, heights.size() - 1)] if not heights.is_empty() else 0.5
		_floes.append(_make_floe(i, at, r, h))
		if i < gaps.size():
			at += dir * (2.0 * r + gaps[i])


func _make_floe(i: int, at: Vector3, r: float, h: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Floe%d" % i
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h + draft
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, (h - draft) * 0.5, 0.0)
	body.add_child(col)
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = h + draft
	mesh.radial_segments = 24
	mesh.material = ICE
	var view := MeshInstance3D.new()
	view.mesh = mesh
	col.add_child(view)
	add_child(body)
	return body
