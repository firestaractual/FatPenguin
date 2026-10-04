class_name RamAttackTuning
extends PodAttackTuning
## The ram (see RamAttack): the pod gathers deep under an ice edge, rushes up and rams it. The ice
## tips toward the pod: a small floe tips steeply and everyone slides off; the big berg only rocks,
## but the jolt knocks penguins near the rammed edge about. Only ice marked TippableIce tips.

@export_group("Ram")
## Targets penguins standing on tippable ice within this far of the edge that faces the pod (m).
## Anywhere on a floe this size or smaller; on bigger ice, inside the jolt zone.
@export var ram_reach := 8.0
## Gathers this far out from the edge (m)...
@export var gather_distance := 6.0
## ...this deep: dark shadows under the ice edge (m).
@export var gather_depth := 4.0
## Rams when the pod is this close to the edge (m).
@export var strike_distance := 2.0
## How far the ice tips: tip_strength ÷ radius^1.5 degrees, so big ice barely moves. 200 tips a
## 4 m floe 25° (its rim goes under) and rocks the 30 m berg about 1.2° (its rim drops ~0.6 m).
@export var tip_strength := 200.0
@export var max_tilt_deg := 30.0
## Tips over this fast, stays tipped this long, then rights itself this slowly (s).
@export var tip_in_seconds := 0.35
@export var tip_hold_seconds := 2.0
@export var tip_out_seconds := 1.2
## The jolt: penguins on the rammed ice are shoved toward the pod this hard (m/s; on your feet
## grip halves it)...
@export var jolt_push := 5.0
## ...everyone on a floe no wider than this (m); on bigger ice, everyone in a strip this far in
## from the rammed edge and twice as wide (the danger zone).
@export var jolt_radius := 8.0


func make_attack(pod: PredatorPod) -> PodAttack:
	return RamAttack.new(pod, self)
