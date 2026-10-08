class_name KrillTuning
extends Resource
## A krill swarm's numbers (see KrillSwarm, GDD §4.11). Values live in tuning/krill.tres; mirrored
## in docs/TUNING.md (Krill).

## Krill in a swarm, and how far they spread round its middle (m).
@export var count := 80
@export var radius := 2.2
## Swarms sit this deep (m, min to max): near the surface, easy to reach.
@export var depth := Vector2(0.6, 3.0)
## Energy from each krill: a whole swarm is worth count × this (six fish, at the start).
@export var krill_energy := 0.75
## A penguin with its beak in the swarm eats this many a second.
@export var eat_rate := 12.0
## The swarm drifts about this fast (m/s), never farther than wander from where it formed (m).
@export var drift_speed := 0.35
@export var wander := 6.0
## Eaten out, it forms again somewhere else nearby after this long (s).
@export var regrow_seconds := 40.0
