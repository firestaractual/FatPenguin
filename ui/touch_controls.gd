extends Control
## Mobile controls: a floating joystick on the left half of the screen, and an action button
## (boost in water / belly-slide on ice) anywhere on the right half.
## Feeds the same input actions as keyboard and gamepad, so gameplay code never knows the difference.

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
	visible = force_visible or DisplayServer.is_touchscreen_available()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var half := get_viewport_rect().size.x * 0.5
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if touch.position.x < half and _stick_index == -1:
				_stick_index = touch.index
				_stick_origin = touch.position
				_stick_pos = touch.position
			elif touch.position.x >= half and _action_index == -1:
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
	# Action button hint, bottom-right.
	var button_centre := Vector2(screen.x - 140.0, screen.y - 140.0)
	var pressed := _action_index != -1
	draw_circle(button_centre, 70.0, Color(1, 1, 1, 0.35 if pressed else 0.15))
	draw_arc(button_centre, 70.0, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
	# Joystick, only while held.
	if _stick_index != -1:
		draw_arc(_stick_origin, stick_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.4), 3.0)
		var knob := _stick_origin + (_stick_pos - _stick_origin).limit_length(stick_radius)
		draw_circle(knob, 34.0, Color(1, 1, 1, 0.45))
