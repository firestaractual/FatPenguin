class_name NpcTuning
extends Resource
## How computer penguins behave (see PenguinBrain). The live values are in
## tuning/npc_default.tres; mirrored in the NPC penguins section of docs/TUNING.md.

@export_group("Huddle")
## Another penguin this close counts as a neighbour, sheltering you (m).
@export var neighbour_range := 1.1
## Sheltered on every side at 4 neighbours.
@export var full_shelter_neighbours := 4
## Warmth (0 to 1) drops this fast fully exposed, and rises this fast fully sheltered (per s).
@export var warmth_loss := 0.05
@export var warmth_gain := 0.04
## Colder than this on the windward edge, a penguin peels off and walks round to the lee side.
@export var cold_below := 0.35
## Warmer than this, it stops pushing in and lets others squeeze it outward...
@export var warm_above := 0.75
## ...giving way upwind at this share of a walk, toward the windward edge.
@export var give_way := 0.15
## Energy drains this many times as fast sheltered in the middle, and exposed on the edge (1 is
## the normal rate: GDD §4.6, centre slow, edge fast).
@export var sheltered_drain := 0.2
@export var exposed_drain := 0.6
## Out of the huddle (fishing, walking home) it drains this many times as fast. Below 1 so the
## colony spends most of its time huddled, as real ones do between foraging trips.
@export var travel_drain := 0.5
## Which way the wind blows (toward; flat). Huddles shelter from it, and their windward edge
## peels off to the lee.
@export var wind := Vector3(1.0, 0.0, 0.35)

@export_group("Fishing")
## Hungrier than this (energy), a penguin waits at the edge for others to go fishing with.
@export var hungry_below := 35.0
## It heads home when it's this full...
@export var full_above := 70.0
## ...or after this long out (s).
@export var trip_seconds := 50.0
## A party goes in once this many are waiting at the edge...
@export var party_size := 3
## ...or after the first has waited this long (s), with whoever's there.
@export var party_wait := 20.0
## Looks for schools this far from its huddle (m).
@export var school_range := 70.0
## Swims out this deep (m), and comes up for air when it has this little left (s).
@export var swim_depth := 1.2
@export var surface_below_air := 8.0

@export_group("Coming home")
## At a launch exit it comes in this deep (m), and from this far off the edge (m) pitches up
## this steeply and boosts out onto the ice. (The same launch the smoke test checks.)
@export var launch_depth := 2.5
@export var launch_distance := 6.5
@export var launch_pitch_deg := 52.0
## A predator hunting it this close: it boosts away (if it can afford to) and heads home (m).
@export var flee_range := 8.0
