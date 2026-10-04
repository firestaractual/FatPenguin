class_name PodAttack
extends RefCounted
## A group attack (see PredatorPod; its numbers are a PodAttackTuning). The pod runs the same
## steps for every attack: find a target, line up, warn, charge, strike, then hunt the water. A
## kind of attack fills in what those steps mean: where its predators swim, when each step is
## done, what the warning looks like and what the strike does.
##
## Two families so far:
##   EdgeAttack - on penguins standing near an ice edge: the pod lines up off the edge and
##                charges it (WaveAttack, RamAttack).
##   In the water - on a penguin that's swimming: the pod herds it (CutOffAttack keeps it from
##                getting back to the ice; CarouselAttack rings it in and strikes).
## Attacks can lead into each other (PodAttackTuning.chains_into), so the pod plays them as one
## trap: knock a penguin into the water, keep it from getting home, then finish it in open water.
##
## Warnings follow docs/ART_DIRECTION.md: something in the water first (fins, shadows), then the
## water moving (a swell, a bulge, bubbles), then the danger zone marked in the danger colour.

const DANGER_MATERIAL := preload("res://art/materials/danger.tres")
## A penguin this far outside a marked zone still counts as in it (about a body width, m).
const ZONE_MARGIN := 0.4
## Close enough to its spot (m).
const IN_PLACE := 2.5

var pod: PredatorPod
var settings: PodAttackTuning
## The penguin it picked.
var target: Penguin = null
## The predators carrying it out, set by the pod when the attack starts. The pod drops any that
## go off to do something else (to eat, or after a penguin of their own).
var attackers: Array[Predator] = []

var _disc: MeshInstance3D = null
var _ring: MeshInstance3D = null


func _init(owner_pod: PredatorPod, attack_settings: PodAttackTuning) -> void:
	pod = owner_pod
	settings = attack_settings


# --- What each kind of attack fills in --------------------------------------

## Looks for something to attack, seen from the pod's leader. Sets target (and anything else the
## attack needs to remember) and returns the target's temptation (GDD §5.1), or -1 if there's
## nothing to attack.
func find_target(_lead: Predator) -> float:
	return -1.0


## The attack has been picked and `attackers` is set: hand out roles.
func begin() -> void:
	pass


## Every frame of LINE_UP, WARN and CHARGE: orders for the attackers.
func steer(_phase: PredatorPod.Phase, _phase_time: float) -> void:
	pass


## Lined up: the warning can start. By default, after lineup_max_seconds.
func lined_up(phase_time: float) -> bool:
	return phase_time >= settings.lineup_max_seconds


## Warned long enough: the charge can start.
func warned(phase_time: float) -> bool:
	return phase_time >= settings.warning_seconds


## The charge has arrived: strike now.
func charged(_phase_time: float) -> bool:
	return true


## The target has got away (or gone): the attack is called off.
func escaped() -> bool:
	return not is_instance_valid(target)


## Warning visuals: lined up (start), then each frame of the warning (progress 0 to 1) and of
## the charge.
func begin_warning() -> void:
	pass


func update_warning(_progress: float) -> void:
	pass


func update_charge(_phase_time: float) -> void:
	pass


## The strike itself. Returns the penguins it hit.
func strike() -> Array[Penguin]:
	return []


## Every frame of HUNT: the attackers that are free hold near the strike, going after anyone in
## the water nearby.
func hunt(_phase_time: float) -> void:
	pass


## Seconds until the strike, for the debug HUD; -1 if it can't tell.
func seconds_to_strike(_phase: PredatorPod.Phase, _phase_time: float) -> float:
	return -1.0


## Called off before the strike: tidy up.
func cancel() -> void:
	hide_zone()


# --- Shared parts -----------------------------------------------------------

## The middle of the attackers.
func attackers_centre() -> Vector3:
	var sum := Vector3.ZERO
	for member in attackers:
		sum += member.global_position
	return sum / maxf(attackers.size(), 1)


## True if every attacker is within IN_PLACE of the spot `spot_of` gives it (it gets i and n).
func all_in_place(spot_of: Callable, tolerance := IN_PLACE) -> bool:
	var n := attackers.size()
	for i in n:
		if attackers[i].global_position.distance_to(spot_of.call(i, n)) > tolerance:
			return false
	return true


## Penguins in the water (or just under it) the pod's leader could go after: within scan range,
## not ignored. `accept` can rule penguins out (it gets the penguin). Picks the most tempting;
## sets target and returns its score, or -1.
func best_swimmer(lead: Predator, accept := Callable()) -> float:
	var best_score := -1.0
	for node in pod.get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p == null or p.state != Penguin.State.SWIM:
			continue
		if lead.global_position.distance_to(p.global_position) > settings.scan_range:
			continue
		if accept.is_valid() and not accept.call(p):
			continue
		var score := lead.temptation(p)
		if score > best_score:
			best_score = score
			target = p
	return best_score


## Marks a disc (a whole floe, or a patch of water), in the danger colour. It follows `centre`.
func show_zone_disc(centre: Vector3, radius: float) -> void:
	if _disc == null:
		var disc := CylinderMesh.new()
		disc.top_radius = 1.0
		disc.bottom_radius = 1.0
		disc.height = 0.04
		_disc = make_marker(&"DangerDisc", disc)
	_disc.global_transform = Transform3D(Basis.from_scale(Vector3(radius, 1.0, radius)), centre + Vector3.UP * 0.03)
	_disc.visible = true


## Marks a circle on the water (a patch about to be hit) with a ring in the danger colour, so the
## water inside stays readable. It follows `centre`.
func show_zone_ring(centre: Vector3, radius: float) -> void:
	if _ring == null:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.94
		torus.outer_radius = 1.0
		torus.rings = 48
		_ring = make_marker(&"DangerRing", torus)
	_ring.global_transform = Transform3D(Basis.from_scale(Vector3(radius, 0.3, radius)), Vector3(centre.x, Penguin.WATER_LEVEL + 0.02, centre.z))
	_ring.visible = true


func hide_zone() -> void:
	for marker in [_disc, _ring]:
		if marker != null:
			marker.visible = false


## A danger-coloured marker, placed in world space (child of the pod).
func make_marker(marker_name: StringName, mesh: Mesh) -> MeshInstance3D:
	mesh.material = DANGER_MATERIAL
	var marker := MeshInstance3D.new()
	marker.name = marker_name
	marker.mesh = mesh
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.top_level = true
	marker.visible = false
	pod.add_child(marker)
	return marker
