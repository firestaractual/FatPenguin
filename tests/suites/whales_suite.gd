extends "res://tests/smoke_suite.gd"
## Whales: what their bodies do to a penguin (dazed and shoved), how orcas press an attack (they
## lead their lunges, strike when bumped, and take turns), and the humpback: blowing and diving,
## the bubble net (herding a school, the lunge, the scoop), and driving orcas off a penguin.

const HUMPBACK_SCENE := "res://actors/whales/humpback.tscn"
const ORCA_SCENE := "res://actors/predators/orca.tscn"
## Open water in the movement toy: no ice within 30 m.
const OPEN_WATER := Vector3(-70.0, -0.1, -70.0)


func suite_name() -> String:
	return "whales"


func run() -> void:
	await _test_body_bump()
	await _test_orca_presses()
	await _test_relay_strike()
	await _test_humpback_breathes()
	await _test_bubble_net()
	await _test_humpback_drives_off_orcas()


## A humpback swimming in open water at `at`.
func _spawn_humpback(at: Vector3) -> Humpback:
	var whale := load(HUMPBACK_SCENE).instantiate() as Humpback
	whale.roam_centre = Vector3(at.x, 0.0, at.z)
	whale.ice_radius = 0.0
	whale.position = at
	_level.add_child(whale)
	return whale


## An orca on its own (not in a pod), not hungry.
func _spawn_orca(at: Vector3) -> Predator:
	var orca := load(ORCA_SCENE).instantiate() as Predator
	orca.ice_radius = _level.berg_radius
	orca.position = at
	_level.add_child(orca)
	orca.hunger = 0.0
	return orca


## Waits up to `max_frames` for `flag[0]` to turn true. True if it did.
func _wait_flag(flag: Array, max_frames: int) -> bool:
	for i in max_frames:
		if flag[0]:
			return true
		await tree.physics_frame
	return flag[0]


func _test_body_bump() -> void:
	# A penguin swimming into a whale's flank is shoved off it and dazed: no boost, its heading
	# wanders, and it wears off.
	var whale := _spawn_humpback(OPEN_WATER + Vector3(0.0, -1.2, 0.0))
	await _frames(2)
	var side := whale.heading().cross(Vector3.UP).normalized()
	var p := _spawn_swimmer(whale.global_position + side * 3.2 + Vector3.UP * 0.9, 0.0)
	p.set_facing(atan2(side.x, side.z)) # facing the whale (yaw 0 faces -Z)
	var bumped := [false]
	whale.bumped_penguin.connect(func(b: Penguin) -> void: bumped[0] = bumped[0] or b == p)
	var ok := await _wait_flag(bumped, 60)
	_check(ok and p.is_dazed() and p.is_stunned(), "a penguin that swims into a whale is dazed")
	# It stops swimming: the shove alone carries it off.
	p.set_swim_speed(0.0)
	await tree.physics_frame
	var away_speed := p.velocity.dot(-side)
	var gap := whale.distance_to_body(p.global_position)
	for i in 20:
		p.set_swim_speed(0.0)
		await tree.physics_frame
	_check(whale.distance_to_body(p.global_position) > gap + 0.3, "and shoved off its body (%.1f m/s away)" % away_speed)
	# Well clear of the whale from here on.
	p.global_position += Vector3(p.global_position - whale.global_position).normalized() * 15.0
	p.reset_physics_interpolation()
	var speed := p.swim_speed()
	_check(not p.boost() and is_equal_approx(p.swim_speed(), speed), "dazed, it can't boost")
	# How far its heading swings about in a second, with no stick input.
	var wander := 0.0
	var yaw := p.facing_yaw()
	for i in 60:
		await tree.physics_frame
		wander += absf(rad_to_deg(angle_difference(yaw, p.facing_yaw())))
		yaw = p.facing_yaw()
	_check(wander > 15.0, "and its heading wanders with no stick input (%.0f° of swinging in a second)" % wander)
	await _frames(int(whale.tuning.bump_daze_seconds * 60.0))
	_check(not p.is_dazed(), "the daze wears off after %.1f s" % whale.tuning.bump_daze_seconds)
	p.queue_free()
	whale.queue_free()
	await _frames(2)


