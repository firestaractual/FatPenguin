class_name PodAttackTuning
extends Resource
## One group attack a pod can make, and its numbers (see PodAttack). Each kind of attack extends
## this and builds its attack in make_attack() (WaveAttackTuning, RamAttackTuning). A pod lists
## the attacks it knows in PodTuning.attacks. Mirrors the Predators section of docs/TUNING.md.
##
## Every attack runs the same steps: line up, warn, charge, strike, then hunt the water.

@export var display_name := "Attack"

@export_group("Choosing")
## When more than one attack has a target, one is picked at random, weighted by this.
@export var weight := 1.0
## Penguins this close to the pod's leader can be targets (m).
@export var scan_range := 40.0
## It takes at least this many free predators.
@export var min_attackers := 2

@export_group("Steps")
## Waits for stragglers to reach their line-up spots no longer than this (s).
@export var lineup_max_seconds := 8.0
## Lined up, the warning lasts this long before the charge (s).
@export var warning_seconds := 2.0
## The danger zone shows on the ice from this far through the warning (0 to 1).
@export var zone_shows_at := 0.4
@export var charge_speed := 8.0
## After the strike, the pod hunts the water near it for this long (s).
@export var hunt_seconds := 6.0
## No attack of any kind for this long afterwards (s).
@export var cooldown := 20.0


## The attack itself, for `pod`. Each kind of attack overrides this.
func make_attack(_pod: PredatorPod) -> PodAttack:
	return null
