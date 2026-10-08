extends SceneTree
## Headless tuning trials for the orca pod's water attacks (and, once they're in, the
## humpbacks). Not part of the smoke test: it plays many short encounters with a bot penguin that
## reacts to each lunge warning the same way every time, and prints how often the pod catches it.
##
## Run from the project folder:
##   godot --headless --fixed-fps 60 --path . --script res://tests/trials/whale_trials.gd -- \
##       --scenario=carousel --policy=turn --reaction=0.3 --runs=8
## Scenarios: carousel (out in open water, holding still), carousel_edge (the same, keeping to the
## ring's edge, out of the slap zone), carousel_swim (keeps swimming round in a circle), cutoff
## (8 m off the ice, heading home), strike (swimming round in open water when one orca of a pod
## goes for it, as after a missed lunge: then the relays, for 14 s), strike_straight (the same,
## swimming straight on rather than round), lunge (one strike, out in open water far from the ice
## and the pod: one orca, 9-12 m off on any side; it swims straight on), lunge_circle (the same,
## swimming round).
## Policies at each lunge warning aimed at it, after `reaction` seconds: still (does nothing),
## turn (turns square to the strike line, away from it, and swims), cross (turns square to it the
## way it was already going, across the line), boost (turns away and boosts), dash (boosts
## straight on, whichever way it was going), smart (heading in toward the line: dashes across it;
## otherwise turns away and boosts). The bot turns at a
## penguin's real turn rate (slower when fat or stunned), as a player's stick would.
## With --single, each encounter ends after the first lunge (one strike, no relays). With
## --humpback=D, a humpback starts D m from the bot (it may come and drive the orcas off).
## Each line prints catches, and per run the lunges at it, the bumps that dazed it and the relay
## strikes the pod sent in.

const SmokeSuite := preload("res://tests/smoke_suite.gd")
const ORCA_POD_SPAWN := "res://levels/movement_toy/predators/orca_pod.tres"
## Open water in the movement toy: no ice within 30 m.
const OPEN_WATER := Vector3(-70.0, -0.1, -70.0)
const HUMPBACK_SCENE := preload("res://actors/whales/humpback.tscn")

