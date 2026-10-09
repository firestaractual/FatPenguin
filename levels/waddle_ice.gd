class_name WaddleIce
extends Node3D
## One berg's waddle and the ice under it (GDD §4.12): how heavy the waddle on it is, the cracks that
## show it, and the ice giving way when it's too much. The level makes one for every berg that
## holds a waddle (IceBerg.holds_waddle()); WaddleMatch lays the eggs and raises the chicks that
## fill them.
##
## The waddle's weight: every family penguin standing in its waddle (players and the "npcs" group,
## not the practice dummies; any family) counts how fat it is, and every chick in it (Chick.berg)
## its size's weight. What the berg holds goes with its size (WaddleTuning.holds_per_metre × its
## reach, or IceBerg.holds). Cracks run out across it from under the waddle as the weight climbs
## (from crack_from of that), and at what it holds the ice gives way:
##   - a beat: everyone on it freezes and the cracks go dark and wide; a player on it gets a wide
##     shot (FollowCamera.frame()) and loses control until the scene's over;
##   - the berg bursts into pieces (FloePiece, cut along the cracks, too small for a waddle) that bob
##     under and push apart, and everyone on it is thrown up in the air, flailing, to come down in
##     the water between them. Its eggs and chicks are lost (Chick.lose()). Its colony is homeless:
##     each moves to the nearest berg that still holds a waddle (PenguinBrain.set_home()), and
##     anyone who'd respawn on it respawns on a piece;
##   - every predator in the level comes for the commotion (Predator.alert, PredatorPod.alert).
## Numbers are in WaddleTuning (tuning/waddle.tres). With `active` off it does nothing.
##
## Keep this node at the origin, unrotated: cracks are placed in world space.

## The waddle's too heavy: the beat before the ice bursts.
signal breaking
## The ice burst.
signal broke_through
## The scene is over: any player thrown off has control again.
signal scene_over

enum Phase { WHOLE, BREAKING, BROKEN }

const DEFAULT_TUNING := preload("res://tuning/waddle.tres")
const FLOE_PIECE_SCRIPT := preload("res://levels/bergs/floe_piece.gd")
## How often it weighs the waddle (s).
const WEIGH_INTERVAL := 0.2
## Cracks are drawn in bits about this long (m), wandering this far off a straight line (m).
const CRACK_STEP := 1.6
const CRACK_JITTER := 0.35
const CRACK_COLOUR := Color(0.2, 0.27, 0.36)
## Where a thrown penguin comes down: in the water, at least this far from any piece (m), as
## close as it can to where it was, preferring outward, looked for in rings this far apart (m) out
## to this far (m).
const LANDING_CLEARANCE := 0.9
const LANDING_STEP := 1.5
const LANDING_SEARCH := 13.5
## A berg this big (reach, m) breaks into WaddleTuning.pieces; smaller ones into fewer (at least 4).
const FULL_SIZE_REACH := 30.0

@export var tuning: WaddleTuning = DEFAULT_TUNING
## Off: no weighing, no breaking.
@export var active := true
## The cracks' (and so the pieces') layout.
@export var crack_seed := 11

## The berg. The level sets it before adding this node.
var berg: IceBerg = null

var phase: Phase = Phase.WHOLE

var _weight := 0.0
var _peak := 0.0
var _weigh_left := 0.0
## The pieces it will break into (the berg's local space, x and z): each {"seed": Vector2,
## "outline": PackedVector2Array round its middle, "middle": Vector2, "cell": the uncentred outline}.
var _cells: Array[Dictionary] = []
## The crack bits, nearest the waddle first, and how many show.
var _cracks: Array[Node3D] = []
var _cracks_shown := 0
var _crack_material: StandardMaterial3D
var _pieces: Array[FloePiece] = []
var _piece_holder: Node3D
## Each piece's middle at the waterline when it burst, and where it ends up.
var _piece_from: Array[Vector3] = []
var _piece_to: Array[Vector3] = []
## Players' own controls while the scene holds them, and the brains it switched off.
var _held_inputs := {}
var _held_brains: Array[PenguinBrain] = []
## Spots already picked for thrown penguins to come down in.
var _landings: Array[Vector3] = []


