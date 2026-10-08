extends "res://tests/smoke_suite.gd"
## Leopard seals: patrol, targeting, lock-on, the lunge warning, catches, hunger, the edge ambush,
## and how readily they come after you (hearing a splash, breaking off feeding or an ambush).


func suite_name() -> String:
	return "seals"


func run() -> void:
	await _test_predators()
	await _test_seal_ambush()
	await _test_seal_aggression()


func _test_predators() -> void:
	# Out of the way: the player waits on the plateau, out of reach, and the level's dummies go.
	await _place_on_ice(_penguin, Vector3(0.0, 3.0, -8.0), 0.0, 50.0)
	for dummy in _level.get_node("Dummies").get_children():
		dummy.queue_free()
	await _frames(2)
	var berg_radius: float = _level.berg_radius

	# Patrol: around the berg and past the schools, in the water and never into the ice. (This one
	# stays round the home floe; roaming the field is checked below.)
	var seal := _spawn_seal(Vector3(berg_radius + 4.0, -2.5, 0.0))
	var stay := seal.tuning.duplicate() as PredatorTuning
	stay.roam_chance = 0.0
	seal.tuning = stay
	var last := 0.0
	var swept := 0.0
	var closest := INF
	var highest := -INF
	for i in 30 * 60:
		await tree.physics_frame
		var at := seal.global_position
		var angle := atan2(at.z, at.x)
		swept += absf(wrapf(angle - last, -PI, PI))
		last = angle
		highest = maxf(highest, at.y)
		if at.y > -3.2:
			closest = minf(closest, Vector2(at.x, at.z).length())
	_check(rad_to_deg(swept) > 45.0, "a seal on patrol swims around the berg (%.0f° in 30 s)" % rad_to_deg(swept))
	_check(highest < 0.0 and closest > berg_radius, "and stays in the water, clear of the ice (top y=%.2f, closest %.1f m out)" % [highest, closest])
	seal.queue_free()

	# In the berg field a seal heads off now and then to patrol another berg.
	seal = _spawn_seal(Vector3(berg_radius + 4.0, -2.5, 0.0))
	var roams := seal.tuning.duplicate() as PredatorTuning
	roams.roam_chance = 0.5
	roams.school_visit_chance = 0.0
	seal.tuning = roams
	var visited := {}
	for i in 90 * 60:
		await tree.physics_frame
		if i % 30 == 0 and seal.patrol_berg != null:
			visited[seal.patrol_berg.name] = true
		if visited.size() >= 2 and seal.patrol_berg != null and seal.global_position.distance_to(seal.patrol_berg.global_position) < seal.patrol_berg.reach() + 8.0 and seal.patrol_berg.name != "HomeFloe":
			break
	_check(visited.size() >= 2, "a seal roams the berg field, patrolling more than one berg (%s)" % ", ".join(visited.keys()))
	seal.queue_free()

	# Targeting: of two penguins in sight, it locks on to the more tempting, fatter one.
	var spot := Vector3(0.0, -3.0, -110.0)
	seal = _spawn_seal(spot)
	var thin := _spawn_bait(spot + Vector3(-10.0, 1.0, 0.0), 0.0)
	var fat := _spawn_bait(spot + Vector3(10.0, 1.0, 0.0), 100.0)
	var events := {"warn": -1, "lunge": -1, "caught": null}
	seal.state_changed.connect(func(s: Predator.State) -> void:
		if s == Predator.State.WARN:
			events["warn"] = Engine.get_physics_frames()
		elif s == Predator.State.LUNGE:
			events["lunge"] = Engine.get_physics_frames())
	seal.caught_penguin.connect(func(p: Penguin) -> void: events["caught"] = p)
	await _frames(10)
	_check(seal.target == fat and seal.state == Predator.State.CHASE, "a seal locks on to the most tempting penguin in sight: the fat one")
	for i in 600:
		await tree.physics_frame
		if events["caught"] != null:
			break
	var warning := float(events["lunge"] - events["warn"]) / 60.0
	_check(events["warn"] >= 0 and absf(warning - seal.tuning.lunge_warning) < 0.05, "it warns for %.2f s before it lunges" % warning)
	_check(events["caught"] == fat, "and the lunge catches the fat penguin")
	# Sated: slow and harmless. The thin penguin right beside it is safe.
	thin.global_position = seal.global_position + Vector3(2.0, 0.0, 0.0)
	await _frames(120)
	_check(seal.state == Predator.State.SATED and events["caught"] == fat, "a seal that has just eaten is sated and leaves a penguin beside it alone")
	seal.queue_free()
	thin.queue_free()
	fat.queue_free()

	# Caught while swimming: the player is eaten and respawns on the ice.
	var spawn := _penguin.spawn_point()
	_place_swimming(spot + Vector3(0.0, 1.0, -8.0), 0.0, 0.0)
	seal = _spawn_seal(spot)
	var eaten := [false]
	_penguin.caught.connect(func(_by: Node3D) -> void: eaten[0] = true, CONNECT_ONE_SHOT)
	for i in 900:
		await tree.physics_frame
		if eaten[0]:
			break
	_check(eaten[0] and _penguin.global_position.distance_to(spawn) < 1.0 and is_equal_approx(_penguin.energy, _penguin.tuning.starting_energy),
		"a seal catches a penguin swimming away, and it's eaten: back on the ice with starting energy")
	seal.queue_free()

	# The warning is a fair chance: turn off the strike line and the lunge misses.
	_place_swimming(Vector3(0.0, -1.0, 100.0), PI, 0.0)
	seal = _spawn_seal(Vector3(0.0, -2.0, 94.0))
	var dodge := {"warn": -1, "lunged": false, "caught": false}
	seal.state_changed.connect(func(s: Predator.State) -> void:
		if s == Predator.State.WARN and dodge["warn"] < 0:
			dodge["warn"] = Engine.get_physics_frames())
	seal.lunged.connect(func(_at: Vector3) -> void: dodge["lunged"] = true)
	seal.caught_penguin.connect(func(_p: Penguin) -> void: dodge["caught"] = true)
	for i in 900:
		await tree.physics_frame
		if dodge["warn"] >= 0 and Engine.get_physics_frames() == dodge["warn"] + 12:
			Input.action_press(&"move_left") # a 0.2 s reaction
		if dodge["caught"] or (dodge["lunged"] and seal.state == Predator.State.RECOVER):
			break
	Input.action_release(&"move_left")
	_check(dodge["lunged"] and not dodge["caught"], "turning off the strike line during the warning dodges the lunge")
	seal.queue_free()
	await _place_on_ice(_penguin, Vector3(0.0, 3.0, -8.0), 0.0, 50.0)

	# Starving: it goes to a school and eats fish, leaving a fat penguin 10 m away alone.
	# (A big silverfish school, so one school is enough to fill it up.)
	var school: Fish = null
	for fish: Fish in _level.get_node("Fish").get_children():
		if fish.species.display_name == "Antarctic silverfish" and fish.school_mate_count() >= 6:
			school = fish
			break
	var home := school.home
	var out := Vector3(home.x, 0.0, home.z).normalized()
	seal = _spawn_seal(Vector3(home.x, -2.5, home.z) + out * 8.0)
	seal.hunger = 90.0
	var bait := _spawn_bait(Vector3(home.x, -2.0, home.z) + out * 22.0, 100.0)
	var meals := [0]
	var chased := [false]
	var bait_id := bait.get_instance_id()
	seal.ate_fish.connect(func() -> void: meals[0] += 1)
	seal.locked_on.connect(func(p: Penguin) -> void: chased[0] = chased[0] or p.get_instance_id() == bait_id)
	for i in 900:
		await tree.physics_frame
		if meals[0] > 0 and seal.state != Predator.State.FEED:
			break
	_check(meals[0] > 0 and seal.hunger <= seal.tuning.fed_hunger, "a starving seal eats from a school (%d fish, hunger down to %.0f)" % [meals[0], seal.hunger])
	_check(not chased[0], "and leaves a fat penguin %.0f m off alone while it feeds" % (22.0 - 8.0))
	bait.queue_free()

	# Starving, it still lunges at a penguin that swims right up to it.
	seal.hunger = 90.0
	bait = _spawn_bait(seal.global_position + Vector3(0.0, 0.0, 3.0), 0.0)
	var lunged := [false]
	seal.lunged.connect(func(_at: Vector3) -> void: lunged[0] = true)
	for i in 120:
		await tree.physics_frame
		if lunged[0]:
			break
	_check(lunged[0], "a starving seal still lunges at a penguin that comes within lunge range")
	seal.queue_free()
	bait.queue_free()

	# Not starving, it never eats fish, even swimming through a school.
	seal = _spawn_seal(home)
	meals[0] = 0
	seal.ate_fish.connect(func() -> void: meals[0] += 1)
	await _frames(5 * 60)
	_check(meals[0] == 0, "a seal that isn't starving never eats fish")
	seal.queue_free()

	# The ice edge: a penguin standing right at it gets grabbed from the water...
	var edge := await _spawn_standing(Vector3(-berg_radius + 0.7, 1.0, 0.0), 0.0)
	seal = _spawn_seal(Vector3(-berg_radius - 4.0, -1.0, 0.0))
	var grabbed := [null]
	seal.caught_penguin.connect(func(p: Penguin) -> void: grabbed[0] = p)
	for i in 300:
		await tree.physics_frame
		if grabbed[0] != null:
			break
	_check(grabbed[0] == edge, "a penguin standing at the ice edge gets grabbed from the water")
	seal.queue_free()
	edge.queue_free()
	# ...but 4 m in from the edge it can't reach you, however often it tries.
	var inland := await _spawn_standing(Vector3(-berg_radius + 4.0, 1.0, 0.0), 0.0)
	seal = _spawn_seal(Vector3(-berg_radius - 1.5, -0.5, 0.0))
	var tries := [0]
	var got_inland := [false]
	seal.lunged.connect(func(_at: Vector3) -> void: tries[0] += 1)
	seal.caught_penguin.connect(func(_p: Penguin) -> void: got_inland[0] = true)
	await _frames(8 * 60)
	_check(not got_inland[0], "4 m in from the edge, a seal can't catch you (it lunged %d times)" % tries[0])
	seal.queue_free()
	inland.queue_free()


