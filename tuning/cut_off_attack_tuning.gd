class_name CutOffAttackTuning
extends PodAttackTuning
## The cut-off (see CutOffAttack): a penguin in the water near the ice finds a wall of fins
## between it and home. The wall closes in and pushes it out to sea; a penguin that tries to
## slip through gets lunged at.

@export_group("Cut-off")
## Goes after penguins in the water at least this far from the nearest ice (m): any closer and
## they're as good as home. Up to open_water_distance (below): farther out is the carousel's job.
@export var home_distance := 4.0
## The wall forms this far from the penguin, between it and the ice (m)...
@export var wall_gap_start := 7.0
## ...and closes in to this by the end of the warning (m). Keep it outside snap_range, so only a
## penguin that swims at the wall (or a wall that can't back off fast enough) gets lunged at
## before the end.
@export var wall_gap_end := 4.5
## The wall keeps at least this far off the ice, so it never jams against the edge (m).
@export var wall_shore_margin := 1.5
## Orcas in the wall swim this deep, fins showing (m).
@export var wall_depth := 0.5
## Orcas in the wall sit this far apart (m).
@export var wall_spacing := 4.0
## A penguin swimming toward the ice this close to an orca in the wall gets lunged at (m); one
## that isn't, only at 60% of this. Diving deeper than this under the wall gets you past.
@export var snap_range := 4.0
## This far from the ice is open water (m): the cut-off doesn't start on penguins out there, and
## once it has pushed one this far out, the wall has done its job and the trap moves on
## (chains_into: the carousel) instead of lunging.
@export var open_water_distance := 10.0


func make_attack(pod: PredatorPod) -> PodAttack:
	return CutOffAttack.new(pod, self)