## Every berg's waddle in the level.
static func all(tree: SceneTree) -> Array[WaddleIce]:
	var list: Array[WaddleIce] = []
	if tree == null:
		return list
	for node in tree.get_nodes_in_group(&"waddle_ice"):
		var ice := node as WaddleIce
		if ice != null:
			list.append(ice)
	return list


## `berg`'s waddle, or null.
static func of(tree: SceneTree, the_berg: IceBerg) -> WaddleIce:
	for ice in all(tree):
		if ice.berg == the_berg:
			return ice
	return null


## The waddle `p` is standing in, or null.
static func holding(tree: SceneTree, p: Penguin) -> WaddleIce:
	for ice in all(tree):
		if ice.in_waddle(p):
			return ice
	return null


## The whole berg's waddle nearest `point` (excluding `but`), or null.
static func nearest(tree: SceneTree, point: Vector3, but: WaddleIce = null) -> WaddleIce:
	var best: WaddleIce = null
	var best_d := INF
	for ice in all(tree):
		if ice == but or ice.is_broken():
			continue
		var d := ice.waddle_spot().distance_to(point)
		if d < best_d:
			best_d = d
			best = ice
	return best


func _ready() -> void:
	add_to_group(&"waddle_ice")
	if tuning == null:
		tuning = DEFAULT_TUNING
	if berg == null:
		return
	name = "%sWaddle" % berg.name
	_lay_out_pieces()
	_draw_cracks()


func _physics_process(delta: float) -> void:
	if not active or berg == null:
		return
	if phase == Phase.BREAKING:
		# Held for the scene: anyone in the water bobs where they are.
		for held: Variant in _held_inputs:
			var p := held as Penguin if is_instance_valid(held) else null
			if p != null and p.state == Penguin.State.SWIM:
				p.set_swim_speed(0.0)
	if phase != Phase.WHOLE:
		return
	_weigh_left -= delta
	if _weigh_left > 0.0:
		return
	_weigh_left = WEIGH_INTERVAL
	_weight = weight()
	var share := _weight / maxf(holds(), 0.01)
	if share > _peak:
		_peak = share
		_show_cracks()
	if _weight >= holds():
		break_ice()


# --- What it answers ---------------------------------------------------------------

## How much its waddle holds before the berg breaks up.
func holds() -> float:
	if berg == null:
		return 1.0
	return berg.holds if berg.holds > 0.0 else tuning.holds_per_metre * berg.reach()


## The waddle's weight right now: how fat every family penguin in it is, plus its chicks.
func weight() -> float:
	var total := 0.0
	for node in get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p != null and (p.is_in_group(&"player") or p.is_in_group(&"npcs")) and in_waddle(p):
			total += p.fatness()
	for chick in chicks():
		total += chick.weight()
	return total


## What `extra` more weight would make it (a share of what it holds): for deciding where to lay.
func share_with(extra: float) -> float:
	return (weight() + extra) / maxf(holds(), 0.01)


## How close it is to breaking up, 0 to 1 (weighed a few times a second), and the most it's been
## (the cracks show that).
func progress() -> float:
	return clampf(_weight / maxf(holds(), 0.01), 0.0, 1.0)


func peak_progress() -> float:
	return clampf(_peak, 0.0, 1.0)


## Is `p` in this waddle: on its feet or belly on the berg, near its waddle spot, while it stands?
func in_waddle(p: Penguin) -> bool:
	if berg == null or phase == Phase.BROKEN or p == null or not p.is_inside_tree():
		return false
	if p.state != Penguin.State.WALK and p.state != Penguin.State.SLIDE:
		return false
	var d := p.global_position - berg.waddle_spot()
	return Vector2(d.x, d.z).length() <= tuning.waddle_radius and absf(d.y) < 1.5


func waddle_spot() -> Vector3:
	return berg.waddle_spot() if berg != null else global_position


