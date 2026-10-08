class_name DebugHud
extends CanvasLayer
## Numbers for testers: the penguin's state, speed, energy, fat and air, the nearest predator,
## any pod attack under way and the nearest humpback, plus the tester notes. Hidden unless "Show
## debug info" is on in the settings (GameSettings.show_debug); F1 flips that setting. The real HUD is GameHud.
## Also the tester keys for the player's penguin, which work whether it shows or not: Q / E energy
## -/+ 10, F2 infinite energy, R reset.

@onready var _debug_label: Label = $DebugLabel
@onready var _hint_label: Label = $HintLabel

var _penguin: Penguin


func _ready() -> void:
	_penguin = get_tree().get_first_node_in_group(&"player") as Penguin
	_apply_setting(&"show_debug")
	GameSettings.current().changed.connect(_apply_setting)
	var touch := DisplayServer.is_touchscreen_available()
	_hint_label.text = "Left thumb: steer (pull back mid-slide to brake)   Right thumb: boost / belly-slide (tap again to push)" if touch else \
		"WASD / arrows: steer   Space: boost (water) / belly-slide, tap again to push (ice)   S: brake a slide   R: reset\n" + \
		"Walk into steps, or at a gap between floes, to hop (thin, you hop farther). Slide into the blue dummies to bump them.   Q / E: energy -/+   F2: infinite   F1: debug\n" + \
		"Seals: an orange ring means one has locked on; when it flashes, turn off the line or boost. A dark shape under the edge is one lying in wait: go in elsewhere.\n" + \
		"Orcas: fins or shadows gathering and orange ice mean get off it (or dig in). In the water, race their fins home, and boost out of a ring of bubbles."


## Is the debug layer showing?
func is_showing() -> bool:
	return visible


func _exit_tree() -> void:
	if GameSettings.current().changed.is_connected(_apply_setting):
		GameSettings.current().changed.disconnect(_apply_setting)


func _apply_setting(setting: StringName) -> void:
	if setting == &"show_debug":
		visible = GameSettings.current().show_debug


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"debug_toggle_hud"):
		GameSettings.current().show_debug = not GameSettings.current().show_debug
	if _penguin == null:
		return
	_tester_keys()
	var t := _penguin.tuning

	if visible:
		_debug_label.text = "state   %s%s\nspeed   %.1f m/s\nenergy  %.0f%s%s\nfat     %.0f%%   mass x%.2f   hop %.2f m up, %.1f m across\nair     %.1f s\nfps     %d" % [
			Penguin.State.keys()[_penguin.state],
			_status(),
			_penguin.get_speed(),
			_penguin.energy,
			"  (overfill)" if _penguin.energy > t.overfill_threshold else "",
			"  [infinite]" if _penguin.infinite_energy else "",
			_penguin.fatness() * 100.0,
			_penguin.mass(),
			_penguin.hop_height(),
			_penguin.hop_distance(),
			_penguin.air,
			Engine.get_frames_per_second(),
		] + _predator_line() + _pod_line() + _humpback_line()


## The nearest predator: what it is, what it's doing and how hungry it is.
func _predator_line() -> String:
	var nearest: Predator = null
	var best := INF
	for node in get_tree().get_nodes_in_group(&"predators"):
		var predator := node as Predator
		var dist := predator.global_position.distance_to(_penguin.global_position)
		if dist < best:
			best = dist
			nearest = predator
	if nearest == null:
		return ""
	return "\n%s  %s  %.0f m  hunger %.0f%s%s" % [
		nearest.tuning.display_name.to_lower(),
		Predator.State.keys()[nearest.state],
		best,
		nearest.hunger,
		"  (starving)" if nearest.is_starving() else "",
		"  [hunting you]" if nearest.is_hunting(_penguin) else "",
	]


## The nearest humpback: what it's doing, and when it next breathes and feeds.
func _humpback_line() -> String:
	var nearest: Humpback = null
	var best := INF
	for node in get_tree().get_nodes_in_group(&"humpbacks"):
		var whale := node as Humpback
		var dist := whale.global_position.distance_to(_penguin.global_position)
		if dist < best:
			best = dist
			nearest = whale
	if nearest == null:
		return ""
	return "\nhumpback  %s  %.0f m  breathes in %.0f s  feeds in %.0f s%s%s" % [
		Humpback.State.keys()[nearest.state],
		best,
		nearest.next_breath_in(),
		nearest.next_feed_in(),
		"  [guarding you]" if nearest.protege() == _penguin else "",
		"  [sheltered]" if Humpback.shelters(_penguin.global_position) else "",
	]


## Any pod with an attack under way.
func _pod_line() -> String:
	for node in get_tree().get_nodes_in_group(&"pods"):
		var pod := node as PredatorPod
		if pod != null and pod.attack != null:
			var eta := pod.seconds_to_strike()
			return "\n%s  %s %s%s%s" % [pod.tuning.display_name.to_lower(), pod.attack.settings.display_name.to_lower(),
				PredatorPod.Phase.keys()[pod.phase], ("  hits in %.1f s" % eta) if eta >= 0.0 else "",
				("  (trap step %d)" % pod.trap_step) if pod.trap_step > 1 else ""]
	return ""


func _status() -> String:
	var bits: Array[String] = []
	if _penguin.is_teetering():
		bits.append("TEETER")
	if _penguin.is_skidding():
		bits.append("skid")
	if _penguin.is_tumbling():
		bits.append("tumble")
	if _penguin.is_braking():
		bits.append("braking")
	if _penguin.is_spun_out():
		bits.append("spun out")
	if _penguin.is_immune():
		bits.append("immune")
	return "  (" + ", ".join(bits) + ")" if not bits.is_empty() else ""


func _tester_keys() -> void:
	var t := _penguin.tuning
	if Input.is_action_just_pressed(&"debug_energy_up"):
		_penguin.energy = minf(_penguin.energy + 10.0, t.max_energy)
	if Input.is_action_just_pressed(&"debug_energy_down"):
		_penguin.energy = maxf(_penguin.energy - 10.0, 0.0)
	if Input.is_action_just_pressed(&"debug_toggle_drain"):
		_penguin.infinite_energy = not _penguin.infinite_energy
	if Input.is_action_just_pressed(&"reset"):
		_penguin.reset()
