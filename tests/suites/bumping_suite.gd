extends "res://tests/smoke_suite.gd"
## Bumps between penguins: knockback by mass, feet vs. belly, teetering at the edge and scrambling back.


func suite_name() -> String:
	return "bumping"


func run() -> void:
	await _test_bump_knockback()
	await _test_teeter_and_scramble()


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
	target.force_state(Penguin.State.SLIDE)
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
		await tree.physics_frame
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
		await tree.physics_frame
		if target.state == Penguin.State.SWIM:
			fell = true
			break
	_check(fell, "with nobody pulling back, it falls in (state=%s)" % Penguin.State.keys()[target.state])
	target.queue_free()
	hitter.queue_free()
