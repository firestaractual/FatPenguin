extends "res://tests/smoke_suite.gd"
## The orca pod's attacks: the wave, the ram, the cut-off and the carousel, and how they chain into a trap.


func suite_name() -> String:
	return "orcas"


func run() -> void:
	await _test_orcas()
	await _test_orca_ram()
	await _test_orca_cut_off()
	await _test_orca_carousel()
	await _test_orca_trap()


func _test_orcas() -> void:
	var berg_radius: float = _level.berg_radius
	# A spawn entry puts three orcas in a pod, on their patrol loop west of the berg.
	var spawner := PredatorSpawner.new()
	spawner.ice_radius = berg_radius
	_level.add_child(spawner)
	var entry: PredatorSpawn = load("res://levels/movement_toy/predators/orca_pod.tres")
	var pod := _spawn_pod(spawner, entry)
	var wave_attack := _only_attack(pod, "Wave")
	var t := wave_attack.settings as WaveAttackTuning
	# No attacks until the wave check below (it attacks soon after it spawns).
	pod.set_attacks([])
	_check(pod.members().size() == entry.pod_size, "a spawn entry puts %d orcas in a pod" % pod.members().size())

	# On patrol the pod swims together (after a few seconds to fall in behind the leader).
	await _frames(6 * 60)
	var total := 0.0
	var samples := 0
	for i in 8 * 60:
		await tree.physics_frame
		for member in pod.members():
			if member != pod.leader():
				total += member.global_position.distance_to(pod.leader().global_position)
				samples += 1
	var mean := total / samples
	_check(mean < pod.tuning.spacing * 2.5, "the pod swims together (followers %.1f m from the leader on average)" % mean)

	# Orcas don't chase far in open water: a fat penguin that keeps 16 m from the pod isn't hunted.
	var bait := _spawn_bait(Vector3(0.0, -1.0, -110.0), 100.0)
	var hunted := [false]
	var bait_id := bait.get_instance_id()
	for member in pod.members():
		member.locked_on.connect(func(p: Penguin) -> void: hunted[0] = hunted[0] or p.get_instance_id() == bait_id)
	for i in 3 * 60:
		var outermost: Predator = null
		for member in pod.members():
			if outermost == null or member.global_position.length() > outermost.global_position.length():
				outermost = member
		var out := Vector3(outermost.global_position.x, 0.0, outermost.global_position.z).normalized()
		bait.global_position = Vector3(outermost.global_position.x, -1.0, outermost.global_position.z) + out * 16.0
		await tree.physics_frame
	_check(not hunted[0], "orcas don't chase a penguin 16 m away in open water")
	bait.queue_free()

	# The wave: a penguin standing near the edge the pod is passing gets washed off; one 6 m in
	# is untouched.
	var facing := Vector3(pod.leader().global_position.x, 0.0, pod.leader().global_position.z).normalized()
	var at_edge := await _spawn_standing(facing * (berg_radius - 1.5) + Vector3.UP, 0.0)
	var inland := await _spawn_standing(facing * (berg_radius - 6.0) + Vector3.UP, 0.0)
	var inland_start := inland.global_position
	pod.set_attacks([wave_attack])
	var wave := {"coming": -1, "hit": -1, "washed": [], "surfaced": true}
	pod.attack_coming.connect(func(_a: PodAttack) -> void: wave["coming"] = Engine.get_physics_frames())
	pod.attack_hit.connect(func(_a: PodAttack, washed: Array[Penguin]) -> void:
		wave["hit"] = Engine.get_physics_frames()
		wave["washed"] = washed)
	pod.clear_cooldown()
	for i in 40 * 60:
		await tree.physics_frame
		if pod.phase == PredatorPod.Phase.WARN and pod.phase_time() > t.warning_seconds * 0.8:
			var at_surface := 0
			for member: Predator in pod.attack.attackers:
				if member.global_position.y > -t.surface_depth - 0.4:
					at_surface += 1
			wave["surfaced"] = wave["surfaced"] and at_surface >= t.min_attackers
		if wave["hit"] >= 0:
			break
	var warning := float(wave["hit"] - wave["coming"]) / 60.0
	_check(wave["hit"] >= 0 and warning >= t.warning_seconds, "orcas line up and warn (fins, swell, danger zone) %.1f s before the wave hits" % warning)
	_check(wave["surfaced"], "lined up, the orcas swim at the surface with their fins showing")
	var washed: Array = wave["washed"]
	_check(washed.has(at_edge) and not washed.has(inland), "the wave washes over the zone by the edge: it shoves the penguin standing there")
	var went_in := await _wait_for(at_edge, Penguin.State.SWIM, 4 * 60)
	_check(went_in or not is_instance_valid(at_edge), "and that penguin ends up in the water")
	_check(inland.state == Penguin.State.WALK and inland.global_position.distance_to(inland_start) < 0.3,
		"a penguin 6 m in from the edge is untouched")
	spawner.queue_free()
	at_edge.queue_free()
	inland.queue_free()
	await _frames(2)


