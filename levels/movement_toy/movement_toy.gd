class_name MovementToy
extends Node3D
## Prototype 0 test level, grown into a berg field: the home floe with a plateau on top (chutes to
## slide down, steps to hop up), a few floes and a low ramp out of the water, and around it five
## bergs of the real kinds (tabular, wedge, pinnacle, dome, drydock) joined by chains of pack ice
## to hop across, with swim tunnels, a cave and a lagoon (BergField; GDD §4.10). Colonies of NPC
## penguins huddle on the bergs and go fishing in parties (PenguinBrain). Fish school round every
## berg; dummy penguins to bump; and predators: leopard seals hunting the water and lying in wait
## under the ice edge, and an orca pod that washes penguins off low ice, tips floes and traps
## penguins in the water (early pieces of Prototypes 1 and 2). The game (WaddleMatch, GDD §4.12):
## each colony is a family, yours on the home floe; lay eggs in any waddle, raise chicks, break your
## rivals' ice with the weight (every berg's waddle is a WaddleIce), and be the last family alive.

const FISH_SCENE := preload("res://actors/fish/fish.tscn")
const PENGUIN_SCENE := preload("res://actors/penguin/penguin.tscn")
const HUMPBACK_SCENE := preload("res://actors/whales/humpback.tscn")
const KRILL_SCRIPT := preload("res://actors/food/krill_swarm.gd")
const SQUID_SCRIPT := preload("res://actors/food/squid.gd")

@export var fish_seed := 7
## The kinds of fish in the level. Each gets at least one school; the rest are picked by
## abundance. School size and depth come from the species.
@export var fish_species: Array[FishSpecies] = [
	preload("res://tuning/fish/silverfish.tres"),
	preload("res://tuning/fish/lanternfish.tres"),
	preload("res://tuning/fish/icefish.tres"),
]
## Single-species schools placed as practice targets (a preview of food pulses). They're spread
## round the bergs (more round the bigger ones), within an easy swim of the ice.
@export var schools := 28
## Fish on their own between the schools. Lone fish that drift within school range of their
## own kind join up and stay.
@export var loose_fish := 36
## This share of the fish (schools and loose) are sick: diseased or full of parasites, and they
## look it. Eating one makes a penguin queasy (Fish.sick, Penguin.eat_sick_fish()).
@export var sick_fish_share := 0.1
## Krill swarms (pink clouds of snacks near the surface) this far out from a berg's edge (m)...
@export var krill_swarms := 8
@export var krill_distance := Vector2(4.0, 20.0)
## ...and squid (a big meal that jets away) this far out.
@export var squid := 6
@export var squid_distance := Vector2(8.0, 30.0)
## The home floe's radius (its shape is the Iceberg node).
@export var berg_radius := 30.0
## Schools sit this far out from a berg's edge (min, max; m)...
@export var school_distance := Vector2(6.0, 18.0)
## ...and loose fish this far.
@export var loose_distance := Vector2(6.0, 40.0)
## No fish's home is closer to ice than this (m), so roaming fish don't swim into a keel.
@export var fish_clearance := 7.0
## The ice orcas can tip with a ram (TippableIce): the berg with its plateau and ramp, and each
## floe. Their size comes from their collision shapes.
@export var berg_bodies: Array[NodePath] = [^"Iceberg", ^"Plateau", ^"Ramp"]
@export var floes: Array[NodePath] = [^"FloeEasy", ^"FloeMedium", ^"FloeHard"]
## A dummy knocked into the water pops back to its spot after this long.
@export var dummy_respawn_seconds := 2.0
## The colonies' NPC penguins start with energy in this range, and are tinted this way so they're
## easy to tell from the player (and from the blue dummies).
@export var npc_energy := Vector2(40.0, 80.0)
@export var npc_tint := Color(0.42, 0.38, 0.34, 1.0)
## The predators: what spawns, how many and where (PredatorSpawn entries, placed around the berg
## by a PredatorSpawner). They start away from the player's spawn on the south side.
@export var predator_spawns: Array[PredatorSpawn] = [
	preload("res://levels/movement_toy/predators/leopard_seals.tres"),
	preload("res://levels/movement_toy/predators/orca_pod.tres"),
]
## Humpbacks (GDD §5.5): how many roam round the berg, and where the first starts (degrees: 0 is
## +X, 90 is +Z; the others are spread evenly round). They go under the Whales node.
@export var humpback_count := 2
@export var humpback_start_deg := 45.0

