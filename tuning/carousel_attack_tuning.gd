class_name CarouselAttackTuning
extends PodAttackTuning
## The carousel (see CarouselAttack): a penguin out in open water gets ringed in. The pod circles
## it, blowing a wall of bubbles that keeps it in and lifts it to the surface, and squeezes the
## ring. Then one orca tail-slaps the middle (stunning anyone in it) and another lunges through.
## Norwegian orcas herd herring this way (carousel feeding).

@export_group("Carousel")
## Goes after penguins in the water at least this far from the nearest ice (m): open water.
@export var open_water_distance := 10.0
## The ring: it forms this wide around the penguin (radius, m)...
@export var ring_start_radius := 10.0
## ...and squeezes in to this over the warning (radius, m).
@export var ring_end_radius := 4.5
## The orcas circle this deep (m), going round at this speed (m/s).
@export var ring_depth := 2.0
@export var circle_speed := 5.0
## While they get into place, the ring's middle follows the penguin this fast (m/s); once the
## bubbles are up, this fast.
@export var follow_speed := 2.5
@export var squeeze_follow_speed := 0.5

@export_group("Bubble wall")
## The wall of bubbles is this thick (m)...
@export var wall_thickness := 1.0
## ...and slows anyone swimming out through it by this much (m/s²): enough to stop a cruising
## penguin, not a boost (a boost at 9 m/s needs 1.6 m to stop at 25).
@export var wall_push := 25.0
## Inside the ring, a penguin deeper than this is lifted toward the surface (m)...
@export var lift_depth := 1.0
## ...rising at up to this speed (m/s), pushed this hard (m/s²).
@export var lift_speed := 1.0
@export var lift_push := 20.0
## The bubbles keep going this long after the strike (s).
@export var wall_linger_seconds := 1.5

@export_group("Tail slap")
## The slap stuns penguins this close to the middle of the ring (m)...
@export var slap_radius := 3.5
## ...and no deeper than this (m)...
@export var slap_depth := 2.0
## ...for this long (s): no boost, slow turns and slow swimming (PenguinTuning, Stunned).
@export var stun_seconds := 1.2
## It also shoves them out from the middle this hard (m/s; the water takes most of it).
@export var slap_push := 3.0


func make_attack(pod: PredatorPod) -> PodAttack:
	return CarouselAttack.new(pod, self)