## Is `point` over the berg's ice (while it stands)?
func covers(point: Vector3) -> bool:
	return berg != null and phase != Phase.BROKEN and _over_ice(point)


## The chicks (and eggs) in it.
func chicks() -> Array[Chick]:
	var list: Array[Chick] = []
	if berg == null:
		return list
	for node in get_tree().get_nodes_in_group(&"chicks"):
		var chick := node as Chick
		if chick != null and chick.berg == berg and not chick.is_lost():
			list.append(chick)
	return list


## Has the ice broken (or is it breaking)?
func is_broken() -> bool:
	return phase != Phase.WHOLE


## The pieces of the broken berg (empty until it breaks).
func pieces() -> Array[FloePiece]:
	return _pieces


## The crack bits on the berg, and how many show.
func crack_count() -> int:
	return _cracks.size()


func cracks_showing() -> int:
	return _cracks_shown


# --- Breaking -------------------------------------------------------------------------

## The ice gives way now (what reaching what it holds does): the beat, then the burst.
func break_ice() -> void:
	if phase != Phase.WHOLE or berg == null:
		return
	phase = Phase.BREAKING
	_weight = weight()
	var held_players := _hold_everyone()
	var beat := create_tween()
	beat.tween_property(_crack_material, "albedo_color", Color(0.03, 0.06, 0.1), tuning.beat_seconds * 0.6)
	for crack in _cracks:
		crack.visible = true
		crack.scale = Vector3.ONE
		beat.parallel().tween_property(crack, "scale:x", 3.0, tuning.beat_seconds * 0.6)
	_cracks_shown = _cracks.size()
	for cam in _cameras_on(held_players):
		cam.shake(0.06)
	_frame_cameras(held_players, tuning.beat_seconds + tuning.scene_seconds)
	breaking.emit()
	get_tree().create_timer(tuning.beat_seconds, false).timeout.connect(_burst)


# --- The cracks ---------------------------------------------------------------------

## Cuts the berg's ice into pieces (Voronoi cells, inside its footprint): three meeting right under
## the waddle, so the cracks start there, and the rest spread about. Smaller bergs, fewer pieces.
func _lay_out_pieces() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = crack_seed + hash(berg.name)
	var radius := berg.reach()
	var area := berg.footprint()
	var spot3 := berg.to_local(berg.waddle_spot())
	var spot := Vector2(spot3.x, spot3.z)
	var count := clampi(roundi(tuning.pieces * radius / FULL_SIZE_REACH), 4, maxi(tuning.pieces, 4))
	var seeds := PackedVector2Array()
	var turn := rng.randf() * TAU
	var ring := minf(radius * 0.25, 7.0)
	for k in 3:
		var a := turn + TAU * k / 3.0
		seeds.append(spot + Vector2(cos(a), sin(a)) * ring)
	var min_gap := radius * 1.25 / sqrt(float(count))
	var tries := 0
	while seeds.size() < count and tries < 3000:
		tries += 1
		if tries % 500 == 0:
			min_gap *= 0.85
		var c := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if c.length() > radius * 0.92:
			continue
		var clear := true
		for other in seeds:
			if other.distance_to(c) < min_gap:
				clear = false
				break
		if clear:
			seeds.append(c)
	# The berg's outline: its footprint, rounded off at its reach.
	var shape := PackedVector2Array()
	for k in 40:
		var a := TAU * k / 40.0
		shape.append(Vector2(cos(a), sin(a)) * radius)
	shape = _clip(shape, Vector2(area.position.x, 0.0), Vector2(-1.0, 0.0))
	shape = _clip(shape, Vector2(area.end.x, 0.0), Vector2(1.0, 0.0))
	shape = _clip(shape, Vector2(0.0, area.position.y), Vector2(0.0, -1.0))
	shape = _clip(shape, Vector2(0.0, area.end.y), Vector2(0.0, 1.0))
	for i in seeds.size():
		var cell := shape
		for j in seeds.size():
			if j != i:
				cell = _clip(cell, (seeds[i] + seeds[j]) * 0.5, seeds[j] - seeds[i])
		if cell.size() < 3:
			continue
		var middle := _centroid(cell)
		var outline := PackedVector2Array()
		for v in cell:
			outline.append(v - middle)
		_cells.append({"seed": seeds[i], "outline": outline, "middle": middle, "cell": cell})


