@tool
class_name HomeFloe
extends IceBerg
## The movement toy's original ice, the big round floe with the plateau and the ramp. Its shape
## is in the scene (Iceberg, Plateau, Ramp); this node only answers the berg questions for it, so
## predators, fish and the colony treat it like the other bergs. Keep it at the floe's middle, at
## the waterline.

@export var radius := 30.0
@export var height := 1.0
## Where the colony huddles (local): open ice clear of the plateau, the ramp and the dummies.
@export var waddle_offset := Vector3(16.0, 0.0, -16.0)
## The ramp's foot (local, on the waterline) and the way up it.
@export var ramp_foot := Vector3(38.5, 0.0, 0.0)
@export var ramp_dir := Vector3(-1.0, 0.0, 0.0)
## Where the ramp comes out on the floe's top (local).
@export var ramp_top := Vector3(26.5, 0.0, 0.0)


func reach() -> float:
	return radius


func top_height() -> float:
	return height


func waddle_spot() -> Vector3:
	return to_global(waddle_offset + Vector3.UP * height)


func exits() -> Array[Dictionary]:
	var ramp := exit_at(ramp_foot, ramp_dir, 3.5, false)
	ramp["climb"] = [to_global(ramp_top + Vector3.UP * height)]
	var list: Array[Dictionary] = [ramp]
	# The edge is low enough to launch onto from anywhere. These spots are on the east side, with
	# a clear walk to the colony (the plateau is in the way from the west).
	for angle_deg in [-75.0, -40.0, 35.0, 70.0]:
		var a := deg_to_rad(angle_deg)
		var edge := Vector3(cos(a), 0.0, sin(a)) * radius
		list.append(exit_at(edge, -edge.normalized(), 4.5, true))
	return list
