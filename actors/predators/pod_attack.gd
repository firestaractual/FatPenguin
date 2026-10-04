class_name PodAttack
extends RefCounted
## A group attack (see PredatorPod; its numbers are a PodAttackTuning). The pod runs the same
## steps for every attack: find a target, line up, warn, charge, strike, then hunt the water. A
## kind of attack fills in where the pod lines up and charges, what the warning looks like and
## what the strike does (WaveAttack, RamAttack). This base class has the shared parts: finding a
## penguin near an ice edge, spots in a line off that edge, and the danger-zone markers.
##
## Warnings follow docs/ART_DIRECTION.md: something in the water first (fins, shadows), then the
## water moving (a swell or a bulge), then the danger zone marked on the ice in the danger colour.

const DANGER_MATERIAL := preload("res://art/materials/danger.tres")
## The search for the ice edge steps this far at a time (m).
const EDGE_STEP := 0.5
## A penguin this far outside a marked zone still counts as in it (about a body width, m).
const ZONE_MARGIN := 0.4

var pod: PredatorPod
var settings: PodAttackTuning
## The penguin it picked.
var target: Penguin = null
## Where it strikes: a spot on the ice edge, at the height of the ice...
var impact := Vector3.ZERO
## ...and the flat direction from there out toward the pod.
var out := Vector3.ZERO

var _strip: MeshInstance3D = null
var _disc: MeshInstance3D = null


func _init(owner_pod: PredatorPod, attack_settings: PodAttackTuning) -> void:
	pod = owner_pod
	settings = attack_settings


# --- What each kind of attack fills in --------------------------------------

## Looks for something to attack, seen from the pod's leader. Sets target, impact and out and
## returns the target's temptation (GDD §5.1), or -1 if there's nothing to attack.
func find_target(_lead: Predator) -> float:
	return -1.0


## Spot `i` of `n` while lining up and warning, and how close to the surface they may come.
func lineup_spot(_i: int, _n: int) -> Vector3:
	return impact + out * 10.0


func lineup_depth() -> float:
	return Predator.MIN_DEPTH


## Spot `i` of `n` to charge at, and how close to the surface they may come.
func charge_spot(_i: int, _n: int) -> Vector3:
	return impact + out * 2.0


func charge_depth() -> float:
	return Predator.MIN_DEPTH


## Where they wait while hunting the water after the strike.
func hunt_spot(i: int, n: int) -> Vector3:
	return line_spot(i, n, strike_distance() + 1.5, Predator.MIN_DEPTH)


## How far out from the edge they line up, and strike (m).
func lineup_distance() -> float:
	return 10.0


func strike_distance() -> float:
	return 2.0


## Warning visuals: lined up (start), then each frame of the warning (progress 0 to 1) and of
## the charge (progress 0 to 1 as they close in).
func begin_warning() -> void:
	pass


func update_warning(_progress: float, _line_centre: Vector3) -> void:
	pass


func update_charge(_progress: float, _line_centre: Vector3) -> void:
	pass


## The strike itself. Returns the penguins it hit.
func strike(_line_centre: Vector3) -> Array[Penguin]:
	return []


## Called off before the strike: tidy up.
func cancel() -> void:
	hide_zone()


# --- Shared parts -----------------------------------------------------------

## Picks the most tempting penguin standing on the ice within `reach` of the edge that faces the
## leader, and within scan range of it. `accept` can rule penguins out (it gets the penguin).
## Sets target, impact and out; returns the score, or -1.
func best_target_near_edge(lead: Predator, reach: float, accept := Callable()) -> float:
	var best_score := -1.0
	for node in pod.get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p == null or not (p.state == Penguin.State.WALK or p.state == Penguin.State.SLIDE):
			continue
		var to_pod := lead.global_position - p.global_position
		to_pod.y = 0.0
		if to_pod.length() > settings.scan_range:
			continue
		if accept.is_valid() and not accept.call(p):
			continue
		var dir := to_pod.normalized()
		var edge := edge_toward(p.global_position, dir, reach)
		if edge.is_empty():
			continue
		var score := lead.temptation(p)
		if score > best_score:
			best_score = score
			target = p
			impact = edge["point"]
			out = dir
	return best_score


