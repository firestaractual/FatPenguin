@tool
class_name IcePlateau
extends StaticBody3D
## A raised plateau on the iceberg, built from plain boxes so every slope and step is a number
## you can tune in the Inspector (it rebuilds live in the editor).
##
## Ways down are chutes: steeper than tuning.walk_max_slope_deg, so you can't stand on them and
## slide instead. Ways up are ledges: walk into one and you hop it, if your belly lets you.
##   South: long, gentle chute.        West:  short, steep chute.
##   East:  small steps anyone can hop, even when stuffed.
##   North: big steps only a thin-ish penguin can hop (the shortcut).
## Everywhere else the plateau edge is a sheer drop.
##
## Local space: the plateau sits on a surface at y = 0, its top is centred on the origin, and +Z is south.

@export var ice_material: Material:
	set(value):
		ice_material = value
		_queue_rebuild()
## Chutes get their own (glossier) material so slippery slopes read at a glance.
@export var chute_material: Material:
	set(value):
		chute_material = value
		_queue_rebuild()
## Footprint of the top (x by z).
@export var top_size := Vector2(16.0, 12.0):
	set(value):
		top_size = value
		_queue_rebuild()
@export var height := 2.0:
	set(value):
		height = value
		_queue_rebuild()
## Everything extends this far below y = 0 so there's no seam with the ice underneath.
@export var sink := 0.5:
	set(value):
		sink = value
		_queue_rebuild()

@export_group("Chutes")
@export var south_chute_angle_deg := 18.0:
	set(value):
		south_chute_angle_deg = value
		_queue_rebuild()
@export var south_chute_width := 6.0:
	set(value):
		south_chute_width = value
		_queue_rebuild()
@export var west_chute_angle_deg := 28.0:
	set(value):
		west_chute_angle_deg = value
		_queue_rebuild()
@export var west_chute_width := 5.0:
	set(value):
		west_chute_width = value
		_queue_rebuild()

@export_group("Steps")
## Target rise of each east step; the real rise is height / round(height / this).
@export var east_step_rise := 0.4:
	set(value):
		east_step_rise = value
		_queue_rebuild()
@export var east_step_depth := 1.2:
	set(value):
		east_step_depth = value
		_queue_rebuild()
@export var east_step_width := 6.0:
	set(value):
		east_step_width = value
		_queue_rebuild()
@export var north_step_rise := 0.667:
	set(value):
		north_step_rise = value
		_queue_rebuild()
@export var north_step_depth := 1.4:
	set(value):
		north_step_depth = value
		_queue_rebuild()
@export var north_step_width := 6.0:
	set(value):
		north_step_width = value
		_queue_rebuild()

const CHUTE_THICKNESS := 1.0
## Chutes run on a little past the bottom so they tuck under the ice instead of leaving a lip.
const CHUTE_OVERRUN := 0.4

var _rebuild_queued := false


func _ready() -> void:
	_rebuild()


# --- Handy positions (world space), used by the smoke test -------------------

func top_y() -> float:
	return to_global(Vector3(0.0, height, 0.0)).y


## On top, just behind the head of the south chute.
func south_chute_head() -> Vector3:
	return to_global(Vector3(0.0, height, top_size.y * 0.5 - 1.0))


## On the ice in front of the lowest east step.
func east_steps_foot() -> Vector3:
	return to_global(Vector3(top_size.x * 0.5 + east_step_count() * east_step_depth + 1.0, 0.0, 0.0))


## On the ice in front of the lowest north step.
func north_steps_foot() -> Vector3:
	return to_global(Vector3(0.0, 0.0, -top_size.y * 0.5 - north_step_count() * north_step_depth - 1.0))


func east_step_count() -> int:
	return maxi(roundi(height / east_step_rise), 1) - 1


func north_step_count() -> int:
	return maxi(roundi(height / north_step_rise), 1) - 1


func east_rise() -> float:
	return height / (east_step_count() + 1)


func north_rise() -> float:
	return height / (north_step_count() + 1)


# --- Building ----------------------------------------------------------------

func _queue_rebuild() -> void:
	if not is_node_ready() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.queue_free()

	var half := top_size * 0.5

	# The top.
	_add_box("Top", Vector3(top_size.x, height + sink, top_size.y),
		Transform3D(Basis.IDENTITY, Vector3(0.0, (height - sink) * 0.5, 0.0)), ice_material)

	# Chutes: (lateral, normal, down-slope) basis, top edge flush with the plateau edge.
	_add_chute("ChuteSouth", Vector3(0.0, height, half.y), Vector3.BACK, south_chute_angle_deg, south_chute_width)
	_add_chute("ChuteWest", Vector3(-half.x, height, 0.0), Vector3.LEFT, west_chute_angle_deg, west_chute_width)

	# Steps rise toward the plateau. Each box runs all the way back to the plateau wall.
	var east_n := east_step_count()
	for k in range(1, east_n + 1):
		var rise := east_rise() * k
		var reach := (east_n - k + 1) * east_step_depth
		_add_box("StepEast%d" % k, Vector3(reach, rise + sink, east_step_width),
			Transform3D(Basis.IDENTITY, Vector3(half.x + reach * 0.5, (rise - sink) * 0.5, 0.0)), ice_material)
	var north_n := north_step_count()
	for k in range(1, north_n + 1):
		var rise := north_rise() * k
		var reach := (north_n - k + 1) * north_step_depth
		_add_box("StepNorth%d" % k, Vector3(north_step_width, rise + sink, reach),
			Transform3D(Basis.IDENTITY, Vector3(0.0, (rise - sink) * 0.5, -half.y - reach * 0.5)), ice_material)


func _add_chute(chute_name: String, top_edge: Vector3, outward: Vector3, angle_deg: float, width: float) -> void:
	var a := deg_to_rad(clampf(angle_deg, 5.0, 60.0))
	var down := (outward * cos(a) + Vector3.DOWN * sin(a)).normalized()
	var normal := (outward * sin(a) + Vector3.UP * cos(a)).normalized()
	var lateral := normal.cross(down).normalized()
	var length := height / sin(a) + CHUTE_OVERRUN
	var centre := top_edge + down * (length * 0.5) - normal * (CHUTE_THICKNESS * 0.5)
	var mat := chute_material if chute_material else ice_material
	_add_box(chute_name, Vector3(width, CHUTE_THICKNESS, length), Transform3D(Basis(lateral, normal, down), centre), mat)


func _add_box(piece_name: String, size: Vector3, xform: Transform3D, mat: Material) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.name = piece_name
	col.shape = shape
	col.transform = xform
	col.set_meta(&"generated", true)
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var view := MeshInstance3D.new()
	view.name = "Mesh"
	view.mesh = mesh
	col.add_child(view)
	# No owner on purpose: the pieces are rebuilt from the numbers above, never saved into the scene.
	add_child(col)
