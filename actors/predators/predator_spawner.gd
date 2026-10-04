class_name PredatorSpawner
extends Node3D
## Spawns a level's predators from its list of PredatorSpawn entries. Each predator starts on its
## patrol loop around the ice (its tuning's patrol_offset outside the edge). Pods are spawned as
## PredatorPod nodes with their members inside, one behind the other.
## Keep this node at the origin, unrotated: predators are placed in world space.

@export var spawns: Array[PredatorSpawn] = []
## The ice the predators patrol around.
@export var ice_centre := Vector3.ZERO
@export var ice_radius := 30.0


func _ready() -> void:
	for entry in spawns:
		spawn(entry)


## Spawns one entry and returns what it added (predators, or pods).
func spawn(entry: PredatorSpawn) -> Array[Node3D]:
	var added: Array[Node3D] = []
	for i in entry.count:
		var step := entry.spread_deg / (entry.count - 1) if entry.count > 1 else 0.0
		var angle := deg_to_rad(entry.start_angle_deg + step * i)
		if entry.pod_scene == null:
			var predator := _make_predator(entry, angle, 0.0)
			add_child(predator)
			added.append(predator)
			continue
		var pod := entry.pod_scene.instantiate() as PredatorPod
		add_child(pod)
		for j in entry.pod_size:
			pod.add_child(_make_predator(entry, angle, j * pod.tuning.spacing))
		added.append(pod)
	return added


## A predator on its patrol loop at `angle`, `behind` metres back along the loop.
func _make_predator(entry: PredatorSpawn, angle: float, behind: float) -> Predator:
	var predator := entry.predator_scene.instantiate() as Predator
	predator.patrol_centre = ice_centre
	predator.ice_radius = ice_radius
	var radius := ice_radius + predator.tuning.patrol_offset
	var along := Vector3(-sin(angle), 0.0, cos(angle))
	predator.position = ice_centre + Vector3(cos(angle) * radius, -entry.start_depth, sin(angle) * radius) - along * behind
	return predator