func _test_orca_presses() -> void:
	# An orca leads its lunge: the strike line is aimed where a swimming penguin is going, not at
	# where it is.
	var p := _spawn_swimmer(OPEN_WATER, PI * 0.5) # swimming toward -X
	await _frames(20) # up to speed
	var orca := _spawn_orca(p.global_position + Vector3(0.0, -1.5, -7.0))
	var aimed := [false]
	var lead := [0.0]
	orca.state_changed.connect(func(s: Predator.State) -> void:
		if s == Predator.State.WARN and not aimed[0]:
			aimed[0] = true
			var to_p := (p.global_position - orca.global_position)
			var line := orca.strike_direction()
			# Positive: the line passes ahead of the penguin, the way it's swimming.
			lead[0] = Vector3(line.x, 0.0, line.z).signed_angle_to(Vector3(to_p.x, 0.0, to_p.z), Vector3.UP))
	orca.order_strike(p)
	await _wait_flag(aimed, 120)
	var lead_deg := rad_to_deg(lead[0])
	_check(aimed[0] and lead_deg > 5.0, "an orca aims its lunge where a swimming penguin is going (%.0f° ahead of it)" % lead_deg)
	p.queue_free()
	orca.queue_free()
	await _frames(2)

	# A penguin that bumps into an orca gets a lunge straight away.
	orca = _spawn_orca(OPEN_WATER + Vector3(0.0, -1.5, 0.0))
	await _frames(2)
	var side := orca.heading().cross(Vector3.UP).normalized()
	p = _spawn_swimmer(orca.global_position + side * 2.4 + Vector3.UP * 0.5, 0.0)
	p.set_facing(atan2(side.x, side.z))
	p.set_swim_speed(p.tuning.swim_cruise_speed)
	var ev := {"bumped": false, "warned": false}
	orca.bumped_penguin.connect(func(b: Penguin) -> void: ev["bumped"] = ev["bumped"] or b == p)
	orca.state_changed.connect(func(s: Predator.State) -> void: ev["warned"] = ev["warned"] or (s == Predator.State.WARN and orca.target == p))
	for i in 90:
		if ev["bumped"] and ev["warned"]:
			break
		await tree.physics_frame
	_check(ev["bumped"] and ev["warned"] and p.is_dazed(), "a penguin that bumps into an orca is dazed, and the orca lines up a lunge at once")
	p.queue_free()
	orca.queue_free()
	await _frames(2)


func _test_relay_strike() -> void:
	# A pod takes turns: when one orca's lunge misses, the nearest other one strikes straight away.
	var spawner := _spawn_pods()
	var entry: PredatorSpawn = load(ORCA_POD_SPAWN)
	var pod := _spawn_pod(spawner, entry)
	pod.set_attacks([])
	await _frames(30)
	# Out of their sight (detect_range), so only the orca sent goes for it at first.
	var middle := Vector3.ZERO
	for m in pod.members():
		middle += m.global_position / pod.members().size()
	var away := Vector3(middle.x, 0.0, middle.z).normalized()
	var p := _spawn_swimmer(Vector3(middle.x, -0.1, middle.z) + away * 11.0, 0.0)
	var first: Predator = null
	for m in pod.members():
		if first == null or m.global_position.distance_to(p.global_position) < first.global_position.distance_to(p.global_position):
			first = m
	var ev := {"relayed": null, "dodged": false, "missed_by": null}
	for m in pod.members():
		var member := m
		member.lunged.connect(func(_to: Vector3) -> void:
			if not ev["dodged"] and member.target == p:
				# Out of the way at the last moment: the lunge misses.
				ev["dodged"] = true
				ev["missed_by"] = member
				var line := member.strike_direction()
				p.global_position += Vector3(line.z, 0.0, -line.x).normalized() * 7.0
				p.reset_physics_interpolation())
	pod.relayed.connect(func(m: Predator, t: Penguin) -> void:
		if t == p and ev["relayed"] == null:
			ev["relayed"] = m)
	_check(first.order_strike(p), "an orca is sent to strike")
	var relayed := [false]
	for i in 6 * 60:
		await tree.physics_frame
		if p.state == Penguin.State.SWIM:
			p.set_swim_speed(0.0)
		if ev["relayed"] != null:
			relayed[0] = true
			break
	var next: Predator = ev["relayed"]
	_check(ev["dodged"] and relayed[0] and next != ev["missed_by"] and next.target == p,
		"its lunge misses, and another orca of the pod goes for the penguin straight away")
	spawner.queue_free()
	p.queue_free()
	await _frames(2)


