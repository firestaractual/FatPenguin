extends SceneTree
## Headless smoke test for the Prototype 0 movement toy.
## Drives the penguin with simulated input and checks each movement verb still works,
## then checks the plateau (slide down chutes, hop up steps), bumping with dummy penguins,
## fish schooling with their own species, leopard seals hunting and lying in ambush, and an orca
## pod's attacks: the wave, the ram, the cut-off and the carousel, and how they chain into a trap.
## Then the berg field (real kinds of berg, ramps, tunnels, the lagoon, pack ice to hop) and the
## colonies of NPC penguins (huddling, fishing parties, getting home).
##
## Run from the project folder:
##   godot --headless --fixed-fps 60 --script res://tests/movement_smoke_test.gd
## Exit code 0 = all checks passed.

const LEVEL := "res://levels/movement_toy/movement_toy.tscn"
const PENGUIN_SCENE := "res://actors/penguin/penguin.tscn"
const SEAL_SCENE := "res://actors/predators/leopard_seal.tscn"
const ORCA_POD_SPAWN := "res://levels/movement_toy/predators/orca_pod.tres"
## Open ice on the south-east of the berg, clear of the plateau, ramp and level dummies.
const BUMP_LANE_Z := 10.0

var _failures: Array[String] = []
var _penguin: Penguin
var _level: Node
var _plateau: IcePlateau
var _states_seen: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node = load(LEVEL).instantiate()
	root.add_child(level)
	_level = level
	_plateau = level.get_node("Plateau") as IcePlateau
	_penguin = level.get_node("Penguin") as Penguin
	_penguin.state_changed.connect(func(s: Penguin.State) -> void: _states_seen.append(Penguin.State.keys()[s]))
	# The level's fish swim about in schools, so one could cross the penguin's path and skew an
	# energy or speed check. They stay in the level but can't be eaten during this test.
	for fish: Fish in level.get_node("Fish").get_children():
		fish.monitoring = false
	# The level's predators would hunt the test penguin. The predator checks bring their own.
	var kinds := {}
	for node in get_nodes_in_group(&"predators"):
		var name := (node as Predator).tuning.display_name
		kinds[name] = kinds.get(name, 0) + 1
	_check(kinds.get("Leopard seal", 0) > 0 and kinds.get("Orca", 0) > 0 and get_nodes_in_group(&"pods").size() > 0,
		"the level spawns its predators from its spawn list (%s)" % str(kinds))
	for spawned in level.get_node("Predators").get_children():
		spawned.queue_free()
	# The colonies' NPC penguins would get in the way too. The NPC checks bring their own.
	var npcs := get_nodes_in_group(&"npcs").size()
	_check(npcs > 0, "the level spawns its colonies of NPC penguins (%d)" % npcs)
	for npc in get_nodes_in_group(&"npcs"):
		npc.queue_free()

	await _test_lands_on_ice()
	await _test_slide_off_edge_into_water()
	await _test_boost_and_porpoise()
	await _test_launch_onto_iceberg()
	await _test_ramp_climb_out()
	await _test_eat_fish_and_fatness()
	await _test_energy_drain_and_overfill()
	await _test_floats_with_back_above_water()
	await _test_air_runs_out_and_forces_surface()
	await _test_land_speeds_and_brake()
	await _test_chute_slide()
	await _test_hop_small_steps_when_fat()
	await _test_big_steps_thin_only()
	await _test_bump_knockback()
	await _test_teeter_and_scramble()
	await _test_fish_schools()
	await _test_predators()
	await _test_seal_ambush()
	await _test_orcas()
	await _test_orca_ram()
	await _test_orca_cut_off()
	await _test_orca_carousel()
	await _test_orca_trap()
	await _test_berg_field()
	await _test_gap_hops()
	await _test_tunnels()
	await _test_spire_climb()
	await _test_huddle()
	await _test_npc_fishing()

	print("\nStates seen: ", " > ".join(_states_seen))
	if _failures.is_empty():
		print("SMOKE TEST PASSED")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("SMOKE TEST FAILED (%d)" % _failures.size())
		quit(1)


# --- Tests ------------------------------------------------------------------

func _test_lands_on_ice() -> void:
	await _frames(45)
	_check(_penguin.state == Penguin.State.WALK, "lands on the iceberg and walks (state=%s)" % _state())
	_check(_penguin.global_position.y > 1.0, "standing on top of the ice (y=%.2f)" % _penguin.global_position.y)


func _test_slide_off_edge_into_water() -> void:
	# Spawn faces +Z toward the edge; camera is behind, so "up" = forward.
	Input.action_press(&"move_up")
	await _frames(10)
	var energy_before := _penguin.energy
	_tap(&"action")
	await _frames(2)
	_check(_penguin.state == Penguin.State.SLIDE, "action on ice starts a belly-slide (state=%s)" % _state())
	var flop_cost := energy_before - _penguin.energy
	_check(absf(flop_cost - _penguin.tuning.slide_energy_cost) < 0.2, "flopping onto your belly costs energy (%.2f)" % flop_cost)
	Input.action_release(&"move_up")
	var entered := await _wait_for_state(Penguin.State.SWIM, 300)
	_check(entered, "slides off the edge and ends up swimming")


func _test_boost_and_porpoise() -> void:
	_penguin.infinite_energy = true
	Input.action_press(&"move_down")
	await _frames(45)
	Input.action_release(&"move_down")
	var depth := -_penguin.global_position.y
	_check(depth > 1.0, "can dive below the surface (depth=%.2f)" % depth)
	await _frames(30)
	var model_up := (_penguin.get_node("Model") as Node3D).basis.y.normalized()
	_check(model_up.dot(_penguin.get_heading()) > 0.9, "model swims head-first along its heading")
	Input.action_press(&"move_up")
	await _frames(25)
	_tap(&"action")
	await _frames(3)
	_check(_penguin.get_speed() > 8.0, "boost reaches ~9 m/s (speed=%.1f)" % _penguin.get_speed())
	var breached := await _wait_for_state(Penguin.State.AIR, 120)
	Input.action_release(&"move_up")
	_check(breached, "fast upward swim breaches the surface (porpoise)")
	var peak := _penguin.global_position.y
	for i in 120:
		await physics_frame
		peak = maxf(peak, _penguin.global_position.y)
		if _penguin.state == Penguin.State.SWIM:
			break
	_check(peak > 0.8, "breach throws the penguin clear of the water (peak=%.2f)" % peak)
	_check(_penguin.state == Penguin.State.SWIM, "falls back into the water")
	_penguin.infinite_energy = false


