class_name PlayerInput
extends PenguinInput
## One player's controls (gameplay reads only the input actions; see CLAUDE.md, Input).
##
## Player 1 reads the shared actions (move_left, move_right, move_up, move_down, action):
## keyboard, any gamepad, and the touch controls, which press those same actions. Players 2 to 4
## read their own copies (p2_move_left, ..., p2_action), bound to one gamepad each, so in local
## coop nobody steers anyone else's penguin. A player's copies are made the first time it reads
## them (player N gets gamepad N - 1); setup_local_coop() makes them all at once and also gives
## player 1 its own copies, so player 1 stops reading the other players' pads.
##
## On the ice the stick is relative to the player's camera: Penguin.camera (set by its
## FollowCamera, so split screen works), or the viewport's camera if it has none. Swimming, the
## stick's up/down is flipped if the player chose invert pitch (GameSettings).

const BASE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"action"]

## Which player this is, 1 to 4.
var player := 1

var _left := &"move_left"
var _right := &"move_right"
var _up := &"move_up"
var _down := &"move_down"
var _action := &"action"


func _init(player_number := 1) -> void:
	player = player_number
	_pick_actions()


func read(penguin: Penguin) -> void:
	move = Input.get_vector(_left, _right, _down, _up)
	action = Input.is_action_just_pressed(_action)
	if penguin.state == Penguin.State.SWIM and GameSettings.current().invert_pitch:
		move.y = -move.y


func ground_dir(penguin: Penguin, stick: Vector2) -> Vector3:
	if stick.length() < 0.05:
		return Vector3.ZERO
	var cam := penguin.camera if is_instance_valid(penguin.camera) else penguin.get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var forward := -cam.global_basis.z
	forward.y = 0.0
	var right := cam.global_basis.x
	right.y = 0.0
	return (right.normalized() * stick.x + forward.normalized() * stick.y).limit_length(1.0)


## The name of this player's copy of a shared action (`base`, such as &"action").
func action_name(base: StringName) -> StringName:
	return _named(player, base) if InputMap.has_action(_named(player, base)) else base


## Local coop for `players` players: each gets its own copies of the controls. Player 1 keeps the
## keyboard and takes the first gamepad; player N takes gamepad N - 1. Call it before the players'
## penguins are made (their PlayerInputs pick their actions when they're created).
static func setup_local_coop(players: int) -> void:
	for n in range(1, players + 1):
		make_actions(n, n - 1, n == 1)


## Makes player `number`'s copies of the controls, bound to gamepad `device` (0 is the first),
## plus the keyboard keys if `keyboard`. Replaces any copies it had.
static func make_actions(number: int, device: int, keyboard := false) -> void:
	for base in BASE_ACTIONS:
		var copy_name := _named(number, base)
		if InputMap.has_action(copy_name):
			InputMap.erase_action(copy_name)
		InputMap.add_action(copy_name, InputMap.action_get_deadzone(base))
		for event in InputMap.action_get_events(base):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				var bound := event.duplicate() as InputEvent
				bound.device = device
				InputMap.action_add_event(copy_name, bound)
			elif keyboard and event is InputEventKey:
				InputMap.action_add_event(copy_name, event.duplicate() as InputEvent)


static func _named(number: int, base: StringName) -> StringName:
	return StringName("p%d_%s" % [number, base])


func _pick_actions() -> void:
	if player > 1 and not InputMap.has_action(_named(player, &"action")):
		make_actions(player, player - 1)
	_left = action_name(&"move_left")
	_right = action_name(&"move_right")
	_up = action_name(&"move_up")
	_down = action_name(&"move_down")
	_action = action_name(&"action")