## The match between the families (WaddleMatch), and every berg's waddle (WaddleIce): on.
@export var play_match := true

var _wet_time := {}


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = fish_seed
	var container := $Fish
	var bergs := _bergs()
	for s in schools:
		var species := fish_species[s] if s < fish_species.size() else _pick_species(rng)
		var centre := _spot_near(rng, species, _pick_berg(rng, bergs), school_distance)
		var size := rng.randi_range(species.school_size.x, species.school_size.y) if species else 6
		for i in size:
			var jitter := Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(-0.8, 0.8), rng.randf_range(-1.5, 1.5))
			var fish := _make_fish(centre + jitter, species)
			container.add_child(fish)
			# The whole school shares one home spot from the start.
			fish.home = centre
	for i in loose_fish:
		var species := _pick_species(rng)
		container.add_child(_make_fish(_spot_near(rng, species, _pick_berg(rng, bergs), loose_distance), species))
	# Which fish are sick, where the krill and squid are, and the colonies each get their own
	# random numbers, so changing one doesn't move the others.
	var sick_rng := RandomNumberGenerator.new()
	sick_rng.seed = fish_seed + 1000
	for fish: Fish in container.get_children():
		if sick_rng.randf() < sick_fish_share:
			fish.make_sick()
	var food_rng := RandomNumberGenerator.new()
	food_rng.seed = fish_seed + 2000
	_spawn_food(food_rng, bergs)
	_make_tippable_ice()
	var colony_rng := RandomNumberGenerator.new()
	colony_rng.seed = fish_seed + 3000
	_spawn_colonies(colony_rng, bergs)
	_make_waddles(bergs)
	var spawner := PredatorSpawner.new()
	spawner.name = "Predators"
	spawner.spawns = predator_spawns
	spawner.ice_centre = Vector3.ZERO
	spawner.ice_radius = berg_radius
	add_child(spawner)
	if play_match:
		_spread_predators(spawner, colony_rng)
	_spawn_humpbacks()


## A waddle (WaddleIce) on every berg that holds one, and the match between the families living on
## them.
func _make_waddles(bergs: Array[IceBerg]) -> void:
	for berg in bergs:
		if berg.holds_waddle():
			var ice := WaddleIce.new()
			ice.berg = berg
			add_child(ice)
	var game := WaddleMatch.new()
	game.name = "WaddleMatch"
	add_child(game)
	game.active = play_match
	game.begin()
	var end := MatchEnd.new()
	end.name = "MatchEnd"
	add_child(end)


## In a match, the predators start round the rival families' bergs (one group each, in turn), not
## all round the player's: everyone's in the same water from the start.
func _spread_predators(spawner: PredatorSpawner, rng: RandomNumberGenerator) -> void:
	var player := get_node_or_null(^"Penguin") as Node3D
	var homes: Array[IceBerg] = []
	for berg in _bergs():
		var players_home := player != null and Vector2(player.global_position.x - berg.global_position.x, player.global_position.z - berg.global_position.z).length() < berg.reach()
		if berg.colony > 0 and not players_home:
			homes.append(berg)
	if homes.is_empty():
		return
	homes.sort_custom(func(a: IceBerg, b: IceBerg) -> bool: return String(a.name) < String(b.name))
	var i := 0
	for group in spawner.get_children():
		var berg := homes[i % homes.size()]
		i += 1
		var members: Array[Predator] = []
		if group is PredatorPod:
			members = (group as PredatorPod).members()
		elif group is Predator:
			members.append(group as Predator)
		if members.is_empty():
			continue
		var a := rng.randf() * TAU
		var r := berg.reach() + members[0].tuning.patrol_offset
		var shift := berg.global_position + Vector3(cos(a), 0.0, sin(a)) * r - members[0].global_position
		shift.y = 0.0
		for member in members:
			member.global_position += shift
			member.patrol_round(berg)


