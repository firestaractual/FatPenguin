@tool
class_name WedgeBerg
extends IceBerg
## A wedge berg: one long side slopes gently up out of the water to a crest, the other is a
## sheer cliff. Draft about 5 × its height. The slope is the way up: swim into its foot and you
## climb out, and it's gentle enough (under 14°) to walk. At the top, a small flat crest, and the
## cliff drops straight into the sea.
##
## A swim tunnel runs through the keel from north to south under the crest.

## Across the berg (z), and how high the crest stands (m).
@export var width := 16.0:
	set(value):
		width = value
		queue_rebuild()
@export var height := 4.0:
	set(value):
		height = value
		queue_rebuild()
## The slope rises toward +x at this angle (under 14° you can walk it).
@export var slope_angle_deg := 12.0:
	set(value):
		slope_angle_deg = value
		queue_rebuild()
## The flat crest, before the cliff (m along x).
@export var crest := 6.0:
	set(value):
		crest = value
		queue_rebuild()
@export var draft_ratio := 5.0:
	set(value):
		draft_ratio = value
		queue_rebuild()

@export_group("Swim tunnel")
@export var tunnel_depth := 2.5:
	set(value):
		tunnel_depth = value
		queue_rebuild()
@export var tunnel_width := 2.2:
	set(value):
		tunnel_width = value
		queue_rebuild()
@export var tunnel_height := 1.8:
	set(value):
		tunnel_height = value
		queue_rebuild()

const FOOT_DEPTH := 1.0
## The keel's top, below the waterline (m).
const KEEL_TOP := 1.4


func reach() -> float:
	return Vector2((_run() + crest) * 0.5, width * 0.5).length()


func top_height() -> float:
	return height


func waddle_spot() -> Vector3:
	return to_global(Vector3(_crest_start() + crest * 0.5, height, 0.0))


func exits() -> Array[Dictionary]:
	# Up the north half of the slope (the pack ice comes in to the south half), to the crest.
	var exit := exit_at(Vector3(_foot_x(), 0.0, -width * 0.25), Vector3.RIGHT, 4.0, false)
	exit["climb"] = [to_global(Vector3(_crest_start() + 1.0, height, -width * 0.25))]
	return [exit]


func tunnels() -> Array[Dictionary]:
	var ends := keel_tunnel_ends(_keel_size(), Vector2(_keel_centre_x(), 0.0), _tunnel())
	return [{"from": ends[0], "to": ends[1], "width": tunnel_width, "height": tunnel_height, "swim": true}]


func _build() -> void:
	var half := width * 0.5
	slope("Slope", Vector3(_foot_x(), -FOOT_DEPTH, 0.0), Vector3.RIGHT, height + FOOT_DEPTH, slope_angle_deg, width, ICE, height + 2.0)
	box_between("Crest", Vector3(_crest_start(), -KEEL_TOP - 0.3, -half), Vector3(_crest_start() + crest, height, half))
	# The keel stays under the slope's foot, so nothing sticks up out of it.
	keel(_keel_size(), Vector2(_keel_centre_x(), 0.0), _tunnel(), -KEEL_TOP)


func _run() -> float:
	return (height + FOOT_DEPTH) / tan(deg_to_rad(slope_angle_deg))


func _foot_x() -> float:
	return -(_run() + crest) * 0.5


func _crest_start() -> float:
	return _foot_x() + _run()


func _keel_centre_x() -> float:
	return _foot_x() + (_run() + crest) * 0.5


func _keel_size() -> Vector3:
	return Vector3(_run() + crest, draft_for(height, draft_ratio), width)


func _tunnel() -> Dictionary:
	# Under the crest, toward the cliff end (clear of the slope's underside).
	return {"axis": "z", "depth": tunnel_depth, "width": tunnel_width, "height": tunnel_height,
		"offset": _crest_start() + crest * 0.65 - _keel_centre_x()}
