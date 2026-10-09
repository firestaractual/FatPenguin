class_name PenguinBrain
extends Node
## Drives a computer penguin (an NPC; GDD §4.6 and §8). Put it under a Penguin and give it a home
## berg; it steers the penguin through Penguin.wish_dir the way a player's stick would. Numbers are
## in NpcTuning (tuning/npc_default.tres).
##
## What it does, by mode:
##   HUDDLE  - stays in its berg's waddle, emperor-penguin style. Each penguin keeps warm by
##             having neighbours round it and shelter from the wind. A cold one on the windward
##             edge peels off, walks round the outside and pushes in at the lee side; a warm one
##             in the middle stops pushing and gets squeezed outward. So the huddle keeps turning
##             over and everyone takes a turn on the cold edge. Sheltered, it drains energy slower.
##   GATHER  - hungry: walks to the edge of the berg facing the nearest school and waits there
##             for others (a fishing party, like Adélies crowding at the ice edge).
##   GO_IN   - the party walks off the edge together.
##   FORAGE  - swims out to the school and eats until it's full, or the trip runs long, or a
##             predator comes for it.
##   HOME    - swims to the nearest way out of the water onto its berg: up a ramp, or a boost and
##             launch onto a low edge. A penguin knocked into the water comes here too.
##   CLIMB   - back on the ice: walks up to the huddle (through the exit's climb spots).
##   LEAVE   - done somewhere else (an errand to another berg): walks off its ice toward home.
## A predator hunting it close by: it boosts away if it can afford to and heads home.
##
## Errands (visit()): with an egg to lay somewhere other than home (WaddleMatch decides where),
## HOME and CLIMB take it to that berg's waddle instead, and it stands there until it's done
## (end_visit(), or it gives up after errand_seconds), then leaves for home. With an egg to lay
## (wants_egg) it fishes until breed_above instead of full_above.

enum Mode { HUDDLE, GATHER, GO_IN, FORAGE, HOME, CLIMB, LEAVE }

## How often it rethinks targets (s).
const THINK := 0.25
## Close enough to a spot it's walking to (m).
const ARRIVED := 0.9

## Each berg's open fishing party, by the berg's instance id: {"spot", "out", "school",
## "members": Array of brains, "since": time the first joined}.
static var _parties := {}
## Every brain, by its home berg's instance id.
static var _colonies := {}

@export var tuning: NpcTuning
## The berg it lives on.
var berg: IceBerg = null

var mode: Mode = Mode.HUDDLE
## It has an egg to lay (WaddleMatch sets it): it fishes until it's breed_above.
var wants_egg := false
## 0 (frozen) to 1 (toasty).
var warmth := 0.6
## True while it's pushing in toward the middle of the huddle (until it's warm).
var pushing := false

var _penguin: Penguin
var _think := 0.0
var _mode_time := 0.0
var _clock := 0.0
## Spots to walk through, in order (HUDDLE peeling round, CLIMB up an exit).
var _route: Array[Vector3] = []
var _party: Dictionary = {}
var _school := Vector3.ZERO
var _meal: Fish = null
var _exit: Dictionary = {}
var _launched := false
var _surfacing := false
var _stuck_time := 0.0
var _last_pos := Vector3.ZERO
var _detour := 0.0
var _detour_dir := Vector3.ZERO
var _avoid_side := 0.0
var _avoid_time := 0.0
## An errand: the berg it's going to (null: none), how long it's been at it, and the way off the
## ice once it's done ({"spot", "out"}, or {} to just walk toward home).
var _visit: IceBerg = null
var _visit_time := 0.0
var _leave_way := {}
## How long an errand may take (s); WaddleMatch sets it from WaddleTuning.errand_seconds.
var errand_seconds := 70.0


func _ready() -> void:
	_penguin = get_parent() as Penguin
	if tuning == null:
		tuning = preload("res://tuning/npc_default.tres")
	if _penguin == null:
		return
	_penguin.player_controlled = false
	_penguin.brain_controlled = true
	warmth = randf_range(0.3, 0.9)
	_join_colony()
	_penguin.caught.connect(func(_by: Node3D) -> void: _set_mode(Mode.CLIMB))