func _test_seal_ambush() -> void:
	var berg_radius: float = _level.berg_radius
	var world: World3D = (_level as Node3D).get_world_3d()
	# A penguin standing 3 m in from the west edge, and a seal that always lies in wait at the end
	# of a patrol leg when there's someone to wait for.
	var waiting := await _spawn_standing(Vector3(-berg_radius + 3.0, 1.0, 0.0), 60.0)
	var seal := _spawn_seal(Vector3(-berg_radius - 4.0, -2.5, -25.0))
	var t := seal.tuning.duplicate() as PredatorTuning
	t.ambush_chance = 1.0
	seal.tuning = t
	var ambushed := false
	for i in 25 * 60:
		await tree.physics_frame
		if seal.state == Predator.State.AMBUSH:
			ambushed = true
			break
	var spot := _ambush_spot_for(world, waiting, t)
	var settled := await _wait_settled(seal, spot, 20 * 60)
	_check(ambushed and settled, "a seal lies in wait under the ice edge nearest a penguin standing by it, still, %.1f m down" % -seal.global_position.y)

	# It follows along the edge as the penguin walks.
	var along := deg_to_rad(30.0)
	waiting.global_position = Vector3(-cos(along), 0.0, sin(along)) * (berg_radius - 3.0) + Vector3.UP * 1.5
	await _wait_for(waiting, Penguin.State.WALK, 60)
	await _frames(10)
	spot = _ambush_spot_for(world, waiting, t)
	_check(await _wait_settled(seal, spot, 12 * 60), "it moves along the edge when the penguin does")

	# The penguin goes in right where the seal waits: a quick lunge, and it's caught.
	var events := {"warn": -1, "lunge": -1}
	seal.state_changed.connect(func(s: Predator.State) -> void:
		if s == Predator.State.WARN and events["warn"] < 0:
			events["warn"] = Engine.get_physics_frames()
		elif s == Predator.State.LUNGE and events["lunge"] < 0:
			events["lunge"] = Engine.get_physics_frames())
	var caught := [false]
	waiting.caught.connect(func(_by: Node3D) -> void: caught[0] = true)
	var edge := IceEdges.nearest_edge(world, waiting.global_position, t.ambush_edge_reach)
	var start := Engine.get_physics_frames()
	_put_in_water(waiting, (edge["point"] as Vector3) + (edge["out"] as Vector3) * 1.0)
	for i in 3 * 60:
		await tree.physics_frame
		if caught[0]:
			break
	var reacted := float(events["warn"] - start) / 60.0
	var warning := float(events["lunge"] - events["warn"]) / 60.0
	_check(events["warn"] >= 0 and reacted < 0.5 and absf(warning - t.ambush_warning) < 0.05,
		"a penguin going into the water there gets a lunge %.2f s later, after a short %.2f s warning" % [reacted, warning])
	_check(caught[0], "and is caught")
	seal.queue_free()
	await _frames(2)

	# Nobody near the edge any more: it gives up waiting.
	waiting.reset()
	await _wait_for(waiting, Penguin.State.WALK, 60)
	seal = _spawn_seal(Vector3(-berg_radius - 4.0, -2.5, -10.0))
	seal.tuning = t
	_check(seal.start_ambush(), "(a second seal lies in wait for it)")
	await _wait_settled(seal, _ambush_spot_for(world, waiting, t), 15 * 60)
	waiting.global_position = Vector3(-10.0, 1.5, 15.0)
	var gave_up := false
	for i in 4 * 60:
		await tree.physics_frame
		if seal.state != Predator.State.AMBUSH:
			gave_up = true
			break
	_check(gave_up and seal.state == Predator.State.PATROL, "with nobody near that edge any more, it gives up waiting")

	# Going in somewhere else gives you a head start: no lunge straight away.
	waiting.global_position = Vector3(-berg_radius + 3.0, 1.5, 0.0)
	await _wait_for(waiting, Penguin.State.WALK, 60)
	seal.start_ambush()
	await _wait_settled(seal, _ambush_spot_for(world, waiting, t), 15 * 60)
	var away := deg_to_rad(35.0)
	var far_spot := Vector3(-cos(away), 0.0, -sin(away)) * (berg_radius + 1.0)
	var lunged := [false]
	seal.state_changed.connect(func(s: Predator.State) -> void: lunged[0] = lunged[0] or s == Predator.State.WARN)
	_put_in_water(waiting, far_spot)
	await _frames(60)
	_check(not lunged[0] and seal.global_position.distance_to(waiting.global_position) > t.ambush_strike_range,
		"a penguin going in %.0f m along the edge from the seal gets a head start" % seal.global_position.distance_to(far_spot))
	seal.queue_free()
	await _frames(2)

	# Coming home past a seal lying in wait: boost and launch from 6.5 m out (before you're close
	# enough for it to strike) and you get past it.
	waiting.reset()
	await _wait_for(waiting, Penguin.State.WALK, 60)
	seal = _spawn_seal(Vector3(-berg_radius - 4.0, -2.5, -6.0))
	seal.tuning = t
	seal.start_ambush()
	spot = _ambush_spot_for(world, waiting, t)
	await _wait_settled(seal, spot, 15 * 60)
	var inward := -Vector3(spot.x, 0.0, spot.z).normalized()
	var from := spot - inward * 12.0
	from.y = -0.6
	var coming := _spawn_swimmer(from, atan2(-inward.x, -inward.z))
	coming.set_swim_speed(coming.tuning.swim_cruise_speed)
	var got_coming := [false]
	coming.caught.connect(func(_by: Node3D) -> void: got_coming[0] = true)
	var launched := false
	var made_it := false
	for i in 8 * 60:
		if coming.state == Penguin.State.SWIM:
			coming.set_facing(atan2(-inward.x, -inward.z))
			if not launched and Vector2(coming.global_position.x, coming.global_position.z).length() < berg_radius + 6.5:
				coming.set_pitch(deg_to_rad(40.0))
				coming.boost()
				launched = true
		await tree.physics_frame
		if got_coming[0]:
			break
		if coming.state in [Penguin.State.WALK, Penguin.State.SLIDE] and coming.global_position.y > 0.5:
			made_it = true
			break
	_check(made_it and not got_coming[0], "a penguin that boosts and launches out from 6.5 m away gets past a seal lying in wait")
	seal.queue_free()
	coming.queue_free()
	waiting.queue_free()
	await _frames(2)


