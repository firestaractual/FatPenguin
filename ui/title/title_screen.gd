class_name TitleScreen
extends Node3D
## The title screen: the logo acted out (ART_DIRECTION, Logo; GDD §1), and a preview of the game's
## goal (GDD §4.12: a waddle fat enough breaks through the ice). A little waddle of fat penguins
## stands on a disc of thin ice, the hero in front. Each tap (or Space, or A) throws him a fish: he
## gulps it down and swells, and the others bob along. From the third fish the ice starts to crack,
## the cracks running out along the seams of the ice; on the last fish it gives way. The ice drops
## out from under them and, cartoon style, they hang in the air a moment, look down, flap, and
## drop one after another, the hero last, and his splash starts the game.
##
## The penguins are the game's own penguin scene with processing switched off: this script poses
## their Models by hand, so a new penguin model shows up here too. The rest (the ice, the cracks,
## the splashes) is built in code. The game scene loads in the background from the first fish.

## It ate a fish (how many so far).
signal fed(count: int)
## The ice gave way and it hit the water.
signal broke_through
## The white-out finished: the game is about to start (or would, with start_game off).
signal finished

const GAME_SCENE := "res://levels/movement_toy/movement_toy.tscn"
const PENGUIN_SCENE := preload("res://actors/penguin/penguin.tscn")
const FISH_SCENE := preload("res://actors/fish/fish.tscn")
const THIN_ICE := preload("res://art/materials/thin_ice.tres")
const SPLASH := preload("res://art/materials/splash.tres")

## Fish it takes to break the ice.
@export var feeds_to_break := 6
## The cracks start showing from this fish on.
@export var cracks_from := 3
## Off for tests: it stops at the white-out (and emits finished) instead of starting the game.
@export var start_game := true
## The thin ice: how wide, how far above the water its top is, and how many pieces it breaks into.
@export var floe_radius := 3.0
@export var ice_top := 0.1
@export var ice_pieces := 9
## How wide the penguin's body gets by the last fish (×), and how tall.
@export var fat_width := 1.9
@export var fat_height := 1.12
## How long a fish takes to fly to its beak (s).
@export var fish_flight := 0.45
## The rest of the waddle: where each stands (behind and beside the hero) and how fat it is (×).
@export var waddle_spots: Array[Vector3] = [Vector3(-1.4, 0.0, -0.5), Vector3(1.45, 0.0, -0.45), Vector3(-0.7, 0.0, -1.5), Vector3(0.8, 0.0, -1.55)]
@export var waddle_widths: Array[float] = [1.55, 1.7, 1.45, 1.6]
## When the ice goes, how long each hangs in the air before it drops (s): the others in turn, then
## the hero, longest of all.
@export var hang_seconds: Array[float] = [0.18, 0.32, 0.44, 0.56]
@export var hero_hang := 0.8
## A drop into the water takes this long (s).
@export var drop_seconds := 0.36

## Fish eaten so far.
var feeds := 0

var _thrown := 0
var _breaking := false
var _penguin: Penguin
var _model: Node3D
var _width := 1.0
var _height := 1.0
var _squash := 0.0
var _tilt := 0.0
var _wobble := 0.0
var _clock := 0.0
var _floe: Node3D
## Each piece of ice: a pivot on its outer edge (it tips about that) holding the mesh.
var _pieces: Array[Node3D] = []
## Each seam's crack, as segments from the middle outward.
var _cracks: Array[Array] = []
var _crack_material: StandardMaterial3D
var _loading := false
## The rest of the waddle: each {"penguin", "model", "width", "phase", "look", "flap", "stretch",
## "bob"}. The hero's look, flap and stretch are in _hero.
var _others: Array[Dictionary] = []
var _hero := {"look": 0.0, "flap": false, "stretch": 0.0}
## Each penguin's flippers at rest, by model.
var _flippers := {}

@onready var _camera: Camera3D = $Camera
@onready var _prompt: Label = %Prompt
@onready var _wordmark: Control = %Wordmark
@onready var _settings_button: Button = %SettingsButton
@onready var _settings: SettingsPanel = %SettingsPanel
@onready var _flash: ColorRect = %Flash


func _ready() -> void:
	_build_floe()
	_spawn_penguin()
	_spawn_waddle()
	_settings_button.pressed.connect(_open_settings)
	_settings.closed.connect(func() -> void: _settings_button.grab_focus())
	_settings_button.add_to_group(&"touch_ui")
	_flash.color.a = 0.0


