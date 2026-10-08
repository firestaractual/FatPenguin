class_name SwimmerTuning
extends Resource
## What every big swimmer shares (see Swimmer): how it steers, and, for whales, its body. The
## predators' numbers (PredatorTuning) and the humpback's (HumpbackTuning) extend this. Mirrors
## docs/TUNING.md (Predators, Humpback). The defaults here are the leopard seal's.

@export_group("Steering")
## Speeding up and slowing down (m/s²).
@export var acceleration := 8.0
## A thin penguin (120 °/s) can out-turn it; a stuffed one (66 °/s) can't.
@export var turn_rate_deg := 85.0

@export_group("Body")
## Whales only (0 = none): a penguin that touches the body is shoved off it and dazed
## (Penguin.disorient()). The body is a capsule along the heading, this long nose to tail (m)...
@export var body_length := 0.0
## ...and this thick (its radius, m).
@export var body_radius := 1.0
## A penguin that touches it is dazed for this long (s)...
@export var bump_daze_seconds := 1.8
## ...and shoved off at this speed (m/s; the water takes some of it, as with any shove).
@export var bump_push := 6.0