func _test_orca_ram() -> void:
	var berg_radius: float = _level.berg_radius
	var entry: PredatorSpawn = (load("res://levels/movement_toy/predators/orca_pod.tres") as PredatorSpawn).duplicate()

	# A floe: the pod rams it, it tips steeply toward them, and a penguin standing on it slides off.
	var floe := _level.get_node("FloeEasy") as Node3D
	var floe_ice := _level.get_node("TippableFloeEasy") as TippableIce
	var floe_rest := floe.global_transform
	var on_floe := await _spawn_standing(Vector3(floe.global_position.x, floe.global_position.y + 1.0, floe.global_position.z), 50.0)
	var spawner := PredatorSpawner.new()
	spawner.ice_radius = berg_radius
	_level.add_child(spawner)
	entry.start_angle_deg = rad_to_deg(atan2(floe.global_position.z, floe.global_position.x))
	var pod := _spawn_pod(spawner, entry)
	var ram := _only_attack(pod, "Ram")
	var t := ram.settings as RamAttackTuning
	var rammed := {"coming": -1, "hit": -1, "jolted": []}
	pod.attack_coming.connect(func(_a: PodAttack) -> void: rammed["coming"] = Engine.get_physics_frames())
	pod.attack_hit.connect(func(_a: PodAttack, hit: Array[Penguin]) -> void:
		rammed["hit"] = Engine.get_physics_frames()
		rammed["jolted"] = hit)
	pod.clear_cooldown()
	var deepest := 0.0
	var tilt := 0.0
	for i in 40 * 60:
		await tree.physics_frame
		if pod.phase == PredatorPod.Phase.WARN:
			for member: Predator in pod.attack.attackers:
				deepest = minf(deepest, member.global_position.y)
		tilt = maxf(tilt, floe_ice.tilt_degrees())
		if rammed["hit"] >= 0 and on_floe.state == Penguin.State.SWIM:
			break
	var warning := float(rammed["hit"] - rammed["coming"]) / 60.0
	_check(rammed["hit"] >= 0 and warning >= t.warning_seconds, "orcas gather under a floe and warn (shadows, bulge, danger zone) %.1f s before they ram it" % warning)
	_check(deepest < -t.gather_depth + 1.0, "they gather deep, as shadows under the ice (down to %.1f m)" % -deepest)
	_check(tilt > 20.0, "the ram tips the floe steeply toward them (%.0f°)" % tilt)
	_check((rammed["jolted"] as Array).has(on_floe) and on_floe.state == Penguin.State.SWIM, "a penguin standing on the floe slides off into the water")
	for i in 6 * 60:
		await tree.physics_frame
		if not floe_ice.is_tipping():
			break
	_check(not floe_ice.is_tipping() and floe.global_transform.is_equal_approx(floe_rest), "then the floe rights itself")
	on_floe.queue_free()

	# Digging in: the player on the floe pulls back the moment it tips, and holds on.
	spawner.queue_free()
	await _frames(2)
	await _place_on_ice(_penguin, Vector3(floe.global_position.x, floe.global_position.y + 1.0, floe.global_position.z), 0.0, 50.0)
	_penguin.infinite_energy = true
	spawner = PredatorSpawner.new()
	spawner.ice_radius = berg_radius
	_level.add_child(spawner)
	pod = _spawn_pod(spawner, entry)
	_only_attack(pod, "Ram")
	pod.clear_cooldown()
	var struck := [false]
	pod.attack_hit.connect(func(_a: PodAttack, _hit: Array[Penguin]) -> void: struck[0] = true)
	var went_in := false
	for i in 40 * 60:
		if struck[0]:
			Input.action_press(&"move_down")
		await tree.physics_frame
		went_in = went_in or _penguin.state == Penguin.State.SWIM
		if struck[0] and not floe_ice.is_tipping():
			break
	Input.action_release(&"move_down")
	_check(struck[0] and not went_in, "pulling back digs in and holds on to a tipping floe")
	_penguin.infinite_energy = false
	spawner.queue_free()
	await _place_on_ice(_penguin, Vector3(0.0, 3.0, -8.0), 0.0, 50.0)

	# The berg only rocks: it tips about a degree, a penguin 5 m in is jolted but stays on the ice,
	# and the berg (plateau and all) settles back exactly where it was.
	var berg := _level.get_node("Iceberg") as Node3D
	var plateau := _level.get_node("Plateau") as Node3D
	var berg_ice := _level.get_node("TippableBerg") as TippableIce
	var berg_rest := berg.global_transform
	var plateau_rest := plateau.global_transform
	var near_edge := await _spawn_standing(Vector3(-berg_radius + 5.0, 1.0, 0.0), 50.0)
	spawner = PredatorSpawner.new()
	spawner.ice_radius = berg_radius
	_level.add_child(spawner)
	entry.start_angle_deg = 180.0
	pod = _spawn_pod(spawner, entry)
	_only_attack(pod, "Ram")
	var jolted := [false]
	pod.attack_hit.connect(func(_a: PodAttack, hit: Array[Penguin]) -> void: jolted[0] = hit.has(near_edge))
	pod.clear_cooldown()
	var rock := 0.0
	var fell_in := false
	for i in 40 * 60:
		await tree.physics_frame
		rock = maxf(rock, berg_ice.tilt_degrees())
		fell_in = fell_in or near_edge.state == Penguin.State.SWIM
		if jolted[0] and not berg_ice.is_tipping():
			break
	_check(jolted[0] and rock > 0.5 and rock < 2.0, "rammed, the berg only rocks (%.1f°) and jolts the penguins near the edge" % rock)
	_check(not fell_in, "a penguin 5 m in from the edge stays on the ice")
	_check(berg.global_transform.is_equal_approx(berg_rest) and plateau.global_transform.is_equal_approx(plateau_rest),
		"and the berg, plateau and all, settles back exactly where it was")
	spawner.queue_free()
	near_edge.queue_free()
	await _frames(2)


