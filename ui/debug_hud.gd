extends CanvasLayer
## Prototype HUD. Body size is the real energy display (no energy bar, per the design),
## so the numbers here are for testers only (F1 toggles them).
## The air bar is a real game element: it shows only while underwater and short of breath.

@onready var _debug_label: Label = $DebugLabel
@onready var _hint_label: Label = $HintLabel
@onready var _air_bar: ProgressBar = $AirBar

var _penguin: Penguin


func _ready() -> void:
	_penguin = get_tree().get_first_node_in_group(&"player") as Penguin
	var touch := DisplayServer.is_touchscreen_available()
	_hint_label.text = "Left thumb: steer (pull back mid-slide to brake)   Right thumb: boost / belly-slide (tap again to push)" if touch else \
		"WASD / arrows: steer   Space: boost (water) / belly-slide, tap again to push (ice)   S: brake a slide   R: reset\n" + \
		"Slide into the blue dummies to bump them; walk into steps to hop.   Q / E: energy -/+   F2: infinite energy   F1: debug\n" + \
		"Seals: an orange ring means one has locked on; when it flashes, turn off the line or boost. A dark shape under the edge is one lying in wait: go in elsewhere.\n" + \
		"Orcas: fins or shadows gathering and orange ice mean get off it (or dig in). In the water, race their fins home, and boost out of a ring of bubbles."


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"debug_toggle_hud"):
		_debug_label.visible = not _debug_label.visible
		_hint_label.visible = _debug_label.visible
	if _penguin == null:
		return

	var t := _penguin.tuning
	_air_bar.max_value = t.air_seconds
	_air_bar.value = _penguin.air
	_air_bar.visible = _penguin.air < t.air_seconds - 0.05

	if _debug_label.visible:
		_debug_label.text = "state   %s%s\nspeed   %.1f m/s\nenergy  %.0f%s%s\nfat     %.0f%%   mass x%.2f   hop %.2f m\nair     %.1f s\nfps     %d" % [
			Penguin.State.keys()[_penguin.state],
			_status(),
			_penguin.get_speed(),
			_penguin.energy,
			"  (overfill)" if _penguin.energy > t.overfill_threshold else "",
			"  [infinite]" if _penguin.infinite_energy else "",
			_penguin.fatness() * 100.0,
			_penguin.mass(),
			_penguin.hop_height(),
			_penguin.air,
			Engine.get_frames_per_second(),
		] + _predator_line() + _pod_line()


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
