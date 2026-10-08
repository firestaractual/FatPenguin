extends RefCounted
## One group of smoke-test checks. tests/movement_smoke_test.gd loads the movement toy, then runs
## each suite (or only some: `-- --only=orcas,npcs`). A suite gets the level and the player
## penguin, runs its checks in run() and reports each through _check().
##
## Drive the actors through their public API only (Penguin.place(), force_state(), set_facing(),
## boost(), PredatorPod.clear_cooldown(), ...), never by setting or calling a private member
## (a leading underscore) by name: Object.set() on a field that no longer exists does nothing, so
## after a rename the check would quietly stop testing instead of failing.

const LEVEL := "res://levels/movement_toy/movement_toy.tscn"
const PENGUIN_SCENE := "res://actors/penguin/penguin.tscn"
const SEAL_SCENE := "res://actors/predators/leopard_seal.tscn"
const ORCA_POD_SPAWN := "res://levels/movement_toy/predators/orca_pod.tres"
## Open ice on the south-east of the berg, clear of the plateau, ramp and level dummies.
const BUMP_LANE_Z := 10.0

var tree: SceneTree
var root: Window
var _level: MovementToy
var _penguin: Penguin
var _plateau: IcePlateau
var _failures: Array[String] = []


func setup(scene_tree: SceneTree, level: MovementToy, failures: Array[String]) -> void:
	tree = scene_tree
	root = scene_tree.root
	_level = level
	_penguin = level.get_node("Penguin") as Penguin
	_plateau = level.get_node("Plateau") as IcePlateau
	_failures = failures


## What --only= calls this suite.
func suite_name() -> String:
	return ""


## The checks, in order.
func run() -> void:
	pass


# --- Helpers ----------------------------------------------------------------


## Leaves `pod` with just its attack called `attack_name`, and returns that attack.
func _only_attack(pod: PredatorPod, attack_name: String) -> PodAttack:
	var kept: Array[PodAttack] = []
	for attack in pod.attacks():
		if attack.settings.display_name == attack_name:
			kept.append(attack)
	pod.set_attacks(kept)
	return kept[0] if not kept.is_empty() else null


## A computer penguin with a brain, living on `home`, at `at`.
func _spawn_npc(home: IceBerg, at: Vector3, energy: float, endless: bool) -> Penguin:
	var p := load(PENGUIN_SCENE).instantiate() as Penguin
	p.player_controlled = false
	p.start_energy = energy
	p.infinite_energy = endless
	p.position = at
	var brain := PenguinBrain.new()
	brain.name = "Brain"
	brain.berg = home
	p.add_child(brain)
	_level.add_child(p)
	return p


## A pod from `entry`, kept round the home floe (no roaming off to other bergs mid-check).
func _spawn_pod(spawner: PredatorSpawner, entry: PredatorSpawn) -> PredatorPod:
	var pod := spawner.spawn(entry)[0] as PredatorPod
	for member in pod.members():
		var t := member.tuning.duplicate() as PredatorTuning
		t.roam_chance = 0.0
		member.tuning = t
	return pod


## A spawner for pods, at the origin, around the berg.
func _spawn_pods() -> PredatorSpawner:
	var spawner := PredatorSpawner.new()
	spawner.ice_radius = _level.berg_radius
	_level.add_child(spawner)
	return spawner


## A computer penguin swimming at the surface at `at`, facing `yaw` (0 faces -Z). It swims
## straight ahead at cruise speed unless a test holds it (set _speed to 0 each frame).
func _spawn_swimmer(at: Vector3, yaw: float) -> Penguin:
	var p := load(PENGUIN_SCENE).instantiate() as Penguin
	p.player_controlled = false
	p.infinite_energy = true
	p.start_energy = 50.0
	p.position = at
	_level.add_child(p)
	p.place(at, yaw, Penguin.State.SWIM)
	return p


## Drops `p` into the water at `at` (on the surface).
func _put_in_water(p: Penguin, at: Vector3) -> void:
	p.global_position = Vector3(at.x, -0.2, at.z)
	p.velocity = Vector3.ZERO
	p.force_state(Penguin.State.SWIM)
	p.reset_physics_interpolation()


## Where a seal with tuning `t` would wait for `p`: off the nearest edge, ambush_depth down.
func _ambush_spot_for(world: World3D, p: Penguin, t: PredatorTuning) -> Vector3:
	var edge := IceEdges.nearest_edge(world, p.global_position, t.ambush_edge_reach)
	if edge.is_empty():
		return Vector3.INF
	var spot: Vector3 = (edge["point"] as Vector3) + (edge["out"] as Vector3) * t.ambush_offset
	spot.y = GameWorld.WATER_LEVEL - t.ambush_depth
	return spot