func _test_orca_cut_off() -> void:
	var berg_radius: float = _level.berg_radius
	var entry: PredatorSpawn = (load(ORCA_POD_SPAWN) as PredatorSpawn).duplicate()
	entry.start_angle_deg = -50.0
	var off_south := Vector3(0.0, -0.1, -berg_radius - 8.0)

	# Floating 8 m off the south edge: a wall of fins forms between it and the ice, closes in, and
	# when the warning runs out the nearest orca lunges.
	var floater := _spawn_bait(off_south, 50.0)
	floater.force_state(Penguin.State.SWIM)
	var spawner := _spawn_pods()
	var pod := _spawn_pod(spawner, entry)
	var cut := _only_attack(pod, "Cut-off") as CutOffAttack
	var t := cut.settings as CutOffAttackTuning
	pod.clear_cooldown()
	var ev := {"coming": -1, "hit": -1, "between": true, "fins": true, "lunge": false, "looked": false}
	pod.attack_coming.connect(func(_a: PodAttack) -> void: ev["coming"] = Engine.get_physics_frames())
	pod.attack_hit.connect(func(_a: PodAttack, _hit: Array[Penguin]) -> void: ev["hit"] = Engine.get_physics_frames())
	for i in 40 * 60:
		await tree.physics_frame
		if pod.phase == PredatorPod.Phase.WARN and pod.phase_time() >= 2.0 and not ev["looked"]:
			ev["looked"] = true
			for member in cut.attackers:
				var rel := member.global_position - floater.global_position
				ev["between"] = ev["between"] and Vector3(rel.x, 0.0, rel.z).dot(cut.home) > 2.0
				ev["fins"] = ev["fins"] and member.global_position.y > -t.wall_depth - 0.6
		if ev["hit"] >= 0:
			for member in pod.members():
				ev["lunge"] = ev["lunge"] or (member.target == floater and member.state in [Predator.State.CHASE, Predator.State.WARN])
			break
	var warning := float(ev["hit"] - ev["coming"]) / 60.0
	_check(ev["looked"] and ev["between"] and ev["fins"], "orcas cut off a penguin 8 m off the ice: a wall of fins forms between it and home")
	_check(ev["hit"] >= 0 and warning >= t.warning_seconds - 0.05, "the wall closes in for %.1f s (a penguin holding still isn't lunged at early)" % warning)
	_check(ev["lunge"], "then the nearest orca goes for it, with the usual lunge warning")
	spawner.queue_free()
	floater.queue_free()
	await _frames(2)

	# Racing home as soon as the fins head for the gap: it gets back to the ice first and the
	# attack is called off.
	var racer := _spawn_swimmer(off_south, PI) # facing north, toward the berg
	spawner = _spawn_pods()
	pod = _spawn_pod(spawner, entry)
	_only_attack(pod, "Cut-off")
	pod.clear_cooldown()
	var called_off := [false]
	pod.attack_called_off.connect(func(_a: PodAttack) -> void: called_off[0] = true)
	var raced := false
	for i in 30 * 60:
		raced = raced or pod.phase != PredatorPod.Phase.PATROL
		if not raced:
			racer.set_swim_speed(0.0) # waits until the pod moves
		await tree.physics_frame
		if called_off[0]:
			break
	_check(called_off[0] and racer.state == Penguin.State.SWIM, "a penguin that races the fins back to the ice gets away (the cut-off is called off)")
	spawner.queue_free()
	racer.queue_free()
	await _frames(2)