func _exit_tree() -> void:
	_leave_party()
	if berg != null and _colonies.has(berg.get_instance_id()):
		(_colonies[berg.get_instance_id()] as Array).erase(self)


## The brains living on `home`.
static func colony_of(home: IceBerg) -> Array:
	return _colonies.get(home.get_instance_id(), []) if home != null else []


## The brains on `home` that are huddling right now.
static func huddlers(home: IceBerg) -> Array:
	return colony_of(home).filter(func(b: PenguinBrain) -> bool: return is_instance_valid(b) and b.mode == Mode.HUDDLE)


## Goes to `target`'s waddle (an errand: to lay an egg there), then home. In the water it swims
## there now; on the ice it walks off toward it first.
func visit(target: IceBerg) -> void:
	if target == null or target == berg:
		end_visit()
		return
	_visit = target
	_visit_time = 0.0
	_exit = {}
	if _penguin == null:
		return
	if _penguin.state == Penguin.State.SWIM:
		_set_mode(Mode.HOME)
	elif mode in [Mode.HUDDLE, Mode.GATHER, Mode.CLIMB]:
		_leave_party()
		_set_mode(Mode.LEAVE)


## The errand's over (done, or no point any more): back home.
func end_visit() -> void:
	var was := _visit
	_visit = null
	_exit = {}
	if _penguin == null or was == null:
		return
	if _penguin.state == Penguin.State.SWIM:
		_set_mode(Mode.HOME)
	elif not _on_berg(berg):
		_set_mode(Mode.LEAVE)


## The berg it's on an errand to, or null.
func visiting() -> IceBerg:
	return _visit if is_instance_valid(_visit) else null


func set_home(home: IceBerg) -> void:
	if berg != null and _colonies.has(berg.get_instance_id()):
		(_colonies[berg.get_instance_id()] as Array).erase(self)
	berg = home
	_join_colony()


func _join_colony() -> void:
	if berg == null:
		return
	var id := berg.get_instance_id()
	if not _colonies.has(id):
		_colonies[id] = []
	if not (_colonies[id] as Array).has(self):
		(_colonies[id] as Array).append(self)


func _physics_process(delta: float) -> void:
	if _penguin == null or berg == null:
		return
	_clock += delta
	_mode_time += delta
	_think -= delta
	if _visit != null:
		_visit_time += delta
		if not is_instance_valid(_visit) or _visit_time > errand_seconds:
			end_visit()
	var rethink := _think <= 0.0
	if rethink:
		_think = THINK
	_penguin.wish_brake = false
	# On its belly on the ice: dig in and get up.
	if _penguin.state == Penguin.State.SLIDE:
		_penguin.wish_dir = Vector3.ZERO
		_penguin.wish_brake = true
		return
	var in_water := _penguin.state == Penguin.State.SWIM
	if in_water and mode in [Mode.HUDDLE, Mode.GATHER, Mode.CLIMB, Mode.LEAVE]:
		_leave_party()
		_set_mode(Mode.HOME) # knocked in, or slipped
	if not in_water and _penguin.state == Penguin.State.WALK and mode in [Mode.FORAGE, Mode.HOME]:
		_set_mode(Mode.CLIMB)
	match mode:
		Mode.HUDDLE:
			_huddle(delta, rethink)
		Mode.GATHER:
			_gather()
		Mode.GO_IN:
			_go_in()
		Mode.FORAGE:
			_forage(rethink)
		Mode.HOME:
			_home(rethink)
		Mode.CLIMB:
			_climb()
		Mode.LEAVE:
			_leave()
	if mode != Mode.HUDDLE:
		_penguin.drain_mult = tuning.travel_drain
	_check_stuck(delta)


# --- Huddle -------------------------------------------------------------------