func _test_launch_onto_iceberg() -> void:
	# Underwater just outside the south edge (z=30), facing the berg (-Z), nose up.
	_place_swimming(Vector3(0, -3.0, 37.0), 0.0, 55.0)
	_penguin.infinite_energy = true
	await _frames(2)
	_tap(&"action")
	var landed := false
	for i in 240:
		await physics_frame
		if _penguin.state in [Penguin.State.WALK, Penguin.State.SLIDE] and _penguin.global_position.y > 1.0:
			landed = true
			break
	_penguin.infinite_energy = false
	_check(landed, "boost + launch lands on the iceberg (state=%s, pos=%s)" % [_state(), _penguin.global_position])
	if landed:
		# The ice is slick enough that a landing slide crosses the berg, so dig in to stop.
		Input.action_press(&"move_down")
		var stopped := await _wait_for_state(Penguin.State.WALK, 300)
		Input.action_release(&"move_down")
		_check(stopped, "digging in after a launch stops the belly-slide and stands you up")


func _test_ramp_climb_out() -> void:
	# Swim at the surface toward the low ramp on the +X side of the berg.
	_place_swimming(Vector3(45.0, -Penguin.SURFACE_DEPTH, 0.0), PI / 2.0, 0.0)
	var out := await _wait_for_state(Penguin.State.WALK, 600)
	_check(out, "swimming into the ramp climbs out onto the ice (state=%s, pos=%s)" % [_state(), _penguin.global_position])
	_check(_penguin.global_position.y > -0.15, "climbing out up the ramp, the penguin stands clear of the water (y=%.2f)" % _penguin.global_position.y)


func _test_eat_fish_and_fatness() -> void:
	_penguin.energy = 0.0
	var thin_turn := _penguin.call(&"_turn_mult") as float
	var before := _penguin.energy
	_penguin.eat_fish()
	_check(is_equal_approx(_penguin.energy - before, _penguin.tuning.fish_value), "eating a fish adds fish_value energy")
	_penguin.energy = 100.0
	var fat_turn := _penguin.call(&"_turn_mult") as float
	_check(fat_turn < thin_turn, "fat penguins turn slower (%.2f < %.2f)" % [fat_turn, thin_turn])
	await _frames(20)
	var width := (_penguin.get_node("Model") as Node3D).basis.get_scale().x
	_check(width > 1.3, "fat penguins look fat (model width x%.2f)" % width)

	# Swim through a real fish.
	_penguin.energy = 30.0
	_place_swimming(Vector3(0, -5.0, 80.0), 0.0, 0.0)
	var fish: Node3D = load("res://actors/fish/fish.tscn").instantiate()
	fish.set(&"circle_radius", 0.0)
	fish.position = Vector3(0, -5.0, 76.0)
	root.add_child(fish)
	await _frames(90)
	_check(_penguin.energy > 35.0, "swimming into a fish eats it (energy=%.1f)" % _penguin.energy)
	fish.queue_free()


func _test_energy_drain_and_overfill() -> void:
	_penguin.infinite_energy = false
	_penguin.energy = 100.0
	await _frames(60)
	var overfill_loss := 100.0 - _penguin.energy
	_penguin.energy = 50.0
	await _frames(60)
	var normal_loss := 50.0 - _penguin.energy
	_check(absf(normal_loss - 1.5) < 0.1, "base drain ~1.5/s (got %.2f)" % normal_loss)
	_check(absf(overfill_loss - 3.0) < 0.15, "overfill drain ~3.0/s (got %.2f)" % overfill_loss)

	# The floor: the cold stops there, and spending below it comes back.
	var t := _penguin.tuning
	_penguin.energy = t.energy_floor + 0.5
	await _frames(60)
	_check(absf(_penguin.energy - t.energy_floor) < 0.01, "the cold can't drain you below the energy floor (energy=%.2f)" % _penguin.energy)
	_penguin.energy = 5.0
	await _frames(60)
	_check(absf(_penguin.energy - (5.0 + t.floor_recovery)) < 0.2, "spent below the floor, you get your breath back (energy=%.2f)" % _penguin.energy)
	# Even a penguin that has spent everything can belly-slide again after a moment.
	await _place_on_ice(_penguin, Vector3(-12.0, 1.0, 16.0), 0.0, 0.0)
	await _frames(int(t.slide_energy_cost / t.floor_recovery * 60.0) + 10)
	_tap(&"action")
	await _frames(3)
	_check(_penguin.state == Penguin.State.SLIDE, "an emptied penguin can flop again after catching its breath (state=%s)" % _state())
	await _wait_for_state(Penguin.State.WALK, 600)


func _test_floats_with_back_above_water() -> void:
	_place_swimming(Vector3(0, -Penguin.SURFACE_DEPTH, 90.0), 0.0, 0.0)
	await _frames(40)
	var top := -INF
	for m in _penguin.get_node("Model").find_children("*", "MeshInstance3D"):
		var mesh := m as MeshInstance3D
		top = maxf(top, (mesh.global_transform * mesh.get_aabb()).end.y)
	_check(_penguin.state == Penguin.State.SWIM and top > 0.1, "swimming along the top, the back stays above the water (top at %.2f)" % top)


func _test_air_runs_out_and_forces_surface() -> void:
	_place_swimming(Vector3(0, -12.0, 90.0), 0.0, 0.0)
	_penguin.infinite_energy = true
	_penguin.air = 0.5
	await _frames(60)
	_check(_penguin.air <= 0.0, "air runs out underwater")
	var surfaced := false
	for i in 600:
		await physics_frame
		if _penguin.global_position.y > -Penguin.BREATH_DEPTH:
			surfaced = true
			break
	_check(surfaced, "out of air forces the penguin up to breathe")
	await _frames(150)
	_check(_penguin.air >= _penguin.tuning.air_seconds - 0.1, "air refills at the surface (air=%.1f)" % _penguin.air)


func _test_land_speeds_and_brake() -> void:
	# Open ice south-east of the plateau, heading east (+X) toward the edge ~18 m away.
	var t := _penguin.tuning
	_penguin.infinite_energy = true
	await _place_on_ice(_penguin, Vector3(10.0, 1.0, BUMP_LANE_Z), -PI / 2.0, 20.0)
	await _frames(20)
	Input.action_press(&"move_up")
	await _frames(45)
	var walk := Vector2(_penguin.velocity.x, _penguin.velocity.z).length()
	_check(absf(walk - t.walk_speed) < 0.05, "walks at walk_speed (%.2f m/s)" % walk)
	_tap(&"action")
	await _frames(3)
	Input.action_release(&"move_up")
	_check(_penguin.state == Penguin.State.SLIDE and _penguin.get_speed() > t.slide_start_speed - 0.2,
		"a flop starts at slide_start_speed (%.1f m/s)" % _penguin.get_speed())
	var start := _penguin.global_position
	Input.action_press(&"move_down") # dig in
	var stood := await _wait_for_state(Penguin.State.WALK, 180)
	Input.action_release(&"move_down")
	var dist := Vector2(_penguin.global_position.x - start.x, _penguin.global_position.z - start.z).length()
	var glide := t.slide_start_speed * t.slide_start_speed / (2.0 * t.slide_friction)
	_check(stood and dist < 6.0, "pulling back digs in and stops a full-speed slide in %.1f m (no brake: ~%.0f m)" % [dist, glide])

	# Left alone, a slow slide glides to a stop by itself (v² / 2 × friction).
	start = _penguin.global_position
	_launch_slide(_penguin, Vector3.LEFT, 3.0)
	stood = await _wait_for_state(Penguin.State.WALK, 600)
	dist = Vector2(_penguin.global_position.x - start.x, _penguin.global_position.z - start.z).length()
	var expected := 3.0 * 3.0 / (2.0 * t.slide_friction)
	_check(stood and absf(dist - expected) < 1.5, "a slow slide glides %.1f m on its own and stands up (expected ~%.0f m)" % [dist, expected])
	_penguin.infinite_energy = false