func _test_humpback_breathes() -> void:
	# It comes up, blows (a bushy spout), then dives nose first, flukes up.
	var whale := _spawn_humpback(OPEN_WATER + Vector3(0.0, -5.0, 0.0))
	var blows := [0]
	whale.blew.connect(func(_at: Vector3) -> void: blows[0] += 1)
	await _frames(2)
	whale.breathe_now()
	var surfaced := false
	var dived := false
	var steepest := 0.0
	for i in 20 * 60:
		await tree.physics_frame
		surfaced = surfaced or GameWorld.WATER_LEVEL - whale.global_position.y <= whale.tuning.surface_depth + 0.3
		if whale.state == Humpback.State.DIVE:
			dived = true
			steepest = minf(steepest, whale.heading().y)
		if dived and whale.state == Humpback.State.TRAVEL:
			break
	_check(surfaced and blows[0] >= whale.tuning.blows, "a humpback comes up to breathe and blows %d times" % blows[0])
	var pitch := rad_to_deg(asin(-steepest))
	_check(dived and pitch > whale.tuning.dive_pitch_deg * 0.6, "then dives nose first (%.0f° down), flukes up" % pitch)
	whale.queue_free()
	await _frames(2)


func _test_bubble_net() -> void:
	# A school in open water: the humpback blows a net round it, herds it into a ball at the
	# surface, and lunges up through it. The school is gone for a while.
	var species: FishSpecies = load("res://tuning/fish/silverfish.tres")
	var school_at := OPEN_WATER + Vector3(0.0, -3.0, 0.0)
	var fishes: Array[Fish] = []
	for i in 10:
		var fish := _spawn_fish(species, school_at + Vector3(randf_range(-1.5, 1.5), randf_range(-0.6, 0.6), randf_range(-1.5, 1.5)))
		fish.home = school_at
		fish.monitoring = false
		fishes.append(fish)
	var whale := _spawn_humpback(OPEN_WATER + Vector3(16.0, -6.0, 0.0))
	# A penguin swimming about in the middle of it all.
	var p := _spawn_swimmer(Vector3(school_at.x + 1.0, -0.1, school_at.z), 0.0)
	var ev := {"net": false, "gulped": -1, "scooped": false, "spilled": false, "caught": false, "warned": false, "herded": 0, "dazed": false}
	whale.net_started.connect(func(_c: Vector3) -> void: ev["net"] = true)
	whale.gulped.connect(func(_c: Vector3, n: int) -> void: ev["gulped"] = n)
	whale.scooped.connect(func(s: Penguin) -> void:
		if s == p:
			ev["scooped"] = true
			ev["dazed"] = s.is_dazed())
	p.spilled_fish.connect(func(_at: Vector3) -> void: ev["spilled"] = true)
	p.caught.connect(func(_by: Node3D) -> void: ev["caught"] = true)
	await _frames(30)
	_check(whale.feed_on(fishes[0]), "a humpback goes to feed on a school in open water")
	var tossed_up := 0.0
	for i in 50 * 60:
		await tree.physics_frame
		if p.state == Penguin.State.SWIM:
			p.set_swim_speed(0.0) # it stays put
		if whale.state == Humpback.State.NET:
			ev["warned"] = ev["warned"] or Humpback.net_closing_on(p.global_position) == whale
			var herded := 0
			for fish in fishes:
				if fish.is_herded():
					herded += 1
			ev["herded"] = maxi(ev["herded"], herded)
		if ev["scooped"]:
			tossed_up = maxf(tossed_up, p.velocity.y)
		if whale.state == Humpback.State.REST:
			break
	_check(ev["net"] and ev["warned"], "it blows a ring of bubbles round the school (and a penguin inside is warned)")
	_check(ev["herded"] >= 8, "the fish in the ring are herded into a ball (%d of 10)" % ev["herded"])
	_check(ev["gulped"] >= 8, "it lunges up through the middle and swallows the lot (%d fish)" % ev["gulped"])
	_check(ev["scooped"] and tossed_up > 3.0 and ev["spilled"], "a penguin in the middle is scooped up and tossed out, losing a fish")
	_check(not ev["caught"] and ev["dazed"], "dazed, but never eaten")
	await _frames(10 * 60)
	var back := 0
	for fish in fishes:
		if fish.visible:
			back += 1
	_check(back == 0, "the school stays gone for a while (%d of 10 back after 10 s)" % back)
	whale.queue_free()
	p.queue_free()
	for fish in fishes:
		fish.queue_free()
	await _frames(2)


