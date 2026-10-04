class_name BubbleWall
extends Node3D
## A ring of bubbles an orca pod blows around a penguin (CarouselAttack): a curtain of bubbles
## rising from below, and a ring of foam where it reaches the surface. Looks only: the attack
## decides what the bubbles do to penguins. It builds its own particles and mesh, so it needs no
## scene.

const FOAM_MATERIAL := preload("res://art/materials/wave.tres")
## Bubbles start between these depths (m) and rise about 1.4 m before they pop, so the curtain
## reaches the surface without spraying into the air.
const CURTAIN_BOTTOM := 4.6
const CURTAIN_TOP := 1.2

var _bubbles: CPUParticles3D
var _foam: MeshInstance3D
var _radius := 10.0


func _ready() -> void:
	top_level = true
	var bubble := SphereMesh.new()
	bubble.radius = 0.07
	bubble.height = 0.14
	bubble.radial_segments = 6
	bubble.rings = 3
	bubble.material = FOAM_MATERIAL
	_bubbles = CPUParticles3D.new()
	_bubbles.amount = 500
	_bubbles.lifetime = 1.2
	_bubbles.mesh = bubble
	_bubbles.local_coords = false
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_bubbles.emission_ring_axis = Vector3.UP
	_bubbles.emission_ring_height = CURTAIN_BOTTOM - CURTAIN_TOP
	_bubbles.direction = Vector3.UP
	_bubbles.spread = 8.0
	_bubbles.gravity = Vector3.ZERO
	_bubbles.initial_velocity_min = 0.8
	_bubbles.initial_velocity_max = 1.2
	_bubbles.scale_amount_min = 0.6
	_bubbles.scale_amount_max = 1.6
	_bubbles.position = Vector3(0.0, -(CURTAIN_BOTTOM + CURTAIN_TOP) * 0.5, 0.0)
	add_child(_bubbles)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.92
	ring.outer_radius = 1.0
	ring.rings = 48
	ring.material = FOAM_MATERIAL
	_foam = MeshInstance3D.new()
	_foam.mesh = ring
	_foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_foam)
	set_ring(global_position, _radius)


## Centres the ring on `centre` (on the water), `radius` across.
func set_ring(centre: Vector3, radius: float) -> void:
	_radius = radius
	global_position = Vector3(centre.x, Penguin.WATER_LEVEL, centre.z)
	if _bubbles == null:
		return
	_bubbles.emission_ring_radius = radius
	_bubbles.emission_ring_inner_radius = maxf(radius - 0.4, 0.0)
	_foam.scale = Vector3(radius, 0.4, radius)


## The bubbles stop and the foam fades, then it's gone.
func fade(seconds := 1.5) -> void:
	_bubbles.emitting = false
	var tween := create_tween()
	tween.tween_property(_foam, ^"transparency", 1.0, seconds)
	tween.tween_interval(_bubbles.lifetime)
	tween.tween_callback(queue_free)
