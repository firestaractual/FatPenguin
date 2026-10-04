class_name PredatorSpawn
extends Resource
## One line of a level's predator list: what to spawn, how many, and where around the ice they
## start. A PredatorSpawner places them.

@export var display_name := ""
## The predator (a scene whose root is a Predator: leopard_seal.tscn, orca.tscn).
@export var predator_scene: PackedScene
## How many: single predators, or pods when pod_scene is set.
@export var count := 1
## Set this to spawn them in pods (a scene whose root is a PredatorPod: orca_pod.tscn)...
@export var pod_scene: PackedScene
## ...of this many predators each.
@export var pod_size := 3
## Where around the ice the first one starts (degrees: 0 is +X, 90 is +Z). The others are spread
## evenly from there across spread_deg.
@export var start_angle_deg := -90.0
@export var spread_deg := 120.0
## Start depth (m below the surface).
@export var start_depth := 2.5
