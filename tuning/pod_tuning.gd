class_name PodTuning
extends Resource
## How a pod of predators keeps together, and which group attacks it knows (see PredatorPod).
## Mirrors the Predators section of docs/TUNING.md.

@export var display_name := "Pod"

@export_group("Formation")
## Followers swim in a V behind the leader, this far apart (m).
@export var spacing := 4.0
## A follower that's fallen behind its spot swims this much faster per metre it's off (m/s per m),
## up to its chase speed.
@export var catch_up := 0.8

@export_group("Attacks")
## The group attacks this pod can make (WaveAttackTuning, RamAttackTuning, ...). Empty for a pod
## that only swims together.
@export var attacks: Array[PodAttackTuning] = []
## No attack before this long into the level (s).
@export var first_attack_delay := 10.0