func _test_chute_slide() -> void:
	# On top of the plateau, just behind the south chute, facing down it (+Z).
	_penguin.infinite_energy = true
	await _place_on_ice(_penguin, _plateau.south_chute_head(), PI, 50.0)
	Input.action_press(&"move_up")
	var slipped := await _wait_for_state(Penguin.State.SLIDE, 150)
	_check(slipped, "walking onto a steep chute slips into a belly-slide (state=%s)" % _state())
	var top_speed := 0.0
	for i in 150:
		await physics_frame
		top_speed = maxf(top_speed, _penguin.get_speed())
		if _penguin.global_position.y < _plateau.top_y() - _plateau.height + 0.6:
			break
	Input.action_release(&"move_up")
	_check(top_speed > 4.5, "the chute speeds the slide up (top speed %.1f m/s)" % top_speed)
	_penguin.infinite_energy = false


func _test_hop_small_steps_when_fat() -> void:
	_penguin.infinite_energy = true
	await _place_on_ice(_penguin, _plateau.east_steps_foot(), PI / 2.0, 100.0) # facing -X, up the steps
	var hops: Array[float] = []
	var on_hop := func(ledge: float, cleared: bool) -> void:
		if cleared:
			hops.append(ledge)
	_penguin.hopped.connect(on_hop)
	Input.action_press(&"move_up")
	var on_top := false
	for i in 900:
		await physics_frame
		if _penguin.global_position.y > _plateau.top_y() + 0.2 and _penguin.state == Penguin.State.WALK:
			on_top = true
			break
	Input.action_release(&"move_up")
	_penguin.hopped.disconnect(on_hop)
	_check(on_top, "a stuffed penguin hops up the small steps onto the plateau (y=%.2f, hops=%d)" % [_penguin.global_position.y, hops.size()])
	_penguin.infinite_energy = false


func _test_big_steps_thin_only() -> void:
	_penguin.infinite_energy = true
	var failed_hops := [0]
	var on_hop := func(_ledge: float, cleared: bool) -> void:
		if not cleared:
			failed_hops[0] += 1
	_penguin.hopped.connect(on_hop)
	# Stuffed: tries, falls short, stays at the bottom.
	await _place_on_ice(_penguin, _plateau.north_steps_foot(), PI, 100.0) # facing +Z, up the steps
	var start_y := _penguin.global_position.y
	Input.action_press(&"move_up")
	await _frames(300)
	Input.action_release(&"move_up")
	await _wait_for_state(Penguin.State.WALK, 60)
	_check(_penguin.global_position.y < start_y + 0.2 and failed_hops[0] > 0,
		"a stuffed penguin can't hop the big steps (dy=%.2f, failed hops=%d)" % [_penguin.global_position.y - start_y, failed_hops[0]])
	_penguin.hopped.disconnect(on_hop)
	# Thin: straight up.
	await _place_on_ice(_penguin, _plateau.north_steps_foot(), PI, 20.0)
	Input.action_press(&"move_up")
	var on_top := false
	for i in 600:
		await physics_frame
		if _penguin.global_position.y > _plateau.top_y() + 0.2 and _penguin.state == Penguin.State.WALK:
			on_top = true
			break
	Input.action_release(&"move_up")
	_check(on_top, "a thin penguin hops the big steps (y=%.2f)" % _penguin.global_position.y)
	_penguin.infinite_energy = false


func _test_bump_knockback() -> void:
	# Thin slides into thin standing: feet grip, short skid.
	var target := await _spawn_standing(Vector3(15.0, 1.0, BUMP_LANE_Z), 0.0)
	var hitter := await _spawn_standing(Vector3(12.0, 1.0, BUMP_LANE_Z), 0.0)
	var start := target.global_position
	_launch_slide(hitter, Vector3.RIGHT, 5.0)
	var hit := await _wait_for_bump(target, 120)
	_check(hit and target.is_immune(), "a slide into a penguin bumps it, and it's briefly immune")
	_check(target.noise > 0.3 and hitter.noise > 0.3, "a bump makes noise that draws predators (%.1f)" % target.noise)
	var moved := await _wait_until_still(target, start)
	_check(moved > 0.5 and moved < 1.6, "thin into thin standing: knocked %.2f m (feet grip)" % moved)
	await _frames(int(target.tuning.noise_fade_seconds * 60.0) + 10)
	_check(target.noise == 0.0, "and the noise fades")
	target.queue_free()
	hitter.queue_free()
	await _frames(2)

	# Fat slides into thin lying on its belly: the puck flies.
	target = await _spawn_standing(Vector3(15.0, 1.0, BUMP_LANE_Z), 0.0)
	hitter = await _spawn_standing(Vector3(13.5, 1.0, BUMP_LANE_Z), 100.0)
	target.call(&"_set_state", Penguin.State.SLIDE)
	start = target.global_position
	_launch_slide(hitter, Vector3.RIGHT, 5.0)
	hit = await _wait_for_bump(target, 60)
	moved = await _wait_until_still(target, start)
	_check(hit and moved > 5.0, "fat into thin on its belly: thin tumbles %.1f m" % moved)
	target.queue_free()
	hitter.queue_free()
	await _frames(2)

	# Thin slides into a stuffed penguin standing: barely moves it, but a fish comes loose.
	target = await _spawn_standing(Vector3(15.0, 1.0, BUMP_LANE_Z), 100.0)
	hitter = await _spawn_standing(Vector3(12.0, 1.0, BUMP_LANE_Z), 0.0)
	start = target.global_position
	var spills := [0]
	target.spilled_fish.connect(func(_at: Vector3) -> void: spills[0] += 1)
	_launch_slide(hitter, Vector3.RIGHT, 5.0)
	hit = await _wait_for_bump(target, 120)
	moved = await _wait_until_still(target, start)
	_check(hit and moved < 0.8, "thin into fat standing: fat moves only %.2f m" % moved)
	_check(spills[0] == 1 and target.energy < 95.0, "a hard bump knocks a fish loose from an overfed penguin (energy=%.0f)" % target.energy)
	target.queue_free()
	hitter.queue_free()
	await _frames(2)


