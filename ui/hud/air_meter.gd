class_name AirMeter
extends Control
## The breath meter (GDD §4.9): a row of bubbles that pop one by one as the air runs out. It only
## shows while the penguin is underwater and short of breath, and fades away once it's breathing
## again. Nearly out, the bubbles pulse. Drawn in code, so it needs no art.

const BUBBLES := 6
const RADIUS := 15.0
const GAP := 12.0
## Below this share of a full breath the bubbles pulse.
const LOW := 0.3
const FADE_SPEED := 4.0

const FILL := Color(0.86, 0.96, 1.0)
const LINE := Color(0.086, 0.161, 0.29)
const SHINE := Color(1, 1, 1, 0.9)

## 0 (no air) to 1 (a full breath).
var ratio := 1.0
## Should it be on screen (underwater and short of breath)?
var wanted := false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	custom_minimum_size = Vector2(BUBBLES * (RADIUS * 2.0 + GAP) - GAP + 8.0, RADIUS * 2.0 + 8.0)


## Sets how much breath is left (seconds of `full`) and whether the meter is wanted.
func show_air(air: float, full: float, underwater: bool) -> void:
	ratio = clampf(air / maxf(full, 0.01), 0.0, 1.0)
	wanted = underwater and ratio < 0.999


## True once it's faded in enough to read.
func is_showing() -> bool:
	return modulate.a > 0.5


func _process(delta: float) -> void:
	modulate.a = move_toward(modulate.a, 1.0 if wanted else 0.0, FADE_SPEED * delta)
	if modulate.a > 0.0:
		queue_redraw()


func _draw() -> void:
	var count := ratio * BUBBLES
	var pulse := 1.0
	if ratio < LOW:
		pulse = 0.82 + 0.18 * sin(Time.get_ticks_msec() * 0.015)
	var step := RADIUS * 2.0 + GAP
	var start := Vector2((size.x - (BUBBLES * step - GAP)) * 0.5 + RADIUS, size.y * 0.5)
	for i in BUBBLES:
		var centre := start + Vector2(i * step, 0.0)
		var fill := clampf(count - i, 0.0, 1.0)
		# An empty bubble is just a faint ring.
		draw_arc(centre, RADIUS, 0.0, TAU, 32, Color(LINE, 0.35), 2.0, true)
		if fill <= 0.0:
			continue
		var r := RADIUS * (0.35 + 0.65 * fill) * pulse
		draw_circle(centre, r, FILL, true, -1.0, true)
		draw_arc(centre, r, 0.0, TAU, 32, LINE, 3.0, true)
		draw_circle(centre + Vector2(-r * 0.35, -r * 0.35), r * 0.22, SHINE, true, -1.0, true)
