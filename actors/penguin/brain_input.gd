class_name BrainInput
extends PenguinInput
## A computer penguin's controls: the stick a player would push to go the way its PenguinBrain
## wants (Penguin.wish_dir), the button (wish_action, pressed for one frame) and pulling back to
## brake a slide (wish_brake). So NPCs move by exactly the player's rules. Setting
## Penguin.brain_controlled switches a penguin to one of these.


func read(penguin: Penguin) -> void:
	move = _stick(penguin)
	action = penguin.wish_action
	penguin.wish_action = false


## On the ice it walks straight where it wants to go (only the flat part counts).
func ground_dir(penguin: Penguin, stick: Vector2) -> Vector3:
	if stick.length() < 0.05:
		return Vector3.ZERO
	return Vector3(penguin.wish_dir.x, 0.0, penguin.wish_dir.z).limit_length(1.0)


## On the ice only the push matters (ground_dir() gives the direction); swimming, sliding and in
## the air it turns and pitches the penguin toward wish_dir the way a player would.
func _stick(penguin: Penguin) -> Vector2:
	var want := penguin.wish_dir
	var strength := minf(want.length(), 1.0)
	var state := penguin.state
	if strength < 0.05:
		return Vector2(0.0, -1.0) if penguin.wish_brake and state == Penguin.State.SLIDE else Vector2.ZERO
	match state:
		Penguin.State.SWIM, Penguin.State.SLIDE, Penguin.State.AIR:
			var turn := 0.0
			if Vector2(want.x, want.z).length() > 0.01:
				var target_yaw := atan2(-want.x, -want.z)
				turn = clampf(-wrapf(target_yaw - penguin.facing_yaw(), -PI, PI) * 3.0, -1.0, 1.0)
			var pitch := 0.0
			if state == Penguin.State.SWIM:
				var target_pitch := asin(clampf(want.normalized().y, -1.0, 1.0))
				pitch = clampf((target_pitch - penguin.swim_pitch()) * 3.0, -1.0, 1.0)
			if state == Penguin.State.SLIDE and penguin.wish_brake:
				pitch = -1.0
			return Vector2(turn, pitch)
	return Vector2(0.0, strength)
