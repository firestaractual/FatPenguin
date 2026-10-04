extends Node3D
## Prototype 0 test level: an iceberg with a plateau on top (chutes to slide down, steps to hop up),
## a few floes, a low ramp out of the water, fish to eat, dummy penguins to bump, and predators:
## leopard seals hunting the water and an orca pod that washes penguins off the ice edge and tips
## floes (early pieces of Prototypes 1 and 2). No goals yet.

const FISH_SCENE := preload("res://actors/fish/fish.tscn")

@export var fish_seed := 7
## The kinds of fish in the level. Each gets at least one school; the rest are picked by
## abundance. School size and depth come from the species.
@export var fish_species: Array[FishSpecies] = [
	preload("res://tuning/fish/silverfish.tres"),
	preload("res://tuning/fish/lanternfish.tres"),
	preload("res://tuning/fish/icefish.tres"),
]
## Single-species schools placed as practice targets (a preview of food pulses). They're spread
## evenly around the berg, so every edge has a school within reach.
@export var schools := 12
## Fish on their own between the schools. Lone fish that drift within school range of their
## own kind join up and stay.
@export var loose_fish := 16
@export var berg_radius := 30.0
## Fish homes sit this far from the middle of the berg (min, max). The inner edge leaves room
## for fish roaming out from their homes without swimming into the ice.
@export var fish_ring := Vector2(36.0, 70.0)
## Schools sit in the inner part of the ring, within an easy swim of the ice edge (min, max).
@export var school_ring := Vector2(36.0, 50.0)
## The ice orcas can tip with a ram (TippableIce): the berg with its plateau and ramp, and each
## floe. Their size comes from their collision shapes.
@export var berg_bodies: Array[NodePath] = [^"Iceberg", ^"Plateau", ^"Ramp"]
@export var floes: Array[NodePath] = [^"FloeEasy", ^"FloeMedium", ^"FloeHard"]
## A dummy knocked into the water pops back to its spot after this long.
@export var dummy_respawn_seconds := 2.0
## The predators: what spawns, how many and where (PredatorSpawn entries, placed around the berg
## by a PredatorSpawner). They start away from the player's spawn on the south side.
@export var predator_spawns: Array[PredatorSpawn] = [
	preload("res://levels/movement_toy/predators/leopard_seals.tres"),
	preload("res://levels/movement_toy/predators/orca_pod.tres"),
]

var _wet_time := {}


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = fish_seed
	var container := $Fish
	for s in schools:
		var species := fish_species[s] if s < fish_species.size() else _pick_species(rng)
		# One school per slice of the ring, at a random spot within its slice.
		var angle := (s + rng.randf_range(0.15, 0.85)) / schools * TAU
		var centre := _random_spot(rng, species, angle, school_ring)
		var size := rng.randi_range(species.school_size.x, species.school_size.y) if species else 6
		for i in size:
			var jitter := Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(-0.8, 0.8), rng.randf_range(-1.5, 1.5))
			var fish := _make_fish(centre + jitter, species)
			container.add_child(fish)
			# The whole school shares one home spot from the start.
			fish.home = centre
	for i in loose_fish:
		var species := _pick_species(rng)
		container.add_child(_make_fish(_random_spot(rng, species, rng.randf() * TAU, fish_ring), species))
	_make_tippable_ice()
	var spawner := PredatorSpawner.new()
	spawner.name = "Predators"
	spawner.spawns = predator_spawns
	spawner.ice_centre = Vector3.ZERO
	spawner.ice_radius = berg_radius
	add_child(spawner)


## Marks the berg and each floe as ice that can be tipped, pivoting at its middle at the waterline.
func _make_tippable_ice() -> void:
	_add_tippable(&"TippableBerg", berg_bodies, Vector3.ZERO, berg_radius)
	for path in floes:
		var floe := get_node_or_null(path) as Node3D
		if floe == null:
			continue
		var shape := (floe.get_node("CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D
		_add_tippable(StringName("Tippable" + floe.name), [path], Vector3(floe.position.x, 0.0, floe.position.z), shape.radius if shape else 4.0)


func _add_tippable(ice_name: StringName, paths: Array[NodePath], at: Vector3, radius: float) -> void:
	var ice := TippableIce.new()
	ice.name = ice_name
	ice.position = at
	ice.radius = radius
	for path in paths:
		ice.bodies.append(NodePath("../" + str(path)))
	add_child(ice)


## A species picked at random, weighted by abundance. Null if the level has none.
func _pick_species(rng: RandomNumberGenerator) -> FishSpecies:
	var total := 0.0
	for species in fish_species:
		total += species.abundance
	var roll := rng.randf() * total
	for species in fish_species:
		roll -= species.abundance
		if roll <= 0.0:
			return species
	return fish_species.back() if not fish_species.is_empty() else null


func _random_spot(rng: RandomNumberGenerator, species: FishSpecies, angle: float, ring: Vector2) -> Vector3:
	var dist := rng.randf_range(ring.x, ring.y)
	var depths := species.depth_range if species else Vector2(1.0, 8.0)
	var depth := rng.randf_range(depths.x, depths.y)
	return Vector3(cos(angle) * dist, -depth, sin(angle) * dist)


func _make_fish(at: Vector3, species: FishSpecies) -> Fish:
	var fish := FISH_SCENE.instantiate() as Fish
	fish.species = species
	fish.position = at
	return fish


func _physics_process(delta: float) -> void:
	for dummy in $Dummies.get_children():
		var p := dummy as Penguin
		if p == null:
			continue
		if p.state == Penguin.State.SWIM:
			_wet_time[p] = _wet_time.get(p, 0.0) + delta
			if _wet_time[p] >= dummy_respawn_seconds:
				_wet_time[p] = 0.0
				p.reset()
		else:
			_wet_time[p] = 0.0