## The part of `shape` on the near side of the line through `point` facing `away` (Sutherland–
## Hodgman, one edge).
static func _clip(shape: PackedVector2Array, point: Vector2, away: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := shape.size()
	for i in n:
		var a := shape[i]
		var b := shape[(i + 1) % n]
		var da := (a - point).dot(away)
		var db := (b - point).dot(away)
		if da <= 0.0:
			out.append(a)
		if (da < 0.0 and db > 0.0) or (da > 0.0 and db < 0.0):
			out.append(a.lerp(b, da / (da - db)))
	return out


static func _centroid(shape: PackedVector2Array) -> Vector2:
	var area := 0.0
	var c := Vector2.ZERO
	var n := shape.size()
	for i in n:
		var a := shape[i]
		var b := shape[(i + 1) % n]
		var cross := a.x * b.y - b.x * a.y
		area += cross
		c += (a + b) * cross
	if absf(area) < 0.0001:
		return shape[0]
	return c / (3.0 * area)


## The cracks along the seams between the pieces, in short ragged bits lying on the ice, hidden
## until the waddle gets heavy. Each bit grows outward from its end nearer the waddle.
func _draw_cracks() -> void:
	_crack_material = StandardMaterial3D.new()
	_crack_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_crack_material.albedo_color = CRACK_COLOUR
	var holder := Node3D.new()
	holder.name = "Cracks"
	add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = crack_seed + 7
	var spot3 := berg.to_local(berg.waddle_spot())
	var spot := Vector2(spot3.x, spot3.z)
	var bits: Array[Dictionary] = []
	for i in _cells.size():
		var cell: PackedVector2Array = _cells[i]["cell"]
		for e in cell.size():
			var a := cell[e]
			var b := cell[(e + 1) % cell.size()]
			if _seam_partner(i, (a + b) * 0.5) <= i:
				continue # the rim, or drawn from the other side
			var steps := maxi(ceili(a.distance_to(b) / CRACK_STEP), 1)
			var side := (b - a).normalized().orthogonal()
			var points: Array[Vector2] = []
			for k in steps + 1:
				var jitter := rng.randf_range(-CRACK_JITTER, CRACK_JITTER) if k > 0 and k < steps else 0.0
				points.append(a.lerp(b, float(k) / steps) + side * jitter)
			for k in steps:
				var from := points[k]
				var to := points[k + 1]
				if from.distance_to(spot) > to.distance_to(spot):
					var swap := from
					from = to
					to = swap
				bits.append({"from": from, "to": to, "near": from.distance_to(spot)})
	bits.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["near"] < y["near"])
	for bit in bits:
		var from := _ice_surface(bit["from"])
		var to := _ice_surface(bit["to"])
		if from == Vector3.INF or to == Vector3.INF:
			continue
		var length := from.distance_to(to)
		if length < 0.05 or absf(from.y - to.y) > length * 0.6:
			continue # a wall or a step in the way
		var box := BoxMesh.new()
		box.size = Vector3(0.07, 0.01, length)
		var mesh := MeshInstance3D.new()
		mesh.mesh = box
		mesh.material_override = _crack_material
		mesh.position = Vector3(0.0, 0.0, -length * 0.5)
		var crack := Node3D.new()
		crack.add_child(mesh)
		crack.visible = false
		holder.add_child(crack)
		crack.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)
		_cracks.append(crack)


## The berg's ice surface at local `xz` (world space, just above it), or Vector3.INF if there's
## none there.
func _ice_surface(xz: Vector2) -> Vector3:
	var top := berg.to_global(Vector3(xz.x, berg.top_height() + 3.0, xz.y))
	var query := PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * (berg.top_height() + 3.5), GameWorld.WORLD_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not berg.ice_bodies().has(hit["collider"]) or (hit["position"] as Vector3).y < GameWorld.WATER_LEVEL + 0.05:
		return Vector3.INF
	return (hit["position"] as Vector3) + Vector3.UP * 0.012


