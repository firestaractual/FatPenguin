class_name PredatorPod
extends Node3D
## A group of predators that swim and attack together (GDD §5.3: the orca pod). Its members are
## its children. The first one leads and patrols on its own; the others keep a V formation behind
## it. A member that's busy (hunting, eating, sated) drops out and rejoins once it's free.
##
## Group attacks are data: the pod's PodTuning lists them (PodAttackTuning resources: the wave,
## the ram, the cut-off, the carousel), and every attack runs the same steps here:
##   PATROL  - formation, and every so often a look for something to attack. When more than one
##             attack has a target, one is picked at random by weight.
##   LINE_UP - the free members get into position (what that means is up to the attack).
##   WARN    - in position, the warning shows (its visuals and danger zone).
##   CHARGE  - the attack closes in, and strikes when it gets there.
##   HUNT    - for hunt_seconds the members hold near the strike and go after anyone in the
##             water, then regroup. No attack again for the attack's cooldown.
## If too few members are left (one went off to eat, or after a penguin), or the target gets
## away, the attack is called off.
##
## Traps: an attack can lead into others (PodAttackTuning.chains_into). During the hunt after a
## strike, the pod checks those, and if one has a target it starts straight away, with no
## cooldown: a wave knocks a penguin in, the cut-off keeps it from getting back, the carousel
## finishes it in open water. The cooldown comes when the trap ends.
##
## Keep this node at the origin, unrotated: its members are placed in world space.

signal phase_changed(new_phase: Phase)
## In position: the warning starts.
signal attack_coming(attack: PodAttack)
## The strike landed on these penguins.
signal attack_hit(attack: PodAttack, hit: Array[Penguin])
## An attack was called off before it struck.
signal attack_called_off(attack: PodAttack)

enum Phase { PATROL, LINE_UP, WARN, CHARGE, HUNT }

## How often it looks for something to attack (s).
const SCAN_INTERVAL := 0.5
## A trap is at most this many attacks in a row.
const MAX_TRAP_STEPS := 4

@export var tuning: PodTuning

var phase: Phase = Phase.PATROL
## The attack under way, if any.
var attack: PodAttack = null
## Which attack of the trap this is: 1 for the first, 2 for the one it led into, and so on.
var trap_step := 0

var _attacks: Array[PodAttack] = []
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
			_hunt(delta)


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


## How long the current phase has run (s).
func phase_time() -> float:
	return _phase_time


## No more waiting: it attacks as soon as it finds a target (a level scripting an attack, tests).
func clear_cooldown() -> void:
	_cooldown = 0.0


## Narrows the attacks it knows to `list` (made from its tuning; see attacks()). For a level that
## saves an attack for later, and for tests.
func set_attacks(list: Array[PodAttack]) -> void:
	_attacks = list


## Seconds until the attack under way strikes; -1 if there's none on its way (or it can't tell).
func seconds_to_strike() -> float:
	if attack == null or phase == Phase.HUNT:
		return -1.0
	return attack.seconds_to_strike(phase, _phase_time)


# --- Attack steps -------------------------------------------------------------

func _look_for_attack(delta: float) -> void:
	_scan -= delta
	if _scan > 0.0 or _cooldown > 0.0 or _attacks.is_empty():
		return
	_scan = SCAN_INTERVAL
	var lead := leader()
	if lead == null or not lead.is_available():
		return
	var free := available_members()
	var picked := _pick(_attacks.filter(func(a: PodAttack) -> bool: return a.settings.starts_alone), lead, free)
	if picked != null:
		trap_step = 0
		_start(picked, free)


## Of `options`, the attacks with a target and enough free members, one picked at random by
## weight; null if none.
func _pick(options: Array[PodAttack], lead: Predator, free: Array[Predator]) -> PodAttack:
	var ready: Array[PodAttack] = []
	var total := 0.0
	for candidate in options:
		if free.size() >= candidate.settings.min_attackers and candidate.find_target(lead) >= 0.0:
			ready.append(candidate)
			total += candidate.settings.weight
	if ready.is_empty():
		return null
	var roll := randf() * total
	for candidate in ready:
		roll -= candidate.settings.weight
		if roll <= 0.0:
			return candidate
	return ready.back()


func _start(next: PodAttack, free: Array[Predator]) -> void:
	attack = next
	attack.attackers = free
	trap_step += 1
	attack.begin()
	_set_phase(Phase.LINE_UP)
	# Orders go out now, before the members' own turn this frame (they'd lock on to a penguin
	# nearby by themselves otherwise).
	attack.steer(Phase.LINE_UP, 0.0)


func _line_up() -> void:
	if not _still_on():
		return
	attack.steer(Phase.LINE_UP, _phase_time)
	if attack.lined_up(_phase_time):
		attack.begin_warning()
		_set_phase(Phase.WARN)
		attack_coming.emit(attack)


func _warn() -> void:
	if not _still_on():
		return
	attack.steer(Phase.WARN, _phase_time)
	attack.update_warning(clampf(_phase_time / maxf(attack.settings.warning_seconds, 0.01), 0.0, 1.0))
	if attack.warned(_phase_time):
		_set_phase(Phase.CHARGE)


func _charge() -> void:
	if not _still_on():
		return
	attack.steer(Phase.CHARGE, _phase_time)
	attack.update_charge(_phase_time)
	if attack.charged(_phase_time):
		_strike()


func _strike() -> void:
	var hit := attack.strike()
	attack_hit.emit(attack, hit)
	_set_phase(Phase.HUNT)
	_scan = 0.0 # look for the trap's next step straight away


## Holds near the strike (the attack says where). A member goes after anyone in the water within
## its detect_range (the penguins the strike knocked in), and comes back when it's done. If the
## attack leads into another that has a target, that one starts now.
func _hunt(delta: float) -> void:
	attack.attackers = attack.attackers.filter(func(m: Predator) -> bool: return is_instance_valid(m))
	attack.hunt(_phase_time)
	_scan -= delta
	if _scan <= 0.0:
		_scan = SCAN_INTERVAL
		if _try_chain():
			return
	if _phase_time >= attack.settings.hunt_seconds:
		_end_attack(attack.settings.cooldown)


## Starts the next attack of the trap, if the one just made leads into one with a target.
func _try_chain() -> bool:
	if trap_step >= MAX_TRAP_STEPS or attack.settings.chains_into.is_empty():
		return false
	var lead := leader()
	if lead == null:
		return false
	var options: Array[PodAttack] = _attacks.filter(func(a: PodAttack) -> bool: return a.settings in attack.settings.chains_into)
	var free := members().filter(func(m: Predator) -> bool: return m.can_be_recalled())
	var next := _pick(options, lead, free)
	if next == null:
		return false
	for member in free:
		member.recall()
	_start(next, free)
	return true


## Drops attackers that have gone off to do something else. Calls the attack off if too few are
## left, or its target has got away.
func _still_on() -> bool:
	attack.attackers = attack.attackers.filter(func(m: Predator) -> bool: return is_instance_valid(m) and m.is_available())
	if attack.attackers.size() >= attack.settings.min_attackers and not attack.escaped():
		return true
	attack.cancel()
	attack_called_off.emit(attack)
	_end_attack(attack.settings.cooldown * 0.5)
	return false


func _end_attack(cooldown: float) -> void:
	for member in attack.attackers:
		if is_instance_valid(member):
			member.release()
	attack.attackers = []
	_cooldown = cooldown
	attack = null
	trap_step = 0
	_set_phase(Phase.PATROL)


func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	_phase_time = 0.0
	phase_changed.emit(phase)
