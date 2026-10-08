class_name SettingsPanel
extends Control
## The settings sheet, shared by the title screen and the pause menu. Each switch is a
## GameSettings value and saves as soon as it's flipped (Screen effects steps through its three
## strengths). Back (or Esc / B) closes it.

## Back was pressed: whoever opened it shows its own menu again.
signal closed

## What the Screen effects button says for each setting (GameSettings.ScreenEffects order).
const EFFECT_NAMES: Array[String] = ["Full", "Reduced", "Off"]

@onready var _invert: CheckButton = %InvertPitch
@onready var _left_handed: CheckButton = %LeftHanded
@onready var _hints: CheckButton = %ControlHints
@onready var _effects: Button = %ScreenEffects
@onready var _debug: CheckButton = %ShowDebug
@onready var _back: Button = %Back
@onready var _sheet: Control = $Center/Sheet
@onready var _scroll: ScrollContainer = $Center/Sheet/Rows/Scroll
@onready var _list: Control = $Center/Sheet/Rows/Scroll/List


func _ready() -> void:
	hide()
	_back.pressed.connect(close)
	_invert.toggled.connect(func(on: bool) -> void: GameSettings.current().invert_pitch = on)
	_left_handed.toggled.connect(func(on: bool) -> void: GameSettings.current().left_handed = on)
	_hints.toggled.connect(func(on: bool) -> void: GameSettings.current().control_hints = on)
	# One button that steps through Full, Reduced and Off.
	_effects.pressed.connect(func() -> void:
		var settings := GameSettings.current()
		settings.screen_effects = ((settings.screen_effects + 1) % EFFECT_NAMES.size()) as GameSettings.ScreenEffects)
	_debug.toggled.connect(func(on: bool) -> void: GameSettings.current().show_debug = on)
	GameSettings.current().changed.connect(_on_settings_changed)
	get_viewport().size_changed.connect(_fit)


func _exit_tree() -> void:
	if GameSettings.current().changed.is_connected(_on_settings_changed):
		GameSettings.current().changed.disconnect(_on_settings_changed)


func open() -> void:
	_sync()
	show()
	_fit()
	_invert.grab_focus()
	_scroll.set_deferred(&"scroll_vertical", 0)


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## The switches scroll when the screen is too short for them all (a phone held sideways); the
## title and Back always show.
func _fit() -> void:
	var list := _list.get_combined_minimum_size()
	var chrome := _sheet.get_combined_minimum_size().y - _scroll.custom_minimum_size.y
	var room := get_viewport_rect().size.y - chrome - 24.0
	_scroll.custom_minimum_size = Vector2(list.x, clampf(room, 120.0, list.y))


## Shows what the settings are now (another screen, or F1, may have changed one).
func _sync() -> void:
	var s := GameSettings.current()
	_invert.set_pressed_no_signal(s.invert_pitch)
	_left_handed.set_pressed_no_signal(s.left_handed)
	_hints.set_pressed_no_signal(s.control_hints)
	_effects.text = "Screen effects: %s" % EFFECT_NAMES[s.screen_effects]
	_debug.set_pressed_no_signal(s.show_debug)


func _on_settings_changed(_setting: StringName) -> void:
	_sync()
