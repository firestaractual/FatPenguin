class_name WaddleMeter
extends Control
## The match on the HUD (WaddleMatch, GDD §4.12), top left:
##   - every family's lives, a coloured disc each with the count (yours first and biggest; a family
##     that's out is crossed out);
##   - the waddle you're in, or the nearest one: its name, the families living there (colour dots),
##     how close its ice is to breaking (a bar) and the cracks it's shown (a little floe);
##   - a bobbing egg while you're full and have an egg to lay.
## Down the right: a feed of what's happening (the match's announcements: a berg breaking up, kin
## eaten, a cuckoo egg laid), each fading after a few seconds. Across the middle: a banner when the
## ice breaks under you, or you carry on as one of your kin. Hidden when the level has no match (or
## it's off). Drawn in code like the air meter; it only reads the match and the waddles.

const FAMILY_RADIUS := 15.0
const YOUR_RADIUS := 19.0
const FAMILY_GAP := 8.0
const FLOE_RADIUS := 16.0
const BAR_WIDTH := 170.0
const BAR_HEIGHT := 12.0
const FILL := Color(0.86, 0.96, 1.0)
const LINE := Color(0.086, 0.161, 0.29)
const CRACK := Color(0.086, 0.161, 0.29, 0.85)
const OUT := Color(0.55, 0.6, 0.66)
const EGG := Color(0.95, 0.93, 0.86)
const TEXT_SIZE := 20
## The cracks on the little floe, from its middle outward (in floe radii).
const CRACKS := [
	[Vector2(0.1, 0.05), Vector2(0.35, -0.2), Vector2(0.55, -0.15), Vector2(0.95, -0.4)],
	[Vector2(0.1, 0.05), Vector2(-0.15, 0.4), Vector2(-0.1, 0.65), Vector2(-0.35, 0.92)],
	[Vector2(0.1, 0.05), Vector2(-0.3, -0.15), Vector2(-0.6, -0.05), Vector2(-0.9, -0.38)],
	[Vector2(0.35, -0.2), Vector2(0.45, 0.25), Vector2(0.8, 0.5)],
	[Vector2(-0.3, -0.15), Vector2(-0.25, -0.6), Vector2(0.05, -0.95)],
]
const FADE_SPEED := 4.0
## The waddle shown: the one you're in, or the nearest within this far (m).
const NEAR_WADDLE := 45.0
## Feed lines stay this long (s), and at most this many show.
const FEED_SECONDS := 5.0
const FEED_LINES := 4
## A banner stays this long (s).
const BANNER_SECONDS := 3.5
const REFRESH := 0.25

## The penguin it's for (GameHud sets it).
var penguin: Penguin = null

