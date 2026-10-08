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

@export_group("Relay strikes")
## Members take turns: when one's lunge misses a penguin in the water (or a penguin bumps into one
## that's out of breath), the nearest other member that can strike goes for it straight away.
@export var relay_strikes := false
## Only members this close to the penguin take over (m). Keep it inside the members' lose_range.
@export var relay_range := 16.0
## At most this many relay strikes in a row, before the pod gives the penguin a break...
@export var relay_max := 4
## ...which it gets once it's been this long without one (s).
@export var relay_reset_seconds := 8.0
## Each relay strike during the hunt after an attack keeps the hunt going this much longer (s).
@export var relay_extends_hunt := 2.0
## While one member hunts a penguin in the water, the free ones shadow the hunt, this far off the
## penguin (m)...
@export var flank_distance := 10.0
## ...on either side of the hunter's line of attack, this far round from it (degrees), ready to
## take over.
@export var flank_angle_deg := 110.0
