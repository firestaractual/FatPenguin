@tool
class_name FloePiece
extends IceBerg
## A piece of a broken berg: a flat slab of ice cut to any convex outline, standing `freeboard`
## above the water and `draft` deep (WaddleIce breaks a berg into these when the waddle
## gets too fat for it). It answers the berg questions like any other berg, so predators patrol
## round it, fish keep clear of it and a colony can live on it. Its edge is low, so you can launch
## onto it from anywhere round it.
##
## Local space: the waterline is y = 0, and the outline is round the origin (its middle).

## The outline seen from above (local x, z), convex, going round either way.
@export var outline := PackedVector2Array([Vector2(-3.0, -3.0), Vector2(3.0, -3.0), Vector2(3.0, 3.0), Vector2(-3.0, 3.0)]):
	set(value):
		outline = value
		queue_rebuild()
@export var freeboard := 0.6:
	set(value):
		freeboard = value
		queue_rebuild()
@export var draft := 3.0:
	set(value):
		draft = value
		queue_rebuild()
## Exits are only on edges at least this long (m).
@export var min_exit_edge := 2.5


func reach() -> float:
	var r := 0.0
	for v in outline:
		r = maxf(r, v.length())
	return r


func top_height() -> float:
	return freeboard


## Too small for a waddle: nobody lays eggs on a piece, and it doesn't break again.
func holds_waddle() -> bool:
	return false


## A launch spot off the middle of every long enough edge, facing in.
func exits() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var n := outline.size()
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		if a.distance_to(b) < min_exit_edge:
			continue
		var mid := (a + b) * 0.5
		var out := _outward(a, b)
		list.append(exit_at(Vector3(mid.x, 0.0, mid.y), Vector3(-out.x, 0.0, -out.y), 4.5, true))
	return list


## Is `point` (world space) over this piece, `margin` metres in from its edge (out from it if
## negative)?
func covers(point: Vector3, margin := 0.0) -> bool:
	var local := to_local(point)
	return contains(outline, Vector2(local.x, local.z), margin)


## Is `p` inside the convex `shape` (x, z), `margin` metres in from its edge (out from it if
## negative)?
static func contains(shape: PackedVector2Array, p: Vector2, margin := 0.0) -> bool:
	var n := shape.size()
	if n < 3:
		return false
	for i in n:
		var a := shape[i]
		var b := shape[(i + 1) % n]
		if (p - a).dot(_outward(a, b)) > -margin:
			return false
	return true


# --- Building ----------------------------------------------------------------

func _build() -> void:
	var n := outline.size()
	if n < 3:
		return
	var ice := SurfaceTool.new()
	ice.begin(Mesh.PRIMITIVE_TRIANGLES)
	ice.set_material(ICE)
	var keel := SurfaceTool.new()
	keel.begin(Mesh.PRIMITIVE_TRIANGLES)
	keel.set_material(KEEL)
	var top := freeboard
	var bottom := -draft
	var points := PackedVector3Array()
	# The top and the bottom, fanned from the middle.
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		_tri(ice, Vector3(0.0, top, 0.0), Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), Vector3.UP)
		_tri(keel, Vector3(0.0, bottom, 0.0), Vector3(a.x, bottom, a.y), Vector3(b.x, bottom, b.y), Vector3.DOWN)
		# The sides: ice above the water, keel below it.
		var out2 := _outward(a, b)
		var out := Vector3(out2.x, 0.0, out2.y)
		_quad(ice, Vector3(a.x, 0.0, a.y), Vector3(b.x, 0.0, b.y), top, out)
		_quad(keel, Vector3(a.x, bottom, a.y), Vector3(b.x, bottom, b.y), -bottom, out)
		points.append(Vector3(a.x, top, a.y))
		points.append(Vector3(a.x, bottom, a.y))
	var mesh := ice.commit()
	keel.commit(mesh)
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	_add_piece("Slab", shape, mesh, Transform3D.IDENTITY)


## The outward flat normal of the edge from `a` to `b` (of a shape round the origin).
static func _outward(a: Vector2, b: Vector2) -> Vector2:
	var along := (b - a).normalized()
	var normal := Vector2(along.y, -along.x)
	var mid := (a + b) * 0.5
	return normal if normal.dot(mid) >= 0.0 else -normal


## A triangle seen from `out` (Godot's front faces wind clockwise as you look at them).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	if (b - a).cross(c - a).dot(out) > 0.0:
		var swap := b
		b = c
		c = swap
	for v: Vector3 in [a, b, c]:
		st.set_normal(out)
		st.add_vertex(v)


## A wall from the edge `a`–`b` up `height`, seen from `out`.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, height: float, out: Vector3) -> void:
	var up := Vector3.UP * height
	_tri(st, a, b, b + up, out)
	_tri(st, a, b + up, a + up, out)
