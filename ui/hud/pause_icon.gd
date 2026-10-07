extends Control
## The two bars of a pause symbol, drawn in the middle of this control (inside the pause button).

const COLOR := Color(0.086, 0.161, 0.29)


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var h := size.y * 0.42
	var w := size.x * 0.12
	var gap := size.x * 0.1
	var c := size * 0.5
	for side in [-1.0, 1.0]:
		var x: float = c.x + side * (gap * 0.5 + w * 0.5)
		draw_rect(Rect2(x - w * 0.5, c.y - h * 0.5, w, h), COLOR)