func _test_humpback_drives_off_orcas() -> void:
	# Orcas ring in a penguin out in open water; a humpback nearby comes over, calls the attack
	# off and stays by the penguin. Sheltered by it, the penguin isn't hunted.
	var spawner := _spawn_pods()
	var entry: PredatorSpawn = (load(ORCA_POD_SPAWN) as PredatorSpawn).duplicate()
	entry.start_angle_deg = -90.0
	var pod := _spawn_pod(spawner, entry)
	_only_attack(pod, "Carousel")
	var open_water := Vector3(0.0, -0.1, -62.0)
	var p := _spawn_swimmer(open_water, 0.0)
	var ev := {"called_off": false, "drove_off": false, "caught": false, "mob": false}
	p.caught.connect(func(_by: Node3D) -> void: ev["caught"] = true)
	pod.clear_cooldown()
	for i in 40 * 60:
		await tree.physics_frame
		if p.state == Penguin.State.SWIM:
			p.set_swim_speed(0.0)
		if pod.attack != null:
			break
	_check(pod.attack != null and pod.attack.target == p, "orcas start to ring in a penguin out in open water")
	# A humpback 30 m off.
	var whale := _spawn_humpback(open_water + Vector3(-28.0, -4.0, -10.0))
	pod.attack_called_off.connect(func(_a: PodAttack) -> void: ev["called_off"] = true)
	whale.drove_off.connect(func(d: Penguin) -> void: ev["drove_off"] = ev["drove_off"] or d == p)
	whale.state_changed.connect(func(s: Humpback.State) -> void: ev["mob"] = ev["mob"] or s == Humpback.State.MOB)
	for i in 30 * 60:
		await tree.physics_frame
		if p.state == Penguin.State.SWIM:
			p.set_swim_speed(0.0)
		if ev["drove_off"] or ev["caught"]:
			break
	_check(ev["mob"] and ev["drove_off"] and ev["called_off"] and not ev["caught"],
		"a humpback comes to a penguin orcas are attacking and calls the attack off")
	_check(whale.state == Humpback.State.GUARD and whale.protege() == p, "and stays by the penguin")
	# Sheltered: for a while, no orca goes for it, even sent straight at it.
	var hunted := false
	var sent := pod.leader().order_strike(p)
	for i in 4 * 60:
		await tree.physics_frame
		if p.state == Penguin.State.SWIM:
			p.set_swim_speed(0.0)
		for m in pod.members():
			hunted = hunted or (m.target == p and m.state in [Predator.State.WARN, Predator.State.LUNGE])
	_check(not sent and not hunted and not ev["caught"] and Humpback.shelters(p.global_position),
		"sheltered by the humpback, the penguin isn't hunted")
	spawner.queue_free()
	whale.queue_free()
	p.queue_free()
	await _frames(2)
