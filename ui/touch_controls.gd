extends Control
## Mobile controls: a floating joystick on one half of the screen, and an action button
## (boost in water / belly-slide on ice) anywhere on the other half. Left-handed (GameSettings):
## the stick is on the right and the button on the left.
## Feeds the same input actions as keyboard and gamepad, so gameplay code never knows the difference.
## Touches on HUD buttons (Controls in the "touch_ui" group, like the pause button) are left to
## them. Pausing lets go of everything and hides the controls.

@export var stick_radius := 90.0
@export var dead_zone := 0.12
## Show even without a touchscreen (handy for testing with "Emulate Touch From Mouse").
@export var force_visible := false

var _stick_index := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _action_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = _available()


## Is the stick on the right (left-handed)?
func stick_on_right() -> bool:
	return GameSettings.current().left_handed


func _available() -> bool:
	return force_visible or DisplayServer.is_touchscreen_available()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED:
			_let_go()
			visible = false
		NOTIFICATION_UNPAUSED:
			visible = _available()
			queue_redraw() # the settings may have swapped sides


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var half := get_viewport_rect().size.x * 0.5
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _on_hud_button(touch.position):
				return
			var stick_side := (touch.position.x >= half) == stick_on_right()
			if stick_side and _stick_index == -1:
				_stick_index = touch.index
				_stick_origin = touch.position
				_stick_pos = touch.position
			elif not stick_side and _action_index == -1:
				_action_index = touch.index
				Input.action_press(&"action")
		else:
			if touch.index == _stick_index:
				_stick_index = -1
				_apply_stick(Vector2.ZERO)
			elif touch.index == _action_index:
				_action_index = -1
				Input.action_release(&"action")
		queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_index:
			_stick_pos = drag.position
			_apply_stick(((_stick_pos - _stick_origin) / stick_radius).limit_length(1.0))
			queue_redraw()


## Is `at` (a touch) on a HUD button?
func _on_hud_button(at: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group(&"touch_ui"):
		var control := node as Control
		if control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(at):
			return true
	return false


## Lets go of the stick and the button.
func _let_go() -> void:
	if _stick_index != -1:
		_stick_index = -1
		_apply_stick(Vector2.ZERO)
	if _action_index != -1:
		_action_index = -1
		Input.action_release(&"action")
	queue_redraw()


func _apply_stick(v: Vector2) -> void:
	if v.length() < dead_zone:
		v = Vector2.ZERO
	_press(&"move_right", maxf(v.x, 0.0))
	_press(&"move_left", maxf(-v.x, 0.0))
	_press(&"move_up", maxf(-v.y, 0.0)) # screen y grows downward
	_press(&"move_down", maxf(v.y, 0.0))


func _press(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _draw() -> void:
	var screen := get_viewport_rect().size
	# Action button hint, in the bottom corner of the button's half.
	var button_x := 140.0 if stick_on_right() else screen.x - 140.0
	var button_centre := Vector2(button_x, screen.y - 140.0)
	var pressed := _action_index != -1
	draw_circle(button_centre, 70.0, Color(1, 1, 1, 0.35 if pressed else 0.15))
	draw_arc(button_centre, 70.0, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
	# Joystick, only while held.
	if _stick_index != -1:
		draw_arc(_stick_origin, stick_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.4), 3.0)
		var knob := _stick_origin + (_stick_pos - _stick_origin).limit_length(stick_radius)
		draw_circle(knob, 34.0, Color(1, 1, 1, 0.45))