func _test_teeter_and_scramble() -> void:
	# The player stands near the east edge facing out; a fat dummy slides in from behind.
	_penguin.infinite_energy = false
	var edge_x := sqrt(30.0 * 30.0 - BUMP_LANE_Z * BUMP_LANE_Z)
	await _place_on_ice(_penguin, Vector3(edge_x - 1.4, 1.0, BUMP_LANE_Z), -PI / 2.0, 50.0)
	await _frames(30) # let the camera settle behind
	var teetered := [false]
	_penguin.teetered.connect(func() -> void: teetered[0] = true)
	var hitter := await _spawn_standing(Vector3(edge_x - 4.6, 1.0, BUMP_LANE_Z), 100.0)
	_launch_slide(hitter, Vector3.RIGHT, 5.0)
	for i in 120:
		await physics_frame
		if teetered[0]:
			break
	_check(teetered[0], "knocked to the edge on its feet, the penguin teeters")
	var energy_before := _penguin.energy
	Input.action_press(&"move_down") # pull back, away from the edge
	await _frames(10)
	Input.action_release(&"move_down")
	var paid := energy_before - _penguin.energy
	await _frames(60)
	_check(_penguin.state == Penguin.State.WALK and _penguin.global_position.y > 1.0 and paid > 3.5,
		"pulling back scrambles to safety (state=%s, paid %.1f energy)" % [_state(), paid])
	hitter.queue_free()
	await _frames(2)

	# A dummy nobody saves goes in (a lane over, clear of the player).
	var lane := BUMP_LANE_Z + 4.0
	edge_x = sqrt(30.0 * 30.0 - lane * lane)
	var target := await _spawn_standing(Vector3(edge_x - 1.0, 1.0, lane), 0.0)
	hitter = await _spawn_standing(Vector3(edge_x - 4.0, 1.0, lane), 0.0)
	_launch_slide(hitter, Vector3.RIGHT, 5.0)
	var fell := false
	for i in 240:
		await physics_frame
		if target.state == Penguin.State.SWIM:
			fell = true
			break
	_check(fell, "with nobody pulling back, it falls in (state=%s)" % Penguin.State.keys()[target.state])
	target.queue_free()
	hitter.queue_free()


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
	var stranger_mates := (stranger.get(&"_neighbours") as Array).size()
	_check(stranger_mates == 0 and stranger.home == stranger_home, "a fish of another kind is never pulled in (school mates=%d)" % stranger_mates)

	# An eaten fish comes back beside its school, wherever it was eaten.
	var eaten := school[0]
	eaten.call(&"_set_active", false)
	eaten.global_position = centre + Vector3(30.0, 0.0, 0.0)
	eaten.call(&"_set_active", true)
	await _frames(2)
	var eaten_gap := eaten.global_position.distance_to(_middle_of(school))
	_check(eaten.visible and eaten_gap < 2.5, "an eaten fish respawns beside its school (%.1f m from the middle)" % eaten_gap)

	for fish in school:
		fish.queue_free()
	stray.queue_free()
	stranger.queue_free()


func _test_predators() -> void:
	# Out of the way: the player waits on the plateau, out of reach, and the level's dummies go.
	await _place_on_ice(_penguin, Vector3(0.0, 3.0, -8.0), 0.0, 50.0)
	for dummy in _level.get_node("Dummies").get_children():
		dummy.queue_free()
	await _frames(2)
	var berg_radius: float = _level.get(&"berg_radius")

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
		await physics_frame
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
		await physics_frame
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
		await physics_frame
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
	var spawn: Vector3 = _penguin.get(&"_spawn_position")
	_place_swimming(spot + Vector3(0.0, 1.0, -8.0), 0.0, 0.0)
	seal = _spawn_seal(spot)
	var eaten := [false]
	_penguin.caught.connect(func(_by: Node3D) -> void: eaten[0] = true, CONNECT_ONE_SHOT)
	for i in 900:
		await physics_frame
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
		await physics_frame
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
		if fish.species.display_name == "Antarctic silverfish" and (fish.get(&"_neighbours") as Array).size() >= 6:
			school = fish
			break
	var home := school.home
	var out := Vector3(home.x, 0.0, home.z).normalized()
	seal = _spawn_seal(Vector3(home.x, -2.5, home.z) + out * 8.0)
	seal.hunger = 90.0
	var bait := _spawn_bait(Vector3(home.x, -2.0, home.z) + out * 18.0, 100.0)
	var meals := [0]
	var chased := [false]
	var bait_id := bait.get_instance_id()
	seal.ate_fish.connect(func() -> void: meals[0] += 1)
	seal.locked_on.connect(func(p: Penguin) -> void: chased[0] = chased[0] or p.get_instance_id() == bait_id)
	for i in 900:
		await physics_frame
		if meals[0] > 0 and seal.state != Predator.State.FEED:
			break
	_check(meals[0] > 0 and seal.hunger <= seal.tuning.fed_hunger, "a starving seal eats from a school (%d fish, hunger down to %.0f)" % [meals[0], seal.hunger])
	_check(not chased[0], "and leaves a fat penguin 10 m away alone while it feeds")
	bait.queue_free()

	# Starving, it still lunges at a penguin that swims right up to it.
	seal.hunger = 90.0
	bait = _spawn_bait(seal.global_position + Vector3(0.0, 0.0, 3.0), 0.0)
	var lunged := [false]
	seal.lunged.connect(func(_at: Vector3) -> void: lunged[0] = true)
	for i in 120:
		await physics_frame
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
		await physics_frame
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
	var berg_radius: float = _level.get(&"berg_radius")
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
		await physics_frame
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
		await physics_frame
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
	_check(seal.call(&"_start_ambush"), "(a second seal lies in wait for it)")
	await _wait_settled(seal, _ambush_spot_for(world, waiting, t), 15 * 60)
	waiting.global_position = Vector3(-10.0, 1.5, 15.0)
	var gave_up := false
	for i in 4 * 60:
		await physics_frame
		if seal.state != Predator.State.AMBUSH:
			gave_up = true
			break
	_check(gave_up and seal.state == Predator.State.PATROL, "with nobody near that edge any more, it gives up waiting")

	# Going in somewhere else gives you a head start: no lunge straight away.
	waiting.global_position = Vector3(-berg_radius + 3.0, 1.5, 0.0)
	await _wait_for(waiting, Penguin.State.WALK, 60)
	seal.call(&"_start_ambush")
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
	seal.call(&"_start_ambush")
	spot = _ambush_spot_for(world, waiting, t)
	await _wait_settled(seal, spot, 15 * 60)
	var inward := -Vector3(spot.x, 0.0, spot.z).normalized()
	var from := spot - inward * 12.0
	from.y = -0.6
	var coming := _spawn_swimmer(from, atan2(-inward.x, -inward.z))
	coming.set(&"_speed", coming.tuning.swim_cruise_speed)
	var got_coming := [false]
	coming.caught.connect(func(_by: Node3D) -> void: got_coming[0] = true)
	var launched := false
	var made_it := false
	for i in 8 * 60:
		if coming.state == Penguin.State.SWIM:
			coming.set(&"_yaw", atan2(-inward.x, -inward.z))
			if not launched and Vector2(coming.global_position.x, coming.global_position.z).length() < berg_radius + 6.5:
				coming.set(&"_pitch", deg_to_rad(40.0))
				coming.call(&"_try_boost")
				launched = true
		await physics_frame
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