func _huddle(delta: float, rethink: bool) -> void:
	var t := tuning
	var me := _penguin.global_position
	var wind := _wind()
	var mates := huddlers(berg)
	var middle := _huddle_middle(mates)
	var radius := 0.42 * sqrt(maxf(mates.size(), 1.0)) + 0.4
	# How exposed it is: few neighbours, and nobody upwind.
	var near := 0
	var upwind := false
	for node in get_tree().get_nodes_in_group(&"penguins"):
		var other := node as Penguin
		if other == null or other == _penguin or other.state != Penguin.State.WALK:
			continue
		var rel := other.global_position - me
		rel.y = 0.0
		var d := rel.length()
		if d <= t.neighbour_range:
			near += 1
		if d <= t.neighbour_range * 1.3 and rel.dot(-wind) > 0.3 * d:
			upwind = true
	var exposure := (1.0 - minf(float(near) / t.full_shelter_neighbours, 1.0)) * 0.5 + (0.0 if upwind else 0.5)
	warmth = clampf(warmth + (t.warmth_gain * (1.0 - exposure) - t.warmth_loss * exposure) * delta, 0.0, 1.0)
	_penguin.drain_mult = lerpf(t.sheltered_drain, t.exposed_drain, exposure)

	if rethink and _penguin.energy < t.hungry_below and _route.is_empty():
		if _join_party():
			return
	var rel_mid := Vector3(me.x - middle.x, 0.0, me.z - middle.z)
	var lee := middle + wind * (radius + 0.5)
	if not _route.is_empty():
		if _walk_route():
			pushing = true
		return
	if rel_mid.length() > radius + 3.0:
		# Out of the huddle (just got here, or squeezed right out): come in at the lee side.
		_route = _round_to(lee, middle, radius)
		return
	if warmth < t.cold_below and not upwind and rel_mid.dot(-wind) > 0.0:
		# Cold on the windward edge: peel off and walk round to the lee.
		pushing = false
		_route = _round_to(lee, middle, radius)
		return
	if warmth > t.warm_above:
		pushing = false
	elif warmth < (t.cold_below + t.warm_above) * 0.5:
		pushing = true
	if pushing and rel_mid.length() > 0.5:
		_penguin.wish_dir = -rel_mid.normalized()
	elif not pushing and upwind and rel_mid.dot(wind) > -radius:
		# Warm and sheltered: it gives way, and the crowd pushing in from the lee moves it toward
		# the windward edge, where it'll cool off and take its turn going round. (Only as far as
		# the edge: past it, the whole huddle would creep off upwind.)
		_penguin.wish_dir = -wind * t.give_way
	else:
		_penguin.wish_dir = Vector3.ZERO


## The middle of the huddle: where its members are, held near the berg's waddle spot. A real
## huddle creeps downwind as the lee side fills; this one is pulled back harder the farther it
## has crept, so it stays in the middle of its berg.
func _huddle_middle(mates: Array) -> Vector3:
	var spot := berg.waddle_spot()
	var sum := Vector3.ZERO
	var n := 0
	for mate: PenguinBrain in mates:
		var p := mate._penguin.global_position
		if Vector2(p.x - spot.x, p.z - spot.z).length() < 8.0:
			sum += p
			n += 1
	if n == 0:
		return spot
	var mean := sum / n
	mean.y = spot.y
	var crept := Vector2(mean.x - spot.x, mean.z - spot.z).length()
	return mean.lerp(spot, clampf(0.4 + crept * 0.25, 0.4, 0.95))


## A route to `target` round the outside of a huddle `radius` wide at `middle` (the side nearer
## to where it is now), so it doesn't cut through the crowd.
func _round_to(target: Vector3, middle: Vector3, radius: float) -> Array[Vector3]:
	var me := _penguin.global_position
	var from := Vector3(me.x - middle.x, 0.0, me.z - middle.z)
	var to := Vector3(target.x - middle.x, 0.0, target.z - middle.z)
	var route: Array[Vector3] = []
	if from.length() > 0.1 and to.length() > 0.1 and from.angle_to(to) > deg_to_rad(70.0):
		var side := from.normalized().cross(Vector3.UP)
		if side.dot(to) < 0.0:
			side = -side
		var round := (from.normalized() + side).normalized() * (radius + 1.2)
		route.append(middle + round)
	route.append(target)
	return route


func _wind() -> Vector3:
	var w := Vector3(tuning.wind.x, 0.0, tuning.wind.z)
	return w.normalized() if w.length() > 0.01 else Vector3.RIGHT


# --- Fishing party ------------------------------------------------------------

