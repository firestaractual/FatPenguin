class_name Swimmer
extends CharacterBody3D
## Anything big that swims: every predator (Predator) and the humpback (Humpback). What they
## share is here, so a new kind of sea animal is mostly its own behaviour:
##   - steering: it turns toward where it's going at its turn rate (no faster), and speeds up and
##     slows down at its acceleration (SwimmerTuning);
##   - staying in the water: never shallower than the depth it's allowed, never past the seafloor;
##     too shallow for it (an orca in a lagoon) stops it like a wall;
##   - ice: pressed against ice it slides along it (round a corner, into a tunnel mouth), and on its
##     way somewhere farther off it dives under ice in its way, if there's open water below;
##   - its look: the Model node turns to face where it's going, and near the surface a dark shadow
##     shows on the water above it (ART_DIRECTION: predators under the surface read as shadows);
##   - for whales, its body (SwimmerTuning.body_length): a penguin that touches it is shoved off and
##     dazed (Penguin.disorient()), and bumped_penguin is emitted.
##
## Like a penguin, the body is a sphere that never rotates; only the Model node turns. It collides
## with the world only. A kind fills in _think() (each physics frame) and swim_tuning().

## A penguin touched its body (a whale's) and was dazed.
signal bumped_penguin(penguin: Penguin)

## The body centre stays at least this far below the surface (m), unless told otherwise.
const MIN_DEPTH := 0.35
## Seafloor safety: never deeper than this (m).
const MAX_DEPTH := 25.0
## Blocked by ice on the way somewhere: dive under it for this long (s).
const DIVE_SECONDS := 1.5
## Near the surface it shows as a dark shadow on the water above it: darkest down to
## SHADOW_FULL_DEPTH, fading out by SHADOW_DEPTH (m).
const SHADOW_DEPTH := 3.0
const SHADOW_FULL_DEPTH := 1.5
const SHADOW_DARKNESS := 0.6
## The same penguin can't be bumped again by this body this soon (s).
const BUMP_COOLDOWN := 1.0

var _speed := 0.0
var _heading := Vector3.FORWARD
var _dive_time := 0.0
var _hit_wall := false
## The last wall it bumped into (its normal), to slide along it.
var _wall_normal := Vector3.ZERO
## Penguins it bumped lately, and how long until they can be bumped again.
var _bumped := {}

@onready var _model: Node3D = $Model
var _shadow: MeshInstance3D
var _shadow_material: StandardMaterial3D
var _shadow_size := Vector3.ONE


func _ready() -> void:
	collision_layer = GameWorld.PREDATOR_LAYER
	collision_mask = GameWorld.WORLD_LAYER
	motion_mode = MOTION_MODE_FLOATING
	_make_shadow()


func _physics_process(delta: float) -> void:
	_dive_time = maxf(_dive_time - delta, 0.0)
	_think(delta)
	_update_model(delta)
	_update_shadow()
	_touch_penguins(delta)


# --- What each kind fills in ----------------------------------------------------

## Its steering and body numbers (each kind returns its own tuning resource).
func swim_tuning() -> SwimmerTuning:
	return null


## Each physics frame: decide what to do and move (with _swim_toward() or _move()).
func _think(_delta: float) -> void:
	pass


## Blocked by ice with `flat_distance` still to go: may it dive under? By default, if it isn't
## nearly there.
func _may_dive_under(flat_distance: float) -> bool:
	return flat_distance > 6.0


## Does touching its body daze `p`? By default, yes (a humpback is gentle with a penguin it's
## guarding).
func _dazes(_p: Penguin) -> bool:
	return true


# --- Shared parts -------------------------------------------------------------

## The way it's swimming (unit vector).
func heading() -> Vector3:
	return _heading


## Its swimming speed now (m/s).
func swim_speed() -> float:
	return _speed


## How far `point` is from its body (0 inside it); for a body-less swimmer, from its centre.
func distance_to_body(point: Vector3) -> float:
	var t := swim_tuning()
	if t == null or t.body_length <= 0.0:
		return global_position.distance_to(point)
	var half := _heading * maxf(t.body_length * 0.5 - t.body_radius, 0.0)
	var closest := Geometry3D.get_closest_point_to_segment(point, global_position - half, global_position + half)
	return maxf(closest.distance_to(point) - t.body_radius, 0.0)


## Steers toward `point` at up to `speed`. With slow_to_turn it slows down while the point is
## off to the side, which tightens its turns. It comes no closer to the surface than min_depth.
func _swim_toward(point: Vector3, speed: float, delta: float, slow_to_turn := false, min_depth := MIN_DEPTH) -> void:
	var t := swim_tuning()
	var to := point - global_position
	if _dive_time > 0.0:
		to.y = minf(to.y, 0.0) - 3.0 # ice in the way: go under it
	var want := to.normalized() if to.length() > 0.01 else _heading
	if _hit_wall and _wall_normal != Vector3.ZERO and want.dot(_wall_normal) < 0.0:
		# Pressed against ice: slide along it the way it wants to go (round a corner, into a
		# tunnel mouth) rather than pushing head-on.
		var along := want.slide(_wall_normal)
		if along.length() > 0.05:
			want = (along.normalized() * 0.8 + want * 0.2).normalized()
	if slow_to_turn:
		speed *= clampf(_heading.dot(want), 0.25, 1.0)
	_heading = _turn_toward(_heading, want, deg_to_rad(t.turn_rate_deg) * delta)
	_speed = move_toward(_speed, speed, t.acceleration * delta)
	velocity = _heading * _speed
	_move(min_depth)
	# Bumped into ice on the way somewhere farther off? Dive under it, if there's open water
	# below to dive into (not in a tunnel or a lagoon, with ice right underneath: there it just
	# slides along the wall).
	var flat := Vector2(to.x, to.z).length()
	if _hit_wall and _dive_time <= 0.0 and _may_dive_under(flat) and _open_below():
		_dive_time = DIVE_SECONDS


