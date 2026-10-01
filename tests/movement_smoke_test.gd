extends SceneTree
## Headless smoke test for the Prototype 0 movement toy.
## Drives the penguin with simulated input and checks each movement verb still works.
##
## Run from the project folder:
##   godot --headless --fixed-fps 60 --script res://tests/movement_smoke_test.gd
## Exit code 0 = all checks passed.

const LEVEL := "res://levels/movement_toy/movement_toy.tscn"

var _failures: Array[String] = []
var _penguin: Penguin
var _states_seen: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node = load(LEVEL).instantiate()
	root.add_child(level)
	_penguin = level.get_node("Penguin") as Penguin
	_penguin.state_changed.connect(func(s: Penguin.State) -> void: _states_seen.append(Penguin.State.keys()[s]))

	await _test_lands_on_ice()
	await _test_slide_off_edge_into_water()
	await _test_boost_and_porpoise()
	await _test_launch_onto_iceberg()
	await _test_ramp_climb_out()
	await _test_eat_fish_and_fatness()
	await _test_energy_drain_and_overfill()
	await _test_air_runs_out_and_forces_surface()

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
	_tap(&"action")
	await _frames(2)
	_check(_penguin.state == Penguin.State.SLIDE, "action on ice starts a belly-slide (state=%s)" % _state())
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
		var stopped := await _wait_for_state(Penguin.State.WALK, 900)
		_check(stopped, "belly-slide slows to a stop and stands up")


func _test_ramp_climb_out() -> void:
	# Swim at the surface toward the low ramp on the +X side of the berg.
	_place_swimming(Vector3(45.0, -Penguin.SURFACE_DEPTH, 0.0), PI / 2.0, 0.0)
	var out := await _wait_for_state(Penguin.State.WALK, 600)
	_check(out, "swimming into the ramp climbs out onto the ice (state=%s, pos=%s)" % [_state(), _penguin.global_position])


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


# --- Helpers ----------------------------------------------------------------

func _place_swimming(pos: Vector3, yaw: float, pitch_deg: float) -> void:
	_penguin.global_position = pos
	_penguin.velocity = Vector3.ZERO
	_penguin.set(&"_yaw", yaw)
	_penguin.set(&"_pitch", deg_to_rad(pitch_deg))
	_penguin.set(&"_speed", _penguin.tuning.swim_cruise_speed)
	_penguin.call(&"_set_state", Penguin.State.SWIM)
	_penguin.reset_physics_interpolation()


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
