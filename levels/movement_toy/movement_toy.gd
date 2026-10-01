extends Node3D
## Prototype 0 test level: one iceberg, a few floes, a low ramp out of the water, and fish to eat.
## No goals, no predators. The only question: is moving around fun?

const FISH_SCENE := preload("res://actors/fish/fish.tscn")

@export var fish_seed := 7
@export var loose_fish := 40
## Small schools placed as practice targets (a preview of food pulses).
@export var schools := 4
@export var fish_per_school := 6
@export var berg_radius := 30.0
@export var fish_ring := Vector2(34.0, 70.0)
@export var fish_depth := Vector2(1.0, 8.0)


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = fish_seed
	var container := $Fish
	for i in loose_fish:
		container.add_child(_make_fish(_random_spot(rng)))
	for s in schools:
		var centre := _random_spot(rng)
		for i in fish_per_school:
			var jitter := Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(-0.8, 0.8), rng.randf_range(-1.5, 1.5))
			container.add_child(_make_fish(centre + jitter))


func _random_spot(rng: RandomNumberGenerator) -> Vector3:
	var angle := rng.randf() * TAU
	var dist := rng.randf_range(fish_ring.x, fish_ring.y)
	var depth := rng.randf_range(fish_depth.x, fish_depth.y)
	return Vector3(cos(angle) * dist, -depth, sin(angle) * dist)


func _make_fish(at: Vector3) -> Node3D:
	var fish := FISH_SCENE.instantiate()
	fish.position = at
	return fish
