class_name PauseMenu
extends CanvasLayer
## The pause menu: Resume, Restart, Settings, Most prolific (the leaderboards: this match and all
## time, LeaderboardTable), Quit to title. Opens with the pause action (Esc, P, a gamepad's Start),
## the HUD's pause button, or by itself when the app goes to the background on a phone (GDD §8:
## instant pause and resume). While it's open the game is paused (SceneTree.paused); this layer keeps
## running.

signal opened
signal closed

const TITLE_SCENE := "res://ui/title/title_screen.tscn"

@onready var _root: Control = $Root
@onready var _sheet: Control = %Sheet
@onready var _resume: Button = %Resume
@onready var _settings: SettingsPanel = %SettingsPanel
var _board: Control
var _table: LeaderboardTable


func _ready() -> void:
	add_to_group(&"pause_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.hide()
	_resume.pressed.connect(close)
	(%Restart as Button).pressed.connect(_restart)
	(%Settings as Button).pressed.connect(_open_settings)
	(%Quit as Button).pressed.connect(_quit)
	(%Leaderboard as Button).pressed.connect(open_leaderboard)
	_settings.closed.connect(_settings_closed)
	_build_board()


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
	_board.hide()
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
	elif is_open() and _board.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_leaderboard()
	elif is_open() and not _settings.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _notification(what: int) -> void:
	# Pause the moment a phone sends the game to the background (a call, the home button).
	if what == NOTIFICATION_APPLICATION_PAUSED or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile")):
		if is_inside_tree():
			open()


## Shows the leaderboards (this match first).
func open_leaderboard() -> void:
	_sheet.hide()
	_board.show()
	_table.show_match()


func leaderboard_showing() -> bool:
	return _board.visible


func _close_leaderboard() -> void:
	_board.hide()
	_sheet.show()
	(%Leaderboard as Button).grab_focus()


## The leaderboards sheet: a title, the table and a Back button, in the middle of the screen.
func _build_board() -> void:
	_board = CenterContainer.new()
	_board.name = "Board"
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.hide()
	_root.add_child(_board)
	var sheet := PanelContainer.new()
	sheet.custom_minimum_size = Vector2(700.0, 0.0)
	_board.add_child(sheet)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 14)
	sheet.add_child(rows)
	var title := Label.new()
	title.text = "Most prolific"
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	_table = LeaderboardTable.new()
	rows.add_child(_table)
	var back := Button.new()
	back.text = "Back"
	back.theme_type_variation = &"PrimaryButton"
	back.pressed.connect(_close_leaderboard)
	rows.add_child(back)


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
