@tool
class_name IceBerg
extends StaticBody3D
## A berg in the berg field (GDD §4.10). Each kind (TabularBerg, WedgeBerg, DrydockBerg,
## PinnacleBerg, DomeBerg) builds its own shape in _build() from plain boxes, like IcePlateau, so
## every height and width is a number in the Inspector, and it rebuilds live in the editor.
##
## The shapes are the real kinds of berg (the International Ice Patrol's classes), at penguin
## scale: bergy bits and small bergs, 1–6 m above the water. Below the waterline each one has its
## real height-to-draft ratio (tabular, wedge and blocky 1:5, dome 1:4, pinnacle 1:2, drydock 1:1),
## so the bigger ones have deep keels that predators have to swim round or under.
##
## Every berg answers the same questions, for the predators, the fish, the NPC penguins and the
## smoke test: how far it reaches, how high it stands (waves only wash low ice), where its colony
## huddles, how you get out of the water onto it, and where its tunnels run.
##
## Local space: the waterline is y = 0, the berg's middle is the origin.

const ICE := preload("res://art/materials/ice.tres")
const SLICK := preload("res://art/materials/ice_slick.tres")
const KEEL := preload("res://art/materials/ice_keel.tres")
## Keels go no deeper than this (m): the seafloor in the movement toy is at 30 m.
const MAX_DRAFT := 25.0

## How many NPC penguins huddle on this berg (the level spawns them at its waddle spot).
@export var colony := 0
## How much weight its waddle holds before the berg breaks up (WaddleIce). 0: worked out from its
## size (WaddleTuning.holds_per_metre × its reach).
@export var holds := 0.0

var _rebuild_queued := false


func _ready() -> void:
	add_to_group(&"bergs")
	collision_layer = GameWorld.WORLD_LAYER
	collision_mask = 0
	_rebuild()


# --- What every berg answers (world space) --------------------------------------

## How far the berg reaches from its middle, keel and all (m). Predators patrol outside this;
## fish keep clear of it.
func reach() -> float:
	return 10.0


## How high the berg's main top stands above the water (m).
func top_height() -> float:
	return 1.0


## Where its colony huddles: on the ice, at the top's surface.
func waddle_spot() -> Vector3:
	return to_global(Vector3(0.0, top_height(), 0.0))


## Ways out of the water: each {"at": a spot on the surface just off the ice, "toward": the flat
## direction into the ice, "launch": true if you boost and launch out there, false for a ramp or
## shelf you can swim straight up, and optionally "climb": spots to walk through on the way up}.
func exits() -> Array[Dictionary]:
	return []


## Tunnels through the berg: each {"from", "to": the two ends (just outside the ice), "width",
## "height", "swim": true for one under the water}.
func tunnels() -> Array[Dictionary]:
	return []


## Can a waddle huddle here (and so lay eggs, and break it)? Every berg can; a piece of a broken one
## can't (FloePiece).
func holds_waddle() -> bool:
	return true


## The bodies that make up its ice: what goes when it breaks up. Usually just itself.
func ice_bodies() -> Array[Node3D]:
	return [self]


## Its ice seen from above, at the waterline (local x, z): what the pieces are cut from when it
## breaks. Worked out from the pieces it built; a square of its reach if it built none.
func footprint() -> Rect2:
	var area := Rect2()
	var first := true
	for child in get_children():
		var col := child as CollisionShape3D
		var view := col.get_node_or_null("Mesh") as MeshInstance3D if col != null else null
		if view == null or not child.has_meta(&"generated"):
			continue
		var box := col.transform * view.get_aabb()
		if box.end.y < 0.05:
			continue # all under water (a keel)
		var flat := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		area = flat if first else area.merge(flat)
		first = false
	if first:
		var r := reach()
		return Rect2(-r, -r, r * 2.0, r * 2.0)
	return area


## Draft for a freeboard of `height` with this kind's real height-to-draft ratio `ratio`.
static func draft_for(height: float, ratio: float) -> float:
	return minf(height * ratio, MAX_DRAFT)


