class_name PredatorPod
extends Node3D
## A group of predators that swim and attack together (GDD §5.3: the orca pod). Its members are
## its children. The first one leads and patrols on its own; the others keep a V formation behind
## it. A member that's busy (hunting, eating, sated) drops out and rejoins once it's free.
##
## Group attacks are data: the pod's PodTuning lists them (PodAttackTuning resources: the wave,
## the ram), and every attack runs the same steps here:
##   PATROL  - formation, and every so often a look for something to attack. When more than one
##             attack has a target, one is picked at random by weight.
##   LINE_UP - the free members swim to the attack's line-up spots.
##   WARN    - lined up, for the attack's warning_seconds (its visuals and danger zone show).
##   CHARGE  - at the edge; the attack strikes when they get there.
##   HUNT    - for hunt_seconds the members hold near the strike and go after anyone in the
##             water, then regroup. No attack again for the attack's cooldown.
## If too few members are left (one went off to eat, or after a penguin), the attack is called off.
##
## Keep this node at the origin, unrotated: its members are placed in world space.

signal phase_changed(new_phase: Phase)
## Lined up: the warning starts.
signal attack_coming(attack: PodAttack)
## The strike landed on these penguins.
signal attack_hit(attack: PodAttack, hit: Array[Penguin])

enum Phase { PATROL, LINE_UP, WARN, CHARGE, HUNT }

## How often it looks for something to attack (s).
const SCAN_INTERVAL := 0.5
## Close enough to its line-up spot (m).
const IN_PLACE := 2.5

@export var tuning: PodTuning

var phase: Phase = Phase.PATROL
## The attack under way, if any.
var attack: PodAttack = null

var _attacks: Array[PodAttack] = []
var _attackers: Array[Predator] = []
var _phase_time := 0.0
var _scan := 0.0
var _cooldown := 0.0


func _ready() -> void:
	add_to_group(&"pods")
	if tuning == null:
		tuning = PodTuning.new()
	for settings in tuning.attacks:
		var made := settings.make_attack(self) if settings != null else null
		if made != null:
			_attacks.append(made)
	_cooldown = tuning.first_attack_delay


func _physics_process(delta: float) -> void:
	_think(delta)


## Each physics frame. Kinds of pod can override this for behaviour beyond the attack steps.
func _think(delta: float) -> void:
	_phase_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	match phase:
		Phase.PATROL:
			keep_formation()
			_look_for_attack(delta)
		Phase.LINE_UP:
			_line_up()
		Phase.WARN:
			_warn()
		Phase.CHARGE:
			_charge()
		Phase.HUNT:
			_hunt()


# --- Members and formation ----------------------------------------------------

## Every predator in the pod, leader first.
func members() -> Array[Predator]:
	var list: Array[Predator] = []
	for child in get_children():
		var member := child as Predator
		if member != null:
			list.append(member)
	return list


func leader() -> Predator:
	var list := members()
	return list[0] if not list.is_empty() else null


## Members free to take orders right now (see Predator.is_available()).
func available_members() -> Array[Predator]:
	return members().filter(func(m: Predator) -> bool: return m.is_available())


## The attacks this pod knows, in the order its tuning lists them.
func attacks() -> Array[PodAttack]:
	return _attacks


## Where follower `index` (1 for the first follower) swims: in a V behind the leader.
func formation_spot(index: int) -> Vector3:
	var lead := leader()
	var back := -lead.heading()
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	var side := back.cross(Vector3.UP).normalized()
	var rank := (index + 1) / 2
	var flip := 1.0 if index % 2 == 1 else -1.0
	return lead.global_position + back * rank * tuning.spacing + side * flip * rank * tuning.spacing * 0.8


## Orders each free follower to its spot in the V, faster the further behind it's fallen.
func keep_formation() -> void:
	var lead := leader()
	if lead == null:
		return
	var index := 0
	for member in members():
		if member == lead:
			continue
		index += 1
		if not member.is_available():
			continue
		var spot := formation_spot(index)
		var behind := member.global_position.distance_to(spot)
		var speed := minf(lead.tuning.patrol_speed + behind * tuning.catch_up, member.tuning.chase_speed)
		member.order_move(spot, speed)


## Sends every member back to its own patrol.
func release_all() -> void:
	for member in members():
		member.release()