## Joins (or starts) its berg's fishing party. False if there's nowhere to fish.
func _join_party() -> bool:
	var id := berg.get_instance_id()
	var party: Dictionary = _parties.get(id, {})
	if party.is_empty():
		var fish := Fish.nearest_in_school(berg.waddle_spot(), tuning.school_range)
		if fish == null:
			return false
		var way := _way_to_water(fish.home)
		if way.is_empty():
			return false
		party = {"spot": way["spot"], "out": way["out"], "school": fish.home, "members": [], "since": _clock}
		_parties[id] = party
	(party["members"] as Array).append(self)
	_party = party
	_school = party["school"]
	pushing = false
	_set_mode(Mode.GATHER)
	return true


func _leave_party() -> void:
	if _party.is_empty():
		return
	(_party["members"] as Array).erase(self)
	if (_party["members"] as Array).is_empty() and berg != null and _parties.get(berg.get_instance_id(), {}) == _party:
		_parties.erase(berg.get_instance_id())
	_party = {}


## Where to go in from the huddle (or from `from`) toward `goal`: a clear walk across flat ice to
## the edge. {"spot": a little way in from the edge, "out": the way off it} or {} if there isn't one.
func _way_to_water(goal: Vector3, from := Vector3.INF) -> Dictionary:
	var start := berg.waddle_spot() if from == Vector3.INF else from
	var toward := Vector3(goal.x - start.x, 0.0, goal.z - start.z).normalized()
	var space := _penguin.get_world_3d().direct_space_state
	for turn_deg in [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0, 135.0, -135.0, 180.0]:
		var dir := toward.rotated(Vector3.UP, deg_to_rad(turn_deg))
		var d := 0.0
		var clear := true
		while d < 60.0:
			d += 0.5
			var at := start + dir * d
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, start.y + 1.5, at.z), Vector3(at.x, -1.0, at.z), GameWorld.WORLD_LAYER))
			if hit.is_empty() or (hit["position"] as Vector3).y < GameWorld.WATER_LEVEL + 0.05:
				break # the edge
			if absf((hit["position"] as Vector3).y - start.y) > 0.35:
				clear = false # a step, a wall or a chute in the way
				break
		if clear and d > 1.5:
			return {"spot": start + dir * (d - 1.6), "out": dir}
	return {}


func _gather() -> void:
	if _party.is_empty():
		_set_mode(Mode.HUDDLE)
		return
	# Line up along the edge, side by side.
	var members: Array = _party["members"]
	var mine := _party_spot()
	_walk_to(mine)
	var waited := _clock - float(_party["since"])
	var ready := 0
	for m: PenguinBrain in members:
		if is_instance_valid(m) and m._penguin.global_position.distance_to(m._party_spot()) < 1.5:
			ready += 1
	if ready >= tuning.party_size or (waited > tuning.party_wait and ready >= 1 and _penguin.global_position.distance_to(mine) < 1.5):
		# Off they go: the party closes, and everyone in it goes in together.
		if berg != null and _parties.get(berg.get_instance_id(), {}) == _party:
			_parties.erase(berg.get_instance_id())
		for m: PenguinBrain in members:
			if is_instance_valid(m) and m.mode == Mode.GATHER:
				m._set_mode(Mode.GO_IN)


## Its place in the party's line-up at the edge: rows of five, side by side, 0.8 m apart.
func _party_spot() -> Vector3:
	if _party.is_empty():
		return _penguin.global_position
	var members: Array = _party["members"]
	var i := members.find(self)
	var out: Vector3 = _party["out"]
	var side := out.cross(Vector3.UP).normalized()
	return (_party["spot"] as Vector3) + side * ((i % 5) - 2) * 0.8 - out * (i / 5) * 0.8


func _go_in() -> void:
	var out: Vector3 = _party["out"] if not _party.is_empty() else (_penguin.global_position - berg.waddle_spot()).normalized()
	_penguin.wish_dir = Vector3(out.x, 0.0, out.z)
	if _penguin.state == Penguin.State.SWIM:
		_party = {}
		_set_mode(Mode.FORAGE)
	elif _mode_time > 6.0:
		_party = {}
		_set_mode(Mode.HUDDLE) # couldn't get off (a gap it won't hop?): give up


# --- In the water -------------------------------------------------------------

