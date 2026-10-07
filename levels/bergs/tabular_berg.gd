@tool
class_name TabularBerg
extends IceBerg
## A tabular berg: flat on top, sheer on every side, with a real 1:5 height-to-draft ratio, so its
## keel runs deep. Too tall to launch onto (a boost lifts you about 1.7 m), so the only way up is
## the ice foot: a ramp of ice along the north face, from the water at its west end up to the top
## at its east end. Waves can't wash a top this high, so it's a safe place to huddle.
##
## A swim tunnel runs through the keel from west to east, a few metres down: too narrow for an
## orca, wide enough for a leopard seal, and you need the air to get through.

## The top's footprint, x by z (m).
@export var size := Vector2(32.0, 22.0):
	set(value):
		size = value
		queue_rebuild()
@export var height := 3.0:
	set(value):
		height = value
		queue_rebuild()
## Real tabular bergs: draft about 5 × the height above water.
@export var draft_ratio := 5.0:
	set(value):
		draft_ratio = value
		queue_rebuild()

@export_group("Ice foot (ramp)")
@export var ramp_width := 3.0:
	set(value):
		ramp_width = value
		queue_rebuild()
## Under 14° you can walk up it.
@export var ramp_angle_deg := 11.0:
	set(value):
		ramp_angle_deg = value
		queue_rebuild()

@export_group("Swim tunnel")
## How deep the middle of the tunnel runs, and how big it is (m). Orcas are 2 m across (too big),
## leopard seals 1.2 m, penguins under 1 m.
@export var tunnel_depth := 3.0:
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

## The ramp's foot starts this far below the waterline, so you swim up onto its slope (not its
## end) and climb out.
const FOOT_DEPTH := 1.0


func reach() -> float:
	return Vector2(size.x * 0.5, size.y * 0.5 + ramp_width).length()


func top_height() -> float:
	return height


func waddle_spot() -> Vector3:
	return to_global(Vector3(size.x * 0.15, height, size.y * 0.1))


func exits() -> Array[Dictionary]:
	var foot := _ramp_foot()
	var exit := exit_at(foot - Vector3(0.6, 0.0, 0.0), Vector3.RIGHT, 4.0, false)
	# Up the ramp to its landing, then onto the top.
	var run := (height + FOOT_DEPTH) / tan(deg_to_rad(ramp_angle_deg))
	exit["climb"] = [to_global(Vector3(foot.x + run + 1.5, height, foot.z)), to_global(Vector3(foot.x + run + 1.5, height, -size.y * 0.5 + 2.0))]
	return [exit]


func tunnels() -> Array[Dictionary]:
	var ends := keel_tunnel_ends(_keel_size(), Vector2.ZERO, _tunnel())
	return [{"from": ends[0], "to": ends[1], "width": tunnel_width, "height": tunnel_height, "swim": true}]


func _build() -> void:
	var half := size * 0.5
	box_between("Top", Vector3(-half.x, -0.5, -half.y), Vector3(half.x, height, half.y))
	keel(_keel_size(), Vector2.ZERO, _tunnel())
	# The ice foot along the north face, climbing east, then a landing to step onto the top.
	var rise := height + FOOT_DEPTH
	var foot := _ramp_foot()
	slope("IceFoot", foot, Vector3.RIGHT, rise, ramp_angle_deg, ramp_width, ICE, height + 2.5)
	var run := rise / tan(deg_to_rad(ramp_angle_deg))
	var landing_x := foot.x + run
	box_between("IceFootLanding", Vector3(landing_x, -2.0, -half.y - ramp_width), Vector3(minf(landing_x + 4.0, half.x), height, -half.y))


func _ramp_foot() -> Vector3:
	return Vector3(-size.x * 0.5 + 1.0, -FOOT_DEPTH, -size.y * 0.5 - ramp_width * 0.5)


func _keel_size() -> Vector3:
	return Vector3(size.x, draft_for(height, draft_ratio), size.y)


func _tunnel() -> Dictionary:
	return {"axis": "x", "depth": tunnel_depth, "width": tunnel_width, "height": tunnel_height}