## Seconds until the attack under way strikes; -1 if there's none on its way.
func seconds_to_strike() -> float:
	if attack == null:
		return -1.0
	var s := attack.settings
	var run := maxf(attack.lineup_distance() - attack.strike_distance(), 0.0) / s.charge_speed
	match phase:
		Phase.WARN:
			return s.warning_seconds - _phase_time + run
		Phase.CHARGE:
			return maxf(attack.distance_out(_line_centre()) - attack.strike_distance(), 0.0) / s.charge_speed
	return -1.0


# --- Attack steps -------------------------------------------------------------

func _look_for_attack(delta: float) -> void:
	_scan -= delta
	if _scan > 0.0 or _cooldown > 0.0 or _attacks.is_empty():
		return
	_scan = SCAN_INTERVAL
	var lead := leader()
	var free := available_members()
	if lead == null or not lead.is_available():
		return
	var options: Array[PodAttack] = []
	var total := 0.0
	for candidate in _attacks:
		if free.size() >= candidate.settings.min_attackers and candidate.find_target(lead) >= 0.0:
			options.append(candidate)
			total += candidate.settings.weight
	if options.is_empty():
		return
	var roll := randf() * total
	attack = options.back()
	for candidate in options:
		roll -= candidate.settings.weight
		if roll <= 0.0:
			attack = candidate
			break
	_attackers = free
	_set_phase(Phase.LINE_UP)


func _line_up() -> void:
	if not _attackers_ready():
		return
	var in_place := true
	var n := _attackers.size()
	for i in n:
		var member := _attackers[i]
		var spot := attack.lineup_spot(i, n)
		member.order_move(spot, member.tuning.chase_speed, attack.lineup_depth(), -attack.out)
		if member.global_position.distance_to(spot) > IN_PLACE:
			in_place = false
	if in_place or _phase_time >= attack.settings.lineup_max_seconds:
		attack.begin_warning()
		_set_phase(Phase.WARN)
		attack_coming.emit(attack)


func _warn() -> void:
	if not _attackers_ready():
		return
	var n := _attackers.size()
	for i in n:
		var member := _attackers[i]
		member.order_move(attack.lineup_spot(i, n), member.tuning.chase_speed, attack.lineup_depth(), -attack.out)
	attack.update_warning(clampf(_phase_time / attack.settings.warning_seconds, 0.0, 1.0), _line_centre())
	if _phase_time >= attack.settings.warning_seconds:
		_set_phase(Phase.CHARGE)


func _charge() -> void:
	if not _attackers_ready():
		return
	var s := attack.settings
	var n := _attackers.size()
	for i in n:
		_attackers[i].order_move(attack.charge_spot(i, n), s.charge_speed, attack.charge_depth())
	var run := maxf(attack.lineup_distance() - attack.strike_distance(), 0.1)
	var left := attack.distance_out(_line_centre()) - attack.strike_distance()
	attack.update_charge(1.0 - clampf(left / run, 0.0, 1.0), _line_centre())
	if left <= 0.5 or _phase_time >= run / s.charge_speed + 2.0:
		var hit := attack.strike(_line_centre())
		attack_hit.emit(attack, hit)
		_set_phase(Phase.HUNT)


## Holds near the strike. A member goes after anyone in the water within its detect_range (the
## penguins the strike knocked in), and comes back to its spot when it's done.
func _hunt() -> void:
	_attackers = _attackers.filter(func(m: Predator) -> bool: return is_instance_valid(m))
	var n := _attackers.size()
	for i in n:
		var member := _attackers[i]
		if member.is_available():
			member.order_move(attack.hunt_spot(i, n), member.tuning.patrol_speed, Predator.MIN_DEPTH, -attack.out)
	if _phase_time < attack.settings.hunt_seconds:
		return
	_end_attack(attack.settings.cooldown)


## Drops attackers that have gone off to do something else. Calls the attack off if too few are
## left.
func _attackers_ready() -> bool:
	_attackers = _attackers.filter(func(m: Predator) -> bool: return is_instance_valid(m) and m.is_available())
	if _attackers.size() >= attack.settings.min_attackers:
		return true
	attack.cancel()
	_end_attack(attack.settings.cooldown * 0.5)
	return false


func _end_attack(cooldown: float) -> void:
	for member in _attackers:
		member.release()
	_attackers.clear()
	_cooldown = cooldown
	attack = null
	_set_phase(Phase.PATROL)


func _line_centre() -> Vector3:
	var sum := Vector3.ZERO
	for member in _attackers:
		sum += member.global_position
	return sum / maxf(_attackers.size(), 1)


func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	_phase_time = 0.0
	phase_changed.emit(phase)