# --- Building ----------------------------------------------------------------

## Each kind of berg builds itself here, with box(), slope(), steps(), keel() and frustum().
func _build() -> void:
	pass


func queue_rebuild() -> void:
	if not is_node_ready() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.queue_free()
	_build()


## A box of ice `size` big, centred on `centre` (local), turned by `basis`.
func box(piece_name: String, size: Vector3, centre: Vector3, mat: Material = ICE, basis := Basis.IDENTITY) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	_add_piece(piece_name, shape, mesh, Transform3D(basis, centre))


## A box of ice spanning from `low` to `high` (local corners).
func box_between(piece_name: String, low: Vector3, high: Vector3, mat: Material = ICE) -> void:
	var size := (high - low).abs()
	if size.x < 0.01 or size.y < 0.01 or size.z < 0.01:
		return
	box(piece_name, size, (low + high) * 0.5, mat)


## A ramp or chute: a slab whose top surface starts at `foot` (local, the middle of its low edge)
## and climbs `rise` metres at `angle_deg` along the flat direction `up_dir`, `width` wide. Under
## 14° you can walk it; steeper, it's a chute you slide down.
func slope(piece_name: String, foot: Vector3, up_dir: Vector3, rise: float, angle_deg: float, width: float, mat: Material = ICE, thickness := 1.5) -> void:
	var a := deg_to_rad(clampf(angle_deg, 2.0, 60.0))
	var flat := Vector3(up_dir.x, 0.0, up_dir.z).normalized()
	var along := (flat * cos(a) + Vector3.UP * sin(a)).normalized()
	var normal := (Vector3.UP * cos(a) - flat * sin(a)).normalized()
	var lateral := normal.cross(along).normalized()
	var length := rise / sin(a)
	var centre := foot + along * (length * 0.5) - normal * (thickness * 0.5)
	box(piece_name, Vector3(width, thickness, length), centre, mat, Basis(lateral, normal, along))


## A flight of steps from `foot` (local, on the ground in front of the first step) climbing `rise`
## in steps about `step_rise` high and `step_depth` deep along the flat direction `dir`. Each step
## runs back to the end of the flight, so there are no gaps underneath, and reaches `below` under
## the foot (into the ice it stands on). Returns the top (local).
func steps(piece_name: String, foot: Vector3, dir: Vector3, rise: float, step_rise: float, step_depth: float, width: float, mat: Material = ICE, below := 0.5) -> Vector3:
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var count := maxi(roundi(rise / step_rise), 1)
	var each := rise / count
	var side := Vector3.UP.cross(flat).normalized()
	for k in range(1, count + 1):
		var start := foot + flat * (k - 1) * step_depth
		var length := (count - k + 1) * step_depth
		var top := foot.y + each * k
		var centre := start + flat * (length * 0.5)
		centre.y = (top + foot.y - below) * 0.5
		var size := Vector3(width, top - foot.y + below, length)
		box("%s%d" % [piece_name, k], size, centre, mat, Basis(side, Vector3.UP, flat))
	return foot + flat * count * step_depth + Vector3.UP * rise


