class_name Fish
extends Area3D
## A single fish. Swim into it to eat it. Respawns after a delay so the toy never runs dry.
##
## With a species, the fish schools: it's pulled toward fish of its own species within school
## range, keeps a little personal space, matches their heading and stays near its home spot.
## It ignores every other species, so schools stay single-species. School mates slowly share
## one home spot, so a school that forms stays formed, and an eaten fish comes back beside its
## school (see docs/GDD.md §4.11).
##
## Without a species (spilled fish, test fish) it swims a small lazy circle around where it was
## placed, or holds still if circle_radius is 0.

## What kind of fish this is. Set it before the fish enters the tree; leave it empty for a fish
## that doesn't school.
@export var species: FishSpecies
## No-species fish only: the lazy circle around where the fish was placed.
@export var circle_radius := 0.8
@export var circle_speed := 0.6
@export var respawn_seconds := 8.0
## Spilled fish (knocked loose in a bump) are eaten once and gone.
@export var one_shot := false
## Can't be eaten by anyone for this long after appearing.
@export var pickup_delay := 0.0
## This body (the penguin that spilled the fish) can't eat it for ignore_seconds.
var ignore_body: Node = null
@export var ignore_seconds := 0.0

## The spot this fish stays near (global position). School mates slowly share theirs.
var home := Vector3.ZERO
## Current swimming velocity (schooling fish only).
var velocity := Vector3.ZERO

## How often each fish looks for its nearest school mates (s); FAR_STEP times less often when
## it's far away. Searches are staggered across fish so they don't all land on the same frame.
const NEIGHBOUR_REFRESH := 0.25
## Schooling fish never come closer to the surface than this (m).
const MIN_DEPTH := 0.3
## Fish swim mostly level: vertical steering is scaled by this, and vertical speed is capped
## at this share of cruising speed.
const VERTICAL_SHARE := 0.35
## Schooling fish farther than this from the camera (m) are lost in the underwater fog, so they
## only take a (bigger) step every FAR_STEP physics frames. Roughly halves their cost.
const FAR_DISTANCE := 40.0
const FAR_STEP := 4

## Every schooling fish in the scene, by species. How fish find their school mates.
static var _by_species := {}
## The camera position, fetched once per physics frame by whichever fish asks first.
static var _viewer_frame := -1
static var _viewer_pos := Vector3.ZERO
static var _has_viewer := false

var _phase := 0.0
var _age := 0.0
var _speed := 0.0
var _wander_dir := Vector3.FORWARD
var _refresh := 0.0
var _neighbours: Array[Fish] = []
## Where this fish was at its last schooling step. School mates read this instead of
## global_position, which is slower to fetch.
var _pos := Vector3.ZERO
## Time since this fish last took a schooling step (more than one frame when it's far away).
var _pending := 0.0
## Spreads far fish's steps across frames.
var _step_offset := 0
var _far := false

@onready var _model: Node3D = $Model


func _enter_tree() -> void:
	if species == null:
		return
	if not _by_species.has(species):
		_by_species[species] = []
	(_by_species[species] as Array).append(self)


func _exit_tree() -> void:
	if species == null or not _by_species.has(species):
		return
	var mates := _by_species[species] as Array
	mates.erase(self)
	if mates.is_empty():
		_by_species.erase(species)


func _ready() -> void:
	home = global_position
	_phase = randf() * TAU
	collision_layer = 0
	collision_mask = GameWorld.PENGUIN_LAYER
	body_entered.connect(_on_body_entered)
	if pickup_delay > 0.0:
		monitoring = false
		get_tree().create_timer(pickup_delay, false).timeout.connect(func() -> void: monitoring = true)
	if species != null:
		_pos = global_position
		_speed = species.swim_speed * (1.0 + randf_range(-species.speed_variation, species.speed_variation))
		var angle := randf() * TAU
		_wander_dir = Vector3(cos(angle), 0.0, sin(angle))
		velocity = _wander_dir * _speed
		_refresh = randf() * NEIGHBOUR_REFRESH
		_step_offset = randi() % FAR_STEP
		_model.scale = Vector3.ONE * species.body_scale
		if species.material != null:
			for mesh: MeshInstance3D in [$Model/Body, $Model/Tail]:
				mesh.material_override = species.material


