class_name SettingsPanel
extends Control
## The settings sheet, shared by the title screen and the pause menu. Each switch is a
## GameSettings value and saves as soon as it's flipped. Back (or Esc / B) closes it.

## Back was pressed: whoever opened it shows its own menu again.
signal closed

@onready var _invert: CheckButton = %InvertPitch
@onready var _left_handed: CheckButton = %LeftHanded
@onready var _hints: CheckButton = %ControlHints
@onready var _debug: CheckButton = %ShowDebug
@onready var _back: Button = %Back


func _ready() -> void:
	hide()
	_back.pressed.connect(close)
	_invert.toggled.connect(func(on: bool) -> void: GameSettings.current().invert_pitch = on)
	_left_handed.toggled.connect(func(on: bool) -> void: GameSettings.current().left_handed = on)
	_hints.toggled.connect(func(on: bool) -> void: GameSettings.current().control_hints = on)
	_debug.toggled.connect(func(on: bool) -> void: GameSettings.current().show_debug = on)
	GameSettings.current().changed.connect(_on_settings_changed)


func _exit_tree() -> void:
	if GameSettings.current().changed.is_connected(_on_settings_changed):
		GameSettings.current().changed.disconnect(_on_settings_changed)


func open() -> void:
	_sync()
	show()
	_invert.grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Shows what the settings are now (another screen, or F1, may have changed one).
func _sync() -> void:
	var s := GameSettings.current()
	_invert.set_pressed_no_signal(s.invert_pitch)
	_left_handed.set_pressed_no_signal(s.left_handed)
	_hints.set_pressed_no_signal(s.control_hints)
	_debug.set_pressed_no_signal(s.show_debug)


func _on_settings_changed(_setting: StringName) -> void:
	_sync()
