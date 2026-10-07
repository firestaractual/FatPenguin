class_name PauseMenu
extends CanvasLayer
## The pause menu: Resume, Restart, Settings, Quit to title. Opens with the pause action (Esc, P,
## a gamepad's Start), the HUD's pause button, or by itself when the app goes to the background on
## a phone (GDD §8: instant pause and resume). While it's open the game is paused
## (SceneTree.paused); this layer keeps running.

signal opened
signal closed

const TITLE_SCENE := "res://ui/title/title_screen.tscn"

@onready var _root: Control = $Root
@onready var _sheet: Control = %Sheet
@onready var _resume: Button = %Resume
@onready var _settings: SettingsPanel = %SettingsPanel


func _ready() -> void:
	add_to_group(&"pause_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.hide()
	_resume.pressed.connect(close)
	(%Restart as Button).pressed.connect(_restart)
	(%Settings as Button).pressed.connect(_open_settings)
	(%Quit as Button).pressed.connect(_quit)
	_settings.closed.connect(_settings_closed)


## The pause menu in this scene, or null.
static func of(node: Node) -> PauseMenu:
	return node.get_tree().get_first_node_in_group(&"pause_menu") as PauseMenu if node.is_inside_tree() else null


func is_open() -> bool:
	return _root.visible


## Pauses the game and shows the menu.
func open() -> void:
	if is_open():
		return
	get_tree().paused = true
	_root.show()
	_sheet.show()
	_settings.hide()
	_resume.grab_focus()
	opened.emit()


## Hides the menu and carries on.
func close() -> void:
	if not is_open():
		return
	_root.hide()
	get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if not is_open():
			open()
		elif not _settings.visible:
			close()
	elif is_open() and not _settings.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _notification(what: int) -> void:
	# Pause the moment a phone sends the game to the background (a call, the home button).
	if what == NOTIFICATION_APPLICATION_PAUSED or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile")):
		if is_inside_tree():
			open()


func _open_settings() -> void:
	_sheet.hide()
	_settings.open()


func _settings_closed() -> void:
	_sheet.show()
	(%Settings as Button).grab_focus()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _quit() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