func _exit_tree() -> void:
	# A background load nobody collected would be left behind when the game quits.
	if _loading:
		ResourceLoader.load_threaded_get(GAME_SCENE)
		_loading = false


func _process(delta: float) -> void:
	_clock += delta
	_pose_penguin()
	_pose_waddle()
	# The prompt breathes, and names the right control.
	_prompt.text = "Tap to feed him" if InputDevice.kind == InputDevice.Kind.TOUCH \
			else "Press %s to feed him" % InputDevice.control_name(&"action")
	_prompt.modulate.a = 0.0 if _breaking or _settings.visible else 0.65 + 0.35 * sin(_clock * 3.0)
	# A slow sway, so the scene isn't a still.
	_camera.position.x = sin(_clock * 0.3) * 0.12


func _unhandled_input(event: InputEvent) -> void:
	InputDevice.note(event)
	if _settings.visible or _breaking:
		return
	# Clicks and taps (a tap arrives as a click too) that no button took, or Space / A / Enter.
	var tap := event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if tap or event.is_action_pressed(&"action") or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		feed()


## Throws the penguin a fish (what a tap does). Ignored once it has all it needs.
func feed() -> void:
	if _breaking or _thrown >= feeds_to_break:
		return
	_thrown += 1
	if start_game and not _loading:
		# Start loading the game while the gag plays out.
		ResourceLoader.load_threaded_request(GAME_SCENE)
		_loading = true
	var fish := FISH_SCENE.instantiate() as Fish
	fish.process_mode = Node.PROCESS_MODE_DISABLED
	fish.scale = Vector3.ONE * 1.6
	add_child(fish)
	# From off to one side, up in a lob, into the beak.
	var side := 1.0 if _thrown % 2 == 1 else -1.0
	var from := Vector3(side * 3.2, 2.6, 1.6)
	var to := _beak()
	var tween := create_tween()
	tween.tween_method(_fly_fish.bind(fish, from, to), 0.0, 1.0, fish_flight)
	tween.tween_callback(_gulp.bind(fish))
	# Head up to catch it.
	create_tween().tween_property(self, "_tilt", -0.35, fish_flight * 0.6).set_trans(Tween.TRANS_SINE)


## The thin ice's pieces, and the crack segments that show now (for tests).
func crack_segments_showing() -> int:
	var n := 0
	for seam in _cracks:
		for segment: Node3D in seam:
			if segment.visible:
				n += 1
	return n


## How wide the penguin's body is now (×).
func penguin_width() -> float:
	return _width


func penguin_position() -> Vector3:
	return _penguin.global_position


func _fly_fish(t: float, fish: Fish, from: Vector3, to: Vector3) -> void:
	var at := from.lerp(to, t) + Vector3.UP * sin(t * PI) * 1.2
	var ahead := from.lerp(to, minf(t + 0.05, 1.0)) + Vector3.UP * sin(minf(t + 0.05, 1.0) * PI) * 1.2
	if ahead.distance_to(at) > 0.001:
		fish.global_transform = Transform3D(Basis.looking_at(ahead - at, Vector3.UP), at).scaled_local(Vector3.ONE * 1.6)
	else:
		fish.global_position = at


