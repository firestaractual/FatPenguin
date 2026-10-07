class_name WaveAttackTuning
extends PodAttackTuning
## The wave (see WaveAttack): the pod lines up side by side off an ice edge, charges, and breaks a
## wave over it that shoves everyone near the edge toward the water. Antarctic orcas really do
## this to wash seals off floes.

@export_group("Wave")
## Targets penguins on the ice within this far of the edge that faces the pod, and washes over
## this much of the ice from the edge inward (m)...
@export var wave_reach := 3.0
## ...along this much of the edge (m).
@export var wave_width := 12.0
## Lines up this far out from the edge (m)...
@export var lineup_distance := 14.0
## ...this deep, so the fins show (m).
@export var surface_depth := 0.5
## The wave breaks when the pod is this close to the edge (m).
@export var break_distance := 3.5
## Only ice this low gets washed (m above the water): orcas wash seals off low floes, and a
## wave can't reach the top of a taller berg.
@export var max_freeboard := 1.5
## The shove toward the water (m/s). On your feet grip halves it (you skid, and teeter if it takes
## you to the edge); on your belly you take all of it.
@export var wave_push := 8.0


func make_attack(pod: PredatorPod) -> PodAttack:
	return WaveAttack.new(pod, self)
