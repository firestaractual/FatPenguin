class_name ScreenFxTuning
extends Resource
## How the screen reacts to danger (see ScreenFx): the edges darkening when a predator's near,
## tunnel vision when you boost, and the screen closing in or blacking out when something hits
## you. Feel numbers, not balance. The player can turn them down or off (GameSettings
## screen_effects). Values live in tuning/screen_fx.tres; mirrored in docs/TUNING.md (Screen
## effects).

@export_group("Anxiety (a predator near)")
## You sense a predator within this far (m), in sight or not: the closer, the darker the edges.
@export var sense_range := 25.0
## One hunting you (locked on, lining up, lunging) counts at least this much (0 to 1)...
@export var hunted_level := 0.85
## ...and a pod's attack on you this much.
@export var attack_level := 0.95
## A predator that has just eaten (sated) counts this share; out of the water, everything but a
## hunt counts this share.
@export var sated_share := 0.35
@export var on_ice_share := 0.5
## It creeps in this fast (per second, 0 to 1)...
@export var rise_rate := 0.4
## ...and fades back out this fast.
@export var fall_rate := 0.25
## At full anxiety the edges get this dark (0 to 1) and the dark reaches this far in (0 to 1).
@export var darkness := 0.6
@export var reach := 0.3
## At full anxiety the dark throbs like a heartbeat: this much (share of the darkness), this fast
## (beats per minute).
@export var heartbeat := 0.15
@export var heartbeat_bpm := 96.0

@export_group("Boost (tunnel vision)")
## While boosting the edges close in this much: dark and reach (0 to 1)...
@export var boost_darkness := 0.3
@export var boost_reach := 0.25
## ...in this fast and out this fast (s).
@export var boost_in_seconds := 0.12
@export var boost_out_seconds := 0.45

@export_group("Hits (tunnel and black-out)")
## Something hits you and the screen closes in, as far and as dark as this at the hit (0 to 1),
## then opens back up over the hit's length.
@export var hit_reach := 0.6
@export var hit_darkness := 0.92
## How hard each kind of hit closes it in (0 to 1): a whale's body (dazed), a tail slap
## (stunned), a lunge at you from close by (even if it misses), a hard bump from a penguin.
@export var daze_strength := 0.9
@export var stun_strength := 0.75
@export var lunge_strength := 0.45
@export var bump_strength := 0.35
## A lunge counts when it starts this close to you (m).
@export var lunge_range := 8.0
## Opens back up over this long after a lunge or a bump (s).
@export var short_hit_seconds := 0.6
## Caught: the screen goes black for this long (s), then comes back over this long (s).
@export var caught_black_seconds := 0.35
@export var caught_fade_seconds := 0.9

@export_group("Queasy (a sick fish)")
## The tint over everything while queasy, and how far the picture swims about (share of the
## screen).
@export var queasy_tint := Color(0.7, 0.85, 0.45, 1.0)
@export var queasy_wobble := 0.008
