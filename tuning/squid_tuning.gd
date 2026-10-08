class_name SquidTuning
extends Resource
## A squid's numbers (see Squid, GDD §4.11). Values live in tuning/squid.tres; mirrored in
## docs/TUNING.md (Squid).

## A big meal: this much energy (two and a half fish, at the start).
@export var energy := 25.0
## Cruising about where it lives (m/s), within this far of home (m), this deep (m, min to max).
@export var cruise_speed := 1.5
@export var roam_radius := 8.0
@export var depth := Vector2(2.0, 8.0)
## A penguin in the water this close (m) makes it jet away...
@export var flee_range := 4.5
## ...at this speed for this long (m/s, s), squirting ink, then it slows back to cruising.
@export var jet_speed := 9.0
@export var jet_seconds := 0.5
## It needs this long between jets (s)...
@export var jet_cooldown := 1.4
## ...and after this many in a row it's spent, and can't jet for spent_seconds (s). Chase it
## down, or catch it with a boost.
@export var jets := 3
@export var spent_seconds := 6.0
## Eaten, another turns up at its home after this long (s).
@export var respawn_seconds := 30.0
