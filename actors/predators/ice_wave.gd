class_name IceWave
extends Node3D
## A swell that a pod pushes ahead of itself, and its crash over the ice edge (GDD §5.3).
## Looks only: the pod decides who gets washed off. It builds its own mesh (a long, rounded ridge
## of water, half under the surface), so it needs no scene.

const MATERIAL := preload("res://art/materials/wave.tres")

## Scaled to the swell's width, height and depth.
var _body: Node3D
var _mesh: MeshInstance3D


func _ready() -> void:
	var ridge := CapsuleMesh.new()
	ridge.radius = 0.5
	ridge.height = 1.0
	ridge.material = MATERIAL
	_mesh = MeshInstance3D.new()
	_mesh.mesh = ridge
	_mesh.rotation = Vector3(0.0, 0.0, PI / 2.0) # lying along the swell's width
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body = Node3D.new()
	_body.add_child(_mesh)
	add_child(_body)


## Puts the swell's crest at `crest` (on the water), moving along `travel`, this wide and this
## high above the surface.
func shape(crest: Vector3, travel: Vector3, width: float, height: float) -> void:
	var flat := Vector3(travel.x, 0.0, travel.z)
	if flat.length() < 0.01:
		return
	global_transform = Transform3D(Basis.looking_at(flat, Vector3.UP), Vector3(crest.x, Penguin.WATER_LEVEL, crest.z))
	_body.scale = Vector3(width, height * 2.0, 2.0 + height)


## Breaks: surges forward over the edge, rises and fades out, then it's gone.
func crash(travel: Vector3, distance := 3.0) -> void:
	var flat := Vector3(travel.x, 0.0, travel.z).normalized()
	var tween := create_tween().set_parallel()
	tween.tween_property(self, ^"global_position", global_position + flat * distance + Vector3.UP * 0.5, 0.5)
	tween.tween_property(_body, ^"scale", _body.scale * Vector3(1.1, 1.2, 1.8), 0.5)
	tween.tween_property(_mesh, ^"transparency", 1.0, 0.6)
	tween.chain().tween_callback(queue_free)


## Called off: sinks back into the sea.
func subside() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(self, ^"global_position", global_position + Vector3.DOWN * 1.5, 0.6)
	tween.tween_property(_mesh, ^"transparency", 1.0, 0.6)
	tween.chain().tween_callback(queue_free)
