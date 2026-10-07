@tool
class_name DomeBerg
extends IceBerg
## A dome berg: smooth and rounded, steeper all round than you can stand on, so it's one big
## chute: land anywhere on it and you slide back into the sea. Draft about 4 × its height. The
## one way up is a stair of small ledges worn into its east side, from the water to the flat cap
## on top, where you can see across the field. From there, every way down is a slide.

@export var base_radius := 14.0:
	set(value):
		base_radius = value
		queue_rebuild()
@export var top_radius := 4.0:
	set(value):
		top_radius = value
		queue_rebuild()
@export var height := 4.0:
	set(value):
		height = value
		queue_rebuild()
## Real dome bergs: draft about 4 × the height above water.
@export var draft_ratio := 4.0:
	set(value):
		draft_ratio = value
		queue_rebuild()
@export var stair_width := 2.5:
	set(value):
		stair_width = value
		queue_rebuild()
@export var step_rise := 0.42:
	set(value):
		step_rise = value
		queue_rebuild()


func reach() -> float:
	return base_radius


func top_height() -> float:
	return height


func waddle_spot() -> Vector3:
	return to_global(Vector3(0.0, height, 0.0))


func exits() -> Array[Dictionary]:
	# Launch onto the first ledge of the stair.
	return [exit_at(Vector3(base_radius, 0.0, 0.0), Vector3.LEFT, 4.5, true)]


## How steep the sides are (degrees).
func side_angle() -> float:
	return rad_to_deg(atan((height + 0.5) / maxf(base_radius - top_radius, 0.1)))


func _build() -> void:
	frustum("Dome", base_radius, top_radius, height + 0.5, -0.5)
	cylinder("Keel", base_radius, -draft_for(height, draft_ratio), -0.4, KEEL)
	# The stair: ledges cut into the east side, from the waterline to the cap.
	var count := maxi(roundi(height / step_rise), 1)
	var depth := (base_radius - top_radius) / count
	steps("Stair", Vector3(base_radius, 0.0, 0.0), Vector3.LEFT, height, step_rise, depth, stair_width)
