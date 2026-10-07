extends "res://tests/smoke_suite.gd"
## The UI: the debug layer (hidden unless asked for), the HUD's air meter and control prompts, the
## pause menu and settings, invert pitch, the game waiting while paused, and the title screen's
## feeding gag.

const TITLE_SCENE := "res://ui/title/title_screen.tscn"

var _hud: GameHud
var _menu: PauseMenu
var _debug: DebugHud


func suite_name() -> String:
	return "ui"


func run() -> void:
	_hud = _level.get_node("GameHud") as GameHud
	_menu = _level.get_node("PauseMenu") as PauseMenu
	_debug = _level.get_node("DebugHud") as DebugHud
	await _test_debug_hidden_by_default()
	await _test_air_meter()
	await _test_control_prompts()
	await _test_pause_menu()
	await _test_invert_pitch()
	await _test_paused_fish_wait()
	await _test_title_screen()


func _test_debug_hidden_by_default() -> void:
	_check(_hud != null and _menu != null and _debug != null, "the level has a HUD, a pause menu and a debug layer")
	_check(not GameSettings.current().show_debug and not _debug.is_showing(), "the debug numbers are hidden by default")
	GameSettings.current().show_debug = true
	await _frames(2)
	_check(_debug.is_showing(), "turning on \"Show debug info\" shows them")
	await _tap(&"debug_toggle_hud")
	await _frames(2)
	_check(not _debug.is_showing() and not GameSettings.current().show_debug, "and F1 hides them again (the same setting)")


func _test_air_meter() -> void:
	var air := _hud.air_meter()
	_penguin.reset()
	await _frames(90)
	_check(not air.is_showing(), "on the ice, there's no air meter")
	_penguin.place(Vector3(0.0, -3.0, 45.0), PI, Penguin.State.SWIM, 0.0, _penguin.tuning.swim_cruise_speed)
	await _frames(60)
	_check(air.is_showing() and air.ratio < 1.0, "underwater, the air meter shows the breath running out (%.0f%% left)" % (air.ratio * 100.0))
	_penguin.place(Vector3(0.0, -Penguin.SURFACE_DEPTH, 45.0), PI, Penguin.State.SWIM, 0.0, _penguin.tuning.swim_cruise_speed)
	await _frames(int((_penguin.tuning.air_refill_seconds + 1.0) * 60.0))
	_check(not air.is_showing(), "back at the surface, it fills up and fades away")
	_penguin.reset()
	await _frames(30)


func _test_control_prompts() -> void:
	var prompts := _hud.prompts()
	var p := _penguin
	p.infinite_energy = true
	p.place(Vector3(0.0, -Penguin.SURFACE_DEPTH, -62.0), 0.0, Penguin.State.SWIM, 0.0, 0.0)
	var shown := false
	for i in 150:
		await tree.physics_frame
		p.set_swim_speed(0.0)
		if prompts.current == &"boost":
			shown = true
			break
	var chip := prompts.get_node("%KeyLabel") as Label
	_check(shown and chip.text == InputDevice.control_name(&"action"), "swimming, a prompt says which button boosts (%s %s)" % [chip.text, (prompts.get_node("%PromptText") as Label).text])
	# Boost enough times and it's learned: the prompt goes.
	for n in 3:
		for i in 90:
			await tree.physics_frame
			p.set_swim_speed(0.0)
		p.boost()
	_check(GameSettings.current().learned(&"boost") >= 3, "boosts are counted (%d)" % GameSettings.current().learned(&"boost"))
	var gone := false
	for i in 180:
		await tree.physics_frame
		p.set_swim_speed(0.0)
		if prompts.current != &"boost":
			gone = true
			break
	_check(gone, "once you've boosted a few times, the boost prompt stops")
	# A warning cuts in straight away.
	p.air = p.tuning.air_seconds * 0.2
	await _frames(3)
	_check(prompts.current == &"air", "low on air, a warning shows at once (%s)" % prompts.current)
	GameSettings.current().control_hints = false
	await _frames(3)
	_check(prompts.current == &"", "with Hints off, nothing shows")
	GameSettings.current().control_hints = true
	p.reset()
	await _frames(30)


