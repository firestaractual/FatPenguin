class_name IceEdges
extends RefCounted
## Questions about where the ice ends, for predators planning an attack: the edge of the ice a
## penguin is standing on (where it would go in), and the nearest ice to a penguin in the water
## (its way home). Everything counts as ice that's on the world layer and above the water: the
## berg, its ramp and the floes.

## The search along the ice steps this far at a time (m).
const EDGE_STEP := 0.5
## Directions tried when looking for the nearest edge or shore.
const DIRECTIONS := 16
const SHORE_DIRECTIONS := 24
## Shore rays run this high above the water: they hit the side of the ice, or a ramp's slope.
const SHORE_RAY_HEIGHT := 0.15


## Walks from `from` (a spot on the ice) toward `dir` looking for the edge, up to `reach` metres.
## Returns {"point": the last spot of ice before the water} or {} if the edge isn't that close.
static func edge_toward(world: World3D, from: Vector3, dir: Vector3, reach: float) -> Dictionary:
	var space := world.direct_space_state
	var last := {}
	var d := 0.0
	while d <= reach:
		var at := from + dir * d
		var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, from.y + 1.5, at.z), Vector3(at.x, GameWorld.WATER_LEVEL - 1.0, at.z), GameWorld.WORLD_LAYER)
		var hit := space.intersect_ray(query)
		if hit.is_empty() or (hit["position"] as Vector3).y < GameWorld.WATER_LEVEL + 0.05:
			return last
		last = {"point": hit["position"]}
		d += EDGE_STEP
	return {}


## The nearest edge of the ice under `from`, within `reach`: {"point", "out" (flat, toward the
## water), "distance"}, or {} if there's no edge that close.
static func nearest_edge(world: World3D, from: Vector3, reach: float) -> Dictionary:
	var best := {}
	var best_distance := INF
	for i in DIRECTIONS:
		var angle := TAU * i / DIRECTIONS
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var edge := edge_toward(world, from, dir, minf(reach, best_distance))
		if edge.is_empty():
			continue
		var point: Vector3 = edge["point"]
		var distance := Vector2(point.x - from.x, point.z - from.z).length()
		if distance < best_distance:
			best_distance = distance
			best = {"point": point, "out": dir, "distance": distance}
	return best


## The nearest ice to a penguin in the water at `from`, within `reach`: {"point" (on the side of
## the ice, at the waterline), "dir" (flat, from `from` toward it), "distance"}, or {} if there's
## no ice that close: open water.
static func nearest_shore(world: World3D, from: Vector3, reach: float) -> Dictionary:
	var space := world.direct_space_state
	var start := Vector3(from.x, GameWorld.WATER_LEVEL + SHORE_RAY_HEIGHT, from.z)
	var best := {}
	var best_distance := INF
	for i in SHORE_DIRECTIONS:
		var angle := TAU * i / SHORE_DIRECTIONS
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var query := PhysicsRayQueryParameters3D.create(start, start + dir * reach, GameWorld.WORLD_LAYER)
		query.hit_from_inside = false
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var point: Vector3 = hit["position"]
		var distance := Vector2(point.x - from.x, point.z - from.z).length()
		if distance < best_distance:
			best_distance = distance
			best = {"point": point, "dir": dir, "distance": distance}
	return best


## How far a penguin in the water at `from` is from the nearest ice (m); INF if none is within
## `reach`.
static func shore_distance(world: World3D, from: Vector3, reach: float) -> float:
	var shore := nearest_shore(world, from, reach)
	return shore["distance"] if not shore.is_empty() else INF