func _forage(rethink: bool) -> void:
	var full := tuning.breed_above if wants_egg else tuning.full_above
	if _danger() or _penguin.energy >= full or _mode_time > tuning.trip_seconds:
		_set_mode(Mode.HOME)
		return
	if _needs_air():
		return
	if rethink and (_meal == null or not is_instance_valid(_meal) or not _meal.visible):
		_meal = Fish.nearest_in_school(_penguin.global_position, 20.0, true)
		if _meal == null and _penguin.global_position.distance_to(_school) < 8.0:
			# Nothing left here: on to the next school, if there's one near enough.
			_meal = Fish.nearest_in_school(_penguin.global_position, 45.0, true)
			if _meal == null:
				_set_mode(Mode.HOME)
				return
			_school = _meal.home
	var goal := _meal.global_position if _meal != null and is_instance_valid(_meal) else _school
	_swim_toward(goal, goal.y)


func _home(rethink: bool) -> void:
	# A predator on it: it boosts away if it can, and keeps heading home either way.
	_danger()
	if rethink and _exit.is_empty():
		_exit = _nearest_exit()
		_launched = false
	if _exit.is_empty():
		_swim_toward(_target().waddle_spot(), -tuning.swim_depth)
		return
	if not _launched and _needs_air():
		return
	var at: Vector3 = _exit["at"]
	var toward: Vector3 = _exit["toward"]
	var me := _penguin.global_position
	var flat := Vector3(me.x - at.x, 0.0, me.z - at.z)
	var along := flat.dot(toward) # how far past the approach spot, toward the ice
	var lateral := (flat - toward * along).length()
	# On the line in, between the approach spot and the ice (not off to the side, not round the far
	# side of the berg).
	var on_line := along > -2.0 and along < _exit_out() + 1.5
	if _exit["launch"]:
		# Come in deep, then pitch up hard and boost out onto the ice.
		var edge := at + toward * _exit_out()
		var to_edge := Vector3(edge.x - me.x, 0.0, edge.z - me.z).length()
		if not _launched and (lateral > 2.0 or not on_line):
			_swim_toward(at + toward * 0.5 + Vector3.DOWN * tuning.launch_depth, -tuning.launch_depth)
			return
		if not _launched and to_edge > tuning.launch_distance:
			_swim_toward(edge - toward * (tuning.launch_distance - 0.5) + Vector3.DOWN * tuning.launch_depth, -tuning.launch_depth)
			return
		var pitch := deg_to_rad(tuning.launch_pitch_deg)
		_penguin.wish_dir = toward * cos(pitch) + Vector3.UP * sin(pitch)
		if not _launched and _penguin.get_heading().y > sin(pitch) * 0.8:
			_penguin.wish_action = true
			_launched = true
		elif _launched and _penguin.state == Penguin.State.SWIM and _penguin.get_speed() < 5.0:
			# Fell back in: go round again.
			_launched = false
			_exit = {}
		return
	# A ramp or shelf: swim at the surface straight up it.
	if lateral > 1.5 or not on_line:
		_swim_toward(at, -0.2)
		return
	_penguin.wish_dir = toward + Vector3.UP * clampf(-me.y - 0.1, 0.0, 1.0)


func _climb() -> void:
	if _penguin.state == Penguin.State.SWIM:
		_set_mode(Mode.HOME)
		return
	var target := _target()
	if not _on_berg(target):
		# On the wrong ice (a floe, another berg): back into the water toward where it's going.
		var home := target.waddle_spot()
		_penguin.wish_dir = Vector3(home.x - _penguin.global_position.x, 0.0, home.z - _penguin.global_position.z).normalized()
		return
	if not _route.is_empty():
		_walk_route()
		return
	var spot := target.waddle_spot()
	var there := Vector2(_penguin.global_position.x - spot.x, _penguin.global_position.z - spot.z).length()
	if _visit != null:
		# On an errand: into the middle of their waddle, and wait there until it's done.
		if there > 2.0:
			_walk_to(spot)
		else:
			_penguin.wish_dir = Vector3.ZERO
		return
	if there < 4.0:
		_exit = {}
		_set_mode(Mode.HUDDLE)
		return
	_walk_to(spot)


