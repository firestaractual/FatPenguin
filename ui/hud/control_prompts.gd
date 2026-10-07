class_name ControlPrompts
extends PanelContainer
## Short prompts at the bottom of the screen, at the moment they're useful: "TAP belly-slide" the
## first times you stand on the ice, "SPACE boost" in the water, "PULL BACK scramble back!" at the
## edge. Each tutorial prompt stops once you've done the thing a few times (GameSettings keeps
## count, so it doesn't come back next session); warnings (out of breath, teetering, a seal locked
## on) are always shown, above tutorials. The key named matches the device the player last used
## (InputDevice). The "Hints" setting hides them all.
##
## The PromptPanel holds a KeyChip (the control) and the words.

## How long a prompt has to be wanted before it shows, and how long it stays at least, so they
## don't flicker (s).
const SETTLE := 0.35
const MIN_SHOW := 1.6
## How often it checks how far the ice is, for the leap prompt (s).
const SHORE_CHECK := 0.5

## Each prompt: the control it names (&"action", &"back" or none), its words, whether it's a
## warning, and how many times the player has to do the thing before it stops (0 = never stops).
const PROMPTS := {
	&"teeter": {"key": &"back", "text": "scramble back!", "warning": true, "learn": 0},
	&"air": {"key": &"", "text": "Low on air: swim up!", "warning": true, "learn": 0},
	&"seal": {"key": &"", "text": "Locked on! Turn off its line, or boost", "warning": true, "learn": 3},
	&"leap": {"key": &"action", "text": "aim up and boost to leap onto the ice", "warning": false, "learn": 2},
	&"boost": {"key": &"action", "text": "boost", "warning": false, "learn": 3},
	&"brake": {"key": &"back", "text": "dig in to brake", "warning": false, "learn": 2},
	&"slide": {"key": &"action", "text": "belly-slide", "warning": false, "learn": 2},
}

var penguin: Penguin = null:
	set(value):
		if penguin != null and is_instance_valid(penguin):
			penguin.state_changed.disconnect(_on_state_changed)
			penguin.boosted.disconnect(_on_boosted)
		penguin = value
		if penguin != null:
			penguin.state_changed.connect(_on_state_changed)
			penguin.boosted.connect(_on_boosted)

## The prompt on screen (its id), or &"".
var current: StringName = &""

var _candidate: StringName = &""
var _candidate_time := 0.0
var _shown_time := 0.0
var _state_time := 0.0
var _shore_check := 0.0
var _near_shore := false
var _braked_this_slide := false
## Left the water through the air (a breach or a launch), not yet landed.
var _breached := false
var _last_state: Penguin.State = Penguin.State.AIR
var _seal_counted := false

@onready var _chip: PanelContainer = %KeyChip
@onready var _chip_label: Label = %KeyLabel
@onready var _text: Label = %PromptText


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	modulate.a = 0.0


func _input(event: InputEvent) -> void:
	InputDevice.note(event)


func _process(delta: float) -> void:
	var want := _pick(delta) if _hints_on() else &""
	if want == _candidate:
		_candidate_time += delta
	else:
		_candidate = want
		_candidate_time = 0.0
	_shown_time += delta
	var warning: bool = PROMPTS.get(want, {}).get("warning", false)
	if want != current:
		# A warning cuts in straight away; otherwise the new one has to settle, and the old one
		# gets its moment on screen.
		var settled := _candidate_time >= SETTLE or warning or not _hints_on()
		var can_replace := current == &"" or _shown_time >= MIN_SHOW or warning or not _hints_on()
		if settled and can_replace:
			_show(want)
	modulate.a = move_toward(modulate.a, 1.0 if current != &"" else 0.0, 5.0 * delta)


func _show(id: StringName) -> void:
	current = id
	_shown_time = 0.0
	if id == &"":
		return
	var p: Dictionary = PROMPTS[id]
	var key: StringName = p["key"]
	_chip.visible = key != &""
	_chip_label.text = InputDevice.control_name(key)
	_text.text = p["text"]
	if id == &"seal" and not _seal_counted:
		_seal_counted = true
		GameSettings.current().note_learned(&"seal")


## The prompt wanted right now: warnings first, then tutorials not learned yet.
func _pick(delta: float) -> StringName:
	if penguin == null or not is_instance_valid(penguin) or penguin.tuning == null:
		return &""
	var p := penguin
	_state_time += delta
	if p.state == Penguin.State.SLIDE and p.is_braking():
		if not _braked_this_slide:
			_braked_this_slide = true
			GameSettings.current().note_learned(&"brake")
	var hunted := _hunted()
	if not hunted:
		_seal_counted = false
	_shore_check -= delta
	if _shore_check <= 0.0 and p.state == Penguin.State.SWIM:
		_shore_check = SHORE_CHECK
		_near_shore = IceEdges.shore_distance(p.get_world_3d(), p.global_position, 9.0) < 9.0
	for id: StringName in PROMPTS:
		if _wanted(id, p, hunted):
			return id
	return &""


func _wanted(id: StringName, p: Penguin, hunted: bool) -> bool:
	var learn: int = PROMPTS[id]["learn"]
	if learn > 0 and id != &"seal" and GameSettings.current().learned(id) >= learn:
		return false
	match id:
		&"teeter":
			return p.is_teetering()
		&"air":
			return p.state == Penguin.State.SWIM and p.air < p.tuning.air_seconds * 0.35
		&"seal":
			return hunted and (_seal_counted or GameSettings.current().learned(&"seal") < learn)
		&"leap":
			return p.state == Penguin.State.SWIM and _near_shore and GameSettings.current().learned(&"boost") > 0 \
					and GameWorld.WATER_LEVEL - p.global_position.y < 1.5
		&"boost":
			return p.state == Penguin.State.SWIM and _state_time > 1.2
		&"brake":
			return p.state == Penguin.State.SLIDE and not p.is_tumbling() and p.get_speed() > 4.0 and _state_time > 0.5
		&"slide":
			return p.state == Penguin.State.WALK and _state_time > 2.0 and not p.is_skidding() and not p.is_teetering()
	return false


## Is a predator after the penguin right now (locked on, or lining up its lunge)?
func _hunted() -> bool:
	for node in get_tree().get_nodes_in_group(&"predators"):
		var predator := node as Predator
		if predator != null and predator.target == penguin and predator.state in [Predator.State.CHASE, Predator.State.WARN]:
			return true
	return false


func _hints_on() -> bool:
	return GameSettings.current().control_hints


func _on_state_changed(state: Penguin.State) -> void:
	_state_time = 0.0
	match state:
		Penguin.State.SWIM:
			_breached = false
		Penguin.State.AIR:
			_breached = _breached or _last_state == Penguin.State.SWIM
		Penguin.State.WALK, Penguin.State.SLIDE:
			if _breached:
				# Out of the water and onto the ice in one leap.
				_breached = false
				GameSettings.current().note_learned(&"leap")
			if state == Penguin.State.SLIDE:
				_braked_this_slide = false
				if _last_state == Penguin.State.WALK:
					GameSettings.current().note_learned(&"slide")
	_last_state = state


func _on_boosted() -> void:
	GameSettings.current().note_learned(&"boost")
