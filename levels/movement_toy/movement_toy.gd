extends Node3D
## Prototype 0 test level: an iceberg with a plateau on top (chutes to slide down, steps to hop up),
## a few floes, a low ramp out of the water, fish to eat, and dummy penguins to bump.
## No goals, no predators. The only question: is moving around fun?

const FISH_SCENE := preload("res://actors/fish/fish.tscn")

@export var fish_seed := 7
## The kinds of fish in the level. Each gets at least one school; the rest are picked by
## abundance. School size and depth come from the species.
@export var fish_species: Array[FishSpecies] = [
	preload("res://tuning/fish/silverfish.tres"),
	preload("res://tuning/fish/lanternfish.tres"),
	preload("res://tuning/fish/icefish.tres"),
]
## Single-species schools placed as practice targets (a preview of food pulses).
@export var schools := 8
## Fish on their own between the schools. Lone fish that drift within school range of their
## own kind join up and stay.
@export var loose_fish := 12
@export var berg_radius := 30.0
## Fish homes sit this far from the middle of the berg (min, max). The inner edge leaves room
## for fish roaming out from their homes without swimming into the ice.
@export var fish_ring := Vector2(36.0, 70.0)
## A dummy knocked into the water pops back to its spot after this long.
@export var dummy_respawn_seconds := 2.0

var _wet_time := {}


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = fish_seed
	var container := $Fish
	for s in schools:
		var species := fish_species[s] if s < fish_species.size() else _pick_species(rng)
		var centre := _random_spot(rng, species)
		var size := rng.randi_range(species.school_size.x, species.school_size.y) if species else 6
		for i in size:
			var jitter := Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(-0.8, 0.8), rng.randf_range(-1.5, 1.5))
			var fish := _make_fish(centre + jitter, species)
			container.add_child(fish)
			# The whole school shares one home spot from the start.
			fish.home = centre
	for i in loose_fish:
		var species := _pick_species(rng)
		container.add_child(_make_fish(_random_spot(rng, species), species))


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


func _random_spot(rng: RandomNumberGenerator, species: FishSpecies) -> Vector3:
	var angle := rng.randf() * TAU
	var dist := rng.randf_range(fish_ring.x, fish_ring.y)
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