var _match: WaddleMatch = null
var _ice: WaddleIce = null
var _clock := 0.0
var _refresh := 0.0
var _shown := 0.0
var _banner: VBoxContainer
var _title: Label
var _caption: Label
var _banner_left := -1.0
var _feed: VBoxContainer
var _watched: Array[WaddleIce] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300.0, 120.0)
	size = custom_minimum_size
	modulate.a = 0.0
	_banner = VBoxContainer.new()
	_banner.name = "Banner"
	_banner.top_level = true
	_banner.mouse_filter = MOUSE_FILTER_IGNORE
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.add_theme_constant_override(&"separation", 6)
	_banner.modulate.a = 0.0
	_banner.visible = false
	add_child(_banner)
	_title = _label(_banner, "", &"BannerLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_caption = _label(_banner, "", &"HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_feed = VBoxContainer.new()
	_feed.name = "Feed"
	_feed.top_level = true
	_feed.mouse_filter = MOUSE_FILTER_IGNORE
	_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	_feed.add_theme_constant_override(&"separation", 2)
	add_child(_feed)


func _process(delta: float) -> void:
	_clock += delta
	var game := WaddleMatch.current(get_tree())
	if game != _match:
		_watch(game)
	_watch_waddles()
	var wanted := _match != null and _match.active and not _match.families.is_empty()
	modulate.a = move_toward(modulate.a, 1.0 if wanted else 0.0, FADE_SPEED * delta)
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = REFRESH
		_ice = _waddle_shown()
	if modulate.a > 0.0:
		_shown = move_toward(_shown, _ice.progress() if _ice != null else 0.0, delta * 0.8)
		queue_redraw()
	_update_banner(delta)
	_update_feed(delta)


# --- What it shows (for tests) ------------------------------------------------------------

## Is the meter on screen (faded in)? And the banner?
func is_showing() -> bool:
	return modulate.a > 0.5


func banner_showing() -> bool:
	return _banner.visible and _banner.modulate.a > 0.5


## The banner's words.
func banner_text() -> String:
	return "%s\n%s" % [_title.text, _caption.text]


## The feed's lines, oldest first.
func feed_lines() -> Array[String]:
	var lines: Array[String] = []
	for child in _feed.get_children():
		lines.append((child as Label).text)
	return lines


## The waddle it's showing (yours, or the nearest), or null.
func waddle_shown() -> WaddleIce:
	return _ice


## Shows `title` (and `caption`) across the middle for a moment.
func show_banner(title: String, caption: String) -> void:
	_title.text = title
	_caption.text = caption
	_caption.visible = not caption.is_empty()
	_banner.visible = true
	_banner_left = BANNER_SECONDS
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2.ONE * 0.4
	create_tween().tween_property(_banner, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# --- Inside ------------------------------------------------------------------------------

func _watch(game: WaddleMatch) -> void:
	if _match != null and is_instance_valid(_match):
		_match.announced.disconnect(_on_announced)
		_match.took_over.disconnect(_on_took_over)
	_match = game
	if _match != null:
		_match.announced.connect(_on_announced)
		_match.took_over.connect(_on_took_over)


func _watch_waddles() -> void:
	for ice in WaddleIce.all(get_tree()):
		if not _watched.has(ice):
			_watched.append(ice)
			ice.breaking.connect(_on_breaking.bind(ice))
			ice.scene_over.connect(_on_scene_over.bind(ice))


## The waddle the penguin's in, or the nearest standing one within NEAR_WADDLE.
func _waddle_shown() -> WaddleIce:
	if penguin == null or not is_instance_valid(penguin) or not penguin.is_inside_tree():
		return null
	var here := WaddleIce.holding(get_tree(), penguin)
	if here != null:
		return here
	var near := WaddleIce.nearest(get_tree(), penguin.global_position)
	if near != null and near.waddle_spot().distance_to(penguin.global_position) <= NEAR_WADDLE:
		return near
	return null


func _on_announced(text: String, colour: Color) -> void:
	var line := _label(_feed, text, &"FeedLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	line.set_meta(&"left", FEED_SECONDS)
	line.modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(Color(colour, 1.0), 0.35)
	while _feed.get_child_count() > FEED_LINES:
		var oldest := _feed.get_child(0)
		_feed.remove_child(oldest)
		oldest.queue_free()


func _on_took_over(player: Penguin, new_name: String) -> void:
	if player == penguin:
		show_banner("You're %s now" % new_name, "Your family carries on")


func _on_breaking(ice: WaddleIce) -> void:
	if penguin != null and is_instance_valid(penguin) and penguin.state != Penguin.State.SWIM and ice.covers(penguin.global_position):
		var where := _match.berg_name(ice.berg) if _match != null else "ice"
		show_banner("The %s broke up!" % where, "")
		_banner_left = INF


func _on_scene_over(ice: WaddleIce) -> void:
	if _banner_left == INF:
		_caption.text = "Get back on the ice!"
		_caption.visible = true
		_banner_left = BANNER_SECONDS


func _update_banner(delta: float) -> void:
	if not _banner.visible:
		return
	var view := get_viewport_rect().size
	_banner.size = Vector2(view.x, 200.0)
	_banner.position = Vector2(0.0, view.y * 0.18)
	_banner.pivot_offset = _banner.size * 0.5
	_banner_left -= delta
	_banner.modulate.a = move_toward(_banner.modulate.a, 1.0 if _banner_left > 0.0 else 0.0, FADE_SPEED * delta)
	if _banner_left <= 0.0 and _banner.modulate.a <= 0.0:
		_banner.visible = false


func _update_feed(delta: float) -> void:
	var view := get_viewport_rect().size
	_feed.size = Vector2(view.x * 0.5, 0.0)
	_feed.position = Vector2(view.x * 0.5 - 24.0, 110.0)
	for child in _feed.get_children():
		var line := child as Label
		var left: float = line.get_meta(&"left", 0.0) - delta
		line.set_meta(&"left", left)
		line.modulate.a = clampf(left / 0.6, 0.0, 1.0)
		if left <= 0.0:
			_feed.remove_child(line)
			line.queue_free()


func _label(parent: Container, text: String, variation: StringName, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = align
	label.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _draw() -> void:
	if _match == null or not is_instance_valid(_match):
		return
	var font := get_theme_default_font()
	# The families' lives: yours first.
	var x := 6.0
	var mine := _match.player_family()
	var order: Array = _match.families.duplicate()
	if mine != null:
		order.erase(mine)
		order.push_front(mine)
	for family: WaddleMatch.Family in order:
		var r := YOUR_RADIUS if family == mine else FAMILY_RADIUS
		var at := Vector2(x + r, YOUR_RADIUS + 4.0)
		var colour := OUT if family.out else family.colour
		draw_circle(at, r, colour, true, -1.0, true)
		draw_arc(at, r, 0.0, TAU, 32, LINE, 3.0, true)
		if family.out:
			draw_line(at + Vector2(-r, -r) * 0.6, at + Vector2(r, r) * 0.6, LINE, 3.0, true)
			draw_line(at + Vector2(-r, r) * 0.6, at + Vector2(r, -r) * 0.6, LINE, 3.0, true)
		else:
			_draw_centred(font, str(_match.lives(family)), at, TEXT_SIZE if family == mine else TEXT_SIZE - 4)
		x += r * 2.0 + FAMILY_GAP
	# The waddle you're in, or the nearest.
	var row := YOUR_RADIUS * 2.0 + 16.0
	if _ice != null and is_instance_valid(_ice):
		var t := _ice.tuning
		var centre := Vector2(FLOE_RADIUS + 6.0, row + FLOE_RADIUS + 2.0)
		var shake := Vector2.ZERO
		if _shown > 0.85:
			shake = Vector2(sin(_clock * 47.0), cos(_clock * 53.0)) * 1.5 * (_shown - 0.85) / 0.15
		draw_circle(centre + shake, FLOE_RADIUS, FILL, true, -1.0, true)
		draw_arc(centre + shake, FLOE_RADIUS, 0.0, TAU, 32, LINE, 3.0, true)
		var k := clampf((_ice.peak_progress() - t.crack_from) / maxf(1.0 - t.crack_from, 0.01), 0.0, 1.0)
		for i in CRACKS.size():
			var grow := clampf(k * CRACKS.size() * 0.75 - i * 0.5, 0.0, 1.0)
			if grow <= 0.0:
				continue
			var crack: Array = CRACKS[i]
			var reach := grow * (crack.size() - 1)
			for s in crack.size() - 1:
				var part := clampf(reach - s, 0.0, 1.0)
				if part <= 0.0:
					break
				var from: Vector2 = crack[s]
				var to: Vector2 = crack[s + 1]
				draw_line(centre + shake + from * FLOE_RADIUS, centre + shake + from.lerp(to, part) * FLOE_RADIUS, CRACK, 2.0, true)
		var left := FLOE_RADIUS * 2.0 + 16.0
		var label := _match.berg_name(_ice.berg)
		_draw_outlined(font, label, Vector2(left, row + 12.0), TEXT_SIZE - 2)
		var dot_x := left + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE - 2).x + 12.0
		for id in _match.families_on(_ice.berg):
			draw_circle(Vector2(dot_x, row + 6.0), 6.0, _match.families[id].colour, true, -1.0, true)
			draw_arc(Vector2(dot_x, row + 6.0), 6.0, 0.0, TAU, 16, LINE, 2.0, true)
			dot_x += 15.0
		var bar := Rect2(left, row + 20.0, BAR_WIDTH, BAR_HEIGHT)
		draw_rect(bar, Color(LINE, 0.35), true)
		if _shown > 0.001:
			var pulse := 1.0 if _shown < 0.85 else 0.8 + 0.2 * sin(_clock * 12.0)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * _shown, bar.size.y)), Color(FILL, pulse), true)
		draw_rect(bar, LINE, false, 3.0)
		row += FLOE_RADIUS * 2.0 + 10.0
	# An egg on its way.
	if penguin != null and is_instance_valid(penguin) and _match.is_full(penguin):
		_draw_egg(Vector2(16.0, row + 14.0 + sin(_clock * 5.0) * 3.0), 1.2)


func _draw_centred(font: Font, text: String, at: Vector2, font_size: int) -> void:
	var size_of := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	_draw_outlined(font, text, at + Vector2(-size_of.x * 0.5, font_size * 0.35), font_size)


func _draw_outlined(font: Font, text: String, at: Vector2, font_size: int) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, LINE)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _draw_egg(at: Vector2, s: float) -> void:
	var points := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		var squash := 1.0 + 0.18 * sin(a) # wider at the bottom
		points.append(at + Vector2(cos(a) * 7.0 * squash, sin(a) * 9.5) * s)
	draw_colored_polygon(points, EGG)
	points.append(points[0])
	draw_polyline(points, LINE, 2.0, true)