var _h: SmokeSuite
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {"scenario": "carousel", "policy": "turn", "reaction": "0.3", "runs": "8", "seed": "1", "limit": "30", "first": "0", "humpback": "0"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var kv := arg.trim_prefix("--").split("=", true, 1)
			args[kv[0]] = kv[1]
	GameSettings.use_defaults()
	var level := load(SmokeSuite.LEVEL).instantiate() as MovementToy
	root.add_child(level)
	await physics_frame
	for spawned in level.get_node("Predators").get_children():
		spawned.queue_free()
	for npc in get_nodes_in_group(&"npcs"):
		npc.queue_free()
	for node in level.find_children("*", "Humpback", true, false):
		node.queue_free()
	for fish: Fish in level.get_node("Fish").get_children():
		fish.monitoring = false
	_h = SmokeSuite.new()
	_h.setup(self, level, _failures)
	var runs := int(args["runs"])
	var caught := 0
	var lunges := 0
	var dazed := 0
	var relays := 0
	var times: Array[float] = []
	var details: Array[String] = []
	var first_caught := 0
	var rescued := 0
	var rescue_time := 0.0
	for i in range(int(args["first"]), int(args["first"]) + runs):
		seed(int(args["seed"]) * 1000 + i)
		var r: Dictionary = await _encounter(level, args["scenario"], args["policy"], float(args["reaction"]), float(args["limit"]), float(args["humpback"]))
		if r["caught"]:
			caught += 1
			times.append(r["time"])
		lunges += r["lunges"]
		dazed += r["dazed"]
		relays += r["relays"]
		details.append("%s%d" % ["C" if r["caught"] else "-", r["lunges"]])
		if r["caught"] and r["lunges"] == 1:
			first_caught += 1
		if r["rescued"] >= 0.0:
			rescued += 1
			rescue_time += r["rescued"]
	var mean_time := 0.0
	for t in times:
		mean_time += t / maxf(times.size(), 1)
	print("TRIAL %s policy=%s reaction=%s: caught %d/%d (%d on the first lunge; %d%% of lunges hit), %.1f lunges, %.1f bumps, %.1f relays per run, caught after %.1f s on average  [%s]" % [
		args["scenario"], args["policy"], args["reaction"], caught, runs, first_caught, roundi(100.0 * caught / maxf(lunges, 1)), float(lunges) / runs, float(dazed) / runs, float(relays) / runs, mean_time, " ".join(details)])
	if float(args["humpback"]) > 0.0:
		print("  humpback %s m off: drove the orcas off %d/%d times, %.1f s in on average" % [args["humpback"], rescued, runs, rescue_time / maxf(rescued, 1)])
	quit(0)


## One encounter: a fresh pod and a bot penguin. Ends when it's caught, or `limit` seconds after
## the pod's first move, or once the trap is over and the pod is back on patrol.
func _encounter(level: MovementToy, scenario: String, policy: String, reaction: float, limit: float, humpback_off: float) -> Dictionary:
	var entry: PredatorSpawn = (load(ORCA_POD_SPAWN) as PredatorSpawn).duplicate()
	var at := Vector3(0.0, -0.1, -62.0)
	var keep: Array[String] = ["Carousel"]
	if scenario.begins_with("strike") or scenario.begins_with("lunge"):
		keep = []
		entry.start_angle_deg = -90.0
	elif scenario == "cutoff":
		entry.start_angle_deg = -50.0
		at = Vector3(0.0, -0.1, -level.berg_radius - 8.0)
		keep = ["Cut-off", "Carousel"]
	else:
		entry.start_angle_deg = -90.0
	var bot: Penguin = _h._spawn_swimmer(at, 0.0)
	bot.infinite_energy = false
	bot.energy = 50.0
	var spawner: PredatorSpawner = _h._spawn_pods()
	var pod: PredatorPod = _h._spawn_pod(spawner, entry)
	var kept: Array[PodAttack] = []
	for attack in pod.attacks():
		if attack.settings.display_name in keep:
			kept.append(attack)
	pod.set_attacks(kept)
	pod.clear_cooldown()
	var ev := {"caught": false, "lunges": 0, "warned_at": -1.0, "line": Vector3.ZERO, "from": Vector3.ZERO, "lunger": null, "react_until": -1.0, "dazed": 0, "relays": 0}
	bot.dazed.connect(func(_s: float) -> void: ev["dazed"] += 1)
	pod.relayed.connect(func(_m: Predator, _t: Penguin) -> void: ev["relays"] += 1)
	var clock := [0.0]
	bot.caught.connect(func(_b: Node3D) -> void: ev["caught"] = true)
	for member in pod.members():
		var m := member
		m.state_changed.connect(func(s: Predator.State) -> void:
			if s == Predator.State.WARN and m.target == bot:
				if OS.get_cmdline_user_args().has("--debug"):
					print("  warn at %.1f m (%s)" % [m.global_position.distance_to(bot.global_position), m.name])
				ev["warned_at"] = clock[0]
				ev["from"] = m.global_position
				var line := m.strike_direction()
				ev["line"] = Vector3(line.x, 0.0, line.z).normalized())
		m.lunged.connect(func(_to: Vector3) -> void:
			if m.target == bot:
				ev["lunges"] += 1
				ev["lunger"] = m
				if OS.get_cmdline_user_args().has("--debug"):
					var rel := bot.global_position - m.global_position
					var line := m.strike_direction()
					var along := rel.dot(line)
					print("  lunge: bot %.1f m along the line, %.1f m off it; bot speed %.1f, stunned %s, dazed %s" % [along, (rel - line * along).length(), bot.get_speed(), bot.is_stunned(), bot.is_dazed()]))
	var started := -1.0
	var reacted := -1.0
	var dodge_yaw := 0.0
	var ordered := false
	var circling := 0.9 # rad/s
	var single := OS.get_cmdline_user_args().has("--single") or scenario.begins_with("lunge")
	var striker: Predator = null
	if scenario.begins_with("lunge"):
		# Out in open water, far from the ice and the rest of the pod: one orca, 9-12 m off on any
		# side, strikes at it once.
		bot.global_position = OPEN_WATER
		bot.set_facing(randf() * TAU)
		bot.set_swim_speed(bot.tuning.swim_cruise_speed)
		circling = randf_range(0.4, 1.0) * (1.0 if randf() < 0.5 else -1.0)
		striker = pod.members()[0]
		var side := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
		striker.global_position = OPEN_WATER + side * randf_range(9.0, 12.0) + Vector3.DOWN * 2.0
	if scenario.begins_with("strike"):
		# Near the pod, in its way: the first strike comes from close by, from any side, and the
		# bot is headed any way and circles either way, at its own rate.
		var off := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(9.0, 14.0)
		bot.global_position = pod.leader().global_position + off
		bot.global_position.y = -0.1
		bot.set_facing(randf() * TAU)
		bot.set_swim_speed(bot.tuning.swim_cruise_speed)
		circling = randf_range(0.4, 1.0) * (1.0 if randf() < 0.5 else -1.0)
	var whale: Humpback = null
	ev["rescued"] = -1.0
	if humpback_off > 0.0:
		# A humpback this far off, cruising.
		whale = HUMPBACK_SCENE.instantiate() as Humpback
		var off := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * humpback_off
		whale.roam_centre = bot.global_position
		whale.ice_radius = 0.0
		whale.position = Vector3(bot.global_position.x + off.x, -4.0, bot.global_position.z + off.z)
		level.add_child(whale)
		whale.drove_off.connect(func(d: Penguin) -> void:
			if d == bot and ev["rescued"] < 0.0:
				ev["rescued"] = clock[0])
	while true:
		await physics_frame
		clock[0] += 1.0 / 60.0
		if striker != null and not ordered:
			striker.order_strike(bot)
			ordered = true
			started = clock[0]
		if scenario.begins_with("strike") and not ordered and clock[0] > 1.0:
			# One orca goes for it (as after a missed lunge, or a bump): the relays follow.
			var nearest: Predator = null
			for m in pod.members():
				if nearest == null or m.global_position.distance_to(bot.global_position) < nearest.global_position.distance_to(bot.global_position):
					nearest = m
			nearest.order_strike(bot)
			ordered = true
			started = clock[0]
		if ev["caught"]:
			break
		if single and ev["lunger"] != null and (ev["lunger"] as Predator).state != Predator.State.LUNGE:
			break # --single: just the first lunge
		if started < 0.0 and pod.phase != PredatorPod.Phase.PATROL:
			started = clock[0]
		if started >= 0.0 and not (scenario.begins_with("strike") or scenario.begins_with("lunge")) and (clock[0] - started > limit or (pod.phase == PredatorPod.Phase.PATROL and clock[0] - started > 3.0)):
			break
		if (scenario.begins_with("strike") or scenario.begins_with("lunge")) and started >= 0.0 and clock[0] - started > 14.0:
			break
		if OS.get_cmdline_user_args().has("--debug") and int(clock[0] * 60.0) % 30 == 0:
			var line := "t=%.1f bot=%s " % [clock[0], bot.global_position.snapped(Vector3.ONE * 0.1)]
			for m in pod.members():
				line += "| %s d=%.1f tgt=%s cd=%s " % [Predator.State.keys()[m.state], m.global_position.distance_to(bot.global_position), m.target == bot, m.can_strike()]
			print(line)
		if clock[0] > 60.0:
			break
		# A warning aimed at it: react after `reaction` seconds.
		var warned: float = ev["warned_at"]
		if policy != "still" and warned >= 0.0 and clock[0] - warned >= reaction and reacted < warned:
			reacted = warned
			var line: Vector3 = ev["line"]
			var side := line.cross(Vector3.UP).normalized()
			var from: Vector3 = ev["from"]
			var away := 1.0 if side.dot(bot.global_position - from) >= 0.0 else -1.0
			var heading_in := side.dot(bot.get_facing()) * away < -0.3
			if policy == "cross" or policy == "dash" or (policy == "smart" and heading_in):
				if side.dot(bot.get_facing()) < 0.0:
					side = -side
			else:
				# Away from the line: the side it's on now.
				side *= away
			dodge_yaw = atan2(-side.x, -side.z) if not (policy == "dash" or (policy == "smart" and heading_in)) else bot.facing_yaw()
			ev["react_until"] = clock[0] + 1.2
		if clock[0] < float(ev["react_until"]):
			_steer(bot, dodge_yaw)
			bot.set_pitch(0.0)
			bot.set_swim_speed(maxf(bot.swim_speed(), 2.0))
			if policy in ["boost", "dash", "smart"] and absf(angle_difference(bot.facing_yaw(), dodge_yaw)) < deg_to_rad(60.0):
				bot.boost()
			continue
		# Otherwise: in open water it holds its place; near the ice it heads home.
		var ring := pod.attack as CarouselAttack
		if scenario == "carousel_swim" or scenario == "strike" or scenario == "lunge_circle":
			# Keeps swimming, circling round where it started (a player milling about, not
			# sitting still): a slow turn at cruise speed.
			bot.set_facing(bot.facing_yaw() + circling / 60.0)
			bot.set_pitch(0.0)
		elif scenario == "lunge":
			bot.set_pitch(0.0) # swims straight on, whichever way it last turned
		elif scenario == "strike_straight":
			# Swims straight on, whichever way it last turned, but not into the ice.
			bot.set_pitch(0.0)
			var shore := IceEdges.nearest_shore(bot.get_world_3d(), bot.global_position, 8.0)
			if not shore.is_empty() and (shore["dir"] as Vector3).dot(bot.get_facing()) > -0.2:
				var off: Vector3 = -shore["dir"]
				_steer(bot, atan2(-off.x, -off.z))
		elif scenario == "carousel_edge" and ring != null and pod.phase != PredatorPod.Phase.LINE_UP:
			# Keeps to the edge of the ring, out of the slap zone.
			var out := Vector3(bot.global_position.x - ring.centre.x, 0.0, bot.global_position.z - ring.centre.z)
			var want := ring.centre + (out.normalized() if out.length() > 0.1 else Vector3.RIGHT) * maxf(ring.radius - 1.4, 3.6)
			var to := Vector3(want.x - bot.global_position.x, 0.0, want.z - bot.global_position.z)
			if to.length() > 0.4:
				_steer(bot, atan2(-to.x, -to.z))
				bot.set_pitch(0.0)
				bot.set_swim_speed(maxf(bot.swim_speed(), 2.0))
			else:
				bot.set_swim_speed(0.0)
		elif scenario == "cutoff":
			var shore := IceEdges.nearest_shore(bot.get_world_3d(), bot.global_position, 30.0)
			if not shore.is_empty():
				var home: Vector3 = shore["dir"]
				_steer(bot, atan2(-home.x, -home.z))
		else:
			bot.set_swim_speed(0.0)
	var result := {"caught": ev["caught"], "lunges": ev["lunges"], "time": clock[0] - maxf(started, 0.0), "dazed": ev["dazed"], "relays": ev["relays"],
		"rescued": ev["rescued"]}
	if whale != null:
		whale.queue_free()
	spawner.queue_free()
	bot.queue_free()
	await physics_frame
	await physics_frame
	return result


## Turns the bot toward `yaw` at a penguin's real turn rate (as holding the stick over would).
func _steer(bot: Penguin, yaw: float) -> void:
	var rate := deg_to_rad(bot.tuning.swim_turn_rate_deg) * bot.turn_rate_mult()
	if bot.is_stunned():
		rate *= bot.tuning.stun_turn_mult
	var diff := angle_difference(bot.facing_yaw(), yaw)
	bot.set_facing(bot.facing_yaw() + clampf(diff, -rate / 60.0, rate / 60.0))