## Off the ice it's on, toward home: to a clear stretch of edge facing home, and over it.
func _leave() -> void:
	if _mode_time < 0.05 or (_leave_way.is_empty() and _mode_time < 0.3):
		_leave_way = _way_to_water(berg.waddle_spot(), _penguin.global_position)
	var home := berg.waddle_spot()
	var toward := Vector3(home.x - _penguin.global_position.x, 0.0, home.z - _penguin.global_position.z).normalized()
	if _leave_way.is_empty():
		_penguin.wish_dir = toward
	elif _penguin.global_position.distance_to(_leave_way["spot"]) > 1.2 and _mode_time < 12.0:
		_walk_to(_leave_way["spot"])
	else:
		_penguin.wish_dir = _leave_way["out"]
	if _mode_time > 25.0:
		_leave_way = {}
		_mode_time = 0.0


## A predator is hunting it close by, or it's inside a humpback's bubble net: boost away if it
## can, and head home.
func _danger() -> bool:
	var me := _penguin.global_position
	var whale := Humpback.net_closing_on(me) if _penguin.state == Penguin.State.SWIM else null
	if whale != null:
		var out := me - whale.net_centre()
		out.y = 0.0
		_penguin.wish_dir = out.normalized() if out.length() > 0.1 else _penguin.get_facing()
		_penguin.wish_action = not _penguin.is_boosting()
		return true
	for node in get_tree().get_nodes_in_group(&"predators"):
		var predator := node as Predator
		if predator == null or not predator.is_hunting(_penguin):
			continue
		var away := me - predator.global_position
		if away.length() > tuning.flee_range:
			continue
		if _penguin.state == Penguin.State.SWIM and not _penguin.is_boosting():
			_penguin.wish_dir = Vector3(away.x, 0.0, away.z).normalized()
			_penguin.wish_action = true
		return true
	return false


## Low on air: straight up until it's got its breath back. True while it's doing that.
func _needs_air() -> bool:
	if _penguin.air < tuning.surface_below_air:
		_surfacing = true
	elif _penguin.air >= _penguin.tuning.air_seconds * 0.9:
		_surfacing = false
	if not _surfacing:
		return false
	var h := _penguin.get_facing()
	_penguin.wish_dir = h * 0.5 + Vector3.UP
	return true


func _swim_toward(goal: Vector3, depth_y: float) -> void:
	var me := _penguin.global_position
	var to := goal - me
	var flat := Vector3(to.x, 0.0, to.z)
	# Hold the cruising depth on the way, and dive or rise to the goal near it.
	var want_y := depth_y if flat.length() > 6.0 else goal.y
	want_y = minf(want_y, -Penguin.SURFACE_DEPTH)
	var dir := flat.normalized() if flat.length() > 0.1 else _penguin.get_facing()
	dir = _round_ice(dir, minf(flat.length(), 10.0))
	dir.y = clampf((want_y - me.y) * 0.6, -0.8, 0.8)
	_penguin.wish_dir = dir.normalized()


## Ice in the way (a berg between it and where it's going): swim round it, keeping to one side
## for a moment so it doesn't dither.
func _round_ice(dir: Vector3, look: float) -> Vector3:
	_avoid_time = maxf(_avoid_time - get_physics_process_delta_time(), 0.0)
	if look < 1.0:
		return dir
	var space := _penguin.get_world_3d().direct_space_state
	var from := _penguin.global_position
	var ahead := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * look, GameWorld.WORLD_LAYER, [_penguin.get_rid()]))
	if ahead.is_empty():
		if _avoid_time <= 0.0:
			_avoid_side = 0.0
		return dir if _avoid_time <= 0.0 else dir.rotated(Vector3.UP, _avoid_side * deg_to_rad(40.0))
	var sides := [_avoid_side] if _avoid_side != 0.0 else [1.0, -1.0]
	for side: float in sides + [-_avoid_side if _avoid_side != 0.0 else 0.0]:
		if side == 0.0:
			continue
		for turn_deg in [45.0, 75.0, 105.0]:
			var try := dir.rotated(Vector3.UP, side * deg_to_rad(turn_deg))
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + try * 6.0, GameWorld.WORLD_LAYER, [_penguin.get_rid()])).is_empty():
				_avoid_side = side
				_avoid_time = 1.5
				return try
	return dir.rotated(Vector3.UP, deg_to_rad(90.0))


