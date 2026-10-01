class_name FollowCamera
extends Camera3D
## Third-person follow camera for the penguin.
## Water: behind and slightly above, tilting with the swim pitch, pulling back as speed rises.
## Ice: higher and further back so you can read the edges.
## Also switches the world's fog on underwater.

@export var target_path: NodePath
@export_group("Framing")
@export var swim_distance := 3.2
@export var swim_height := 0.8
@export var ice_distance := 4.0
@export var ice_height := 2.0
## Extra distance per m/s of speed.
@export var speed_pullback := 0.25
## How much of the swim pitch the camera follows (0 = stays level, 1 = full).
@export var pitch_follow := 0.5
@export var smoothing := 6.0
@export_group("Underwater look")
@export var underwater_fog_color := Color(0.05, 0.25, 0.38)
@export var underwater_fog_density := 0.06

var _target: Penguin
var _env: Environment
var _surface_fog_enabled := false
var _surface_fog_color := Color.WHITE
var _surface_fog_density := 0.0
var _surface_fog_sky_affect := 0.0


func _ready() -> void:
	# Moved in _process from an interpolated target, so skip interpolating the camera itself.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_target = get_node_or_null(target_path) as Penguin
	_env = get_world_3d().environment
	if _env:
		_surface_fog_enabled = _env.fog_enabled
		_surface_fog_color = _env.fog_light_color
		_surface_fog_density = _env.fog_density
		_surface_fog_sky_affect = _env.fog_sky_affect
	if _target:
		global_position = _desired_position(_target.global_position)


func _process(delta: float) -> void:
	if _target == null:
		return
	var target_pos := _target.get_global_transform_interpolated().origin
	var desired := _desired_position(target_pos)
	desired = _avoid_clipping(target_pos, desired)
	global_position = global_position.lerp(desired, 1.0 - exp(-smoothing * delta))

	var look_at_point := target_pos + _target.get_heading() * 2.0 + Vector3.UP * 0.4
	if global_position.distance_squared_to(look_at_point) > 0.01:
		look_at(look_at_point, Vector3.UP)
	_update_underwater()


func _desired_position(target_pos: Vector3) -> Vector3:
	var swimming := _target.state == Penguin.State.SWIM
	var dir := _target.get_facing()
	if swimming:
		var heading := _target.get_heading()
		dir = dir.lerp(heading, pitch_follow).normalized()
	var distance := (swim_distance if swimming else ice_distance) + _target.get_speed() * speed_pullback
	var height := swim_height if swimming else ice_height
	return target_pos - dir * distance + Vector3.UP * height


## Keep the camera from ending up inside the iceberg.
func _avoid_clipping(from: Vector3, to: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [_target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return to
	return hit.position + hit.normal * 0.3


func _update_underwater() -> void:
	if _env == null:
		return
	var under := global_position.y < Penguin.WATER_LEVEL
	_env.fog_enabled = under or _surface_fog_enabled
	_env.fog_light_color = underwater_fog_color if under else _surface_fog_color
	_env.fog_density = underwater_fog_density if under else _surface_fog_density
	# Underwater the background is murky blue, not sky.
	_env.fog_sky_affect = 1.0 if under else _surface_fog_sky_affect