## Open water for a few metres under it (no tunnel floor, no lagoon bed).
func _open_below() -> bool:
	var from := global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 4.0, GameWorld.WORLD_LAYER, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## move_and_slide, kept in the water (no shallower than min_depth below the surface; a negative
## min_depth lets it rise that far out of the water, as a lunge does).
func _move(min_depth: float) -> void:
	var before := global_position
	move_and_slide()
	_hit_wall = false
	var grounded := false
	for i in get_slide_collision_count():
		var normal := get_slide_collision(i).get_normal()
		if absf(normal.y) < 0.5:
			_hit_wall = true
			_wall_normal = normal
		elif normal.y > 0.5:
			grounded = true
	var p := global_position
	var top := GameWorld.WATER_LEVEL - min_depth
	if grounded and p.y > top + 0.05:
		# Ice underneath pushing it up out of the water: too shallow for it to swim here (an orca
		# in a lagoon). It can't go on; it stays where it was, like at a wall.
		global_position = Vector3(before.x, minf(before.y, top), before.z)
		_hit_wall = true
		return
	if p.y > top or p.y < -MAX_DEPTH:
		p.y = clampf(p.y, -MAX_DEPTH, top)
		global_position = p
		_heading.y = minf(_heading.y, 0.0) if p.y >= top else maxf(_heading.y, 0.0)
		if _heading.length() < 0.01:
			_heading = Vector3.FORWARD
		_heading = _heading.normalized()


static func _turn_toward(from: Vector3, to: Vector3, max_angle: float) -> Vector3:
	var angle := from.angle_to(to)
	if angle <= max_angle:
		return to
	var axis := from.cross(to)
	if axis.length() < 0.0001:
		axis = Vector3.UP # dead behind: turn sideways
	return from.rotated(axis.normalized(), max_angle).normalized()


# --- Its body -----------------------------------------------------------------

## A whale's body: any penguin touching it is shoved straight off it and dazed.
func _touch_penguins(delta: float) -> void:
	for p: Variant in _bumped.keys():
		_bumped[p] -= delta
		if _bumped[p] <= 0.0 or not is_instance_valid(p):
			_bumped.erase(p)
	var t := swim_tuning()
	if t == null or t.body_length <= 0.0:
		return
	var half := _heading * maxf(t.body_length * 0.5 - t.body_radius, 0.0)
	var a := global_position - half
	var b := global_position + half
	var reach := t.body_radius + t.body_length * 0.5
	for node in get_tree().get_nodes_in_group(&"penguins"):
		var p := node as Penguin
		if p == null or _bumped.has(p) or global_position.distance_to(p.global_position) > reach + 1.0 or not _dazes(p):
			continue
		var closest := Geometry3D.get_closest_point_to_segment(p.global_position, a, b)
		var off := p.global_position - closest
		if off.length() > t.body_radius + p.body_radius():
			continue
		var away := off.normalized() if off.length() > 0.01 else _heading.cross(Vector3.UP).normalized()
		p.push(away * t.bump_push + velocity * 0.5)
		p.disorient(t.bump_daze_seconds)
		_bumped[p] = BUMP_COOLDOWN
		bumped_penguin.emit(p)


# --- Looks --------------------------------------------------------------------

func _update_model(delta: float) -> void:
	var dir := velocity if velocity.length() > 0.3 else _heading
	if absf(dir.normalized().y) > 0.98:
		return
	var want := Basis.looking_at(dir, Vector3.UP).get_rotation_quaternion()
	var current := _model.global_basis.get_rotation_quaternion()
	_model.global_basis = Basis(current.slerp(want, clampf(8.0 * delta, 0.0, 1.0)))


## The shadow on the water: dark, not the danger colour, and sized from the body.
func _make_shadow() -> void:
	var t := swim_tuning()
	if t != null and t.body_length > 0.0:
		_shadow_size = Vector3(t.body_radius * 1.7, 1.0, t.body_length * 0.6)
	else:
		var body := get_node_or_null("CollisionShape3D") as CollisionShape3D
		var r := (body.shape as SphereShape3D).radius if body != null and body.shape is SphereShape3D else 0.6
		_shadow_size = Vector3(r * 1.6, 1.0, r * 3.5)
	_shadow_material = StandardMaterial3D.new()
	_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_material.albedo_color = Color(0.02, 0.06, 0.1, 0.0)
	var blob := CylinderMesh.new()
	blob.top_radius = 1.0
	blob.bottom_radius = 1.0
	blob.height = 0.02
	blob.material = _shadow_material
	_shadow = MeshInstance3D.new()
	_shadow.name = &"Shadow"
	_shadow.mesh = blob
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	_shadow.visible = false
	add_child(_shadow)


func _update_shadow() -> void:
	var depth := GameWorld.WATER_LEVEL - global_position.y
	var dark := clampf((SHADOW_DEPTH - depth) / (SHADOW_DEPTH - SHADOW_FULL_DEPTH), 0.0, 1.0) * SHADOW_DARKNESS
	_shadow.visible = dark > 0.01
	if _shadow.visible:
		_shadow_material.albedo_color.a = dark
		var flat := Vector3(_heading.x, 0.0, _heading.z)
		var facing := Basis.looking_at(flat, Vector3.UP) if flat.length() > 0.05 else Basis.IDENTITY
		_shadow.global_transform = Transform3D(facing * Basis.from_scale(_shadow_size), Vector3(global_position.x, GameWorld.WATER_LEVEL + 0.015, global_position.z))
