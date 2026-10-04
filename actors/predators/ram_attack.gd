class_name RamAttack
extends EdgeAttack
## The ram (numbers in RamAttackTuning). The pod gathers deep under an ice edge where a penguin
## stands, rushes up and rams it, and the ice tips toward the pod (TippableIce). A small floe tips
## steeply: everyone on it slips onto their belly and slides off into the water, unless they dig
## in (pull back) and hold on until it rights itself. The big berg only rocks, but the jolt shoves
## penguins near the rammed spot toward the water.
##
## Warning: dark shadows gathering under the ice edge, then the water bulging there, then the ice
## that will be hit marked (a whole floe, or a strip of the berg's edge).

var _ice: TippableIce = null
var _bulge: IceWave = null


func find_target(lead: Predator) -> float:
	var score := best_target_near_edge(lead, _t().ram_reach, func(p: Penguin) -> bool: return _ice_under(p) != null)
	if score >= 0.0:
		_ice = _ice_under(target)
	return score


func lineup_distance() -> float:
	return _t().gather_distance


func strike_distance() -> float:
	return _t().strike_distance


func lineup_spot(i: int, n: int) -> Vector3:
	return line_spot(i, n, _t().gather_distance, _t().gather_depth)


func charge_spot(i: int, n: int) -> Vector3:
	return line_spot(i, n, _t().strike_distance, 0.8)


func hunt_spot(i: int, n: int) -> Vector3:
	return line_spot(i, n, _t().strike_distance + 2.5, Predator.MIN_DEPTH)


func begin_warning() -> void:
	_bulge = IceWave.new()
	pod.add_child(_bulge)


func update_warning(progress: float) -> void:
	_bulge.shape(impact + out * 1.5, -out, _bulge_width(), lerpf(0.05, 0.35, progress))
	if progress >= settings.zone_shows_at:
		_show_zone()


func update_charge_progress(progress: float) -> void:
	_bulge.shape(impact + out * 1.5, -out, _bulge_width(), lerpf(0.35, 0.8, progress))


## Rams: the ice tips toward the pod, and penguins on it near the rammed spot are jolted.
func strike() -> Array[Penguin]:
	var t := _t()
	var jolted: Array[Penguin] = []
	if is_instance_valid(_ice):
		_ice.tip(out, tilt_for(_ice.radius), t.tip_in_seconds, t.tip_hold_seconds, t.tip_out_seconds)
		# Everyone on a floe; on bigger ice, everyone in the marked strip by the rammed edge.
		var in_reach: Array[Penguin] = []
		if _whole_piece():
			for node in pod.get_tree().get_nodes_in_group(&"penguins"):
				in_reach.append(node as Penguin)
		else:
			in_reach = penguins_in_strip(t.jolt_radius, t.jolt_radius * 2.0)
		for p in in_reach:
			if p != null and _ice_under(p) == _ice:
				p.push(out * t.jolt_push)
				jolted.append(p)
	if _bulge != null:
		_bulge.crash(-out, 1.5)
		_bulge = null
	hide_zone()
	return jolted


func cancel() -> void:
	if _bulge != null:
		_bulge.subside()
		_bulge = null
	hide_zone()


## How far a ram tips ice of this radius (degrees): big ice barely moves.
func tilt_for(ice_radius: float) -> float:
	return minf(_t().tip_strength / pow(maxf(ice_radius, 0.5), 1.5), _t().max_tilt_deg)


## Small enough that the whole piece is in the jolt (a floe no wider than jolt_radius), rather
## than just the strip by the rammed edge.
func _whole_piece() -> bool:
	return is_instance_valid(_ice) and _ice.radius * 2.0 <= _t().jolt_radius


func _show_zone() -> void:
	if _whole_piece():
		var top := _ice.global_position
		top.y = impact.y
		show_zone_disc(top, _ice.radius)
	else:
		show_zone_strip(_t().jolt_radius, _t().jolt_radius * 2.0)


func _bulge_width() -> float:
	return (pod.members().size() + 1) * pod.tuning.spacing


func _ice_under(p: Penguin) -> TippableIce:
	return TippableIce.under(pod.get_world_3d(), p.global_position)


func _t() -> RamAttackTuning:
	return settings as RamAttackTuning