func _test_orcas() -> void:
	var berg_radius: float = _level.get(&"berg_radius")
	# A spawn entry puts three orcas in a pod, on their patrol loop west of the berg.
	var spawner := PredatorSpawner.new()
	spawner.ice_radius = berg_radius
	_level.add_child(spawner)
	var entry: PredatorSpawn = load("res://levels/movement_toy/predators/orca_pod.tres")
	var pod := _spawn_pod(spawner, entry)
	var t := _only_attack(pod, "Wave").settings as WaveAttackTuning
	_check(pod.members().size() == entry.pod_size, "a spawn entry puts %d orcas in a pod" % pod.members().size())

	# On patrol the pod swims together (after a few seconds to fall in behind the leader).
	await _frames(6 * 60)
	var total := 0.0
	var samples := 0
	for i in 8 * 60:
		await physics_frame
		for member in pod.members():
			if member != pod.leader():
				total += member.global_position.distance_to(pod.leader().global_position)
				samples += 1
	var mean := total / samples
	_check(mean < pod.tuning.spacing * 2.5, "the pod swims together (followers %.1f m from the leader on average)" % mean)

	# Orcas don't chase in open water: a fat penguin that keeps 12 m from the pod isn't hunted.
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
		bait.global_position = Vector3(outermost.global_position.x, -1.0, outermost.global_position.z) + out * 12.0
		await physics_frame
	_check(not hunted[0], "orcas don't chase a penguin 12 m away in open water")
	bait.queue_free()

	# The wave: a penguin standing near the edge the pod is passing gets washed off; one 6 m in
	# is untouched.
	var facing := Vector3(pod.leader().global_position.x, 0.0, pod.leader().global_position.z).normalized()
	var at_edge := await _spawn_standing(facing * (berg_radius - 1.5) + Vector3.UP, 0.0)
	var inland := await _spawn_standing(facing * (berg_radius - 6.0) + Vector3.UP, 0.0)
	var inland_start := inland.global_position
	var wave := {"coming": -1, "hit": -1, "washed": [], "surfaced": true}
	pod.attack_coming.connect(func(_a: PodAttack) -> void: wave["coming"] = Engine.get_physics_frames())
	pod.attack_hit.connect(func(_a: PodAttack, washed: Array[Penguin]) -> void:
		wave["hit"] = Engine.get_physics_frames()
		wave["washed"] = washed)
	pod.set(&"_cooldown", 0.0)
	for i in 40 * 60:
		await physics_frame
		if pod.phase == PredatorPod.Phase.WARN and pod.get(&"_phase_time") > t.warning_seconds * 0.8:
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
	var berg_radius: float = _level.get(&"berg_radius")
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
	pod.set(&"_cooldown", 0.0)
	var deepest := 0.0
	var tilt := 0.0
	for i in 40 * 60:
		await physics_frame
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
		await physics_frame
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
	pod.set(&"_cooldown", 0.0)
	var struck := [false]
	pod.attack_hit.connect(func(_a: PodAttack, _hit: Array[Penguin]) -> void: struck[0] = true)
	var went_in := false
	for i in 40 * 60:
		if struck[0]:
			Input.action_press(&"move_down")
		await physics_frame
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
	pod.set(&"_cooldown", 0.0)
	var rock := 0.0
	var fell_in := false
	for i in 40 * 60:
		await physics_frame
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
	var berg_radius: float = _level.get(&"berg_radius")
	var entry: PredatorSpawn = (load(ORCA_POD_SPAWN) as PredatorSpawn).duplicate()
	entry.start_angle_deg = -50.0
	var off_south := Vector3(0.0, -0.1, -berg_radius - 8.0)

	# Floating 8 m off the south edge: a wall of fins forms between it and the ice, closes in, and
	# when the warning runs out the nearest orca lunges.
	var floater := _spawn_bait(off_south, 50.0)
	floater.call(&"_set_state", Penguin.State.SWIM)
	var spawner := _spawn_pods()
	var pod := _spawn_pod(spawner, entry)
	var cut := _only_attack(pod, "Cut-off") as CutOffAttack
	var t := cut.settings as CutOffAttackTuning
	pod.set(&"_cooldown", 0.0)
	var ev := {"coming": -1, "hit": -1, "between": true, "fins": true, "lunge": false, "looked": false}
	pod.attack_coming.connect(func(_a: PodAttack) -> void: ev["coming"] = Engine.get_physics_frames())
	pod.attack_hit.connect(func(_a: PodAttack, _hit: Array[Penguin]) -> void: ev["hit"] = Engine.get_physics_frames())
	for i in 40 * 60:
		await physics_frame
		if pod.phase == PredatorPod.Phase.WARN and pod.get(&"_phase_time") >= 2.0 and not ev["looked"]:
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
	pod.set(&"_cooldown", 0.0)
	var called_off := [false]
	pod.attack_called_off.connect(func(_a: PodAttack) -> void: called_off[0] = true)
	var raced := false
	for i in 30 * 60:
		raced = raced or pod.phase != PredatorPod.Phase.PATROL
		if not raced:
			racer.set(&"_speed", 0.0) # waits until the pod moves
		await physics_frame
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
	floater.call(&"_set_state", Penguin.State.SWIM)
	var spawner := _spawn_pods()
	var pod := _spawn_pod(spawner, entry)
	var ring := _only_attack(pod, "Carousel") as CarouselAttack
	var t := ring.settings as CarouselAttackTuning
	pod.set(&"_cooldown", 0.0)
	var ev := {"ringed": true, "looked": false, "zone": -1, "hit": -1, "stunned": [], "lunge": false}
	pod.attack_hit.connect(func(_a: PodAttack, hit: Array[Penguin]) -> void:
		ev["hit"] = Engine.get_physics_frames()
		ev["stunned"] = hit)
	for i in 40 * 60:
		await physics_frame
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
	var speed := floater.get(&"_speed") as float
	floater.call(&"_try_boost")
	_check(is_equal_approx(floater.get(&"_speed") as float, speed), "stunned, it can't boost")
	_check(ev["lunge"], "and another orca lunges at it")
	spawner.queue_free()
	floater.queue_free()
	await _frames(2)

	# Swimming out (and diving) once the bubbles are up: held in, and lifted to the surface.
	var swimmer := _spawn_swimmer(open_water, 0.0)
	spawner = _spawn_pods()
	pod = _spawn_pod(spawner, entry)
	ring = _only_attack(pod, "Carousel") as CarouselAttack
	pod.set(&"_cooldown", 0.0)
	var worst := 0.0
	var deepest := 0.0
	for i in 40 * 60:
		if pod.phase in [PredatorPod.Phase.PATROL, PredatorPod.Phase.LINE_UP]:
			swimmer.set(&"_speed", 0.0)
		elif pod.phase == PredatorPod.Phase.WARN:
			var outward := Vector3(swimmer.global_position.x - ring.centre.x, 0.0, swimmer.global_position.z - ring.centre.z)
			if outward.length() > 0.1:
				swimmer.set(&"_yaw", atan2(-outward.x, -outward.z))
			swimmer.set(&"_pitch", deg_to_rad(-40.0))
			if pod.get(&"_phase_time") > 1.0:
				var r := Vector2(outward.x, outward.z).length()
				worst = maxf(worst, r - ring.radius)
				deepest = maxf(deepest, -swimmer.global_position.y)
		await physics_frame
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
	pod.set(&"_cooldown", 0.0)
	var called_off := [false]
	pod.attack_called_off.connect(func(_a: PodAttack) -> void: called_off[0] = true)
	var boosted := false
	for i in 40 * 60:
		if pod.phase in [PredatorPod.Phase.PATROL, PredatorPod.Phase.LINE_UP]:
			swimmer.set(&"_speed", 0.0)
		elif pod.phase == PredatorPod.Phase.WARN:
			var outward := Vector3(swimmer.global_position.x - ring.centre.x, 0.0, swimmer.global_position.z - ring.centre.z)
			if outward.length() > 0.1:
				swimmer.set(&"_yaw", atan2(-outward.x, -outward.z))
			if not boosted and pod.get(&"_phase_time") > 0.5:
				swimmer.call(&"_try_boost")
				boosted = true
		await physics_frame
		if called_off[0] or pod.phase == PredatorPod.Phase.HUNT:
			break
	_check(called_off[0], "a boost straight out, early, breaks through the bubbles")
	spawner.queue_free()
	swimmer.queue_free()
	await _frames(2)