func _physics_process(delta: float) -> void:
	_age += delta
	if species == null:
		_swim_circle(delta)
		return
	if not visible:
		return
	_pending += delta
	_far = _is_far()
	if _far and (Engine.get_physics_frames() + _step_offset) % FAR_STEP != 0:
		return
	_swim_in_school(_pending)
	_pending = 0.0


## True when this fish is too far from the camera to be seen. With no camera, nothing is far.
func _is_far() -> bool:
	var frame := Engine.get_physics_frames()
	if frame != _viewer_frame:
		_viewer_frame = frame
		var camera := get_viewport().get_camera_3d()
		_has_viewer = camera != null
		if _has_viewer:
			_viewer_pos = camera.global_position
	return _has_viewer and _pos.distance_squared_to(_viewer_pos) > FAR_DISTANCE * FAR_DISTANCE


func _swim_circle(delta: float) -> void:
	_phase += circle_speed * delta
	var offset := Vector3(cos(_phase), sin(_phase * 2.0) * 0.15, sin(_phase)) * circle_radius
	# Face along the circle.
	var forward := Vector3(-sin(_phase), 0.0, cos(_phase))
	global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), home + offset)


func _swim_in_school(delta: float) -> void:
	var s := species
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = NEIGHBOUR_REFRESH * (FAR_STEP if _far else 1)
		_find_neighbours()

	var pos := global_position
	_pos = pos
	var steer := Vector3.ZERO

	# The swarm pull: toward the middle of the school mates in range, matching their heading,
	# without crowding them. Other species aren't in the list, so they never pull.
	var to_centre := Vector3.ZERO
	var heading := Vector3.ZERO
	var mates_home := Vector3.ZERO
	var count := 0
	var school_range := s.school_range
	var personal_space := s.personal_space
	for mate: Fish in _neighbours:
		if not is_instance_valid(mate) or not mate.visible:
			continue
		var offset := mate._pos - pos
		var dist := offset.length()
		if dist > school_range:
			continue
		count += 1
		to_centre += offset
		heading += mate.velocity
		mates_home += mate.home
		if dist < personal_space and dist > 0.001:
			steer -= offset / dist * (1.0 - dist / personal_space) * s.separation
	if count > 0:
		steer += to_centre / count * s.cohesion
		steer += (heading / count - velocity) * s.alignment
		# Share the school's home spot, so the school stays together where it formed.
		home = home.lerp(mates_home / count, minf(s.home_merge_rate * delta, 1.0))

	# Meander: a slowly turning random nudge.
	var jitter := Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3), randf_range(-1.0, 1.0))
	_wander_dir = (_wander_dir + jitter * 2.0 * delta).normalized()
	steer += _wander_dir * s.wander

	# Stay near home.
	var from_home := pos - home
	var past := from_home.length() - s.roam_radius
	if past > 0.0:
		steer -= from_home.normalized() * past * s.home_pull

	# Hold cruising speed: fish never hover.
	var speed := velocity.length()
	if speed > 0.001:
		steer += velocity / speed * (_speed - speed)

	steer.y *= VERTICAL_SHARE
	velocity += steer.limit_length(s.max_steer) * delta
	velocity.y = clampf(velocity.y, -VERTICAL_SHARE * _speed, VERTICAL_SHARE * _speed)
	velocity = velocity.limit_length(_speed * 1.5)

	pos += velocity * delta
	pos.y = minf(pos.y, GameWorld.WATER_LEVEL - MIN_DEPTH)
	_pos = pos
	# One transform write per frame: every write also moves the pickup area in physics.
	var facing := global_basis
	if velocity.length_squared() > 0.0001:
		facing = Basis.looking_at(velocity, Vector3.UP)
	global_transform = Transform3D(facing, pos)


