extends "res://tests/smoke_suite.gd"
## A penguin's parts, and who decides what a catch does: each player reads only its own controls
## (PlayerInput), a dummy reads none, energy is paid through PenguinVitals, the look (PenguinLook)
## follows the body, and the level's GameMode decides what happens to a caught penguin.


## A level's rules that keep a caught penguin where it is and note it, instead of respawning it.
class NoteCatches extends GameMode:
	var caught: Array[Penguin] = []

	func penguin_caught(penguin: Penguin, _by: Node3D) -> void:
		caught.append(penguin)


func suite_name() -> String:
	return "players"


func run() -> void:
	await _test_each_player_reads_own_controls()
	await _test_vitals_pay_for_moves()
	await _test_look_follows_body()
	await _test_game_mode_decides_catches()


func _test_each_player_reads_own_controls() -> void:
	var open_water := Vector3(0.0, -0.3, -62.0)
	var second := _spawn_player(2, open_water + Vector3(-6.0, 0.0, 0.0))
	var dummy := _spawn_player(0, open_water + Vector3(6.0, 0.0, 0.0))
	await _frames(2)
	_check(second.input is PlayerInput and (second.input as PlayerInput).player == 2, "a player 2 penguin reads player 2's controls")
	_check(not (dummy.input is PlayerInput) and not (dummy.input is BrainInput), "a dummy reads nobody's")

	# Player 1's stick (the shared actions: keyboard, any pad, touch) turns neither of them.
	var second_yaw := second.facing_yaw()
	var dummy_yaw := dummy.facing_yaw()
	Input.action_press(&"move_left")
	await _frames(30)
	Input.action_release(&"move_left")
	_check(absf(second.facing_yaw() - second_yaw) < 0.01, "player 1's stick doesn't steer player 2's penguin")
	_check(absf(dummy.facing_yaw() - dummy_yaw) < 0.01, "or a dummy")

	# Player 2's own copy of the stick does.
	var move_left := (second.input as PlayerInput).action_name(&"move_left")
	_check(move_left == &"p2_move_left" and InputMap.has_action(move_left), "player 2 has its own copy of the controls (%s)" % move_left)
	Input.action_press(move_left)
	await _frames(30)
	Input.action_release(move_left)
	var turned := absf(wrapf(second.facing_yaw() - second_yaw, -PI, PI))
	_check(turned > 0.5, "player 2's stick steers player 2's penguin (turned %.0f°)" % rad_to_deg(turned))
	var pads := InputMap.action_get_events(move_left).filter(func(e: InputEvent) -> bool: return e.device != 1)
	_check(pads.is_empty() and not InputMap.action_get_events(move_left).is_empty(), "and its controls are bound to the second gamepad only")
	second.queue_free()
	dummy.queue_free()
	await _frames(2)


func _test_vitals_pay_for_moves() -> void:
	var p := _spawn_player(0, Vector3(0.0, -0.3, -62.0))
	await _frames(2)
	p.infinite_energy = false
	p.energy = p.tuning.boost_energy_cost - 1.0
	var before := p.energy
	_check(not p.boost() and is_equal_approx(p.energy, before), "short of energy, a boost is refused and costs nothing")
	p.energy = 60.0
	await _frames(int((p.tuning.boost_duration + p.tuning.boost_cooldown) * 60.0) + 5)
	before = p.energy
	_check(p.boost() and absf(before - p.energy - p.tuning.boost_energy_cost) < 0.1, "with enough, it boosts and pays boost_energy_cost (%.1f)" % (before - p.energy))
	_check(is_equal_approx(p.vitals.energy, p.energy) and p.vitals.fatness() == p.fatness(), "the penguin's energy is its vitals' energy")
	p.queue_free()
	await _frames(2)


func _test_look_follows_body() -> void:
	var tint := Color(0.8, 0.2, 0.2, 1.0)
	var p := load(PENGUIN_SCENE).instantiate() as Penguin
	p.player_controlled = false
	p.body_tint = tint
	p.position = Vector3(0.0, 2.5, -62.0)
	_level.add_child(p)
	var body := p.get_node("Model/Body") as MeshInstance3D
	var mat := body.material_override as StandardMaterial3D
	_check(p.get_node("Model") is PenguinLook and mat != null and mat.albedo_color == tint, "the look tints the body with body_tint")
	# Dropped into the water from 2.5 m up: the splash plays where it went in.
	var splashes := []
	p.splashed.connect(func(at: Vector3, _s: float) -> void: splashes.append(at))
	await _wait_for(p, Penguin.State.SWIM, 120)
	await _frames(1)
	var splash := p.get_node("Splash") as Node3D
	_check(not splashes.is_empty() and splash.global_position.distance_to(splashes[0]) < 0.01 and absf(splash.global_position.y - GameWorld.WATER_LEVEL) < 0.01,
		"hitting the water splashes, and the look plays it on the water where it went in")
	p.queue_free()
	await _frames(2)


func _test_game_mode_decides_catches() -> void:
	var at := Vector3(10.0, -0.3, -62.0)
	var p := _spawn_player(0, at)
	await _frames(2)
	var rules := NoteCatches.new()
	_level.add_child(rules)
	var by := Node3D.new()
	_level.add_child(by)
	var got := [false]
	p.caught.connect(func(_b: Node3D) -> void: got[0] = true)
	var spot := p.global_position
	p.get_caught(by)
	_check(got[0] and rules.caught.has(p), "a catch is handed to the level's GameMode")
	_check((p.get_node("Puff") as Node3D).global_position.distance_to(spot) < 0.01, "and feathers fly where it was caught")
	_check(p.global_position.distance_to(spot) < 0.01, "which decides what happens (these rules leave it where it was)")
	rules.queue_free()
	await _frames(2)
	p.place(at + Vector3(8.0, 0.0, 0.0), 0.0, Penguin.State.SWIM)
	p.get_caught(by)
	_check(p.global_position.distance_to(p.spawn_point()) < 0.5, "with no GameMode, the movement toy's rule: it's eaten and respawns")
	by.queue_free()
	p.queue_free()
	await _frames(2)


## A penguin swimming at `at`, steered by player `number` (0 for a dummy), with infinite energy.
func _spawn_player(number: int, at: Vector3) -> Penguin:
	var p := load(PENGUIN_SCENE).instantiate() as Penguin
	p.player_controlled = number > 0
	p.player_number = maxi(number, 1)
	p.infinite_energy = true
	p.start_energy = 50.0
	p.position = at
	_level.add_child(p)
	p.place(at, 0.0, Penguin.State.SWIM)
	return p
