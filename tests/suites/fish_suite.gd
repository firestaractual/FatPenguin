extends "res://tests/smoke_suite.gd"
## Food: single-species fish schools, strays joining, eaten fish coming back beside their school;
## sick fish (how they look and swim, and the queasy spell from eating one); krill swarms; squid.


func suite_name() -> String:
	return "fish"


func run() -> void:
	await _test_fish_schools()
	await _test_sick_fish()
	await _test_krill()
	await _test_squid()


func _test_fish_schools() -> void:
	# The level puts most of its fish in single-species schools.
	var level_fish := _level.get_node("Fish").get_children()
	var schooled := 0
	for f: Fish in level_fish:
		if _school_mates_in_range(f, level_fish) >= 2:
			schooled += 1
	_check(schooled >= level_fish.size() * 0.75, "most of the level's fish swim in a school (%d of %d)" % [schooled, level_fish.size()])

	# Far from the level's fish: a school of silverfish, plus a lone silverfish and a lone
	# lanternfish, each just inside school range of it.
	var silverfish: FishSpecies = load("res://tuning/fish/silverfish.tres")
	var lanternfish: FishSpecies = load("res://tuning/fish/lanternfish.tres")
	var centre := Vector3(0.0, -6.0, -110.0)
	var school: Array[Fish] = []
	for i in 6:
		var fish := _spawn_fish(silverfish, centre + Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3), randf_range(-1.0, 1.0)))
		fish.home = centre
		school.append(fish)
	var stray := _spawn_fish(silverfish, centre + Vector3(4.5, 0.0, 0.0))
	var stranger := _spawn_fish(lanternfish, centre + Vector3(-4.5, 0.0, 0.0))
	var stranger_home := stranger.home
	await _frames(15 * 60)

	var middle := _middle_of(school)
	var widest := 0.0
	for fish in school:
		widest = maxf(widest, fish.global_position.distance_to(middle))
	_check(widest < 2.5, "a school stays together (widest fish %.1f m from the middle)" % widest)
	var stray_gap := stray.global_position.distance_to(middle)
	_check(stray_gap < 2.5, "a lone fish in range is pulled into a school of its own kind (%.1f m from the middle)" % stray_gap)
	var stray_home := stray.home.distance_to(centre)
	_check(stray_home < 2.0, "and it stays: it now shares the school's home spot (%.1f m away)" % stray_home)
	var stranger_mates := stranger.school_mate_count()
	_check(stranger_mates == 0 and stranger.home == stranger_home, "a fish of another kind is never pulled in (school mates=%d)" % stranger_mates)

	# An eaten fish comes back beside its school, wherever it was eaten.
	var eaten := school[0]
	eaten.get_eaten()
	eaten.global_position = centre + Vector3(30.0, 0.0, 0.0)
	eaten.respawn()
	await _frames(2)
	var eaten_gap := eaten.global_position.distance_to(_middle_of(school))
	_check(eaten.visible and eaten_gap < 2.5, "an eaten fish respawns beside its school (%.1f m from the middle)" % eaten_gap)

	for fish in school:
		fish.queue_free()
	stray.queue_free()
	stranger.queue_free()


func _test_sick_fish() -> void:
	# The level has some sick fish among the healthy ones.
	var level_fish := _level.get_node("Fish").get_children()
	var sick := 0
	for f: Fish in level_fish:
		if f.sick:
			sick += 1
	var share: float = _level.sick_fish_share
	_check(sick > 0 and sick < level_fish.size() * share * 2.0, "some of the level's fish are sick (%d of %d)" % [sick, level_fish.size()])

	# A sick fish looks it: sickly colours, blotches, listing on its side, and slower.
	var silverfish: FishSpecies = load("res://tuning/fish/silverfish.tres")
	# (Far apart, so they don't school together and match speeds.)
	var centre := Vector3(30.0, -4.0, -120.0)
	var well := _spawn_fish(silverfish, centre)
	var ill := _spawn_fish(silverfish, centre + Vector3(30.0, 0.0, 0.0))
	ill.make_sick()
	well.monitoring = false
	ill.monitoring = false
	await _frames(60)
	var body := ill.get_node("Model/Body") as MeshInstance3D
	var roll := absf(rad_to_deg(ill.global_basis.x.signed_angle_to(Vector3(ill.global_basis.x.x, 0.0, ill.global_basis.x.z), -ill.global_basis.z)))
	var upright := absf(rad_to_deg(well.global_basis.x.signed_angle_to(Vector3(well.global_basis.x.x, 0.0, well.global_basis.x.z), -well.global_basis.z)))
	_check(body.material_override == Fish.SICK_MATERIAL and ill.get_node("Model").get_child_count() > 2,
		"a sick fish looks it: sickly colours and blotches")
	_check(roll > 35.0 and upright < 10.0, "and swims listing on its side (%.0f°; a healthy one %.0f°)" % [roll, upright])
	var ill_speed := 0.0
	var well_speed := 0.0
	for i in 120:
		await tree.physics_frame
		ill_speed += ill.velocity.length() / 120.0
		well_speed += well.velocity.length() / 120.0
	_check(ill_speed < well_speed * 0.85, "and lamely (%.2f m/s on average to %.2f)" % [ill_speed, well_speed])
	well.queue_free()
	ill.queue_free()
	# In a school, a penguin looking for a healthy meal passes the sick one over.
	var school_at := centre + Vector3(0.0, 0.0, 30.0)
	var school: Array[Fish] = []
	for i in 5:
		var fish := _spawn_fish(silverfish, school_at + Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.8, 0.8)))
		fish.home = school_at
		fish.monitoring = false
		school.append(fish)
	school[0].make_sick()
	school[0].global_position = school_at
	var picked_sick := false
	var picked_any := false
	for i in 60:
		await tree.physics_frame
		var pick := Fish.nearest_in_school(school[0].global_position, 10.0, true)
		picked_any = picked_any or pick != null
		picked_sick = picked_sick or pick == school[0]
	_check(picked_any and not picked_sick, "in a school, a penguin looking for a healthy meal passes the sick one over")
	for fish in school:
		fish.queue_free()

	# Eating one: queasy (no boost, slow), and it comes back up, worth nothing.
	var p := _spawn_swimmer(Vector3(30.0, -0.3, -100.0), 0.0)
	p.infinite_energy = false
	p.energy = 50.0
	var fish := _spawn_fish(null, p.global_position)
	fish.circle_radius = 0.0
	fish.make_sick()
	var ev := {"sick": false, "threw_up": false, "ate": false}
	p.sickened.connect(func(_s: float) -> void: ev["sick"] = true)
	p.threw_up.connect(func(_at: Vector3) -> void: ev["threw_up"] = true)
	p.ate_fish.connect(func(_e: float) -> void: ev["ate"] = true)
	for i in 30:
		await tree.physics_frame
		if ev["sick"]:
			break
	_check(ev["sick"] and p.is_queasy() and not ev["ate"], "eating a sick fish makes a penguin queasy, and gives it nothing")
	await _frames(30)
	var speed := p.swim_speed()
	_check(not p.boost() and speed < p.tuning.swim_cruise_speed * 0.7, "queasy, it can't boost and swims slowly (%.1f m/s)" % speed)
	await _frames(int(p.tuning.throw_up_delay * 60.0))
	_check(ev["threw_up"] and p.energy < 50.0, "and it throws the fish back up (energy %.0f)" % p.energy)
	await _frames(int(p.tuning.queasy_seconds * 60.0))
	_check(not p.is_queasy() and p.boost(), "it wears off after %.0f s" % p.tuning.queasy_seconds)
	p.queue_free()
	await _frames(2)