func _test_orca_trap() -> void:
	var berg_radius: float = _level.get(&"berg_radius")
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
	pod.set(&"_attacks", kept)
	pod.set(&"_cooldown", 0.0)
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
			fleeing.set(&"_speed", 0.0)
		else:
			fleeing.set(&"_yaw", atan2(cut.home.x, cut.home.z)) # straight away from the ice
		await physics_frame
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
	pod.set(&"_attacks", kept)
	await _frames(6 * 60)
	var facing := Vector3(pod.leader().global_position.x, 0.0, pod.leader().global_position.z).normalized()
	var at_edge := await _spawn_standing(facing * (berg_radius - 1.5) + Vector3.UP, 0.0)
	pod.set(&"_cooldown", 0.0)
	var wave_hit := [-1]
	pod.attack_hit.connect(func(a: PodAttack, _hit: Array[Penguin]) -> void:
		if a is WaveAttack:
			wave_hit[0] = Engine.get_physics_frames())
	for i in 40 * 60:
		await physics_frame
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
		await physics_frame
		if pod.attack is CutOffAttack:
			cut_started = Engine.get_physics_frames()
			break
	var after := float(cut_started - wave_hit[0]) / 60.0
	_check(wave_hit[0] >= 0 and cut_started >= 0 and pod.trap_step == 2,
		"a penguin a wave washed in that swims off is cut off straight away (%.1f s after the wave, no cooldown)" % after)
	spawner.queue_free()
	at_edge.queue_free()
	await _frames(2)


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
	for node in get_nodes_in_group(&"bergs"):
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
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(mid, mid + Vector3.UP * 29.0, Penguin.WORLD_LAYER))
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
	for node in get_nodes_in_group(&"bergs"):
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
		if not _level.call(&"_clear_of_ice", fish.home, 5.0):
			too_close += 1
	_check(too_close == 0, "every fish lives at least 5 m from the ice (%d too close)" % too_close)


## Tries one way out of the water onto `berg`: a ramp (swim straight up it) or a launch (come in
## deep, pitch up, boost). True if it ends up standing on the berg.
func _try_exit(berg: IceBerg, exit: Dictionary) -> bool:
	var at: Vector3 = exit["at"]
	var toward: Vector3 = exit["toward"]
	var p := _spawn_swimmer(at - toward * 2.0 + Vector3.DOWN * (2.5 if exit["launch"] else 0.0), atan2(-toward.x, -toward.z))
	p.brain_controlled = true
	p.set(&"_pitch", deg_to_rad(52.0) if exit["launch"] else 0.0)
	var boosted := false
	var ok := false
	for i in 12 * 60:
		p.wish_dir = toward * cos(deg_to_rad(52.0)) + Vector3.UP * sin(deg_to_rad(52.0)) if exit["launch"] else toward
		p.wish_brake = p.state == Penguin.State.SLIDE
		if exit["launch"] and not boosted and p.global_position.distance_to(at) > 1.0 and p.get_heading().y > 0.6:
			p.wish_action = true
			boosted = true
		await physics_frame
		var flat := Vector2(p.global_position.x - berg.global_position.x, p.global_position.z - berg.global_position.z).length()
		if p.state == Penguin.State.WALK and p.global_position.y > 0.4 and flat <= berg.reach() + 0.5:
			ok = true
			break
	p.queue_free()
	await _frames(2)
	return ok


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
		p.set(&"_yaw", atan2(-dir.x, -dir.z))
		var hops := [0]
		p.hopped.connect(func(_d: float, _cleared: bool) -> void: hops[0] += 1)
		var wet := false
		var along := 0.0
		for i in 60 * 60:
			p.energy = energy # (a fish it swims past mustn't fatten it up on the way)
			p.wish_dir = dir
			p.wish_brake = p.state == Penguin.State.SLIDE
			await physics_frame
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
		await physics_frame
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
			await physics_frame
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
			await physics_frame
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
		await physics_frame
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
			await physics_frame
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


