class_name PenguinTuning
extends Resource
## Every penguin balance number in one place. Mirrors docs/TUNING.md.
## All values are starting guesses for playtesting: tweak them in the inspector on
## res://tuning/penguin_tuning_default.tres, then copy the winners back into TUNING.md.
##
## "Fat" multipliers are the value at full energy; at zero energy every multiplier is 1.0
## and the penguin scales linearly in between.

@export_group("Energy")
@export var max_energy := 100.0
@export var starting_energy := 50.0
## Turn off (F2 in game) to play with the toy without ever going hungry.
@export var energy_drain_enabled := true
## Energy lost per second in water or on open ice.
@export var base_drain := 1.5
@export var overfill_threshold := 70.0
## Drain is multiplied by this while energy is above the overfill threshold.
@export var overfill_drain_mult := 2.0
@export var fish_value := 10.0
@export var boost_energy_cost := 8.0
## Flopping onto your belly on purpose (from walking). Landing in a slide after a launch is free.
@export var slide_energy_cost := 3.0
## Saving yourself from a teeter at the ice edge.
@export var scramble_energy_cost := 4.0

@export_group("Fat vs thin (multiplier at full energy)")
@export var fat_turn_rate_mult := 0.55
@export var fat_acceleration_mult := 0.6
@export var fat_cruise_speed_mult := 1.15
@export var fat_boost_speed_mult := 1.25
## Scales the height of a breach (vertical exit speed is scaled by the square root).
@export var fat_launch_height_mult := 0.65
## Visual girth of the model.
@export var fat_body_width_mult := 1.6
@export var fat_collision_radius_mult := 1.3
## Heavier penguins hit harder and are harder to move (see Bumping).
@export var fat_mass_mult := 2.0
## A full belly is a bad jumper: hop height at full energy.
@export var fat_hop_height_mult := 0.55
## Fat penguins take longer to get back on their feet after a slide.
@export var fat_getup_mult := 2.0

@export_group("Swimming")
@export var swim_cruise_speed := 4.0
## How fast the penguin gets up to cruise speed (m/s²).
@export var swim_acceleration := 6.0
## How fast a boost bleeds back down to cruise speed (m/s²).
@export var swim_drag := 5.0
@export var swim_turn_rate_deg := 120.0
@export var swim_max_pitch_deg := 75.0
## With no up/down input, pitch drifts back to level at this rate.
@export var swim_pitch_return_deg := 25.0
## While cruising along the surface the nose can tilt up this far (aiming a launch).
@export var surface_max_pitch_deg := 50.0
@export var invert_pitch := false

@export_group("Boost & launch")
@export var boost_peak_speed := 9.0
@export var boost_duration := 0.8
@export var boost_cooldown := 0.5
## Crossing the surface upward at or above this speed throws the penguin into the air.
@export var porpoise_min_speed := 6.0
## Extra multiplier on vertical exit speed, for feel. 1.0 = pure physics.
@export var breach_vertical_mult := 1.0
## Fraction of speed kept when hitting the water from the air.
@export var water_entry_speed_keep := 0.8

@export_group("Ice")
@export var walk_speed := 1.2
@export var walk_acceleration := 6.0
@export var walk_turn_rate_deg := 300.0
@export var slide_start_speed := 5.0
## Belly-slide deceleration on ice (m/s²). Low = slippery.
@export var slide_friction := 0.6
@export var slide_turn_rate_deg := 45.0
## How quickly a slide's direction follows the way the penguin is facing.
@export var slide_grip := 1.5
## Tapping action mid-slide pushes off with the flippers.
@export var slide_push_speed := 1.5
@export var slide_push_cooldown := 0.4
@export var slide_stop_speed := 0.8
## Landing faster than this (horizontal m/s) turns into a belly-slide.
@export var slide_land_min_speed := 2.5
## Once a slide stops, this long on the belly (still a puck) before standing up.
@export var slide_getup_seconds := 0.4
## Slopes steeper than this are too slippery to stand on: you slip into a belly-slide.
@export var walk_max_slope_deg := 14.0
## Scales how hard slopes speed up (or slow down) a slide. 1.0 = real gravity.
@export var slide_slope_gravity_mult := 1.0
@export var slide_max_speed := 12.0
## Walk into a ledge this high or lower and you hop up it (thin penguin; fat scales it down).
@export var hop_height := 0.9
@export var hop_forward_speed := 1.6
@export var hop_cooldown := 0.3

@export_group("Bumping")
## Closing speed needed for a bump. Slower than this, penguins just push each other.
@export var bump_min_speed := 2.0
## Closing speed for a hard bump: side hits spin you out, overfed penguins spill a fish.
@export var hard_bump_speed := 4.0
## 1.0 = perfect billiard balls, 0.0 = no bounce at all.
@export var bump_bounciness := 0.8
## On your feet you have grip and take this share of the knockback. On your belly you take it all.
@export var feet_grip_mult := 0.5
@export var water_knockback_mult := 0.35
@export var max_knockback_speed := 6.0
## Deceleration while skidding on your feet after a hit (m/s²).
@export var foot_skid_friction := 2.5
## Deceleration while tumbling on your belly after a hit (m/s²). Higher than a normal slide.
@export var tumble_friction := 2.0
## How fast knockback fades in water (m/s²).
@export var water_knock_drag := 6.0
## Share of a hit a knocked penguin passes on when it flies into another.
@export var chain_transfer := 0.5
@export var spin_out_seconds := 0.5
## After a bump, a penguin can't be knocked again for this long. No juggling.
@export var knock_immunity_seconds := 0.75
## Knocked to the ice edge on your feet, you wobble this long before falling in.
@export var teeter_seconds := 0.6

@export_group("Air & gravity")
@export var air_seconds := 25.0
@export var air_refill_seconds := 2.0
@export var gravity := 9.8
@export var air_turn_rate_deg := 30.0