## Waits until `predator` is lying still close to `spot`, in ambush. False if it never does.
func _wait_settled(predator: Predator, spot: Vector3, max_frames: int) -> bool:
	for i in max_frames:
		await tree.physics_frame
		if predator.state == Predator.State.AMBUSH and predator.global_position.distance_to(spot) < 1.5 and predator.velocity.length() < 0.3:
			return true
	return false


## Is the pod showing the danger marker called `marker_name`?
func _marker_shown(pod: PredatorPod, marker_name: String) -> bool:
	var marker := pod.get_node_or_null(marker_name) as Node3D
	return marker != null and marker.visible


## A leopard seal at `at`, not hungry, patrolling round the berg.
func _spawn_seal(at: Vector3) -> Predator:
	var seal := load(SEAL_SCENE).instantiate() as Predator
	seal.ice_radius = _level.berg_radius
	seal.position = at
	_level.add_child(seal)
	seal.hunger = 0.0
	return seal


## A penguin floating still in the water: bait that doesn't swim off.
func _spawn_bait(at: Vector3, with_energy: float) -> Penguin:
	var p := load(PENGUIN_SCENE).instantiate() as Penguin
	p.player_controlled = false
	p.infinite_energy = true
	p.start_energy = with_energy
	p.position = at
	_level.add_child(p)
	p.set_physics_process(false)
	return p


## A fish of `species` at `at`.
func _spawn_fish(species: FishSpecies, at: Vector3) -> Fish:
	var fish := load("res://actors/fish/fish.tscn").instantiate() as Fish
	fish.species = species
	fish.position = at
	root.add_child(fish)
	return fish


## How many fish of `fish`'s species in `all` are within its school range.
func _school_mates_in_range(fish: Fish, all: Array) -> int:
	var mates := 0
	for other: Fish in all:
		if other != fish and other.species == fish.species \
				and other.global_position.distance_to(fish.global_position) <= fish.species.school_range:
			mates += 1
	return mates


## The middle of a group of fish.
func _middle_of(fishes: Array[Fish]) -> Vector3:
	var sum := Vector3.ZERO
	for fish in fishes:
		sum += fish.global_position
	return sum / fishes.size()


## Puts the test penguin in the water at `pos`, swimming at cruise speed.
func _place_swimming(pos: Vector3, yaw: float, pitch_deg: float) -> void:
	_penguin.place(pos, yaw, Penguin.State.SWIM, deg_to_rad(pitch_deg), _penguin.tuning.swim_cruise_speed)


## Stand a penguin on the ice at `ground` (a point on the surface) and wait until it's on its feet.
func _place_on_ice(p: Penguin, ground: Vector3, yaw: float, with_energy: float) -> void:
	p.energy = with_energy
	p.place(ground + Vector3.UP * (p.get_node("CollisionShape3D").shape.radius + 0.05), yaw, Penguin.State.AIR)
	for i in 60:
		await tree.physics_frame
		if p.state == Penguin.State.WALK:
			break
	await _frames(20)

func _spawn_standing(ground: Vector3, with_energy: float) -> Penguin:
	var p: Penguin = load(PENGUIN_SCENE).instantiate()
	p.player_controlled = false
	p.infinite_energy = true
	p.start_energy = with_energy
	p.position = ground + Vector3.UP * 0.5
	_level.add_child(p)
	await _wait_for(p, Penguin.State.WALK, 60)
	await _frames(5)
	return p

func _launch_slide(p: Penguin, dir: Vector3, speed: float) -> void:
	p.start_slide(dir, speed)

func _wait_for_bump(p: Penguin, max_frames: int) -> bool:
	var got := [false]
	var cb := func(_o: Penguin, _s: float, _h: bool) -> void: got[0] = true
	p.bumped.connect(cb)
	for i in max_frames:
		await tree.physics_frame
		if got[0]:
			break
	p.bumped.disconnect(cb)
	return got[0]


## Waits until `p` stops moving; returns how far it ended up from `from` (horizontally).
func _wait_until_still(p: Penguin, from: Vector3) -> float:
	var still := 0
	for i in 600:
		await tree.physics_frame
		still = still + 1 if Vector2(p.velocity.x, p.velocity.z).length() < 0.05 else 0
		if still > 10:
			break
	return Vector2(p.global_position.x - from.x, p.global_position.z - from.z).length()

func _wait_for(p: Penguin, state: Penguin.State, max_frames: int) -> bool:
	for i in max_frames:
		if p.state == state:
			return true
		await tree.physics_frame
	return p.state == state

func _tap(action: StringName) -> void:
	Input.action_press(action)
	await tree.physics_frame
	await tree.physics_frame
	Input.action_release(action)

func _wait_for_state(state: Penguin.State, max_frames: int) -> bool:
	for i in max_frames:
		if _penguin.state == state:
			return true
		await tree.physics_frame
	return _penguin.state == state

func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame

func _state() -> String:
	return Penguin.State.keys()[_penguin.state]

func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failures.append(what)