func _test_huddle() -> void:
	# A colony of 8 on the home floe, not hungry: they huddle round its waddle spot, and the
	# huddle keeps turning over.
	var home := _level.get_node("BergField/HomeFloe") as IceBerg
	var spot := home.waddle_spot()
	var colony: Array[Penguin] = []
	for i in 8:
		var a := TAU * i / 8.0
		colony.append(_spawn_npc(home, spot + Vector3(cos(a), 0.5, sin(a)) * 3.0, 60.0, true))
	await _frames(25 * 60)
	var tuning: NpcTuning = (colony[0].get_node("Brain") as PenguinBrain).tuning
	var wind := Vector3(tuning.wind.x, 0.0, tuning.wind.z).normalized()
	var core := {}
	var edge := {}
	var samples := 0
	var spread := 0.0
	var off_spot := 0.0
	var drain := 0.0
	for i in 90 * 60:
		await physics_frame
		if i % 30 != 0:
			continue
		samples += 1
		var middle := Vector3.ZERO
		for p in colony:
			middle += p.global_position
		middle /= colony.size()
		off_spot = maxf(off_spot, Vector2(middle.x - spot.x, middle.z - spot.z).length())
		for p in colony:
			spread += Vector2(p.global_position.x - middle.x, p.global_position.z - middle.z).length()
			drain += p.drain_mult
			var near := 0
			var sheltered := false
			for other in colony:
				var rel := other.global_position - p.global_position
				rel.y = 0.0
				if other == p:
					continue
				if rel.length() < tuning.neighbour_range:
					near += 1
				if rel.length() < tuning.neighbour_range * 1.3 and rel.dot(-wind) > 0.3 * rel.length():
					sheltered = true
			if near >= 3:
				core[p] = core.get(p, 0) + 1
			if not sheltered:
				edge[p] = edge.get(p, 0) + 1
	var mean_spread := spread / (samples * colony.size())
	var took_turns := 0
	var got_warm := 0
	for p in colony:
		if edge.get(p, 0) >= samples * 0.1:
			took_turns += 1
		if core.get(p, 0) >= samples * 0.05:
			got_warm += 1
	_check(mean_spread < 2.0 and off_spot < 3.0, "NPC penguins huddle in the middle of their berg (%.1f m from the huddle's middle on average, which stays within %.1f m of the spot)" % [mean_spread, off_spot])
	_check(took_turns >= 6 and got_warm >= 6, "the huddle turns over: %d of 8 took turns on the windward edge, %d of 8 got in among the others" % [took_turns, got_warm])
	_check(drain / (samples * colony.size()) < 0.6, "huddled, they burn energy slower (×%.2f on average)" % (drain / (samples * colony.size())))
	for p in colony:
		p.queue_free()
	await _frames(2)


func _test_npc_fishing() -> void:
	# Four hungry NPCs on the home floe: they gather at the edge, go in together, eat and come
	# home. And one knocked into the water swims back.
	for fish: Fish in _level.get_node("Fish").get_children():
		fish.monitoring = true
	var home := _level.get_node("BergField/HomeFloe") as IceBerg
	var spot := home.waddle_spot()
	var party: Array[Penguin] = []
	var went_in := {}
	var best := {}
	for i in 4:
		var p := _spawn_npc(home, spot + Vector3(i * 0.9 - 1.3, 0.5, 0.0), 25.0, false)
		party.append(p)
		p.state_changed.connect(func(s: Penguin.State) -> void:
			if s == Penguin.State.SWIM and not went_in.has(p):
				went_in[p] = Engine.get_physics_frames())
	var home_again := 0
	for i in 150 * 60:
		await physics_frame
		for p in party:
			best[p] = maxf(best.get(p, 0.0), p.energy)
		if i % 60 == 0:
			home_again = 0
			for p in party:
				var brain := p.get_node("Brain") as PenguinBrain
				if went_in.has(p) and brain.mode == PenguinBrain.Mode.HUDDLE:
					home_again += 1
			if home_again >= 3:
				break
	var entries: Array = went_in.values()
	entries.sort()
	var together := entries.size() >= 3 and float(entries[2] - entries[0]) / 60.0 < 4.0
	var fed := 0
	for p in party:
		if best.get(p, 0.0) > 50.0:
			fed += 1
	_check(together, "hungry NPCs gather at the edge and go in together (%d went in%s)" % [entries.size(), "" if entries.size() < 3 else ", the first three within %.1f s" % (float(entries[2] - entries[0]) / 60.0)])
	_check(fed >= 3, "they catch fish out there (%d of 4 got past 50 energy)" % fed)
	_check(home_again >= 3, "and come home to the huddle (%d of 4 back)" % home_again)
	for p in party:
		p.queue_free()

	# Knocked in off the east side: it swims back, gets out and walks back to the huddle.
	var swimmer := _spawn_npc(home, Vector3(38.0, -0.2, 8.0), 60.0, true)
	swimmer.call(&"_set_state", Penguin.State.SWIM)
	var brain := swimmer.get_node("Brain") as PenguinBrain
	var out := false
	for i in 60 * 60:
		await physics_frame
		if brain.mode == PenguinBrain.Mode.HUDDLE and swimmer.state == Penguin.State.WALK:
			out = true
			break
	_check(out, "an NPC knocked into the water swims back, climbs out and rejoins the huddle")
	swimmer.queue_free()
	for fish: Fish in _level.get_node("Fish").get_children():
		fish.monitoring = false
	await _frames(2)


# --- Helpers ----------------------------------------------------------------

## Leaves `pod` with just its attack called `attack_name`, and returns that attack.
func _only_attack(pod: PredatorPod, attack_name: String) -> PodAttack:
	var kept: Array[PodAttack] = []
	for attack in pod.attacks():
		if attack.settings.display_name == attack_name:
			kept.append(attack)
	pod.set(&"_attacks", kept)
	return kept[0] if not kept.is_empty() else null


## A computer penguin with a brain, living on `home`, at `at`.
func _spawn_npc(home: IceBerg, at: Vector3, energy: float, endless: bool) -> Penguin:
	var p := load(PENGUIN_SCENE).instantiate() as Penguin
	p.player_controlled = false
	p.start_energy = energy
	p.infinite_energy = endless
	p.position = at
	var brain := PenguinBrain.new()
	brain.name = "Brain"
	brain.berg = home
	p.add_child(brain)
	_level.add_child(p)
	return p


## A pod from `entry`, kept round the home floe (no roaming off to other bergs mid-check).
func _spawn_pod(spawner: PredatorSpawner, entry: PredatorSpawn) -> PredatorPod:
	var pod := spawner.spawn(entry)[0] as PredatorPod
	for member in pod.members():
		var t := member.tuning.duplicate() as PredatorTuning
		t.roam_chance = 0.0
		member.tuning = t
	return pod


## A spawner for pods, at the origin, around the berg.
func _spawn_pods() -> PredatorSpawner:
	var spawner := PredatorSpawner.new()
	spawner.ice_radius = _level.get(&"berg_radius")
	_level.add_child(spawner)
	return spawner