func _test_krill() -> void:
	var swarms := _level.get_node("Food").get_children().filter(func(n: Node) -> bool: return n is KrillSwarm)
	_check(swarms.size() > 0, "the level has krill swarms (%d)" % swarms.size())
	# Swimming through a swarm eats krill: lots of little snacks.
	var swarm := KrillSwarm.new()
	var t := swarm.tuning.duplicate() as KrillTuning
	t.regrow_seconds = 1.0
	t.drift_speed = 0.0
	swarm.tuning = t
	swarm.position = Vector3(-70.0, -1.0, -60.0)
	_level.add_child(swarm)
	await _frames(2)
	var p := _spawn_swimmer(swarm.global_position + Vector3(0.0, 0.7, 0.0), 0.0)
	p.infinite_energy = false
	p.energy = 30.0
	var full := swarm.remaining()
	for i in 60:
		p.set_swim_speed(0.0)
		await tree.physics_frame
	var ate := full - swarm.remaining()
	_check(ate >= int(t.eat_rate * 0.7) and p.energy > 30.0 + t.krill_energy * ate * 0.5,
		"a penguin in a krill swarm eats krill as long as it stays (%d in a second, energy %.0f)" % [ate, p.energy])
	for i in 8 * 60:
		p.set_swim_speed(0.0)
		await tree.physics_frame
		if swarm.remaining() == 0:
			break
	_check(swarm.remaining() == 0, "a swarm can be eaten out")
	p.global_position += Vector3(0.0, 0.0, 30.0)
	await _frames(int(t.regrow_seconds * 60.0) + 10)
	_check(swarm.remaining() == t.count, "and forms again a while later")
	swarm.queue_free()
	p.queue_free()
	await _frames(2)


func _test_squid() -> void:
	var squids := _level.get_node("Food").get_children().filter(func(n: Node) -> bool: return n is Squid)
	_check(squids.size() > 0, "the level has squid (%d)" % squids.size())
	var squid := Squid.new()
	squid.position = Vector3(-70.0, -2.5, -60.0)
	_level.add_child(squid)
	await _frames(2)
	var jets := [0]
	var ate := [false]
	squid.jetted.connect(func() -> void: jets[0] += 1)
	squid.eaten.connect(func(_p: Penguin) -> void: ate[0] = true)
	# A penguin coming at it makes it jet away; it keeps jetting until it's spent.
	var p := _spawn_swimmer(squid.global_position + Vector3(0.0, 0.0, 6.0), 0.0)
	p.global_position.y = squid.global_position.y
	p.infinite_energy = false
	p.energy = 40.0
	var fastest := 0.0
	var gained := [0.0]
	p.ate_fish.connect(func(e: float) -> void: gained[0] = maxf(gained[0], e))
	for i in 20 * 60:
		var to := squid.global_position - p.global_position
		p.set_facing(atan2(-to.x, -to.z))
		p.set_pitch(clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.0, 1.0))
		await tree.physics_frame
		fastest = maxf(fastest, squid.velocity.length())
		if ate[0]:
			break
	_check(jets[0] >= 1 and fastest > squid.tuning.jet_speed * 0.9, "a squid jets away from a penguin that comes close (%.0f m/s)" % fastest)
	_check(jets[0] <= squid.tuning.jets + 1 and ate[0], "it can only jet so often: chased down, it's caught (%d jets)" % jets[0])
	_check(gained[0] >= squid.tuning.energy * 0.99, "a squid is a big meal (+%.0f energy)" % gained[0])
	squid.queue_free()
	p.queue_free()
	await _frames(2)