## The other cell whose seam with cell `i` runs through `point`, or -1 (it's on the rim).
func _seam_partner(i: int, point: Vector2) -> int:
	var mine := point.distance_to(_cells[i]["seed"])
	for j in _cells.size():
		if j != i and absf(point.distance_to(_cells[j]["seed"]) - mine) < 0.02:
			return j
	return -1


## Shows the cracks the heaviest the waddle has been calls for: none below crack_from, all of
## them at what the berg holds.
func _show_cracks() -> void:
	var k := clampf((_peak - tuning.crack_from) / maxf(1.0 - tuning.crack_from, 0.01), 0.0, 1.0)
	var want := roundi(_cracks.size() * k)
	if want <= _cracks_shown:
		return
	for i in range(_cracks_shown, want):
		var crack := _cracks[i]
		crack.visible = true
		crack.scale = Vector3(1.0, 1.0, 0.05)
		create_tween().tween_property(crack, "scale:z", 1.0, 0.2).set_delay((i - _cracks_shown) * 0.04)
	_cracks_shown = want
	# Anyone in the waddle feels it go.
	for node in get_tree().get_nodes_in_group(&"follow_cameras"):
		var cam := node as FollowCamera
		if cam.target() != null and in_waddle(cam.target()):
			cam.shake(0.05)


# --- Breaking through ------------------------------------------------------------------

## Everyone on the berg holds still for the scene: a player's controls go dead until it's over, and
## the colony's brains stop. Returns the players held.
func _hold_everyone() -> Array[Penguin]:
	var players: Array[Penguin] = []
	for p in _on_ice():
		if p.is_in_group(&"player") and not _held_inputs.has(p):
			_held_inputs[p] = p.input
			p.input = PenguinInput.new()
			players.append(p)
		for child in p.get_children():
			var brain := child as PenguinBrain
			if brain != null and brain.process_mode != Node.PROCESS_MODE_DISABLED:
				brain.process_mode = Node.PROCESS_MODE_DISABLED
				_held_brains.append(brain)
		p.wish_dir = Vector3.ZERO
		p.wish_action = false
	return players


## The ice bursts: the pieces take its place, everyone on it goes flying, its eggs and chicks are
## lost, its colony and the spawn points move, and the predators come.
func _burst() -> void:
	var thrown := _on_ice()
	var spawns := _spawns_on_ice()
	var lost := chicks()
	for body in berg.ice_bodies():
		if is_instance_valid(body):
			var tippable := TippableIce.of(body)
			if tippable != null:
				tippable.queue_free()
			body.visible = false
			var solid := body as CollisionObject3D
			if solid != null:
				solid.collision_layer = 0
	berg.remove_from_group(&"bergs")
	for crack in _cracks:
		crack.visible = false
	_make_pieces()
	for chick in lost:
		chick.lose()
	_move_colony()
	for pair in spawns:
		_move_spawn(pair[0], pair[1])
	_landings.clear()
	for p in thrown:
		_throw(p)
	var at := berg.waddle_spot()
	for node in get_tree().get_nodes_in_group(&"pods"):
		(node as PredatorPod).alert(at, tuning.frenzy_seconds)
	for node in get_tree().get_nodes_in_group(&"predators"):
		(node as Predator).alert(at, tuning.frenzy_seconds)
	_burst_chips(at)
	for cam in _cameras_on(_held_players()):
		cam.shake(0.25)
	broke_through.emit()
	get_tree().create_timer(tuning.scene_seconds, false).timeout.connect(_end_scene)
	get_tree().create_timer(tuning.spread_seconds + 0.25, false).timeout.connect(_settle_pieces)


