extends "res://tests/smoke_suite.gd"
## The berg field: ways out of the water onto every berg, gap hops on pack ice, tunnels, the lagoon and the spire.


func suite_name() -> String:
	return "bergs"


func run() -> void:
	await _test_berg_field()
	await _test_gap_hops()
	await _test_tunnels()
	await _test_spire_climb()


func _test_berg_field() -> void:
	var world: World3D = (_level as Node3D).get_world_3d()
	var space := world.direct_space_state
	# The kinds of berg, each with its real height-to-draft ratio (the International Ice Patrol's
	# averages), at penguin scale.
	var ratios := {"TabularBerg": 5.0, "WedgeBerg": 5.0, "PinnacleBerg": 2.0, "DomeBerg": 4.0, "DrydockBerg": 1.0}
	var kinds := {}
	var notes: Array[String] = []
	var real := true
	var climbable := true
	for node in tree.get_nodes_in_group(&"bergs"):
		var berg := node as IceBerg
		var kind: String = berg.get_script().get_global_name()
		if not ratios.has(kind):
			continue
		kinds[kind] = true
		var tallest := berg.top_height()
		if berg is PinnacleBerg:
			tallest = (berg as PinnacleBerg).lookout().y
		# The keel's bottom, straight under the middle (from below).
		var mid := Vector3(berg.global_position.x, -29.0, berg.global_position.z)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(mid, mid + Vector3.UP * 29.0, GameWorld.WORLD_LAYER))
		var draft := -(hit["position"] as Vector3).y if not hit.is_empty() else 0.0
		var ratio := draft / tallest
		real = real and absf(ratio - ratios[kind]) < 0.15 * ratios[kind]
		climbable = climbable and tallest <= 6.05
		notes.append("%s 1:%.1f" % [kind.trim_suffix("Berg").to_lower(), ratio])
	_check(kinds.size() == ratios.size(), "the field has a berg of every kind: tabular, wedge, pinnacle, dome, drydock")
	_check(real, "each sits as deep as the real kind does (%s)" % ", ".join(notes))
	_check(climbable, "and they're penguin-sized: no more than 6 m above the water")

	# Out of the water onto every berg: swim up its ramp or shelf, or launch onto its low edge.
	var landed: Array[String] = []
	var failed: Array[String] = []
	for node in tree.get_nodes_in_group(&"bergs"):
		var berg := node as IceBerg
		for exit in berg.exits():
			var ok := await _try_exit(berg, exit)
			(landed if ok else failed).append("%s %s" % [berg.name, "launch" if exit["launch"] else "ramp"])
			if not exit["launch"]:
				break # one ramp per berg is enough
	_check(failed.is_empty(), "you can get out of the water onto every berg (%d ways tried%s)" % [landed.size() + failed.size(), "" if failed.is_empty() else "; failed: " + ", ".join(failed)])

	# Fish keep clear of the ice, so a roaming fish doesn't swim into a keel.
	var too_close := 0
	for fish: Fish in _level.get_node("Fish").get_children():
		if not _level.clear_of_ice(fish.home, 5.0):
			too_close += 1
	_check(too_close == 0, "every fish lives at least 5 m from the ice (%d too close)" % too_close)


## Tries one way out of the water onto `berg`: a ramp (swim straight up it) or a launch (come in
## deep, pitch up, boost). True if it ends up standing on the berg.


func _test_gap_hops() -> void:
	# The pack ice east of the home floe: a thin penguin hops floe to floe all the way to the
	# wedge berg; a stuffed one hops the narrow gaps but stops at the first wide one.
	var chain := _level.get_node("BergField/PackIceEast") as FloeChain
	var dir := chain.end - chain.start
	dir.y = 0.0
	dir = dir.normalized()
	var total := (chain.end - chain.start).length()
	var results := {}
	for energy in [10.0, 100.0]:
		var p := load(PENGUIN_SCENE).instantiate() as Penguin
		p.player_controlled = false
		p.brain_controlled = true
		p.infinite_energy = true
		p.start_energy = energy
		_level.add_child(p)
		p.global_position = chain.global_transform * (chain.start - dir * 2.5) + Vector3.UP * 1.6
		p.set_facing(atan2(-dir.x, -dir.z))
		var hops := [0]
		p.hopped.connect(func(_d: float, _cleared: bool) -> void: hops[0] += 1)
		var wet := false
		var along := 0.0
		for i in 60 * 60:
			p.energy = energy # (a fish it swims past mustn't fatten it up on the way)
			p.wish_dir = dir
			p.wish_brake = p.state == Penguin.State.SLIDE
			await tree.physics_frame
			wet = wet or p.state == Penguin.State.SWIM
			along = (p.global_position - chain.global_transform * chain.start).dot(dir)
			if along > total + 1.0 and p.state == Penguin.State.WALK:
				break
		results[energy] = {"hops": hops[0], "along": along, "wet": wet, "reach": p.hop_distance()}
		p.queue_free()
		await _frames(2)
	var thin: Dictionary = results[10.0]
	var fat: Dictionary = results[100.0]
	var tilt := 0.0
	for floe in chain.floes():
		tilt = maxf(tilt, rad_to_deg(floe.global_basis.y.angle_to(Vector3.UP)))
	_check(thin["along"] > total and not thin["wet"], "a thin penguin hops the pack ice all the way to the wedge berg (%d hops, %.1f m gaps at most)%s" % [thin["hops"], thin["reach"],
		"" if thin["along"] > total and not thin["wet"] else " [got %.1f of %.1f m, wet %s, floes tilted up to %.0f°]" % [thin["along"], total, thin["wet"], tilt]])
	_check(fat["along"] < total * 0.5 and not fat["wet"] and fat["hops"] >= 1,
		"a stuffed one (%.1f m hops) gets %d floes along and stops at the edge of the first wide gap, dry" % [fat["reach"], fat["hops"]])


