@tool
class_name DrydockBerg
extends IceBerg
## A drydock berg: eroded into a U, two towers joined at the back and below the water, with a
## channel of water between them open to the sea at the front (-z). Draft only about 1 × its
## height. The channel's floor is the shared ice below, so the water in it is shallow: a sheltered
## lagoon where an orca can't swim (it's too shallow for one), though a leopard seal can.
##
## At the back of the lagoon a gentle shelf climbs out of the water, and steps go up the back wall
## to the top. An ice bridge spans the mouth between the two towers: walk across it, or swim under.

## Each tower, x by z (m), and the channel between them.
@export var tower_size := Vector2(5.0, 20.0):
	set(value):
		tower_size = value
		queue_rebuild()
@export var channel_width := 6.0:
	set(value):
		channel_width = value
		queue_rebuild()
@export var height := 2.5:
	set(value):
		height = value
		queue_rebuild()
## Real drydock bergs: draft about 1 × the height above water.
@export var draft_ratio := 1.0:
	set(value):
		draft_ratio = value
		queue_rebuild()
## How deep the lagoon is (m). An orca (2 m across) can't swim in water this shallow; a leopard
## seal (1.2 m) can.
@export var lagoon_depth := 1.3:
	set(value):
		lagoon_depth = value
		queue_rebuild()
## The back wall joining the towers (m along z).
@export var back_wall := 3.0:
	set(value):
		back_wall = value
		queue_rebuild()
## The bridge across the mouth: how deep (along z) and how thick (m).
@export var bridge_depth := 2.5:
	set(value):
		bridge_depth = value
		queue_rebuild()
@export var bridge_thickness := 0.8:
	set(value):
		bridge_thickness = value
		queue_rebuild()

## The shelf at the back of the lagoon climbs out of the water at this angle, to this high (m).
const SHELF_ANGLE := 10.0
const SHELF_TOP := 0.35
const SHELF_FOOT := 1.0


func reach() -> float:
	return Vector2(channel_width * 0.5 + tower_size.x, tower_size.y * 0.5).length()


func top_height() -> float:
	return height


func waddle_spot() -> Vector3:
	return to_global(Vector3(-(channel_width + tower_size.x) * 0.5, height, 0.0))


func exits() -> Array[Dictionary]:
	# Swim in through the mouth, up the lagoon, onto the shelf.
	var shelf_foot := _shelf_foot()
	var exit := exit_at(Vector3(0.0, 0.0, shelf_foot.z), Vector3.BACK, shelf_foot.z + tower_size.y * 0.5 + 2.0, false)
	# Across the shelf, up the steps, onto the back wall.
	var back := tower_size.y * 0.5 - back_wall
	exit["climb"] = [to_global(Vector3(0.0, SHELF_TOP, back - 3.6)), to_global(Vector3(0.0, height, back + 1.5))]
	return [exit]


## The lagoon, as a swim route: from just outside the mouth to the shelf.
func tunnels() -> Array[Dictionary]:
	var z0 := -tower_size.y * 0.5
	return [{"from": to_global(Vector3(0.0, -0.4, z0 - 1.5)), "to": to_global(Vector3(0.0, -0.4, _shelf_foot().z)),
		"width": channel_width, "height": lagoon_depth, "swim": true, "lagoon": true}]


func _build() -> void:
	var draft := draft_for(height, draft_ratio)
	var half_c := channel_width * 0.5
	var outer := half_c + tower_size.x
	var z0 := -tower_size.y * 0.5
	var z1 := tower_size.y * 0.5
	var back := z1 - back_wall
	# The towers and the back wall, from the keel up.
	box_between("TowerWest", Vector3(-outer, -draft, z0), Vector3(-half_c, height, z1))
	box_between("TowerEast", Vector3(half_c, -draft, z0), Vector3(outer, height, z1))
	box_between("BackWall", Vector3(-half_c, -draft, back), Vector3(half_c, height, z1))
	# The lagoon's floor: the ice joining the towers below the water.
	box_between("LagoonFloor", Vector3(-half_c, -draft, z0), Vector3(half_c, -lagoon_depth, back), KEEL)
	# The shelf out of the water, then steps up the back wall.
	var foot := _shelf_foot()
	slope("Shelf", foot, Vector3.BACK, SHELF_TOP + SHELF_FOOT, SHELF_ANGLE, channel_width, ICE, 1.0)
	var shelf_top_z := foot.z + (SHELF_TOP + SHELF_FOOT) / tan(deg_to_rad(SHELF_ANGLE))
	box_between("ShelfFill", Vector3(-half_c, -lagoon_depth, shelf_top_z), Vector3(half_c, SHELF_TOP, back))
	var step_room := back - shelf_top_z - 0.6
	var count := maxi(roundi((height - SHELF_TOP) / 0.42), 1)
	steps("BackSteps", Vector3(0.0, SHELF_TOP, back - step_room), Vector3.BACK, height - SHELF_TOP, 0.42, step_room / count, channel_width * 0.6)
	# The bridge across the mouth.
	box_between("Bridge", Vector3(-half_c - 0.5, height - bridge_thickness, z0), Vector3(half_c + 0.5, height, z0 + bridge_depth))


func _shelf_foot() -> Vector3:
	var back := tower_size.y * 0.5 - back_wall
	var run := (SHELF_TOP + SHELF_FOOT) / tan(deg_to_rad(SHELF_ANGLE))
	# The shelf and the steps take up the back of the lagoon; the rest is open water.
	return Vector3(0.0, -SHELF_FOOT, back - run - 4.0)
