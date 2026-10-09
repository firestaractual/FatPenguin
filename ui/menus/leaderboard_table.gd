class_name LeaderboardTable
extends VBoxContainer
## The most prolific penguins (GDD §4.12), as a table: this match's (WaddleMatch.ranking()) or the
## all-time top ten (Leaderboard), switched with the two tabs at the top. Each row: rank, the
## family's colour, the penguin's name ("you" for one the player played), eggs laid, cuckoo eggs
## (laid in a rival's waddle) and chicks raised to grown-ups; this match's eaten penguins are
## dimmed. Used by the pause menu and the end screen; it builds itself in code and is styled by the
## theme (RowLabel, CaptionLabel).

## A family's colour: a dot.
class Dot extends Control:
	var colour := Color.WHITE

	func _init(with: Color) -> void:
		colour = with
		custom_minimum_size = Vector2(18.0, 18.0)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		draw_circle(size * 0.5, 7.0, colour, true, -1.0, true)
		draw_arc(size * 0.5, 7.0, 0.0, TAU, 16, Color(0.086, 0.161, 0.29), 2.0, true)

## How many rows of this match it shows.
@export var match_rows := 8

var _match_tab: Button
var _all_tab: Button
var _grid: GridContainer
var _empty: Label
var _showing_match := true


func _ready() -> void:
	add_theme_constant_override(&"separation", 10)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 12)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(tabs)
	_match_tab = _tab(tabs, "This match")
	_all_tab = _tab(tabs, "All time")
	_match_tab.pressed.connect(show_match)
	_all_tab.pressed.connect(show_all_time)
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override(&"h_separation", 16)
	_grid.add_theme_constant_override(&"v_separation", 4)
	add_child(_grid)
	_empty = Label.new()
	_empty.theme_type_variation = &"CaptionLabel"
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_empty)
	show_match()


## Shows this match's ranking.
func show_match() -> void:
	_showing_match = true
	_match_tab.button_pressed = true
	_all_tab.button_pressed = false
	var game := WaddleMatch.current(get_tree()) if is_inside_tree() else null
	var rows: Array = game.ranking() if game != null else []
	_fill(rows.slice(0, match_rows), "Nobody's laid an egg yet.")


## Shows the all-time top ten.
func show_all_time() -> void:
	_showing_match = false
	_match_tab.button_pressed = false
	_all_tab.button_pressed = true
	_fill(Leaderboard.current().entries, "No eggs on record yet: finish a match to get on the board.")


## Shows whichever it was showing, up to date.
func refresh() -> void:
	if _showing_match:
		show_match()
	else:
		show_all_time()


## How many penguins it's listing.
func row_count() -> int:
	return maxi(_grid.get_child_count() / _grid.columns - 1, 0)


func _fill(rows: Array, nobody: String) -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var shown := rows.filter(func(r: Dictionary) -> bool: return int(r.get("eggs", 0)) > 0)
	_empty.text = nobody if shown.is_empty() else ""
	_empty.visible = shown.is_empty()
	_grid.visible = not shown.is_empty()
	if shown.is_empty():
		return
	for heading in ["", "", "Penguin", "Eggs", "Cuckoos", "Raised"]:
		_cell(heading, &"CaptionLabel", HORIZONTAL_ALIGNMENT_RIGHT if heading in ["Eggs", "Cuckoos", "Raised"] else HORIZONTAL_ALIGNMENT_LEFT)
	var rank := 0
	for row: Dictionary in shown:
		rank += 1
		var dim := Color(1.0, 1.0, 1.0, 0.5 if _showing_match and not row.get("alive", true) else 1.0)
		_cell("%d" % rank, &"RowLabel", HORIZONTAL_ALIGNMENT_RIGHT).modulate = dim
		var dot := Dot.new(Color.html(String(row.get("colour", "ffffff"))))
		dot.modulate = dim
		_grid.add_child(dot)
		var who := String(row.get("name", "?"))
		if row.get("player", false):
			who += " (you)"
		_cell(who, &"RowLabel", HORIZONTAL_ALIGNMENT_LEFT).modulate = dim
		_cell(str(row.get("eggs", 0)), &"RowLabel", HORIZONTAL_ALIGNMENT_RIGHT).modulate = dim
		_cell(str(row.get("cuckoos", 0)), &"RowLabel", HORIZONTAL_ALIGNMENT_RIGHT).modulate = dim
		_cell(str(row.get("raised", 0)), &"RowLabel", HORIZONTAL_ALIGNMENT_RIGHT).modulate = dim


func _cell(text: String, variation: StringName, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = align
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if variation == &"RowLabel" and align == HORIZONTAL_ALIGNMENT_LEFT else Control.SIZE_FILL
	_grid.add_child(label)
	return label


func _tab(parent: Container, text: String) -> Button:
	var tab := Button.new()
	tab.text = text
	tab.toggle_mode = true
	tab.focus_mode = Control.FOCUS_ALL
	parent.add_child(tab)
	return tab