## The berg below the waterline: a block `size.x` by `size.z`, `size.y` deep, centred on
## `centre_xz`, up to `top_y` (keep it under any slope that runs down into the water). With a
## tunnel, it leaves a passage through it: {"axis": "x" or "z" (which way it runs), "depth": of its
## middle below the surface, "width", "height", "offset": sideways from the middle}.
func keel(size: Vector3, centre_xz := Vector2.ZERO, tunnel := {}, top_y := 0.0) -> void:
	var lo := Vector3(centre_xz.x - size.x * 0.5, -size.y, centre_xz.y - size.z * 0.5)
	var hi := Vector3(centre_xz.x + size.x * 0.5, top_y, centre_xz.y + size.z * 0.5)
	if tunnel.is_empty():
		box_between("Keel", lo, hi, KEEL)
		return
	var depth: float = tunnel["depth"]
	var half_w: float = tunnel["width"] * 0.5
	var half_h: float = tunnel["height"] * 0.5
	var roof := -(depth - half_h)
	var floor_y := -(depth + half_h)
	box_between("KeelTop", Vector3(lo.x, roof, lo.z), hi, KEEL)
	box_between("KeelBottom", lo, Vector3(hi.x, floor_y, hi.z), KEEL)
	if tunnel["axis"] == "x":
		var mid: float = centre_xz.y + tunnel.get("offset", 0.0)
		box_between("KeelSideA", Vector3(lo.x, floor_y, lo.z), Vector3(hi.x, roof, mid - half_w), KEEL)
		box_between("KeelSideB", Vector3(lo.x, floor_y, mid + half_w), Vector3(hi.x, roof, hi.z), KEEL)
	else:
		var mid: float = centre_xz.x + tunnel.get("offset", 0.0)
		box_between("KeelSideA", Vector3(lo.x, floor_y, lo.z), Vector3(mid - half_w, roof, hi.z), KEEL)
		box_between("KeelSideB", Vector3(mid + half_w, floor_y, lo.z), Vector3(hi.x, roof, hi.z), KEEL)


## The two ends of a keel tunnel (world space), `beyond` metres outside the ice.
func keel_tunnel_ends(size: Vector3, centre_xz: Vector2, tunnel: Dictionary, beyond := 1.5) -> Array[Vector3]:
	var depth: float = tunnel["depth"]
	var off: float = tunnel.get("offset", 0.0)
	if tunnel["axis"] == "x":
		var z := centre_xz.y + off
		return [to_global(Vector3(centre_xz.x - size.x * 0.5 - beyond, -depth, z)), to_global(Vector3(centre_xz.x + size.x * 0.5 + beyond, -depth, z))]
	var x := centre_xz.x + off
	return [to_global(Vector3(x, -depth, centre_xz.y - size.z * 0.5 - beyond)), to_global(Vector3(x, -depth, centre_xz.y + size.z * 0.5 + beyond))]


## A round piece narrowing upward (a cone with its top cut off), from `base_y` to `base_y +
## height`. Its sides are as steep as the radii make them: steeper than 14° and you slide.
func frustum(piece_name: String, bottom_radius: float, top_radius: float, height: float, base_y: float, mat: Material = ICE) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = 32
	mesh.material = mat
	var shape := mesh.create_convex_shape(true, false)
	_add_piece(piece_name, shape, mesh, Transform3D(Basis.IDENTITY, Vector3(0.0, base_y + height * 0.5, 0.0)))


## A round block (a cylinder) from `bottom_y` up to `top_y`.
func cylinder(piece_name: String, radius: float, bottom_y: float, top_y: float, mat: Material = ICE) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = top_y - bottom_y
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = top_y - bottom_y
	mesh.radial_segments = 32
	mesh.material = mat
	_add_piece(piece_name, shape, mesh, Transform3D(Basis.IDENTITY, Vector3(0.0, (top_y + bottom_y) * 0.5, 0.0)))


func _add_piece(piece_name: String, shape: Shape3D, mesh: Mesh, xform: Transform3D) -> void:
	var col := CollisionShape3D.new()
	col.name = piece_name
	col.shape = shape
	col.transform = xform
	col.set_meta(&"generated", true)
	var view := MeshInstance3D.new()
	view.name = "Mesh"
	view.mesh = mesh
	col.add_child(view)
	# No owner on purpose: the pieces are rebuilt from the numbers, never saved into the scene.
	add_child(col)


## A spot on the surface `out` metres off the ice at local `edge` (on the waterline), facing in.
func exit_at(edge: Vector3, into: Vector3, out: float, launch: bool) -> Dictionary:
	var flat := Vector3(into.x, 0.0, into.z).normalized()
	var at := to_global(Vector3(edge.x, 0.0, edge.z) - flat * out)
	return {"at": at, "toward": (global_basis * flat).normalized(), "launch": launch}