func _test_orca_carousel() -> void:
	var entry: PredatorSpawn = (load(ORCA_POD_SPAWN) as PredatorSpawn).duplicate()
	entry.start_angle_deg = -90.0
	var open_water := Vector3(0.0, -0.1, -62.0)

	# Floating still out in open water: the pod rings it in, blows a wall of bubbles and squeezes,
	# then one tail-slaps the middle and another lunges.
	var floater := _spawn_bait(open_water, 50.0)
	floater.force_state(Penguin.State.SWIM)
	var spawner := _spawn_pods()
	var pod := _spawn_pod(spawner, entry)
	var ring := _only_attack(pod, "Carousel") as CarouselAttack
	var t := ring.settings as CarouselAttackTuning
	pod.clear_cooldown()
	var ev := {"ringed": true, "looked": false, "zone": -1, "hit": -1, "stunned": [], "lunge": false}
	pod.attack_hit.connect(func(_a: PodAttack, hit: Array[Penguin]) -> void:
		ev["hit"] = Engine.get_physics_frames()
		ev["stunned"] = hit)
	for i in 40 * 60:
		await tree.physics_frame
		# By the end of the squeeze they're circling tight around it.
		if pod.phase == PredatorPod.Phase.CHARGE and not ev["looked"]:
			ev["looked"] = true
			for member in ring.attackers:
				var r := Vector2(member.global_position.x - ring.centre.x, member.global_position.z - ring.centre.z).length()
				ev["ringed"] = ev["ringed"] and absf(r - ring.radius) < 2.0
		if ev["zone"] < 0 and _marker_shown(pod, "DangerRing"):
			ev["zone"] = Engine.get_physics_frames()
		if ev["hit"] >= 0:
			for member in pod.members():
				ev["lunge"] = ev["lunge"] or (member.target == floater and member.state in [Predator.State.CHASE, Predator.State.WARN])
			break
	var zone_up := float(ev["hit"] - ev["zone"]) / 60.0
	_check(ev["hit"] >= 0 and ev["looked"] and ev["ringed"], "orcas ring in a penguin out in open water and squeeze the ring")
	_check(ev["zone"] >= 0 and zone_up >= 1.5, "the slap zone is marked %.1f s before the tail slap" % zone_up)
	_check((ev["stunned"] as Array).has(floater) and floater.is_stunned(), "the tail slap stuns the penguin in the middle")
	var speed := floater.swim_speed()
	floater.boost()
	_check(is_equal_approx(floater.swim_speed(), speed), "stunned, it can't boost")
	_check(ev["lunge"], "and another orca lunges at it")
	spawner.queue_free()
	floater.queue_free()
	await _frames(2)

	# Swimming out (and diving) once the bubbles are up: held in, and lifted to the surface.
	var swimmer := _spawn_swimmer(open_water, 0.0)
	spawner = _spawn_pods()
	pod = _spawn_pod(spawner, entry)
	ring = _only_attack(pod, "Carousel") as CarouselAttack
	pod.clear_cooldown()
	var worst := 0.0
	var deepest := 0.0
	for i in 40 * 60:
		if pod.phase in [PredatorPod.Phase.PATROL, PredatorPod.Phase.LINE_UP]:
			swimmer.set_swim_speed(0.0)
		elif pod.phase == PredatorPod.Phase.WARN:
			var outward := Vector3(swimmer.global_position.x - ring.centre.x, 0.0, swimmer.global_position.z - ring.centre.z)
			if outward.length() > 0.1:
				swimmer.set_facing(atan2(-outward.x, -outward.z))
			swimmer.set_pitch(deg_to_rad(-40.0))
			if pod.phase_time() > 1.0:
				var r := Vector2(outward.x, outward.z).length()
				worst = maxf(worst, r - ring.radius)
				deepest = maxf(deepest, -swimmer.global_position.y)
		await tree.physics_frame
		if pod.phase == PredatorPod.Phase.CHARGE:
			break
	_check(pod.phase == PredatorPod.Phase.CHARGE and worst <= t.wall_thickness, "the bubble wall holds in a penguin swimming out (%.1f m past the ring at most)" % worst)
	_check(deepest <= t.lift_depth + 0.4, "and lifts one trying to dive under it (%.1f m down at most)" % deepest)
	spawner.queue_free()
	swimmer.queue_free()
	await _frames(2)

	# A boost straight out early on breaks through the bubbles: the carousel is called off.
	swimmer = _spawn_swimmer(open_water, 0.0)
	spawner = _spawn_pods()
	pod = _spawn_pod(spawner, entry)
	ring = _only_attack(pod, "Carousel") as CarouselAttack
	pod.clear_cooldown()
	var called_off := [false]
	pod.attack_called_off.connect(func(_a: PodAttack) -> void: called_off[0] = true)
	var boosted := false
	for i in 40 * 60:
		if pod.phase in [PredatorPod.Phase.PATROL, PredatorPod.Phase.LINE_UP]:
			swimmer.set_swim_speed(0.0)
		elif pod.phase == PredatorPod.Phase.WARN:
			var outward := Vector3(swimmer.global_position.x - ring.centre.x, 0.0, swimmer.global_position.z - ring.centre.z)
			if outward.length() > 0.1:
				swimmer.set_facing(atan2(-outward.x, -outward.z))
			if not boosted and pod.phase_time() > 0.5:
				swimmer.boost()
				boosted = true
		await tree.physics_frame
		if called_off[0] or pod.phase == PredatorPod.Phase.HUNT:
			break
	_check(called_off[0], "a boost straight out, early, breaks through the bubbles")
	spawner.queue_free()
	swimmer.queue_free()
	await _frames(2)


