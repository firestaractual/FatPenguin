class_name HumpbackTuning
extends SwimmerTuning
## A humpback's numbers (see Humpback, GDD §5.5). Its steering and body are in SwimmerTuning.
## Mirrors docs/TUNING.md (Humpback). Values live in tuning/humpback.tres.

@export var display_name := "Humpback"

@export_group("Travelling")
## Cruising between waypoints (m/s): slower than a penguin, so one can keep up with it.
@export var travel_speed := 2.5
## Cruising depth (m below the surface, min to max).
@export var travel_depth := Vector2(3.0, 7.0)
## Its waypoints are this far out from the edge of the ice it roams round (m, min to max).
@export var roam_offset := Vector2(14.0, 45.0)

@export_group("Breathing")
## Comes up to breathe this often (s, min to max)...
@export var breath_interval := Vector2(25.0, 40.0)
## ...rolls along the top this long, its back and little fin out of the water (s)...
@export var surface_seconds := 6.0
## ...with its middle this far under (m; its back shows above the water)...
@export var surface_depth := 0.7
## ...and blows this many times, this far apart (s): a bushy spout, the giveaway from afar.
@export var blows := 3
@export var blow_interval := 1.8
## Then it dives, nose down at this angle, its flukes rising out of the water (s, degrees).
@export var dive_seconds := 2.5
@export var dive_pitch_deg := 50.0

@export_group("Feeding (bubble net)")
## Goes looking for a fish school to feed on this often (s, min to max)...
@export var feed_interval := Vector2(50.0, 80.0)
## ...within this far (m). The school has to be in open water: no ice within the net's start
## radius plus net_clearance (m).
@export var feed_range := 45.0
@export var net_clearance := 5.0
## Gives up getting to the school after this long (s).
@export var approach_seconds := 25.0
## The net: it circles this deep (m; deeper still under a deep school), round and round the
## school blowing bubbles, the ring closing from the first radius to the second (m), net_turns
## times round in net_seconds (s). Fish within herd_reach of the middle (m) are herded into a ball
## inside the ring, up at the surface.
@export var net_depth := 8.0
@export var net_radius := Vector2(7.0, 3.5)
@export var net_turns := 1.0
@export var net_seconds := 8.0
@export var herd_reach := 10.0
## The ring closed, it turns up under the middle (s; the fish boil at the surface: the last
## tell)...
@export var aim_seconds := 1.0
## ...and lunges up through it, mouth open, at this speed and at least this steep (m/s, degrees
## from flat), until its head is this high out of the water (m).
@export var lunge_speed := 8.0
@export var lunge_pitch_deg := 75.0
@export var lunge_height := 2.5
## It swallows every fish within this of the middle (m), and the school stays gone this long (s).
@export var gulp_radius := 4.0
@export var fish_gone_seconds := 45.0
## A penguin in the water within this of the middle (m) when it comes up is scooped up and thrown
## out: never eaten, but tossed up and out (m/s), dazed (s), and a fish comes back up.
@export var scoop_radius := 4.5
@export var scoop_up_speed := 7.0
@export var scoop_out_speed := 4.0
@export var scoop_daze_seconds := 2.5
## Up and over, it falls back in (s), then rests at the surface (s).
@export var fall_seconds := 1.5
@export var rest_seconds := 8.0

@export_group("Driving off orcas")
## Sees an orca hunt (a pod's attack, or an orca after a penguin) within this far of itself (m)...
@export var mob_range := 35.0
## ...and goes to break it up at this speed (m/s), giving up after mob_seconds (s).
@export var mob_speed := 4.0
@export var mob_seconds := 20.0
## Any penguin within this far of its body is sheltered (m): orcas are shy of humpbacks
## (PredatorTuning.shy_of_humpbacks) and won't go after it, and a pod attacking it calls the attack
## off. That's how it drives them off: it gets this close to the hunted penguin...
@export var shelter_radius := 10.0
## ...and stays by it this long (s), keeping this far off its side (m).
@export var guard_seconds := 10.0
@export var guard_offset := 4.5