## The quickest way home: swimming to an exit, then walking from it to the huddle (walking is
## the slow part).
func _nearest_exit() -> Dictionary:
	var me := _penguin.global_position
	var target := _target()
	var huddle := target.waddle_spot()
	var swim_speed := _penguin.tuning.swim_cruise_speed
	var walk_speed := _penguin.tuning.walk_speed
	var best := {}
	var best_time := INF
	for exit: Dictionary in target.exits():
		var at: Vector3 = exit["at"]
		var time := me.distance_to(at) / swim_speed + Vector2(at.x - huddle.x, at.z - huddle.z).length() / walk_speed
		# A launch takes energy for the boost; low on it, prefer a ramp.
		if exit["launch"] and not _penguin.vitals.can_afford(_penguin.tuning.boost_energy_cost):
			time += 1000.0
		if time < best_time:
			best_time = time
			best = exit
	return best


## How far from the approach spot to the ice for the current exit.
func _exit_out() -> float:
	var at: Vector3 = _exit["at"]
	var toward: Vector3 = _exit["toward"]
	var space := _penguin.get_world_3d().direct_space_state
	var from := Vector3(at.x, 0.3, at.z)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + toward * 12.0, GameWorld.WORLD_LAYER))
	return from.distance_to(hit["position"]) if not hit.is_empty() else 4.5


func _on_home_berg() -> bool:
	return _on_berg(berg)


func _on_berg(which: IceBerg) -> bool:
	if which == null:
		return false
	var me := _penguin.global_position
	var centre := which.global_position
	return Vector2(me.x - centre.x, me.z - centre.z).length() <= which.reach() + 0.5 and me.y > GameWorld.WATER_LEVEL + 0.2


## Where it's headed: the berg it's on an errand to, or home.
func _target() -> IceBerg:
	return _visit if _visit != null and is_instance_valid(_visit) else berg


# --- Walking ------------------------------------------------------------------

func _walk_to(spot: Vector3) -> void:
	var to := Vector3(spot.x - _penguin.global_position.x, 0.0, spot.z - _penguin.global_position.z)
	if _detour > 0.0:
		_penguin.wish_dir = _detour_dir
		return
	_penguin.wish_dir = to.normalized() * clampf(to.length(), 0.0, 1.0) if to.length() > 0.25 else Vector3.ZERO


## Walks the route, dropping spots as it reaches them. True once it's done.
func _walk_route() -> bool:
	while not _route.is_empty():
		var next: Vector3 = _route[0]
		if Vector2(_penguin.global_position.x - next.x, _penguin.global_position.z - next.z).length() < ARRIVED:
			_route.remove_at(0)
			continue
		_walk_to(next)
		return false
	_penguin.wish_dir = Vector3.ZERO
	return true


## Pressing on but going nowhere (a wall): walk off to the side for a moment.
func _check_stuck(delta: float) -> void:
	_detour = maxf(_detour - delta, 0.0)
	if _penguin.state != Penguin.State.WALK or _penguin.wish_dir.length() < 0.5 or mode == Mode.HUDDLE:
		_stuck_time = 0.0
		_last_pos = _penguin.global_position
		return
	if _penguin.global_position.distance_to(_last_pos) < 0.4 * delta:
		_stuck_time += delta
	else:
		_stuck_time = maxf(_stuck_time - delta, 0.0)
	_last_pos = _penguin.global_position
	if _stuck_time > 0.8 and _detour <= 0.0:
		_stuck_time = 0.0
		_detour = 1.5
		_detour_dir = _penguin.wish_dir.rotated(Vector3.UP, deg_to_rad(70.0 if randf() < 0.5 else -70.0))
		_detour_dir.y = 0.0


func _set_mode(new_mode: Mode) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	_mode_time = 0.0
	_route.clear()
	_meal = null
	_surfacing = false
	if new_mode == Mode.CLIMB:
		# Up through the exit's climb spots, if it has any.
		for spot: Vector3 in _exit.get("climb", []):
			_route.append(spot)
	elif new_mode != Mode.HOME:
		_exit = {}
