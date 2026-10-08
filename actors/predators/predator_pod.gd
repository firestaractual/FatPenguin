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
## away (or shelters by a humpback, if the pod is shy of them), the attack is called off. A
## humpback that comes to drive the pod off calls it off too (call_off()).
##
## Traps: an attack can lead into others (PodAttackTuning.chains_into). During the hunt after a
## strike, the pod checks those, and if one has a target it starts straight away, with no
## cooldown: a wave knocks a penguin in, the cut-off keeps it from getting back, the carousel
## finishes it in open water. The cooldown comes when the trap ends.
##
## Relay strikes (PodTuning, Relay strikes): when a member's lunge misses a penguin in the water
## (or it gives up the chase), or a penguin bumps into one that's out of breath, the nearest other
## member that can strike goes for it straight away, from where it is, with the usual lunge
## warning. Not while an attack is lining up or under way. While one member hunts, the others
## shadow it a little way off, so there's always one close enough to take over. They take turns
## like this (up to relay_max strikes, each keeping the hunt going a little longer) while the
## penguin is still in the water and in reach.
##
## Keep this node at the origin, unrotated: its members are placed in world space.

signal phase_changed(new_phase: Phase)
## In position: the warning starts.
signal attack_coming(attack: PodAttack)
## The strike landed on these penguins.
signal attack_hit(attack: PodAttack, hit: Array[Penguin])
## An attack was called off before it struck.
signal attack_called_off(attack: PodAttack)
## `member` was sent in to strike at `target` after another member missed (or was bumped).
signal relayed(member: Predator, target: Penguin)

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
## Relay strikes left in this hunt, the time since the last one, and how much longer they've kept
## the hunt after a strike going.
var _relays_left := 0
var _relay_quiet := 0.0
var _hunt_extra := 0.0
## Members are shadowing a hunt (see _shadow_hunt()).
var _shadowing := false


func _ready() -> void:
	add_to_group(&"pods")
	if tuning == null:
		tuning = PodTuning.new()
	for settings in tuning.attacks:
		var made := settings.make_attack(self) if settings != null else null
		if made != null:
			_attacks.append(made)
	_cooldown = tuning.first_attack_delay
	_relays_left = tuning.relay_max
	# Members are its children, including ones added later (a spawner adds them after the pod).
	for child in get_children():
		_listen_to(child)
	child_entered_tree.connect(_listen_to)


func _physics_process(delta: float) -> void:
	_think(delta)


## Each physics frame. Kinds of pod can override this for behaviour beyond the attack steps.
func _think(delta: float) -> void:
	_phase_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_relay_quiet += delta
	if _relay_quiet > tuning.relay_reset_seconds:
		_relays_left = tuning.relay_max
	match phase:
		Phase.PATROL:
			if not _shadow_hunt():
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


## While a member hunts a penguin in the water (on its own, or after a relay), the free members
## shadow the hunt flank_distance off the penguin, either side of the hunter's line, ready to take
## over (relay strikes). False if nobody's hunting; then any shadowing is over and they're
## released.
func _shadow_hunt() -> bool:
	var hunter: Predator = null
	if tuning.relay_strikes:
		for member in members():
			var prey := member.target
			if member.state in [Predator.State.CHASE, Predator.State.WARN, Predator.State.LUNGE, Predator.State.RECOVER] \
					and is_instance_valid(prey) and _in_water(prey) and not member.shies_from(prey):
				hunter = member
				break
	if hunter == null:
		if _shadowing:
			_shadowing = false
			release_all()
		return false
	_shadowing = true
	var prey := hunter.target
	var from := hunter.global_position - prey.global_position
	from.y = 0.0
	from = from.normalized() if from.length() > 0.1 else Vector3.BACK
	var slot := 0
	for member in members():
		if member == hunter or not member.is_available():
			continue
		slot += 1
		var side := 1.0 if slot % 2 == 1 else -1.0
		var angle := side * deg_to_rad(tuning.flank_angle_deg) * ((slot + 1) / 2)
		var spot := prey.global_position + from.rotated(Vector3.UP, angle) * tuning.flank_distance
		spot.y = GameWorld.WATER_LEVEL - member.tuning.patrol_depth.x
		member.order_move(spot, member.tuning.chase_speed, Predator.MIN_DEPTH, Vector3.ZERO, false)
	return true


static func _in_water(p: Penguin) -> bool:
	return p.state == Penguin.State.SWIM or p.global_position.y < GameWorld.WATER_LEVEL


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


## Calls off the attack under way (a humpback has come to break it up, say): the attackers go back
## to the pod, and no attack for the attack's cooldown.
func call_off() -> void:
	if attack == null:
		return
	attack.cancel()
	attack_called_off.emit(attack)
	_end_attack(attack.settings.cooldown)


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
		if free.size() >= candidate.settings.min_attackers and candidate.find_target(lead) >= 0.0 and not lead.shies_from(candidate.target):
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
	if trap_step == 1:
		_relays_left = tuning.relay_max
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
	if _phase_time >= attack.settings.hunt_seconds + _hunt_extra:
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
## left, or its target has got away (or is sheltering by a humpback the pod is shy of).
func _still_on() -> bool:
	attack.attackers = attack.attackers.filter(func(m: Predator) -> bool: return is_instance_valid(m) and m.is_available())
	var sheltered := not attack.attackers.is_empty() and attack.attackers[0].shies_from(attack.target)
	if attack.attackers.size() >= attack.settings.min_attackers and not attack.escaped() and not sheltered:
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
	_hunt_extra = 0.0
	phase_changed.emit(phase)


# --- Relay strikes --------------------------------------------------------------

func _listen_to(child: Node) -> void:
	var member := child as Predator
	if member == null or member.lunge_missed.is_connected(_on_member_missed):
		return
	member.lunge_missed.connect(_on_member_missed.bind(member))
	member.gave_up.connect(_on_member_missed.bind(member))
	member.bumped_penguin.connect(_on_member_bumped.bind(member))


func _on_member_missed(missed: Penguin, member: Predator) -> void:
	_relay(missed, member)


## A penguin bumped into a member. If that member is going for it itself, fine; if it's out of
## breath (or busy), another one goes in. Not while an attack is lining up or under way: the trap
## goes on (and a dazed penguin is all the easier to catch in it).
func _on_member_bumped(p: Penguin, member: Predator) -> void:
	if phase in [Phase.LINE_UP, Phase.WARN, Phase.CHARGE]:
		return
	if member.target == p and member.state in [Predator.State.CHASE, Predator.State.WARN, Predator.State.LUNGE]:
		if member.can_strike() or member.state != Predator.State.CHASE:
			return
	_relay(p, member)


## Sends the nearest other member that can strike at `p`, if relays are on and any are left, and
## `p` is still in the water and in reach. False if nobody went.
func _relay(p: Penguin, missed_by: Predator) -> bool:
	if not tuning.relay_strikes or _relays_left <= 0 or not is_instance_valid(p) or not p.is_inside_tree():
		return false
	if not _in_water(p):
		return false
	var best: Predator = null
	var best_d := tuning.relay_range
	for member in members():
		if member == missed_by or not member.can_strike():
			continue
		var d := member.global_position.distance_to(p.global_position)
		if d <= best_d:
			best_d = d
			best = member
	if best == null:
		return false
	best.recall()
	if not best.order_strike(p):
		return false
	_relays_left -= 1
	_relay_quiet = 0.0
	if phase == Phase.HUNT:
		_hunt_extra += tuning.relay_extends_hunt
	relayed.emit(best, p)
	return true