## The colony that lived here is homeless: each moves to the nearest berg that still holds a
## waddle (or onto a piece, if there's none left).
func _move_colony() -> void:
	for brain in PenguinBrain.colony_of(berg).duplicate():
		var b := brain as PenguinBrain
		if not is_instance_valid(b) or not b.get_parent() is Node3D:
			continue
		var at := (b.get_parent() as Node3D).global_position
		var next := nearest(get_tree(), at, self)
		b.set_home(next.berg if next != null else _pieces[_cell_at(at)])
	for node in get_tree().get_nodes_in_group(&"penguins"):
		for child in (node as Node).get_children():
			var visitor := child as PenguinBrain
			if visitor != null and visitor.visiting() == berg:
				visitor.end_visit()


## Chips of ice flying up from under the waddle.
func _burst_chips(at: Vector3) -> void:
	var chip := BoxMesh.new()
	chip.size = Vector3(0.22, 0.12, 0.18)
	chip.material = IceBerg.ICE
	var chips := CPUParticles3D.new()
	chips.name = "IceChips"
	chips.mesh = chip
	chips.amount = 90
	chips.lifetime = 1.6
	chips.one_shot = true
	chips.explosiveness = 0.95
	chips.direction = Vector3.UP
	chips.spread = 55.0
	chips.gravity = Vector3(0.0, -9.8, 0.0)
	chips.initial_velocity_min = 4.0
	chips.initial_velocity_max = 9.0
	chips.angular_velocity_min = -540.0
	chips.angular_velocity_max = 540.0
	chips.scale_amount_min = 0.5
	chips.scale_amount_max = 1.6
	chips.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	chips.emission_sphere_radius = tuning.waddle_radius * 0.6
	chips.top_level = true
	add_child(chips)
	chips.global_position = at
	chips.emitting = true
	get_tree().create_timer(3.0, false).timeout.connect(chips.queue_free)