func _test_orca_trap() -> void:
	var berg_radius: float = _level.berg_radius
	var entry: PredatorSpawn = (load(ORCA_POD_SPAWN) as PredatorSpawn).duplicate()

	# The cut-off pushes a penguin that flees out to sea straight into the carousel: no cooldown.
	entry.start_angle_deg = -50.0
	var fleeing := _spawn_swimmer(Vector3(0.0, -0.1, -berg_radius - 8.0), 0.0)
	var spawner := _spawn_pods()
	var pod := _spawn_pod(spawner, entry)
	var kept: Array[PodAttack] = []
	for attack in pod.attacks():
		if attack is CutOffAttack or attack is CarouselAttack:
			kept.append(attack)
	pod.set_attacks(kept)
	pod.clear_cooldown()
	var ev := {"cut_hit": -1, "carousel": -1, "cut_lunged": true}
	pod.attack_hit.connect(func(a: PodAttack, hit: Array[Penguin]) -> void:
		if a is CutOffAttack:
			ev["cut_hit"] = Engine.get_physics_frames()
			ev["cut_lunged"] = not hit.is_empty())
	pod.phase_changed.connect(func(ph: PredatorPod.Phase) -> void:
		if ph == PredatorPod.Phase.LINE_UP and pod.attack is CarouselAttack and ev["carousel"] < 0:
			ev["carousel"] = Engine.get_physics_frames())
	for i in 40 * 60:
		var cut := pod.attack as CutOffAttack
		if cut == null or pod.phase == PredatorPod.Phase.LINE_UP:
			fleeing.set_swim_speed(0.0)
		else:
			fleeing.set_facing(atan2(cut.home.x, cut.home.z)) # straight away from the ice
		await tree.physics_frame
		if ev["carousel"] >= 0:
			break
	var handed := float(ev["carousel"] - ev["cut_hit"]) / 60.0
	_check(ev["carousel"] >= 0 and not ev["cut_lunged"] and handed < 0.6 and pod.trap_step == 2,
		"a penguin the wall pushes out to sea goes straight into the carousel (%.1f s later, trap step %d)" % [handed, pod.trap_step])
	spawner.queue_free()
	fleeing.queue_free()
	await _frames(2)

	# A wave washes a penguin in; when it swims off the edge, the pod cuts it off straight away.
	entry.start_angle_deg = 180.0
	spawner = _spawn_pods()
	pod = _spawn_pod(spawner, entry)
	kept = []
	for attack in pod.attacks():
		if attack is WaveAttack or attack is CutOffAttack:
			kept.append(attack)
	pod.set_attacks(kept)
	await _frames(6 * 60)
	var facing := Vector3(pod.leader().global_position.x, 0.0, pod.leader().global_position.z).normalized()
	var at_edge := await _spawn_standing(facing * (berg_radius - 1.5) + Vector3.UP, 0.0)
	pod.clear_cooldown()
	var wave_hit := [-1]
	pod.attack_hit.connect(func(a: PodAttack, _hit: Array[Penguin]) -> void:
		if a is WaveAttack:
			wave_hit[0] = Engine.get_physics_frames())
	for i in 40 * 60:
		await tree.physics_frame
		if wave_hit[0] >= 0 and at_edge.state == Penguin.State.SWIM:
			break
	# It swims off: 6 m out, 15 m along the edge from where the wave broke.
	var turn := 15.0 / berg_radius
	var off := facing.rotated(Vector3.UP, turn) * (berg_radius + 6.0)
	at_edge.global_position = Vector3(off.x, -0.1, off.z)
	at_edge.velocity = Vector3.ZERO
	at_edge.set_physics_process(false)
	var cut_started := -1
	for i in 3 * 60:
		await tree.physics_frame
		if pod.attack is CutOffAttack:
			cut_started = Engine.get_physics_frames()
			break
	var after := float(cut_started - wave_hit[0]) / 60.0
	_check(wave_hit[0] >= 0 and cut_started >= 0 and pod.trap_step == 2,
		"a penguin a wave washed in that swims off is cut off straight away (%.1f s after the wave, no cooldown)" % after)
	spawner.queue_free()
	at_edge.queue_free()
	await _frames(2)