func _test_tunnels() -> void:
	var mesa := _level.get_node("BergField/Mesa") as TabularBerg
	var tunnel: Dictionary = mesa.tunnels()[0]
	var from: Vector3 = tunnel["from"]
	var to: Vector3 = tunnel["to"]
	var dir := (to - from).normalized()
	# A penguin swims through the tabular berg's keel, with air to spare.
	var p := _spawn_swimmer(from, atan2(-dir.x, -dir.z))
	p.brain_controlled = true
	var through := false
	var air_left := 99.0
	for i in 25 * 60:
		p.wish_dir = (to - p.global_position).normalized()
		await tree.physics_frame
		air_left = minf(air_left, p.air)
		if p.global_position.distance_to(to) < 1.5:
			through = true
			break
	_check(through and air_left > 5.0, "a penguin swims through the tunnel in the tabular berg's keel (%.0f m, %.0f s of air left)" % [from.distance_to(to), air_left])
	p.queue_free()

	# A leopard seal fits through it; an orca doesn't.
	var made_it := {}
	for scene_path in [SEAL_SCENE, "res://actors/predators/orca.tscn"]:
		var predator := load(scene_path).instantiate() as Predator
		_level.add_child(predator)
		predator.global_position = from - dir * 3.0
		predator.hunger = 0.0
		var t := predator.tuning.duplicate() as PredatorTuning
		t.roam_chance = 0.0
		t.ambush_chance = 0.0
		predator.tuning = t
		var deepest_in := 0.0
		for i in 20 * 60:
			predator.order_move(to + dir * 3.0, 4.0, Predator.MIN_DEPTH, Vector3.ZERO, false)
			await tree.physics_frame
			var rel := predator.global_position - from
			var along := Vector3(rel.x, 0.0, rel.z).dot(Vector3(dir.x, 0.0, dir.z).normalized())
			if Vector3(rel.x, 0.0, rel.z).length() - absf(along) < 1.5 and absf(rel.y) < 2.0:
				deepest_in = maxf(deepest_in, along)
			if predator.global_position.distance_to(to + dir * 3.0) < 2.5:
				deepest_in = INF
				break
		made_it[predator.tuning.display_name] = deepest_in
		predator.queue_free()
		await _frames(2)
	_check(is_inf(made_it.get("Leopard seal", 0.0)), "a leopard seal can follow you through it")
	_check(made_it.get("Orca", 0.0) < 2.0, "an orca can't: it's too big for the tunnel")

	# The drydock's lagoon: too shallow for an orca, not for a seal.
	var dock := _level.get_node("BergField/Drydock") as DrydockBerg
	var lagoon: Dictionary = dock.tunnels()[0]
	var mouth: Vector3 = lagoon["from"]
	var shelf: Vector3 = lagoon["to"]
	var into := (shelf - mouth)
	into.y = 0.0
	into = into.normalized()
	var reached := {}
	for scene_path in [SEAL_SCENE, "res://actors/predators/orca.tscn"]:
		var predator := load(scene_path).instantiate() as Predator
		_level.add_child(predator)
		predator.global_position = mouth - into * 4.0 + Vector3.DOWN * 0.5
		predator.hunger = 0.0
		var t := predator.tuning.duplicate() as PredatorTuning
		t.roam_chance = 0.0
		t.ambush_chance = 0.0
		predator.tuning = t
		var furthest := -INF
		for i in 15 * 60:
			predator.order_move(shelf, 3.0, Predator.MIN_DEPTH, Vector3.ZERO, false)
			await tree.physics_frame
			furthest = maxf(furthest, (predator.global_position - mouth).dot(into))
		# How far its middle got past the mouth ('from' is 1.5 m outside it).
		reached[predator.tuning.display_name] = furthest - 1.5
		predator.queue_free()
		await _frames(2)
	_check(reached.get("Leopard seal", -INF) > 3.0 and reached.get("Orca", INF) < 1.0,
		"the drydock's lagoon is too shallow for an orca (its middle got %.1f m past the mouth) but a seal swims in (%.1f m)" % [reached.get("Orca", 0.0), reached.get("Leopard seal", 0.0)])

	# The cave through the pinnacle's spire: walk in one side and out the other.
	var pin := _level.get_node("BergField/Pinnacle") as PinnacleBerg
	var cave: Dictionary = pin.tunnels()[0]
	var walker := await _spawn_standing((cave["from"] as Vector3) + Vector3.DOWN * 0.4, 50.0)
	walker.brain_controlled = true
	var out := false
	for i in 15 * 60:
		var aim: Vector3 = cave["to"] - walker.global_position
		aim.y = 0.0
		walker.wish_dir = aim.normalized()
		await tree.physics_frame
		if Vector2(walker.global_position.x - (cave["to"] as Vector3).x, walker.global_position.z - (cave["to"] as Vector3).z).length() < 1.0:
			out = true
			break
	_check(out and walker.state == Penguin.State.WALK, "you can walk through the cave in the pinnacle's spire")
	walker.queue_free()
	await _frames(2)


