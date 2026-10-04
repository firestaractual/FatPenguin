class_name WaveAttack
extends EdgeAttack
## The wave (GDD §5.3; numbers in WaveAttackTuning). The pod lines up side by side off an ice edge
## where a penguin stands, fins showing, raises a swell, charges, and breaks a wave over the edge
## that shoves everyone in the danger zone toward the water.
##
## Warning: the fins lining up, then the swell rising, then the strip of ice marked.

## The swell runs this far ahead of the pod (m).
const SWELL_AHEAD := 2.5

var _swell: IceWave = null


func find_target(lead: Predator) -> float:
	return best_target_near_edge(lead, _t().wave_reach)


func lineup_distance() -> float:
	return _t().lineup_distance


func strike_distance() -> float:
	return _t().break_distance


func lineup_spot(i: int, n: int) -> Vector3:
	return line_spot(i, n, _t().lineup_distance, _t().surface_depth)


func lineup_depth() -> float:
	return _t().surface_depth


func charge_spot(i: int, n: int) -> Vector3:
	return line_spot(i, n, _t().break_distance, _t().surface_depth)


func charge_depth() -> float:
	return _t().surface_depth


func begin_warning() -> void:
	_swell = IceWave.new()
	pod.add_child(_swell)


func update_warning(progress: float) -> void:
	_swell.shape(attackers_centre() - out * SWELL_AHEAD, -out, _t().wave_width, lerpf(0.15, 0.7, progress))
	if progress >= settings.zone_shows_at:
		show_zone_strip(_t().wave_reach, _t().wave_width)


func update_charge_progress(progress: float) -> void:
	_swell.shape(attackers_centre() - out * SWELL_AHEAD, -out, _t().wave_width, lerpf(0.7, 1.8, progress))


## Breaks over the edge: everyone on the ice in the zone is shoved toward the water.
func strike() -> Array[Penguin]:
	var washed := penguins_in_strip(_t().wave_reach, _t().wave_width)
	for p in washed:
		p.push(out * _t().wave_push)
	if _swell != null:
		_swell.crash(-out, _t().wave_reach + 1.0)
		_swell = null
	hide_zone()
	return washed


func cancel() -> void:
	if _swell != null:
		_swell.subside()
		_swell = null
	hide_zone()


func _t() -> WaveAttackTuning:
	return settings as WaveAttackTuning
