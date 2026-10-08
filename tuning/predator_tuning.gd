class_name PredatorTuning
extends SwimmerTuning
## One kind of predator's balance numbers (see Predator). Mirrors the Predators section of
## docs/TUNING.md. The defaults here are the leopard seal; each kind is a resource in
## res://tuning/predators/ (leopard_seal.tres, orca.tres). Edit them in the inspector, then copy
## the winners back into TUNING.md. Group behaviour (orca pods) is in PodTuning and the pod's
## attacks (PodAttackTuning). Steering (acceleration, turn rate) and a whale's body are in the
## parent class, SwimmerTuning.
##
## Hunger runs from 0 (just ate) to 100. A predator hunts penguins unless it's starving; a
## starving one goes to a school and eats fish instead (it still lunges at a penguin that
## comes close).

@export var display_name := "Leopard seal"

@export_group("Swimming")
@export var patrol_speed := 3.5
## Well above a cruising penguin (4.0 thin, 4.6 stuffed), below a boost (9 to 11).
@export var chase_speed := 6.5
## Sluggish after eating a penguin.
@export var sated_speed := 1.5
## Getting its breath back after a lunge.
@export var recover_speed := 2.0
## Patrol depth below the surface (min, max).
@export var patrol_depth := Vector2(1.5, 3.5)

@export_group("Patrol")
## The patrol loop runs this far out from the ice edge (m).
@export var patrol_offset := 4.0
## Share of patrol legs that swing past a school instead of following the ice edge.
@export var school_visit_chance := 0.4
## Only schools this close are on the way (m).
@export var school_visit_range := 30.0
## In a berg field, the share of patrol legs that head off to patrol another berg nearby.
@export var roam_chance := 0.25

@export_group("Hunting")
## Penguins in the water are noticed this far away (m). Underwater fog hides things past ~20 m.
@export var detect_range := 24.0
## ...and a noisy one farther, up to this far at full noise (m): it hears the splash of a penguin
## going in, or a bump (Penguin.noise).
@export var hear_range := 35.0
## Penguins out of the water (on the ice, or in the air) are only noticed this close (m):
## the ambush at the ice edge.
@export var edge_detect_range := 6.0
## A chase is given up beyond this distance (m)...
@export var lose_range := 30.0
## ...or after this long without a catch (s).
@export var chase_give_up_seconds := 15.0
## Ignores a penguin it gave up on for this long (s).
@export var give_up_ignore_seconds := 4.0
## Targeting score (GDD §5.1): weights for body size, noise and closeness, each 0 to 1.
@export var size_weight := 0.5
@export var noise_weight := 0.3
@export var closeness_weight := 0.2
## A new target has to score this many times higher to steal the lock-on.
@export var switch_threshold := 1.25
## Starving, it still breaks off from feeding (or from setting off to feed) to chase a penguin in
## the water this close (m).
@export var feeding_break_range := 10.0

@export_group("Lunge")
## Starts the lunge warning this close to its target (m).
@export var lunge_range := 5.0
## The warning before every lunge (s): the lock-on ring flashes and a line marks the lunge.
## During it the predator stops closing in and just matches its target's speed.
@export var lunge_warning := 0.6
@export var lunge_speed := 12.0
@export var lunge_seconds := 0.5
## No lunging again for this long afterwards (s).
@export var lunge_cooldown := 2.0
## A lunge catches any penguin this close to the predator's jaws (m).
@export var catch_radius := 1.3
## The jaws are this far ahead of the body centre (m). Catches are measured from them, so a
## lunge at the ice edge reaches a little way onto the ice.
@export var jaw_reach := 1.0
## How far a lunge can rear up out of the water (m above the surface), to grab penguins
## standing right at the ice edge.
@export var lunge_rise := 0.6

@export_group("Pressing the attack")
## Aims each lunge this far ahead of where its target is going (0: at where it is now; 1: where
## it'll be when the jaws get there, if it keeps going the way it is, straight or round the curve
## it's turning; Penguin.turning()). The strike line shows the aimed line, so the warning stays
## honest: change what you're doing and the lunge misses.
@export var lunge_lead := 0.0
## A penguin that touches its body (and is dazed by it, SwimmerTuning) gets a lunge straight away.
@export var strikes_when_bumped := false
## Humpbacks see it off: it won't go after a penguin within a humpback's shelter_radius
## (HumpbackTuning), and its pod calls off an attack on one. A hunted penguin can hide by a humpback.
@export var shy_of_humpbacks := false

@export_group("Ambush")
## At the end of each patrol leg, the chance it lies in wait at the ice edge instead (0 to 1; 0
## never). It also waits where a penguin it was chasing climbed out.
@export var ambush_chance := 0.5
## It waits for penguins on the ice within this far of an edge (m)...
@export var ambush_edge_reach := 10.0
## ...and within this far of itself (m).
@export var ambush_scan_range := 45.0
## Its spot: this far out from the edge (m)...
@export var ambush_offset := 1.6
## ...and this deep, a dark shape just under the surface (m). Shallow enough to peek over the edge.
@export var ambush_depth := 1.2
## Gives up after waiting this long at one spot (s). Moving to a new spot starts the wait again.
@export var ambush_seconds := 15.0
## Lunges at a penguin that comes into the water this close (m): about as far as a lunge carries
## (lunge_speed × lunge_seconds). Out of the water, only within reach of its jaws (jaw_reach +
## catch_radius).
@export var ambush_strike_range := 6.0
## A penguin in the water farther off than that but within this (m) brings it out of hiding: it
## gives up the ambush and chases.
@export var ambush_break_range := 14.0
## The warning before a lunge from an ambush (s): shorter than a normal lunge_warning, because
## it's already lined up. The shadow under the edge is the first warning.
@export var ambush_warning := 0.4
## Moves to a new spot along the edge when the penguin it's waiting for has moved this far (m).
@export var ambush_reposition := 6.0

@export_group("Hunger")
## Per second.
@export var hunger_rate := 0.6
## Starting hunger is random in this range, so predators don't all get hungry at once.
@export var start_hunger := Vector2(10.0, 40.0)
## Hungrier than this, it's starving: it goes off to eat fish from a school.
@export var starving_hunger := 70.0
## A starving predator eats fish until its hunger is down to this.
@export var fed_hunger := 40.0
## Each fish takes this much hunger away.
@export var fish_hunger := 8.0
## Snaps up a fish this close (m).
@export var fish_bite_radius := 1.0
## Looks for schools this far away when starving (m).
@export var school_search_range := 80.0
## Slow and harmless for this long after eating a penguin (s). Its hunger drops to 0.
@export var sated_seconds := 8.0