func _test_spire_climb() -> void:
	# Up the pinnacle's spiral (its own space): the shelf steps, round the first tier's ledge to
	# the second flight, round the second tier's ledge to the third, up to the lookout. Each
	# flight is taller than the last: a very thin penguin reaches the top, a middling one the
	# second tier, a fat one only the first.
	var pin := _level.get_node("BergField/Pinnacle") as PinnacleBerg
	var route: Array[Vector3] = [Vector3(10.5, 0, -2.5), Vector3(4.25, 0, -2.5), Vector3(4.25, 0, -4.25), Vector3(-0.4, 0, -4.25),
		Vector3(-0.4, 0, -2.75), Vector3(-2.75, 0, -2.75), Vector3(-2.75, 0, 0.95), Vector3(-1.0, 0, 0.95)]
	var tops: Array[float] = []
	for t in pin.tiers:
		tops.append(t.y)
	var reached := {}
	for energy in [10.0, 37.0, 80.0]:
		var p := load(PENGUIN_SCENE).instantiate() as Penguin
		p.player_controlled = false
		p.brain_controlled = true
		p.infinite_energy = true
		p.start_energy = energy
		_level.add_child(p)
		p.global_position = pin.to_global(Vector3(12.0, pin.shelf_height + 0.6, -2.5))
		await _frames(30)
		var next := 0
		var since := 0
		var highest := -INF
		while next < route.size() and since < 8 * 60:
			var to := pin.to_global(route[next]) - p.global_position
			to.y = 0.0
			if to.length() < 0.3:
				next += 1
				since = 0
				continue
			p.wish_dir = to.normalized()
			p.wish_brake = p.state == Penguin.State.SLIDE
			p.energy = energy
			await tree.physics_frame
			since += 1
			if p.state == Penguin.State.WALK:
				highest = maxf(highest, pin.to_local(p.global_position).y - 0.4)
		var tier := 0
		for k in tops.size():
			if highest >= tops[k] - 0.15:
				tier = k + 1
		reached[energy] = tier
		p.queue_free()
		await _frames(2)
	_check(reached[10.0] == 3 and reached[37.0] == 2 and reached[80.0] == 1,
		"the pinnacle's spiral gets harder going up: at energy 10 you reach tier %d (the lookout is 3), at 37 tier %d, at 80 tier %d" % [reached[10.0], reached[37.0], reached[80.0]])


## Tries one way out of the water onto `berg`: a ramp (swim straight up it) or a launch (come in
## deep, pitch up, boost). True if it ends up standing on the berg.
func _try_exit(berg: IceBerg, exit: Dictionary) -> bool:
	var at: Vector3 = exit["at"]
	var toward: Vector3 = exit["toward"]
	var p := _spawn_swimmer(at - toward * 2.0 + Vector3.DOWN * (2.5 if exit["launch"] else 0.0), atan2(-toward.x, -toward.z))
	p.brain_controlled = true
	p.set_pitch(deg_to_rad(52.0) if exit["launch"] else 0.0)
	var boosted := false
	var ok := false
	for i in 12 * 60:
		p.wish_dir = toward * cos(deg_to_rad(52.0)) + Vector3.UP * sin(deg_to_rad(52.0)) if exit["launch"] else toward
		p.wish_brake = p.state == Penguin.State.SLIDE
		if exit["launch"] and not boosted and p.global_position.distance_to(at) > 1.0 and p.get_heading().y > 0.6:
			p.wish_action = true
			boosted = true
		await tree.physics_frame
		var flat := Vector2(p.global_position.x - berg.global_position.x, p.global_position.z - berg.global_position.z).length()
		if p.state == Penguin.State.WALK and p.global_position.y > 0.4 and flat <= berg.reach() + 0.5:
			ok = true
			break
	p.queue_free()
	await _frames(2)
	return ok