## The match between the families (null if the level has none).
func waddle_match() -> WaddleMatch:
	return get_node_or_null(^"WaddleMatch") as WaddleMatch


## Krill swarms and squid round the bergs, under a Food node.
func _spawn_food(rng: RandomNumberGenerator, bergs: Array[IceBerg]) -> void:
	var food := Node3D.new()
	food.name = "Food"
	add_child(food)
	for i in krill_swarms:
		var swarm := KRILL_SCRIPT.new() as KrillSwarm
		swarm.name = "Krill%d" % i
		swarm.position = _spot_at_depth(rng, swarm.tuning.depth, _pick_berg(rng, bergs), krill_distance)
		food.add_child(swarm)
	for i in squid:
		var one := SQUID_SCRIPT.new() as Squid
		one.name = "Squid%d" % i
		one.position = _spot_at_depth(rng, one.tuning.depth, _pick_berg(rng, bergs), squid_distance)
		food.add_child(one)


func _spawn_humpbacks() -> void:
	var whales := Node3D.new()
	whales.name = "Whales"
	add_child(whales)
	for i in humpback_count:
		var whale := HUMPBACK_SCENE.instantiate() as Humpback
		var angle := deg_to_rad(humpback_start_deg) + TAU * i / maxf(humpback_count, 1)
		var d := berg_radius + whale.tuning.roam_offset.x + 10.0
		whale.roam_centre = Vector3.ZERO
		whale.ice_radius = berg_radius
		whale.position = Vector3(cos(angle) * d, GameWorld.WATER_LEVEL - whale.tuning.travel_depth.x, sin(angle) * d)
		whales.add_child(whale)


