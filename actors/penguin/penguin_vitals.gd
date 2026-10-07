class_name PenguinVitals
extends RefCounted
## A penguin's energy and air (GDD §4.1, §4.2, §4.4). Every penguin has one (Penguin.vitals), and
## the rules about both live here: the energy loop, the waddle's drain and exhaustion build on
## this. Numbers are in PenguinTuning (Energy, Air).
##
## Food is energy: eating adds to it, and it pays for boosts, flops and scrambles (spend()). It
## drains over time, twice as fast when overfed, and a computer penguin sheltered in a huddle drains
## slower (drain_mult). The cold never takes it below the energy floor (a stand-in until there's a
## real exhausted state); spent below the floor, it creeps back up to it. How full it is
## (fatness()) is how fat the penguin is. Air runs down underwater and refills at the surface.

var tuning: PenguinTuning
var energy := 50.0
## Seconds of breath left.
var air := 25.0
## Energy drains this many times as fast as normal (1). A PenguinBrain lowers it while its
## penguin is sheltered in a huddle.
var drain_mult := 1.0
## No drain and no costs (F2 toggles it for the player; dummies have it on).
var infinite := false


## 0.0 = starving, 1.0 = stuffed.
func fatness() -> float:
	return clampf(energy / tuning.max_energy, 0.0, 1.0)


## Overfed: past overfill_threshold, it drains faster and a hard bump knocks a fish loose.
func is_overfed() -> bool:
	return energy > tuning.overfill_threshold


func can_afford(cost: float) -> bool:
	return infinite or energy >= cost


## Pays `cost` if it can afford it (free with infinite). False, with nothing spent, if it can't.
func spend(cost: float) -> bool:
	if not can_afford(cost):
		return false
	if not infinite:
		energy -= cost
	return true


## Adds `amount` (a fish), up to max_energy. Returns how much it actually gained.
func gain(amount: float) -> float:
	var before := energy
	energy = minf(energy + amount, tuning.max_energy)
	return energy - before


## Loses `amount` whatever infinite says (a fish knocked loose in a bump), down to 0.
func lose(amount: float) -> void:
	energy = maxf(energy - amount, 0.0)


## Back to `start_energy` and a full breath (a respawn).
func refill(start_energy: float) -> void:
	energy = start_energy
	air = tuning.air_seconds


## Each physics frame: breath runs down while `underwater` and refills otherwise; energy drains.
func tick(delta: float, underwater: bool) -> void:
	if underwater:
		air = maxf(air - delta, 0.0)
	else:
		air = minf(air + tuning.air_seconds / tuning.air_refill_seconds * delta, tuning.air_seconds)
	if infinite or not tuning.energy_drain_enabled:
		return
	if energy < tuning.energy_floor:
		# Spent below the floor: get your breath back, up to the floor.
		energy = minf(energy + tuning.floor_recovery * delta, tuning.energy_floor)
		return
	var rate := tuning.base_drain * drain_mult
	if is_overfed():
		rate *= tuning.overfill_drain_mult
	# The cold never takes you below the floor (a stand-in until there's a real exhausted state).
	energy = maxf(energy - rate * delta, tuning.energy_floor)
