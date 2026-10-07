@tool
class_name PinnacleBerg
extends IceBerg
## A pinnacle berg: a spire rising from a low shelf. Draft about 2 × its full height. The shelf is
## low enough to launch onto from anywhere (and there's a small ramp on the west), so the colony
## lives there. The spire climbs in three tiers joined by steps that spiral round it, each flight
## harder than the last (the top two are thin-penguin only). From the lookout on top, a steep
## chute shoots you down the south side, across the shelf and into the sea unless you dig in.
##
## A wave-cut cave runs through the spire's base from north to south at shelf level.

@export var shelf_size := 26.0:
	set(value):
		shelf_size = value
		queue_rebuild()
@export var shelf_height := 1.0:
	set(value):
		shelf_height = value
		queue_rebuild()
## The spire's three tiers: each is (side, top height above water) in metres.
@export var tiers: Array[Vector2] = [Vector2(10.0, 3.0), Vector2(7.0, 4.4), Vector2(4.0, 6.0)]:
	set(value):
		tiers = value
		queue_rebuild()
## Real pinnacle bergs: draft about 2 × the height above water.
@export var draft_ratio := 2.0:
	set(value):
		draft_ratio = value
		queue_rebuild()

@export_group("Steps")
## Shelf to the first tier: small steps anyone can hop. The flights higher up are taller: the
## second for thin penguins (about energy 50 or less), the third for very thin ones (about 25).
@export var first_step_rise := 0.4:
	set(value):
		first_step_rise = value
		queue_rebuild()
@export var second_step_rise := 0.7:
	set(value):
		second_step_rise = value
		queue_rebuild()
@export var third_step_rise := 0.8:
	set(value):
		third_step_rise = value
		queue_rebuild()

@export_group("Cave and chute")
@export var cave_width := 2.4:
	set(value):
		cave_width = value
		queue_rebuild()
@export var cave_height := 1.8:
	set(value):
		cave_height = value
		queue_rebuild()
@export var chute_angle_deg := 28.0:
	set(value):
		chute_angle_deg = value
		queue_rebuild()

const RAMP_ANGLE := 11.0
const RAMP_WIDTH := 4.0
const FOOT_DEPTH := 1.0


func reach() -> float:
	return maxf(shelf_size * 0.5 * sqrt(2.0), shelf_size * 0.5 + _ramp_run())


func top_height() -> float:
	return shelf_height


func waddle_spot() -> Vector3:
	return to_global(Vector3(-shelf_size * 0.3, shelf_height, -shelf_size * 0.3))


func exits() -> Array[Dictionary]:
	var half := shelf_size * 0.5
	var ramp := exit_at(Vector3(-half - _ramp_run(), 0.0, half * 0.5), Vector3.RIGHT, 3.0, false)
	ramp["climb"] = [to_global(Vector3(-half + 1.5, shelf_height, half * 0.5))]
	return [
		ramp,
		exit_at(Vector3(half, 0.0, -half * 0.5), Vector3.LEFT, 4.5, true),
		exit_at(Vector3(-half * 0.4, 0.0, -half), Vector3.BACK, 4.5, true),
	]


func tunnels() -> Array[Dictionary]:
	var half := tiers[0].x * 0.5 if not tiers.is_empty() else 4.0
	return [{"from": to_global(Vector3(0.0, shelf_height + 0.4, -half - 1.5)), "to": to_global(Vector3(0.0, shelf_height + 0.4, half + 1.5)),
		"width": cave_width, "height": cave_height, "swim": false}]


## The lookout on top of the spire.
func lookout() -> Vector3:
	return to_global(Vector3(0.0, tiers.back().y, 0.0)) if not tiers.is_empty() else waddle_spot()


func _build() -> void:
	var half := shelf_size * 0.5
	box_between("Shelf", Vector3(-half, -0.5, -half), Vector3(half, shelf_height, half))
	keel(Vector3(shelf_size, draft_for(_full_height(), draft_ratio), shelf_size), Vector2.ZERO, {}, -0.4)
	slope("Ramp", Vector3(-half - _ramp_run(), -FOOT_DEPTH, half * 0.5), Vector3.RIGHT, shelf_height + FOOT_DEPTH, RAMP_ANGLE, RAMP_WIDTH, ICE, 2.5)
	if tiers.size() < 3:
		return
	# Tier 1, with the cave through it (north to south).
	var t1 := tiers[0]
	var h1 := t1.x * 0.5
	var cw := cave_width * 0.5
	box_between("Tier1West", Vector3(-h1, shelf_height - 0.2, -h1), Vector3(-cw, t1.y, h1))
	box_between("Tier1East", Vector3(cw, shelf_height - 0.2, -h1), Vector3(h1, t1.y, h1))
	box_between("Tier1Roof", Vector3(-cw, shelf_height + cave_height, -h1), Vector3(cw, t1.y, h1))
	var t2 := tiers[1]
	var h2 := t2.x * 0.5
	box_between("Tier2", Vector3(-h2, t1.y - 0.2, -h2), Vector3(h2, t2.y, h2))
	var t3 := tiers[2]
	var h3 := t3.x * 0.5
	box_between("Tier3", Vector3(-h3, t2.y - 0.2, -h3), Vector3(h3, t3.y, h3))
	# The spiral: the east flight from the shelf up to tier 1. Then round tier 1's ledge to the
	# north flight, which climbs west along the ledge to step off onto tier 2; and round tier 2's
	# ledge to the west flight, which climbs south along it to step off onto the lookout. The
	# ledges are 1.5 m wide, the steps as wide as the ledge.
	var rise1 := t1.y - shelf_height
	var n1 := maxi(roundi(rise1 / first_step_rise), 1)
	steps("StepsEast", Vector3(h1 + n1 * 1.0, shelf_height, -h1 * 0.5), Vector3.LEFT, rise1, first_step_rise, 1.0, 2.5)
	var ledge12 := h1 - h2
	# (Sitting on the tier, not sunk into it: the cave runs under this ledge.)
	steps("StepsNorth", Vector3(h2 * 0.6, t1.y, -(h1 + h2) * 0.5), Vector3.LEFT, t2.y - t1.y, second_step_rise, 1.6, ledge12, ICE, 0.15)
	var ledge23 := h2 - h3
	steps("StepsWest", Vector3(-(h2 + h3) * 0.5, t2.y, -h3 * 0.5), Vector3.BACK, t3.y - t2.y, third_step_rise, 1.3, ledge23, ICE, 0.15)
	# The chute: from the lookout's south edge, over the tiers, down to the shelf.
	_chute(Vector3(0.0, t3.y, h3), t3.y - shelf_height)


## A chute running down (+z) from `top` and dropping `drop` metres.
func _chute(top: Vector3, drop: float) -> void:
	var a := deg_to_rad(chute_angle_deg)
	var run := drop / tan(a)
	slope("Chute", top + Vector3(0.0, -drop, run), Vector3.FORWARD, drop, chute_angle_deg, 2.5, SLICK, 1.0)


func _full_height() -> float:
	return tiers.back().y if not tiers.is_empty() else shelf_height


func _ramp_run() -> float:
	return (shelf_height + FOOT_DEPTH) / tan(deg_to_rad(RAMP_ANGLE))