## Caches the nearest few visible school mates within school range.
func _find_neighbours() -> void:
	_neighbours.clear()
	var pos := global_position
	var range_sq := species.school_range * species.school_range
	var found: Array[Array] = []
	for mate: Fish in _by_species.get(species, []):
		if mate == self or not mate.visible:
			continue
		var dist_sq := pos.distance_squared_to(mate._pos)
		if dist_sq <= range_sq:
			found.append([dist_sq, mate])
	if found.size() > species.max_neighbours:
		found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		found.resize(species.max_neighbours)
	for entry in found:
		_neighbours.append(entry[1] as Fish)


## An eaten schooling fish comes back beside the school mate nearest its home, so it
## reappears in its school. With no school mate nearby it comes back at home.
func _rejoin_school() -> void:
	var nearest: Fish = null
	var nearest_sq := INF
	for mate: Fish in _by_species.get(species, []):
		if mate == self or not mate.visible:
			continue
		var dist_sq := home.distance_squared_to(mate._pos)
		if dist_sq < nearest_sq:
			nearest_sq = dist_sq
			nearest = mate
	var reach := species.school_range + species.roam_radius
	if nearest != null and nearest_sq <= reach * reach:
		var angle := randf() * TAU
		global_position = nearest._pos + Vector3(cos(angle), 0.0, sin(angle)) * species.personal_space
		velocity = nearest.velocity
	else:
		global_position = home
	# It teleported: don't let physics interpolation draw it sliding there.
	reset_physics_interpolation()
	_pos = global_position
	_pending = 0.0
	_refresh = 0.0


## Gone down someone's throat (a penguin's or a predator's). It respawns after respawn_seconds,
## beside its school if it has one.
func get_eaten() -> void:
	if not visible:
		return
	if one_shot:
		queue_free()
		return
	_set_active(false)
	# (false: the timer waits while the game is paused.)
	get_tree().create_timer(respawn_seconds, false).timeout.connect(_set_active.bind(true))


## Comes back now, beside its school if it has one (as it does respawn_seconds after being eaten).
func respawn() -> void:
	_set_active(true)


## How many school mates it's swimming with right now (the nearest few in school range).
func school_mate_count() -> int:
	return _neighbours.size()


## The nearest visible fish within max_distance that's swimming in a school (with at least two
## school mates around it), or null. How a starving predator finds a meal.
static func nearest_in_school(from: Vector3, max_distance: float) -> Fish:
	var best: Fish = null
	var best_sq := max_distance * max_distance
	for mates: Array in _by_species.values():
		for fish: Fish in mates:
			if not fish.visible or fish._neighbours.size() < 2:
				continue
			var dist_sq := from.distance_squared_to(fish._pos)
			if dist_sq < best_sq:
				best_sq = dist_sq
				best = fish
	return best


## A random visible fish swimming in a school within `radius` of `from`, or null.
## Predators use it to swing their patrols past schools.
static func random_in_school_near(from: Vector3, radius: float) -> Fish:
	var found: Array[Fish] = []
	var radius_sq := radius * radius
	for mates: Array in _by_species.values():
		for fish: Fish in mates:
			if fish.visible and fish._neighbours.size() >= 2 and from.distance_squared_to(fish._pos) <= radius_sq:
				found.append(fish)
	return found.pick_random() if not found.is_empty() else null


func _on_body_entered(body: Node3D) -> void:
	if body == ignore_body and _age < ignore_seconds:
		return
	if body is Penguin and visible:
		(body as Penguin).eat_fish()
		get_eaten()


func _set_active(active: bool) -> void:
	if active and species != null:
		_rejoin_school()
	visible = active
	set_deferred(&"monitoring", active)
