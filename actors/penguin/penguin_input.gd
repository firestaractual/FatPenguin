class_name PenguinInput
extends RefCounted
## Where a penguin's stick and button come from. Each physics frame the penguin calls read(), then
## moves by `move` and `action` under the same rules whoever is behind them. This base class is
## nobody: a dummy that only gets knocked around. PlayerInput reads one player's controls;
## BrainInput turns what a PenguinBrain wants (Penguin.wish_dir) into a stick.

## The stick: x is right, y is forward (up on the stick).
var move := Vector2.ZERO
## Action was pressed this frame (boost in the water, flop or push on the ice).
var action := false


## Reads this frame's stick and button into `move` and `action`.
func read(_penguin: Penguin) -> void:
	move = Vector2.ZERO
	action = false


## Which way `stick` points on the ice, as a flat world direction up to 1 long (zero for no
## push). The penguin passes its stick after anything that overrides it (a spin-out zeroes it).
func ground_dir(_penguin: Penguin, _stick: Vector2) -> Vector3:
	return Vector3.ZERO