func _gulp(fish: Fish) -> void:
	fish.queue_free()
	feeds += 1
	fed.emit(feeds)
	var k := float(feeds) / feeds_to_break
	# Swell (with a little overshoot), a stretch as it swallows, head back down.
	create_tween().tween_property(self, "_width", lerpf(1.0, fat_width, k), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(self, "_height", lerpf(1.0, fat_height, k), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var squash := create_tween()
	squash.tween_property(self, "_squash", 1.0, 0.08)
	squash.tween_property(self, "_squash", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(self, "_tilt", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	# The ice takes the weight.
	create_tween().tween_property(_floe, "position:y", -0.025 * feeds, 0.25)
	# The others bob along (they'd like one too).
	for other in _others:
		var bob := create_tween()
		bob.tween_method(_bob_other.bind(other), 0.0, 1.0, 0.45).set_delay(randf() * 0.12)
	_grow_cracks()
	if feeds >= feeds_to_break:
		_break_through()


## Cracks run out along the seams as the fish go down: a segment more per fish.
func _grow_cracks() -> void:
	var stage := feeds - cracks_from + 1
	if stage <= 0:
		return
	for seam in _cracks:
		for i in seam.size():
			var segment: Node3D = seam[i]
			if i < stage and not segment.visible:
				segment.visible = true
				segment.scale = Vector3(1.0, 1.0, 0.05)
				create_tween().tween_property(segment, "scale:z", 1.0, 0.18).set_delay(randf() * 0.12)


func _break_through() -> void:
	_breaking = true
	var beat := create_tween()
	# A beat: it wobbles, the cracks flash...
	beat.tween_property(self, "_wobble", 1.0, 0.35)
	beat.parallel().tween_property(_crack_material, "albedo_color", Color(0.06, 0.1, 0.16), 0.35)
	for seam in _cracks:
		for segment: Node3D in seam:
			beat.parallel().tween_property(segment, "scale:x", 2.6, 0.35)
	beat.tween_callback(_drop)


## The ice gives way: the pieces tip into the water and, cartoon style, the penguins hang in the
## air a moment, look down, flap, and drop one after another, the hero last.
func _drop() -> void:
	_wobble = 0.0
	for pivot in _pieces:
		var out := Vector3(pivot.position.x, 0.0, pivot.position.z).normalized()
		var axis := out.cross(Vector3.UP).normalized()
		var tip := create_tween().set_parallel()
		tip.tween_property(pivot, "basis", Basis(axis, deg_to_rad(randf_range(28.0, 42.0))), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tip.tween_property(pivot, "position", pivot.position + out * 0.25 + Vector3.DOWN * 0.35, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for seam in _cracks:
		for segment: Node3D in seam:
			segment.hide()
	for i in _others.size():
		var hang: float = hang_seconds[i] if i < hang_seconds.size() else 0.3 + 0.12 * i
		_hang_and_drop(_others[i], _others[i]["penguin"], hang, false)
	var fall := _hang_and_drop(_hero, _penguin, hero_hang, true)
	# White-out, then the game.
	fall.tween_property(_flash, "color:a", 1.0, 0.55).set_delay(0.2)
	fall.tween_callback(_finish)


## `who` hangs in the air for `hang` (s), looking down at where the ice was, flapping, then drops
## into the water, stretched out, with a splash. Returns the tween, to chain onto.
func _hang_and_drop(who: Dictionary, penguin: Penguin, hang: float, hero: bool) -> Tween:
	var fall := create_tween()
	who["flap"] = true
	fall.tween_method(_set_look.bind(who), 0.0, 0.5, hang * 0.45).set_trans(Tween.TRANS_SINE)
	fall.tween_method(_set_look.bind(who), 0.5, -0.15, hang * 0.25).set_delay(hang * 0.1).set_trans(Tween.TRANS_BACK)
	fall.tween_interval(hang * 0.2)
	fall.tween_method(_set_stretch.bind(who), 0.0, 1.0, drop_seconds * 0.4)
	fall.parallel().tween_property(penguin, "position:y", -1.6, drop_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_callback(_splash_at.bind(penguin, hero)).set_delay(drop_seconds * 0.55)
	if not hero:
		# Bob back up, head out of the water, a bit stunned.
		fall.tween_callback(func() -> void:
			who["flap"] = false
			who["stretch"] = 0.0
			who["look"] = -0.2)
		fall.tween_property(penguin, "position:y", -0.12, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return fall


func _set_look(value: float, who: Dictionary) -> void:
	who["look"] = value


func _set_stretch(value: float, who: Dictionary) -> void:
	who["stretch"] = value


func _bob_other(t: float, other: Dictionary) -> void:
	other["bob"] = sin(t * PI) * 0.12

## A splash where `penguin` hits the water: a big one for the hero (and that's the breakthrough).
func _splash_at(penguin: Penguin, hero: bool) -> void:
	if hero:
		broke_through.emit()
	var spray := CPUParticles3D.new()
	var drop := SphereMesh.new()
	drop.radius = 0.035
	drop.height = 0.07
	drop.radial_segments = 8
	drop.rings = 4
	drop.material = SPLASH
	spray.mesh = drop
	spray.amount = 160 if hero else 70
	spray.lifetime = 1.0
	spray.one_shot = true
	spray.explosiveness = 0.95
	# Up and back, away from the camera.
	spray.direction = Vector3(0.0, 1.0, -0.35)
	spray.spread = 28.0
	spray.initial_velocity_min = 2.5
	spray.initial_velocity_max = 5.5
	spray.scale_amount_min = 0.6
	spray.scale_amount_max = 1.6
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	spray.emission_ring_axis = Vector3.UP
	spray.emission_ring_radius = 0.6 if hero else 0.45
	spray.emission_ring_inner_radius = 0.2
	spray.emission_ring_height = 0.05
	add_child(spray)
	spray.position = Vector3(penguin.position.x, GameWorld.WATER_LEVEL, penguin.position.z)
	spray.emitting = true


func _finish() -> void:
	finished.emit()
	if not start_game:
		return
	while _loading and ResourceLoader.load_threaded_get_status(GAME_SCENE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var game := ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene if _loading else load(GAME_SCENE) as PackedScene
	_loading = false
	get_tree().change_scene_to_packed(game)


func _open_settings() -> void:
	_settings.open()


# --- The penguin --------------------------------------------------------------

func _spawn_penguin() -> void:
	_penguin = PENGUIN_SCENE.instantiate() as Penguin
	_penguin.player_controlled = false
	_penguin.infinite_energy = true
	# Posed by hand here: no physics, no look script.
	_penguin.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_penguin)
	_penguin.remove_from_group(&"penguins")
	_penguin.position = Vector3(0.0, ice_top + _penguin.base_radius(), 0.0)
	_model = _penguin.get_node("Model") as Node3D
	_pose_penguin()


## Faces the camera, as wide and tall as it's been fed, squashed as it gulps, tipped back to
## catch a fish, wobbling as the ice goes; looking down, flapping and stretched out as it drops.
func _pose_penguin() -> void:
	if _model == null:
		return
	var stretch: float = _hero["stretch"]
	var width := _width * (1.0 + 0.12 * _squash) * (1.0 - 0.22 * stretch)
	var height := _height * (1.0 - 0.1 * _squash) * (1.0 + 0.35 * stretch)
	var wobble := _wobble * 0.18 * sin(_clock * 38.0)
	var b := Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, _tilt + _hero["look"]) * Basis(Vector3.BACK, wobble)
	_model.basis = b * Basis.from_scale(Vector3(width, height, width))
	# Feet stay on the ice as it grows taller.
	_model.position.y = (height - 1.0) * 0.3
	_flap(_model, _hero["flap"])


## The rest of the waddle: fat, swaying, bobbing when the hero gets a fish, wobbling as the ice
## goes, and the same hang and drop as the hero.
func _pose_waddle() -> void:
	for other in _others:
		var model: Node3D = other["model"]
		var phase: float = other["phase"]
		var stretch: float = other["stretch"]
		var w: float = other["width"] * (1.0 - 0.22 * stretch)
		var h := 1.08 * (1.0 + 0.35 * stretch)
		var sway := 0.05 * sin(_clock * 1.3 + phase) + _wobble * 0.16 * sin(_clock * 35.0 + phase)
		var turn: float = other["turn"]
		model.basis = Basis(Vector3.UP, PI + turn) * Basis(Vector3.RIGHT, other["look"]) * Basis(Vector3.BACK, sway) \
				* Basis.from_scale(Vector3(w, h, w))
		model.position.y = (h - 1.0) * 0.3 + other["bob"]
		_flap(model, other["flap"])


## Flippers beating (as it hangs in the air), or at rest.
func _flap(model: Node3D, flapping: bool) -> void:
	if not _flippers.has(model):
		var rest := {}
		for flipper_name in [&"FlipperL", &"FlipperR"]:
			var flipper := model.get_node_or_null(NodePath(flipper_name)) as Node3D
			if flipper != null:
				rest[flipper] = flipper.transform
		_flippers[model] = rest
	var flippers: Dictionary = _flippers[model]
	for flipper: Node3D in flippers:
		var at_rest: Transform3D = flippers[flipper]
		if not flapping:
			flipper.transform = at_rest
			continue
		var side := signf(at_rest.origin.x)
		var angle := side * 0.75 * (0.5 + 0.5 * sin(_clock * 34.0 + side))
		var pivot := at_rest.origin + at_rest.basis.y * 0.15
		flipper.transform = Transform3D(Basis(Vector3.BACK, angle), pivot) * Transform3D(Basis.IDENTITY, -pivot) * at_rest


## The rest of the waddle, already fat, round and behind the hero.
func _spawn_waddle() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in waddle_spots.size():
		var other := PENGUIN_SCENE.instantiate() as Penguin
		other.player_controlled = false
		other.infinite_energy = true
		other.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(other)
		other.remove_from_group(&"penguins")
		other.position = waddle_spots[i] + Vector3.UP * (ice_top + other.base_radius())
		_others.append({
			"penguin": other,
			"model": other.get_node("Model"),
			"width": waddle_widths[i] if i < waddle_widths.size() else 1.5,
			"phase": rng.randf() * TAU,
			"turn": rng.randf_range(-0.35, 0.35) - waddle_spots[i].x * 0.12,
			"look": 0.0,
			"flap": false,
			"stretch": 0.0,
			"bob": 0.0,
		})
	_pose_waddle()


## The penguins standing on the thin ice: the hero first.
func penguin_count() -> int:
	return 1 + _others.size()


## How many penguins are still up on the ice (not dropped into the water yet).
func penguins_on_ice() -> int:
	var n := 1 if _penguin.position.y > 0.0 else 0
	for other in _others:
		if (other["penguin"] as Penguin).position.y > 0.0:
			n += 1
	return n


func _beak() -> Vector3:
	return _penguin.global_position + Vector3(0.0, 0.22 * _height, 0.3 * _width)


# --- The thin ice -------------------------------------------------------------

## A disc of thin ice in pieces (wedges with a ragged rim), each on a pivot at its outer edge, and
## a crack along every seam, hidden until the fish start to tell.
func _build_floe() -> void:
	_floe = Node3D.new()
	_floe.name = "ThinIce"
	add_child(_floe)
	_crack_material = StandardMaterial3D.new()
	_crack_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_crack_material.albedo_color = Color(0.2, 0.27, 0.36)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := maxi(ice_pieces, 3)
	var seams: Array[float] = []
	for i in n:
		seams.append((TAU * i / n) + rng.randf_range(-0.25, 0.25) * TAU / n)
	for i in n:
		var a0 := seams[i]
		var a1 := seams[(i + 1) % n] + (TAU if i == n - 1 else 0.0)
		_add_piece(a0, a1, rng)
	for a in seams:
		_add_crack(a, rng)


func _add_piece(a0: float, a1: float, rng: RandomNumberGenerator) -> void:
	var thickness := 0.22
	var rim: Array[Vector3] = []
	var steps := 5
	for s in steps + 1:
		var a := lerpf(a0, a1, float(s) / steps)
		var r := floe_radius * rng.randf_range(0.93, 1.04)
		rim.append(Vector3(cos(a), 0.0, sin(a)) * r)
	var mid_a := (a0 + a1) * 0.5
	var pivot_at := Vector3(cos(mid_a), 0.0, sin(mid_a)) * floe_radius
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3.UP * ice_top
	var bottom := Vector3.UP * (ice_top - thickness)
	for s in steps:
		var p0 := rim[s] - pivot_at
		var p1 := rim[s + 1] - pivot_at
		var c := -pivot_at
		# Top and bottom.
		st.add_vertex(c + top); st.add_vertex(p1 + top); st.add_vertex(p0 + top)
		st.add_vertex(c + bottom); st.add_vertex(p0 + bottom); st.add_vertex(p1 + bottom)
		# Rim.
		st.add_vertex(p0 + top); st.add_vertex(p1 + top); st.add_vertex(p1 + bottom)
		st.add_vertex(p0 + top); st.add_vertex(p1 + bottom); st.add_vertex(p0 + bottom)
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = THIN_ICE
	var pivot := Node3D.new()
	pivot.position = pivot_at
	pivot.add_child(mesh)
	_floe.add_child(pivot)
	_pieces.append(pivot)


func _add_crack(angle: float, rng: RandomNumberGenerator) -> void:
	var seam: Array[Node3D] = []
	var from := Vector3(cos(angle), 0.0, sin(angle)) * 0.25
	var segments := 3
	for i in segments:
		var r := floe_radius * float(i + 1) / segments
		var jitter := rng.randf_range(-0.12, 0.12) if i < segments - 1 else 0.0
		var to := Vector3(cos(angle + jitter), 0.0, sin(angle + jitter)) * r
		var length := from.distance_to(to)
		var box := BoxMesh.new()
		box.size = Vector3(0.035, 0.01, length)
		var piece := MeshInstance3D.new()
		piece.mesh = box
		piece.material_override = _crack_material
		# Pivot at the inner end so it grows outward.
		var holder := Node3D.new()
		holder.position = from + Vector3.UP * (ice_top + 0.006)
		holder.basis = Basis.looking_at(to - from, Vector3.UP)
		piece.position = Vector3(0.0, 0.0, -length * 0.5)
		holder.add_child(piece)
		holder.visible = false
		_floe.add_child(holder)
		seam.append(holder)
		from = to
	_cracks.append(seam)