func _test_seal_aggression() -> void:
	var berg_radius: float = _level.berg_radius
	var world: World3D = (_level as Node3D).get_world_3d()
	# Out in open water: a seal hears a penguin splash in from farther off than it would see one
	# swimming quietly.
	var open_water := Vector3(-70.0, -2.5, -70.0)
	var seal := _spawn_seal(open_water)
	var stay := seal.tuning.duplicate() as PredatorTuning
	stay.roam_chance = 0.0
	seal.tuning = stay
	var quiet_at := seal.tuning.detect_range + 4.0
	var quiet := _spawn_bait(open_water + Vector3(quiet_at, 2.0, 0.0), 100.0)
	quiet.force_state(Penguin.State.SWIM)
	var noticed := {}
	seal.locked_on.connect(func(p: Penguin) -> void: noticed[p] = true)
	for i in 60:
		quiet.global_position = seal.global_position + Vector3(quiet_at, 0.0, 0.0)
		quiet.global_position.y = -0.5
		await tree.physics_frame
	_check(not noticed.has(quiet), "a seal doesn't notice a penguin swimming quietly %.0f m off" % quiet_at)
	quiet.queue_free()
	var diver := _spawn_swimmer(seal.global_position + Vector3(0.0, 0.0, quiet_at), 0.0)
	diver.global_position.y = 1.5
	diver.force_state(Penguin.State.AIR)
	diver.toss(Vector3(0.0, -3.0, 0.0))
	for i in 90:
		await tree.physics_frame
		if noticed.has(diver):
			break
	_check(noticed.has(diver) and diver.noise > 0.0, "but it hears one splash in at that distance, and comes for it")
	diver.queue_free()
	seal.queue_free()
	await _frames(2)

	# Lying in wait, a seal comes out after a penguin that goes in near it, out of its reach.
	var waiting := await _spawn_standing(Vector3(-berg_radius + 3.0, 1.0, 0.0), 60.0)
	seal = _spawn_seal(Vector3(-berg_radius - 4.0, -2.5, -10.0))
	var t := seal.tuning.duplicate() as PredatorTuning
	t.ambush_chance = 1.0
	t.roam_chance = 0.0
	seal.tuning = t
	seal.start_ambush()
	await _wait_settled(seal, _ambush_spot_for(world, waiting, t), 15 * 60)
	var along := (t.ambush_strike_range + t.ambush_break_range) * 0.5
	var angle := along / (berg_radius + 1.0)
	var spot := Vector3(-cos(angle), 0.0, -sin(angle)) * (berg_radius + 1.0)
	var came_out := [false]
	seal.locked_on.connect(func(p: Penguin) -> void: came_out[0] = came_out[0] or p == waiting)
	_put_in_water(waiting, spot)
	for i in 60:
		await tree.physics_frame
		if came_out[0]:
			break
	_check(came_out[0] and seal.state != Predator.State.AMBUSH,
		"a seal lying in wait comes out after a penguin that goes in %.0f m along the edge" % along)
	seal.queue_free()
	waiting.queue_free()
	await _frames(2)

	# Starving and on its way to feed, a seal still breaks off for a penguin that comes close.
	seal = _spawn_seal(open_water)
	seal.tuning = stay
	seal.hunger = 95.0
	await _frames(20)
	var near := _spawn_swimmer(seal.global_position + Vector3(stay.feeding_break_range - 2.0, 0.0, 0.0), 0.0)
	near.global_position.y = -0.3
	var chased := [false]
	seal.locked_on.connect(func(p: Penguin) -> void: chased[0] = chased[0] or p == near)
	for i in 60:
		near.set_swim_speed(0.0)
		await tree.physics_frame
		if chased[0]:
			break
	_check(chased[0], "a starving seal breaks off feeding for a penguin %.0f m off" % (stay.feeding_break_range - 2.0))
	seal.queue_free()
	near.queue_free()
	await _frames(2)