## A computer penguin swimming at the surface at `at`, facing `yaw` (0 faces -Z). It swims
## straight ahead at cruise speed unless a test holds it (set _speed to 0 each frame).
func _spawn_swimmer(at: Vector3, yaw: float) -> Penguin:
	var p := load(PENGUIN_SCENE).instantiate() as Penguin
	p.player_controlled = false
	p.infinite_energy = true
	p.start_energy = 50.0
	p.position = at
	_level.add_child(p)
	p.set(&"_yaw", yaw)
	p.set(&"_speed", 0.0)
	p.call(&"_set_state", Penguin.State.SWIM)
	return p


## Drops `p` into the water at `at` (on the surface).
func _put_in_water(p: Penguin, at: Vector3) -> void:
	p.global_position = Vector3(at.x, -0.2, at.z)
	p.velocity = Vector3.ZERO
	p.call(&"_set_state", Penguin.State.SWIM)
	p.reset_physics_interpolation()


## Where a seal with tuning `t` would wait for `p`: off the nearest edge, ambush_depth down.
func _ambush_spot_for(world: World3D, p: Penguin, t: PredatorTuning) -> Vector3:
	var edge := IceEdges.nearest_edge(world, p.global_position, t.ambush_edge_reach)
	if edge.is_empty():
		return Vector3.INF
	var spot: Vector3 = (edge["point"] as Vector3) + (edge["out"] as Vector3) * t.ambush_offset
	spot.y = Penguin.WATER_LEVEL - t.ambush_depth
	return spot


## Waits until `predator` is lying still close to `spot`, in ambush. False if it never does.
func _wait_settled(predator: Predator, spot: Vector3, max_frames: int) -> bool:
	for i in max_frames:
		await physics_frame
		if predator.state == Predator.State.AMBUSH and predator.global_position.distance_to(spot) < 1.5 and predator.velocity.length() < 0.3:
			return true
	return false


## Is the pod showing the danger marker called `marker_name`?
func _marker_shown(pod: PredatorPod, marker_name: String) -> bool:
	var marker := pod.get_node_or_null(marker_name) as Node3D
	return marker != null and marker.visible


func _spawn_seal(at: Vector3) -> Predator:
	var seal := load(SEAL_SCENE).instantiate() as Predator
	seal.ice_radius = _level.get(&"berg_radius")
	seal.position = at
	_level.add_child(seal)
	seal.hunger = 0.0
	return seal


## A penguin floating still in the water: bait that doesn't swim off.
func _spawn_bait(at: Vector3, with_energy: float) -> Penguin:
	var p := load(PENGUIN_SCENE).instantiate() as Penguin
	p.player_controlled = false
	p.infinite_energy = true
	p.start_energy = with_energy
	p.position = at
	_level.add_child(p)
	p.set_physics_process(false)
	return p


func _spawn_fish(species: FishSpecies, at: Vector3) -> Fish:
	var fish := load("res://actors/fish/fish.tscn").instantiate() as Fish
	fish.species = species
	fish.position = at
	root.add_child(fish)
	return fish


func _school_mates_in_range(fish: Fish, all: Array) -> int:
	var mates := 0
	for other: Fish in all:
		if other != fish and other.species == fish.species \
				and other.global_position.distance_to(fish.global_position) <= fish.species.school_range:
			mates += 1
	return mates


func _middle_of(fishes: Array[Fish]) -> Vector3:
	var sum := Vector3.ZERO
	for fish in fishes:
		sum += fish.global_position
	return sum / fishes.size()


func _place_swimming(pos: Vector3, yaw: float, pitch_deg: float) -> void:
	_penguin.global_position = pos
	_penguin.velocity = Vector3.ZERO
	_penguin.set(&"_yaw", yaw)
	_penguin.set(&"_pitch", deg_to_rad(pitch_deg))
	_penguin.set(&"_speed", _penguin.tuning.swim_cruise_speed)
	_penguin.call(&"_set_state", Penguin.State.SWIM)
	_penguin.reset_physics_interpolation()


## Stand a penguin on the ice at `ground` (a point on the surface) and wait until it's on its feet.
func _place_on_ice(p: Penguin, ground: Vector3, yaw: float, with_energy: float) -> void:
	p.energy = with_energy
	p.global_position = ground + Vector3.UP * (p.get_node("CollisionShape3D").shape.radius + 0.05)
	p.velocity = Vector3.ZERO
	p.set(&"_yaw", yaw)
	p.set(&"_walk_vel", Vector3.ZERO)
	p.set(&"_knock", Vector3.ZERO)
	p.call(&"_set_state", Penguin.State.AIR)
	p.reset_physics_interpolation()
	for i in 60:
		await physics_frame
		if p.state == Penguin.State.WALK:
			break
	await _frames(20)


func _spawn_standing(ground: Vector3, with_energy: float) -> Penguin:
	var p: Penguin = load(PENGUIN_SCENE).instantiate()
	p.player_controlled = false
	p.infinite_energy = true
	p.start_energy = with_energy
	p.position = ground + Vector3.UP * 0.5
	_level.add_child(p)
	await _wait_for(p, Penguin.State.WALK, 60)
	await _frames(5)
	return p


func _launch_slide(p: Penguin, dir: Vector3, speed: float) -> void:
	p.set(&"_yaw", atan2(-dir.x, -dir.z))
	p.velocity = dir * speed
	p.call(&"_set_state", Penguin.State.SLIDE)


func _wait_for_bump(p: Penguin, max_frames: int) -> bool:
	var got := [false]
	var cb := func(_o: Penguin, _s: float, _h: bool) -> void: got[0] = true
	p.bumped.connect(cb)
	for i in max_frames:
		await physics_frame
		if got[0]:
			break
	p.bumped.disconnect(cb)
	return got[0]


## Waits until `p` stops moving; returns how far it ended up from `from` (horizontally).
func _wait_until_still(p: Penguin, from: Vector3) -> float:
	var still := 0
	for i in 600:
		await physics_frame
		still = still + 1 if Vector2(p.velocity.x, p.velocity.z).length() < 0.05 else 0
		if still > 10:
			break
	return Vector2(p.global_position.x - from.x, p.global_position.z - from.z).length()


func _wait_for(p: Penguin, state: Penguin.State, max_frames: int) -> bool:
	for i in max_frames:
		if p.state == state:
			return true
		await physics_frame
	return p.state == state


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)


func _wait_for_state(state: Penguin.State, max_frames: int) -> bool:
	for i in max_frames:
		if _penguin.state == state:
			return true
		await physics_frame
	return _penguin.state == state


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _state() -> String:
	return Penguin.State.keys()[_penguin.state]


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failures.append(what)
