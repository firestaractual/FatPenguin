class_name InputDevice
extends RefCounted
## What the player is holding: a touch screen, a keyboard or a gamepad. It's whichever they used
## last, so prompts name the right button ("tap", "Space", "A"). UI that shows prompts passes its
## input events to note().

enum Kind { TOUCH, KEYBOARD, GAMEPAD }

static var kind: Kind = Kind.TOUCH if DisplayServer.is_touchscreen_available() else Kind.KEYBOARD


## Updates `kind` from an input event (a stick barely moving doesn't count).
static func note(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		kind = Kind.TOUCH
	elif event is InputEventKey or (event is InputEventMouseButton and not DisplayServer.is_touchscreen_available()):
		kind = Kind.KEYBOARD
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		kind = Kind.GAMEPAD


## What to call the control for `what` on the current device: &"action" (boost / belly-slide /
## feed) or &"back" (pull back: brake, dig in, scramble).
static func control_name(what: StringName) -> String:
	match what:
		&"action":
			return ["TAP", "SPACE", "A"][kind]
		&"back":
			return ["PULL BACK", "S", "PULL BACK"][kind]
	return ""
