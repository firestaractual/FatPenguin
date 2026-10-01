class_name FishSpecies
extends Resource
## One kind of fish: how it looks and how it schools. Mirrors the Fish section of docs/TUNING.md.
## The species live in res://tuning/fish/. Edit them in the inspector, then copy the winners
## back into TUNING.md.
##
## Fish only school with their own species: a fish is pulled toward fish of its own kind within
## school range and ignores every other kind, so mixed groups sort themselves out.

@export var display_name := "Fish"

@export_group("Look")
## Shared by every fish of this species (one material per species keeps draw calls batched).
@export var material: Material
## Scales the model only. The eat radius stays the same for every species.
@export var body_scale := 1.0

@export_group("Swimming")
## Cruising speed (m/s). Fish never hover.
@export var swim_speed := 0.6
## Each fish's cruising speed is randomly up to this share faster or slower, so a school
## doesn't move in lockstep.
@export var speed_variation := 0.15
## The hardest a fish can steer (m/s²).
@export var max_steer := 1.5
## A slowly turning random nudge (m/s²), so lone fish and whole schools meander.
@export var wander := 0.4

@export_group("Schooling")
## The swarm pull reaches this far (m). School mates closer than this pull together; fish
## farther apart ignore each other.
@export var school_range := 6.0
## How hard a fish is pulled toward the middle of its school mates in range (m/s² per metre).
@export var cohesion := 0.5
## How hard a fish matches its school mates' heading (per second).
@export var alignment := 1.0
## Fish try to keep at least this far apart (m).
@export var personal_space := 0.6
## How hard fish push apart inside personal space (m/s² at zero distance).
@export var separation := 3.0
## A fish only follows its nearest few school mates, as real schooling fish do.
@export var max_neighbours := 7

@export_group("Home range")
## A fish roams this far from its home spot before it's pulled back (m).
@export var roam_radius := 4.0
## How hard a fish is pulled back once it's past the roam radius (m/s² per metre).
@export var home_pull := 0.3
## School mates slowly share one home spot, so a school that forms stays together (per second).
@export var home_merge_rate := 0.1

@export_group("Spawning")
## Relative chance a level picks this species for a school or a loose fish.
@export var abundance := 1.0
## How many fish a level puts in one school of this species (min, max).
@export var school_size := Vector2i(5, 8)
## The depths (m below the surface) a level spawns this species at.
@export var depth_range := Vector2(1.0, 8.0)
