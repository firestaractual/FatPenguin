extends SceneTree
## Headless smoke test for the Prototype 0 movement toy.
## Drives the penguin with simulated input and checks each movement verb still works,
## then checks the plateau (slide down chutes, hop up steps), bumping with dummy penguins,
## and fish schooling with their own species.
##
## Run from the project folder:
##   godot --headless --fixed-fps 60 --script res://tests/movement_smoke_test.gd
## Exit code 0 = all checks passed.

const LEVEL := "res://levels/movement_toy/movement_toy.tscn"
const PENGUIN_SCENE := "res://actors/penguin/penguin.tscn"
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
	var moved := await _wait_until_still(target, start)
	_check(moved > 0.5 and moved < 1.6, "thin into thin standing: knocked %.2f m (feet grip)" % moved)
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


# --- Helpers ----------------------------------------------------------------

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