## Walks from `from` toward `dir` looking for the ice edge, up to `reach` metres. Returns
## {"point": the last spot of ice before the water} or {} if the edge isn't that close.
func edge_toward(from: Vector3, dir: Vector3, reach: float) -> Dictionary:
	var space := pod.get_world_3d().direct_space_state
	var last := {}
	var d := 0.0
	while d <= reach:
		var at := from + dir * d
		var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, from.y + 1.5, at.z), Vector3(at.x, Penguin.WATER_LEVEL - 1.0, at.z), Penguin.WORLD_LAYER)
		var hit := space.intersect_ray(query)
		if hit.is_empty() or (hit["position"] as Vector3).y < Penguin.WATER_LEVEL + 0.05:
			return last
		last = {"point": hit["position"]}
		d += EDGE_STEP
	return {}


## Spot `i` of `n` in a line side by side, `distance` out from the edge and `depth` down.
func line_spot(i: int, n: int, distance: float, depth: float) -> Vector3:
	var side := out.cross(Vector3.UP).normalized()
	var spot := impact + out * distance + side * (i - (n - 1) * 0.5) * pod.tuning.spacing
	spot.y = Penguin.WATER_LEVEL - depth
	return spot


## How far out from the edge `point` is (m).
func distance_out(point: Vector3) -> float:
	var rel := point - impact
	rel.y = 0.0
	return rel.dot(out)


## Penguins out of the water in a strip of ice running `width` along the edge and `reach` in.
func penguins_in_strip(reach: float, width: float) -> Array[Penguin]:
	var side := out.cross(Vector3.UP).normalized()
	var found: Array[Penguin] = []
	for node in pod.get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p == null or p.global_position.y < Penguin.WATER_LEVEL:
			continue
		var rel := p.global_position - impact
		rel.y = 0.0
		var inland := -rel.dot(out)
		if inland < -1.0 or inland > reach + ZONE_MARGIN or absf(rel.dot(side)) > width * 0.5 + ZONE_MARGIN:
			continue
		found.append(p)
	return found


## Marks the strip of ice from the edge `reach` in and `width` along, in the danger colour.
func show_zone_strip(reach: float, width: float) -> void:
	if _strip == null:
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 0.04, 1.0)
		_strip = _make_marker(&"DangerStrip", box)
	if not _strip.visible:
		var centre := impact - out * reach * 0.5 + Vector3.UP * 0.03
		_strip.global_transform = Transform3D(Basis.looking_at(out, Vector3.UP), centre).scaled_local(Vector3(width, 1.0, reach))
		_strip.visible = true


## Marks a disc of ice (a whole floe), in the danger colour.
func show_zone_disc(centre: Vector3, radius: float) -> void:
	if _disc == null:
		var disc := CylinderMesh.new()
		disc.top_radius = 1.0
		disc.bottom_radius = 1.0
		disc.height = 0.04
		_disc = _make_marker(&"DangerDisc", disc)
	if not _disc.visible:
		_disc.global_transform = Transform3D(Basis.from_scale(Vector3(radius, 1.0, radius)), centre + Vector3.UP * 0.03)
		_disc.visible = true


func hide_zone() -> void:
	for marker in [_strip, _disc]:
		if marker != null:
			marker.visible = false


func _make_marker(marker_name: StringName, mesh: Mesh) -> MeshInstance3D:
	mesh.material = DANGER_MATERIAL
	var marker := MeshInstance3D.new()
	marker.name = marker_name
	marker.mesh = mesh
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.top_level = true
	marker.visible = false
	pod.add_child(marker)
	return marker