## Marks the berg and each floe as ice that can be tipped, pivoting at its middle at the waterline.
## The pack-ice floes in the chains can be tipped too; the bigger bergs can't.
func _make_tippable_ice() -> void:
	_add_tippable(&"TippableBerg", berg_bodies, Vector3.ZERO, berg_radius)
	for path in floes:
		var floe := get_node_or_null(path) as Node3D
		if floe == null:
			continue
		var shape := (floe.get_node("CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D
		_add_tippable(StringName("Tippable" + floe.name), [path], Vector3(floe.position.x, 0.0, floe.position.z), shape.radius if shape else 4.0)
	for node in find_children("*", "FloeChain", true, false):
		var chain := node as FloeChain
		for floe in chain.floes():
			_add_tippable(StringName("Tippable%s%s" % [chain.name, floe.name]), [get_path_to(floe)], Vector3(floe.global_position.x, 0.0, floe.global_position.z), chain.floe_radius())


## The bergs in the field (and the home floe), for fish and colonies.
func _bergs() -> Array[IceBerg]:
	var list: Array[IceBerg] = []
	for node in get_tree().get_nodes_in_group(&"bergs"):
		var berg := node as IceBerg
		if berg != null and is_ancestor_of(berg):
			list.append(berg)
	return list


## A berg picked at random, bigger ones more often.
func _pick_berg(rng: RandomNumberGenerator, bergs: Array[IceBerg]) -> IceBerg:
	var total := 0.0
	for berg in bergs:
		total += berg.reach()
	var roll := rng.randf() * total
	for berg in bergs:
		roll -= berg.reach()
		if roll <= 0.0:
			return berg
	return bergs.back() if not bergs.is_empty() else null


## A fish home in the water `distance` (min, max) off `berg`'s edge, at the species' depth, and
## clear of all ice.
func _spot_near(rng: RandomNumberGenerator, species: FishSpecies, berg: IceBerg, distance: Vector2) -> Vector3:
	return _spot_at_depth(rng, species.depth_range if species else Vector2(1.0, 8.0), berg, distance)


## A spot in the water `distance` (min, max) off `berg`'s edge, `depths` (min, max) down, and clear
## of all ice.
func _spot_at_depth(rng: RandomNumberGenerator, depths: Vector2, berg: IceBerg, distance: Vector2) -> Vector3:
	var centre := berg.global_position if berg != null else Vector3.ZERO
	var reach := berg.reach() if berg != null else berg_radius
	var spot := Vector3.ZERO
	for attempt in 16:
		var angle := rng.randf() * TAU
		var d := reach + rng.randf_range(distance.x, distance.y)
		spot = centre + Vector3(cos(angle) * d, -rng.randf_range(depths.x, depths.y), sin(angle) * d)
		if clear_of_ice(spot, fish_clearance):
			return spot
	return spot


## No ice (berg, floe, keel) within `clearance` of `spot`.
func clear_of_ice(spot: Vector3, clearance: float) -> bool:
	var ball := SphereShape3D.new()
	ball.radius = clearance
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform = Transform3D(Basis.IDENTITY, spot)
	query.collision_mask = GameWorld.WORLD_LAYER
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 4):
		if hit["collider"] != $Seafloor and hit["collider"] != $Bounds:
			return false
	return true


## Each berg's colony of NPC penguins, standing round its waddle spot.
func _spawn_colonies(rng: RandomNumberGenerator, bergs: Array[IceBerg]) -> void:
	var colonies := Node3D.new()
	colonies.name = "Colonies"
	add_child(colonies)
	for berg in bergs:
		var spot := berg.waddle_spot()
		for i in berg.colony:
			var npc := PENGUIN_SCENE.instantiate() as Penguin
			npc.name = "%sNpc%d" % [berg.name, i]
			npc.player_controlled = false
			npc.start_energy = rng.randf_range(npc_energy.x, npc_energy.y)
			npc.body_tint = npc_tint
			var angle := rng.randf() * TAU
			npc.position = spot + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(0.5, 3.0) + Vector3.UP * 0.5
			var brain := PenguinBrain.new()
			brain.name = "Brain"
			brain.berg = berg
			npc.add_child(brain)
			npc.add_to_group(&"npcs")
			colonies.add_child(npc)


func _add_tippable(ice_name: StringName, paths: Array[NodePath], at: Vector3, radius: float) -> void:
	var ice := TippableIce.new()
	ice.name = ice_name
	ice.position = at
	ice.radius = radius
	for path in paths:
		ice.bodies.append(NodePath("../" + str(path)))
	add_child(ice)


## A species picked at random, weighted by abundance. Null if the level has none.
func _pick_species(rng: RandomNumberGenerator) -> FishSpecies:
	var total := 0.0
	for species in fish_species:
		total += species.abundance
	var roll := rng.randf() * total
	for species in fish_species:
		roll -= species.abundance
		if roll <= 0.0:
			return species
	return fish_species.back() if not fish_species.is_empty() else null


func _make_fish(at: Vector3, species: FishSpecies) -> Fish:
	var fish := FISH_SCENE.instantiate() as Fish
	fish.species = species
	fish.position = at
	return fish


func _physics_process(delta: float) -> void:
	for dummy in $Dummies.get_children():
		var p := dummy as Penguin
		if p == null:
			continue
		if p.state == Penguin.State.SWIM:
			_wet_time[p] = _wet_time.get(p, 0.0) + delta
			if _wet_time[p] >= dummy_respawn_seconds:
				_wet_time[p] = 0.0
				p.reset()
		else:
			_wet_time[p] = 0.0