func _test_pause_menu() -> void:
	_check(not _menu.is_open() and not tree.paused, "the pause menu starts closed")
	_send(&"pause")
	await _frames(3)
	_check(_menu.is_open() and tree.paused, "the pause action (Esc, P, Start) pauses the game and opens the menu")
	var at := _penguin.global_position
	_penguin.velocity = Vector3(5.0, 0.0, 0.0)
	await _frames(30)
	_check(_penguin.global_position.distance_to(at) < 0.001, "paused, the penguin doesn't move")
	_send(&"pause")
	await _frames(3)
	_check(not _menu.is_open() and not tree.paused, "pressing it again carries on")
	# The HUD's pause button, then Settings and back, then Resume.
	(_hud.get_node("%PauseButton") as Button).pressed.emit()
	await _frames(2)
	_check(_menu.is_open() and tree.paused, "the HUD's pause button pauses too")
	(_menu.get_node("%Settings") as Button).pressed.emit()
	await _frames(2)
	var settings := _menu.get_node("%SettingsPanel") as SettingsPanel
	_check(settings.visible and not (_menu.get_node("%Sheet") as Control).visible, "Settings opens the settings sheet in its place")
	_send(&"ui_cancel")
	await _frames(3)
	_check(not settings.visible and _menu.is_open(), "Back (Esc) returns to the pause menu, still paused")
	(_menu.get_node("%Resume") as Button).pressed.emit()
	await _frames(2)
	_check(not _menu.is_open() and not tree.paused, "Resume carries on")
	# Left-handed swaps the touch controls' sides.
	var touch := _level.get_node("TouchControls/Pad")
	GameSettings.current().left_handed = true
	_check(touch.call(&"stick_on_right"), "left-handed, the touch stick moves to the right")
	GameSettings.current().left_handed = false


func _test_invert_pitch() -> void:
	var climbs := []
	for inverted in [false, true]:
		GameSettings.current().invert_pitch = inverted
		_penguin.place(Vector3(0.0, -4.0, 45.0), PI, Penguin.State.SWIM, 0.0, _penguin.tuning.swim_cruise_speed)
		Input.action_press(&"move_up")
		await _frames(20)
		Input.action_release(&"move_up")
		climbs.append(_penguin.get_heading().y)
	GameSettings.current().invert_pitch = false
	_check(climbs[0] > 0.2 and climbs[1] < -0.2, "swimming, stick up climbs; with invert pitch on it dives (%.2f, %.2f)" % [climbs[0], climbs[1]])
	_penguin.reset()
	await _frames(30)


func _test_paused_fish_wait() -> void:
	var fish := _spawn_fish(null, Vector3(0.0, -2.0, -62.0))
	fish.respawn_seconds = 0.3
	await _frames(2)
	fish.get_eaten()
	tree.paused = true
	await _frames(40)
	var waited := not fish.visible
	tree.paused = false
	await _frames(40)
	_check(waited and fish.visible, "an eaten fish's respawn waits while the game is paused")
	fish.queue_free()


func _test_title_screen() -> void:
	var title := (load(TITLE_SCENE) as PackedScene).instantiate() as TitleScreen
	title.start_game = false
	root.add_child(title)
	var events := {"broke": false, "finished": false}
	title.broke_through.connect(func() -> void: events["broke"] = true)
	title.finished.connect(func() -> void: events["finished"] = true)
	await _frames(10)
	# Settings opens over it, and a tap meant for the menu doesn't feed him.
	(title.get_node("%SettingsButton") as Button).pressed.emit()
	await _frames(2)
	_send(&"action")
	await _frames(40)
	var settings := title.get_node("%SettingsPanel") as SettingsPanel
	_check(settings.visible and title.feeds == 0, "the title's Settings opens over it, and doesn't count as feeding")
	settings.close()
	await _frames(2)
	var widths: Array[float] = [title.penguin_width()]
	var cracks: Array[int] = [title.crack_segments_showing()]
	for i in title.feeds_to_break - 1:
		_send(&"action")
		await _frames(50)
		widths.append(title.penguin_width())
		cracks.append(title.crack_segments_showing())
	var growing := true
	for i in range(1, widths.size()):
		growing = growing and widths[i] > widths[i - 1]
	_check(title.feeds == title.feeds_to_break - 1 and growing, "each fish he gulps down makes him fatter (width %s)" % str(widths.map(func(w: float) -> String: return "%.2f" % w)))
	_check(cracks[title.cracks_from - 1] == 0 and cracks[title.cracks_from] > 0 and cracks.back() > cracks[title.cracks_from],
		"the ice holds at first, then cracks, more with every fish (%s)" % str(cracks))
	_send(&"action")
	for i in 240:
		await tree.physics_frame
		if events["finished"]:
			break
	_check(events["broke"] and title.penguin_position().y < -0.5, "on the last fish he drops through the ice with a splash")
	_check(events["finished"], "and it whites out to start the game")
	title.queue_free()
	await _frames(2)


## Sends a press of `action` through input, as a key or button would.
func _send(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
