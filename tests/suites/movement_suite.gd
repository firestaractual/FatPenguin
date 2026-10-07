extends "res://tests/smoke_suite.gd"
## Swimming, boosting and launching, walking, sliding and braking, chutes and steps, eating, energy and air.


func suite_name() -> String:
	return "movement"


func run() -> void:
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
		await tree.physics_frame
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
		await tree.physics_frame
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
	var thin_turn := _penguin.turn_rate_mult()
	var before := _penguin.energy
	_penguin.eat_fish()
	_check(is_equal_approx(_penguin.energy - before, _penguin.tuning.fish_value), "eating a fish adds fish_value energy")
	_penguin.energy = 100.0
	var fat_turn := _penguin.turn_rate_mult()
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
		await tree.physics_frame
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
		await tree.physics_frame
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
		await tree.physics_frame
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
		await tree.physics_frame
		if _penguin.global_position.y > _plateau.top_y() + 0.2 and _penguin.state == Penguin.State.WALK:
			on_top = true
			break
	Input.action_release(&"move_up")
	_check(on_top, "a thin penguin hops the big steps (y=%.2f)" % _penguin.global_position.y)
	_penguin.infinite_energy = false
