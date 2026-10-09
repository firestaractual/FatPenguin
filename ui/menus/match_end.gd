class_name MatchEnd
extends CanvasLayer
## The end of a match (WaddleMatch, GDD §4.12): when one family is left (or yours is gone), a moment
## later the game pauses and this sheet says who won, how long it took, how many bergs broke up and
## how many eggs went down, with the leaderboards (LeaderboardTable: this match and all time), and
## Play again / Quit to title. The level adds one; it builds itself in code and finds the match by
## itself.

const TITLE_SCENE := "res://ui/title/title_screen.tscn"
## How long after the end it waits before pausing and showing (s): let the last moment play.
const DELAY := 1.5

var _match: WaddleMatch = null
var _root: Control
var _title: Label
var _caption: Label
var _table: LeaderboardTable
var _again: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()


func _process(_delta: float) -> void:
	if _match == null or not is_instance_valid(_match):
		_match = WaddleMatch.current(get_tree())
		if _match != null:
			_match.ended.connect(_on_ended)


## Is it showing?
func is_open() -> bool:
	return _root.visible


## What it says: the title and the line under it.
func headline() -> String:
	return "%s\n%s" % [_title.text, _caption.text]


## Shows it now (and pauses), for the match as it stands.
func open() -> void:
	_fill()
	_root.show()
	get_tree().paused = true
	_again.grab_focus()


## Hides it and lets the game run again (for tests; the buttons leave the scene).
func dismiss() -> void:
	_root.hide()
	get_tree().paused = false


func _on_ended(_winner: int) -> void:
	get_tree().create_timer(DELAY, true).timeout.connect(open)


func _fill() -> void:
	var game := _match
	if game == null:
		return
	var mine := game.player_family()
	var winner: WaddleMatch.Family = game.families[game.winner()] if game.winner() >= 0 else null
	if mine != null and winner == mine:
		_title.text = "Your family wins!"
	elif mine != null and mine.out:
		_title.text = "Your family is gone"
	elif winner != null:
		_title.text = "%s win!" % winner.name
	else:
		_title.text = "Nobody's left"
	var seconds := roundi(game.elapsed())
	var eggs := 0
	for row in game.ranking():
		eggs += int(row["eggs"])
	_caption.text = "%d:%02d  ·  %d %s broke up  ·  %d %s laid" % [seconds / 60, seconds % 60, game.breaks(),
		"berg" if game.breaks() == 1 else "bergs", eggs, "egg" if eggs == 1 else "eggs"]
	_table.show_match()


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.08, 0.16, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(centre)
	var sheet := PanelContainer.new()
	sheet.custom_minimum_size = Vector2(720.0, 0.0)
	centre.add_child(sheet)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 12)
	sheet.add_child(rows)
	_title = Label.new()
	_title.theme_type_variation = &"TitleLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_title)
	_caption = Label.new()
	_caption.theme_type_variation = &"CaptionLabel"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_caption)
	_table = LeaderboardTable.new()
	rows.add_child(_table)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 16)
	rows.add_child(buttons)
	_again = Button.new()
	_again.text = "Play again"
	_again.theme_type_variation = &"PrimaryButton"
	_again.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	buttons.add_child(_again)
	var quit := Button.new()
	quit.text = "Quit to title"
	quit.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file(TITLE_SCENE))
	buttons.add_child(quit)