## The pieces, where the old ice was, top level with its top: they bob under and back up, and push
## apart from the middle.
func _make_pieces() -> void:
	_piece_holder = Node3D.new()
	_piece_holder.name = "%sPieces" % berg.name
	var level := get_parent() if get_parent() != null else self
	level.add_child(_piece_holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = crack_seed + 1
	var centre := berg.global_position
	var turn := berg.global_basis.orthonormalized()
	var start_top := minf(berg.top_height(), 1.5)
	for i in _cells.size():
		var middle: Vector2 = _cells[i]["middle"]
		var at := berg.to_global(Vector3(middle.x, 0.0, middle.y))
		at.y = GameWorld.WATER_LEVEL
		var out := Vector3(at.x - centre.x, 0.0, at.z - centre.z)
		var a := rng.randf() * TAU
		out = out.normalized() if out.length() > 0.5 else Vector3(cos(a), 0.0, sin(a))
		_piece_from.append(at)
		_piece_to.append(at + out * rng.randf_range(tuning.spread.x, tuning.spread.y))
		var piece := FLOE_PIECE_SCRIPT.new() as FloePiece
		piece.name = "Piece%d" % i
		piece.outline = _cells[i]["outline"]
		piece.freeboard = tuning.piece_freeboard
		piece.draft = tuning.piece_draft
		# Its top starts about where the old top was.
		piece.transform = Transform3D(turn, at + Vector3.UP * (start_top - tuning.piece_freeboard))
		_piece_holder.add_child(piece)
		_pieces.append(piece)
		var bob := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		bob.tween_property(piece, "position:y", GameWorld.WATER_LEVEL - tuning.dip_depth, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		bob.tween_property(piece, "position:y", GameWorld.WATER_LEVEL + 0.25, 0.8).set_trans(Tween.TRANS_SINE)
		bob.tween_property(piece, "position:y", GameWorld.WATER_LEVEL, 0.9).set_trans(Tween.TRANS_SINE)
		var rock := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		var tilt := Vector3(rng.randf_range(-0.09, 0.09), 0.0, rng.randf_range(-0.09, 0.09))
		rock.tween_property(piece, "rotation", piece.rotation + tilt, 0.5).set_trans(Tween.TRANS_SINE)
		rock.tween_property(piece, "rotation", piece.rotation - tilt * 0.5, 0.7).set_trans(Tween.TRANS_SINE)
		rock.tween_property(piece, "rotation", piece.rotation, 0.8).set_trans(Tween.TRANS_SINE)
		var drift := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		drift.tween_method(_spread_piece.bind(i), 0.0, 1.0, tuning.spread_seconds)


func _spread_piece(t: float, i: int) -> void:
	var piece := _pieces[i]
	if not is_instance_valid(piece):
		return
	var at := _piece_from[i].lerp(_piece_to[i], _spread_ease(t))
	piece.position.x = at.x
	piece.position.z = at.z


## How far along its spread a piece is (0 to 1) at `t` of the way through: most of it at first (so
## the gaps are open by the time the penguins come down), then easing to a stop.
static func _spread_ease(t: float) -> float:
	var k := clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 4.0)


## Which piece's cell `point` (world) is in, or the nearest.
func _cell_at(point: Vector3) -> int:
	var local := berg.to_local(point)
	var p := Vector2(local.x, local.z)
	var best := 0
	var best_d := INF
	for i in _cells.size():
		var middle: Vector2 = _cells[i]["middle"]
		if FloePiece.contains(_cells[i]["outline"], p - middle):
			return i
		var d := p.distance_to(middle)
		if d < best_d:
			best_d = d
			best = i
	return best


## Penguins standing (or in the air) on the berg's ice.
func _on_ice() -> Array[Penguin]:
	var list: Array[Penguin] = []
	for node in get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p != null and p.state != Penguin.State.SWIM and _over_ice(p.global_position):
			list.append(p)
	return list


## Every penguin whose spawn point is on the berg, with that spot.
func _spawns_on_ice() -> Array:
	var list := []
	for node in get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p != null and _over_ice(p.spawn_point()):
			list.append([p, p.spawn_point()])
	return list


func _over_ice(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.3, point + Vector3.DOWN * 8.0, GameWorld.WORLD_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and berg.ice_bodies().has(hit["collider"])


## `p` respawns on the piece its old spawn point was on, at the same spot on it.
func _move_spawn(p: Penguin, spawn: Vector3) -> void:
	if not is_instance_valid(p):
		return
	var i := _cell_at(spawn)
	var middle: Vector2 = _cells[i]["middle"]
	var local := berg.to_local(spawn)
	var on := Vector2(local.x, local.z) - middle
	if not FloePiece.contains(_cells[i]["outline"], on, 0.8):
		on = Vector2.ZERO
	var at := _piece_to[i] + berg.global_basis.orthonormalized() * Vector3(on.x, 0.0, on.y)
	at.y = GameWorld.WATER_LEVEL + tuning.piece_freeboard + 0.45
	p.set_spawn_point(at)


## Throws `p` up off the bursting ice, flailing, to come down in the water between the pieces.
func _throw(p: Penguin) -> void:
	var g := p.tuning.gravity
	var up := tuning.toss_speed * randf_range(0.9, 1.12)
	var height := maxf(p.global_position.y - GameWorld.WATER_LEVEL, 0.0)
	var seconds := (up + sqrt(up * up + 2.0 * g * height)) / g
	var spot := _landing_spot(p.global_position, seconds)
	_landings.append(spot)
	var launch := (spot - p.global_position) / seconds
	launch.y = up
	p.toss(launch)
	p.flail(tuning.flail_seconds)
	# Its brain comes back on when it lands (in the water, or on a piece after all).
	if _held_brains.any(func(b: PenguinBrain) -> bool: return is_instance_valid(b) and b.get_parent() == p):
		p.state_changed.connect(_on_landed.bind(p), CONNECT_ONE_SHOT)


func _on_landed(_state: Penguin.State, p: Penguin) -> void:
	for brain in _held_brains:
		if is_instance_valid(brain) and brain.get_parent() == p:
			brain.process_mode = Node.PROCESS_MODE_INHERIT


## A spot in the water near `from` that's clear of every piece `seconds` after the burst and once
## they've stopped, and of other ice; outward and close are best, and not on top of someone else.
func _landing_spot(from: Vector3, seconds: float) -> Vector3:
	var centre := berg.global_position
	var out := Vector3(from.x - centre.x, 0.0, from.z - centre.z)
	out = out.normalized() if out.length() > 0.5 else Vector3.BACK
	var best := Vector3.INF
	var best_score := INF
	var r := LANDING_STEP
	while r <= LANDING_SEARCH:
		var count := 10 + roundi(r * 1.5)
		for k in count:
			var a := TAU * (k + randf() * 0.5) / count
			var dir := Vector3(cos(a), 0.0, sin(a))
			var spot := Vector3(from.x, GameWorld.WATER_LEVEL, from.z) + dir * r
			var score := r - 2.0 * dir.dot(out)
			for other in _landings:
				if other.distance_to(spot) < 1.2:
					score += 3.0
			if score >= best_score:
				continue
			if _over_pieces(spot, seconds) or _over_pieces(spot, tuning.spread_seconds) or not _open_water(spot):
				continue
			best_score = score
			best = spot
		r += LANDING_STEP
	return best if best != Vector3.INF else Vector3(from.x, GameWorld.WATER_LEVEL, from.z) + out * LANDING_SEARCH


## Is `spot` over a piece (or within LANDING_CLEARANCE of one) `seconds` after the burst?
func _over_pieces(spot: Vector3, seconds: float) -> bool:
	var k := _spread_ease(seconds / maxf(tuning.spread_seconds, 0.01))
	var turn := berg.global_basis.orthonormalized().inverse()
	for i in _cells.size():
		var local := turn * (spot - _piece_from[i].lerp(_piece_to[i], k))
		if FloePiece.contains(_cells[i]["outline"], Vector2(local.x, local.z), -LANDING_CLEARANCE):
			return true
	return false


## No other ice at `spot` (the pieces aside).
func _open_water(spot: Vector3) -> bool:
	var exclude: Array[RID] = []
	for piece in _pieces:
		exclude.append(piece.get_rid())
	var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 6.0, spot + Vector3.DOWN * 1.0, GameWorld.WORLD_LAYER, exclude)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## The scene's over: the players get their controls back, and any colony penguin still held gets
## its brain back.
func _end_scene() -> void:
	phase = Phase.BROKEN
	for held: Variant in _held_inputs:
		if is_instance_valid(held):
			(held as Penguin).input = _held_inputs[held]
	_held_inputs.clear()
	for brain in _held_brains:
		if is_instance_valid(brain):
			brain.process_mode = Node.PROCESS_MODE_INHERIT
	_held_brains.clear()
	scene_over.emit()


## The pieces have stopped: from now on they're ice an orca can tip, like any floe.
func _settle_pieces() -> void:
	for piece in _pieces:
		if not is_instance_valid(piece):
			continue
		var ice := TippableIce.new()
		ice.name = "Tippable%s" % piece.name
		ice.position = Vector3(piece.position.x, GameWorld.WATER_LEVEL, piece.position.z)
		ice.radius = piece.reach()
		ice.bodies.append(NodePath("../" + piece.name))
		_piece_holder.add_child(ice)


func _held_players() -> Array[Penguin]:
	var list: Array[Penguin] = []
	for held: Variant in _held_inputs:
		if is_instance_valid(held):
			list.append(held as Penguin)
	return list


## The cameras following any of `players`.
func _cameras_on(players: Array[Penguin]) -> Array[FollowCamera]:
	var list: Array[FollowCamera] = []
	for node in get_tree().get_nodes_in_group(&"follow_cameras"):
		var cam := node as FollowCamera
		if cam != null and players.has(cam.target()):
			list.append(cam)
	return list


## The cameras of the players on the berg hold a wide shot of its waddle for `seconds`, from the
## side they were on.
func _frame_cameras(players: Array[Penguin], seconds: float) -> void:
	var focus := berg.waddle_spot()
	for cam in _cameras_on(players):
		var away := cam.global_position - focus
		away.y = 0.0
		away = away.normalized() if away.length() > 0.5 else Vector3.BACK
		cam.frame(focus, focus + away * 20.0 + Vector3.UP * 12.0, seconds)
