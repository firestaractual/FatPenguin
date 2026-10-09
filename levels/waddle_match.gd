class_name WaddleMatch
extends GameMode
## Families of penguins outlasting each other (GDD §4.12, §6): the movement toy's game.
##
## Families: every berg that starts with a colony is a family's home, and the player's family is the
## colony on the berg the player starts on. Each penguin has a silly name and its family's colour
## (NPCs' backs are tinted with it; chicks' down too). A family's lives are its kin alive: its grown
## penguins and its hatched chicks, wherever they are.
##
## The life loop, the same for everyone: huddle, fish, and when you've filled up out in the water
## (hatch_energy) you're full: lay the egg in any waddle (WaddleIce). Yours, or a rival's: a chick
## belongs to whoever laid it, and computer penguins can't tell and feed any chick that begs (a
## cuckoo: raised on their fish, weighing down their ice). Players feed only their own chicks. A
## chick grows a size every few feedings and, full grown for a while, grows up into a young adult of
## its family (one more computer penguin, living where it grew up). Computer penguins lay at home
## while home would stay safe even with the chick grown (nest_safe), otherwise in the rival waddle
## nearest to breaking, otherwise on an empty berg (PenguinBrain.visit()). A family stops laying at
## family_cap.
##
## Death: a penguin that's caught is eaten (gone). A player that's caught carries on as its family's
## fattest grown penguin (it takes its place); with none left, its biggest chick grows up on the spot
## and it carries on as that; with none, its family is out. The same goes for a computer family:
## when its last adult goes, its biggest chick grows up at once. A berg that breaks up loses every
## egg and chick on it (WaddleIce). The last family with anyone alive wins.
##
## Stats: every penguin's eggs laid, cuckoo eggs and chicks raised to grown-ups. ranking() is this
## match's leaderboard; when the match ends its penguins go on the all-time one (Leaderboard).
##
## Numbers are in WaddleTuning (tuning/waddle.tres). The level makes one, after its WaddleIce and
## colonies, and calls begin() (MovementToy). With `active` off it's out of the way: a catch is the
## movement toy's (respawn), and the waddles don't break.
##
## Chicks are its children (in world space: it isn't a 3D node).

## Something happened worth telling the player (for the HUD's feed): `text`, in `colour`.
signal announced(text: String, colour: Color)
## `parent` laid `chick` in a waddle (a rival's: `cuckoo`).
signal laid(chick: Chick, parent: Penguin, cuckoo: bool)
## `by` fed `chick` a beakful.
signal fed(chick: Chick, by: Penguin)
## A chick grew up into `adult`.
signal grew_up(adult: Penguin)
## A chick (or egg) was lost: its berg broke up.
signal lost_chick(chick: Chick)
## `penguin` (of `family`) was eaten.
signal died(penguin: Penguin, family: int)
## The player carries on as `name`, a penguin of its family.
signal took_over(player: Penguin, new_name: String)
## Nobody of `family` is left.
signal family_out(family: int)
## The match is over: `winner` is the family left (-1: nobody).
signal ended(winner: int)

## A family: an id (its index in families), its name and colour, the berg it started on, and
## whether a player is in it.
class Family:
	var id := 0
	var name := ""
	var colour := Color.WHITE
	var home: IceBerg = null
	var player := false
	var out := false

const DEFAULT_TUNING := preload("res://tuning/waddle.tres")
const PENGUIN_SCENE := preload("res://actors/penguin/penguin.tscn")
const CHICK_SCRIPT := preload("res://actors/penguin/chick.gd")
## Families' colours, in order (the player's first): clear of the danger colour and its oranges.
const COLOURS: Array[Color] = [
	Color(0.36, 0.62, 1.0), Color(0.7, 0.48, 0.95), Color(0.38, 0.82, 0.52),
	Color(0.97, 0.55, 0.78), Color(0.35, 0.85, 0.88), Color(0.78, 0.8, 0.86),
]
const KINDS: Array[String] = ["family", "mob", "gang", "crew", "lot", "bunch"]
## Nicer names for bergs in family names.
const BERG_NAMES := {"HomeFloe": "Floe"}
## Silly names: a title and a name.
const TITLES: Array[String] = ["Big", "Little", "Lord", "Auntie", "Captain", "Chubby", "Sir", "Old",
	"Wee", "Madame", "Uncle", "Professor", "Lady", "Baby", "Grand", "Duchess", "Sergeant", "Mister"]
const NAMES: Array[String] = ["Gus", "Pip", "Flipper", "Waddles", "Mo", "Dot", "Nugget", "Bubbles",
	"Sprat", "Krill", "Biscuit", "Tux", "Pudding", "Noodle", "Squid", "Mittens", "Puffin", "Gerald",
	"Waffles", "Sardine", "Pebble", "Blubber", "Dumpling", "Jelly", "Toast", "Slushy", "Iggy", "Fudge"]
## How often it hands out wants_egg and checks for families out (s).
const CHECK_INTERVAL := 0.5

@export var tuning: WaddleTuning = DEFAULT_TUNING
## Off: out of the way (a catch respawns, the waddles don't break). The smoke test turns it off for
## the other checks.
@export var active := true:
	set(value):
		active = value
		_sync_active()
@export var name_seed := 5

var families: Array[Family] = []

## Each grown penguin's family id.
var _family_of := {}
## Each penguin's record (alive ones, by penguin), and every record this match, dead or alive:
## {"name", "family", "eggs", "cuckoos", "raised", "alive", "player"}.
var _records := {}
var _all_records: Array[Dictionary] = []
## Each chick's layer's record.
var _parent_of := {}
## Penguins that are full: where they'll lay (a berg, or null for anywhere: a player).
var _full := {}
## Each penguin's time beside a hungry chick toward its next feeding (s).
var _feed_clock := {}
var _clock := 0.0
var _check_left := 0.0
var _ended := false
var _winner := -1
var _breaks := 0
var _names_used := {}
## Chicks lost by each family since the last berg broke up (told all at once).
var _lost_tally := {}
var _rng := RandomNumberGenerator.new()
var _meal_mesh: Mesh


## The level's match, or null.
static func current(tree: SceneTree) -> WaddleMatch:
	return tree.get_first_node_in_group(&"waddle_match") as WaddleMatch if tree != null else null


func _enter_tree() -> void:
	add_to_group(&"waddle_match")
	if active:
		add_to_group(&"game_mode")


func _ready() -> void:
	if tuning == null:
		tuning = DEFAULT_TUNING
	_sync_active()


# --- Setting up -----------------------------------------------------------------------

## Starts the match: a family for every berg with a colony (the player's, on the berg it starts
## on, first), names and colours for everyone. Call it once the colonies are in place; calling it
## again starts over with whoever is there now.
func begin() -> void:
	families.clear()
	_family_of.clear()
	_records.clear()
	_all_records.clear()
	_parent_of.clear()
	_full.clear()
	_feed_clock.clear()
	_names_used.clear()
	_clock = 0.0
	_ended = false
	_winner = -1
	_breaks = 0
	_rng.seed = name_seed
	var player := get_tree().get_first_node_in_group(&"player") as Penguin
	var homes: Array[IceBerg] = []
	var player_home: IceBerg = null
	if player != null:
		var ice: WaddleIce = null
		for each in WaddleIce.all(get_tree()):
			if each.covers(player.spawn_point()):
				ice = each
		if ice == null:
			ice = WaddleIce.nearest(get_tree(), player.global_position)
		player_home = ice.berg if ice != null else null
		if player_home != null:
			homes.append(player_home)
	for node in get_tree().get_nodes_in_group(&"bergs"):
		var berg := node as IceBerg
		if berg != null and berg.holds_waddle() and not homes.has(berg) and not PenguinBrain.colony_of(berg).is_empty():
			homes.append(berg)
	for berg in homes:
		var family := Family.new()
		family.id = families.size()
		family.home = berg
		family.colour = COLOURS[family.id % COLOURS.size()]
		family.player = berg == player_home and player != null
		var place: String = BERG_NAMES.get(String(berg.name), String(berg.name))
		family.name = "Your family" if family.player else "The %s %s" % [place, KINDS[family.id % KINDS.size()]]
		families.append(family)
		for brain in PenguinBrain.colony_of(berg):
			var b := brain as PenguinBrain
			if is_instance_valid(b) and b.get_parent() is Penguin:
				_join(b.get_parent() as Penguin, family)
	if player != null and player_home != null:
		_join(player, families[0])
	for ice in WaddleIce.all(get_tree()):
		if not ice.broke_through.is_connected(_on_berg_broke):
			ice.broke_through.connect(_on_berg_broke.bind(ice))


## Makes `p` one of `family`, with a name and the family's colour.
func _join(p: Penguin, family: Family) -> void:
	_family_of[p] = family.id
	var record := {"name": _new_name(), "family": family.id, "eggs": 0, "cuckoos": 0, "raised": 0,
		"alive": true, "player": p.is_in_group(&"player")}
	_records[p] = record
	_all_records.append(record)
	if not p.is_in_group(&"player"):
		p.body_tint = Color(family.colour.r * 0.34, family.colour.g * 0.34, family.colour.b * 0.34)
		var brain := _brain(p)
		if brain != null:
			brain.errand_seconds = tuning.errand_seconds


func _new_name() -> String:
	for attempt in 40:
		var title := TITLES[_rng.randi() % TITLES.size()]
		var one := NAMES[_rng.randi() % NAMES.size()]
		var full := "%s %s" % [title, one]
		if not _names_used.has(full):
			_names_used[full] = true
			return full
	var n := _names_used.size()
	return "Penguin %d" % n


# --- What it answers ---------------------------------------------------------------------

## The family `p` belongs to (null: none, a practice dummy).
func family_of(p: Penguin) -> Family:
	var id: int = _family_of.get(p, -1)
	return families[id] if id >= 0 and id < families.size() else null


## The player's family (null if there's no player).
func player_family() -> Family:
	for family in families:
		if family.player:
			return family
	return null


## `p`'s name ("" if it has none).
func name_of(p: Penguin) -> String:
	return _records[p]["name"] if _records.has(p) else ""


## `family`'s grown penguins alive.
func adults(family: Family) -> Array[Penguin]:
	var list: Array[Penguin] = []
	for p: Variant in _family_of:
		if is_instance_valid(p) and _family_of[p] == family.id and (p as Penguin).is_inside_tree():
			list.append(p as Penguin)
	return list


## `family`'s chicks, hatched or not (not the lost ones).
func chicks_of(family: Family, hatched_only := true) -> Array[Chick]:
	var list: Array[Chick] = []
	for node in get_tree().get_nodes_in_group(&"chicks"):
		var chick := node as Chick
		if chick != null and chick.family == family.id and not chick.is_lost() and (chick.is_hatched() or not hatched_only):
			list.append(chick)
	return list


## `family`'s lives: its grown penguins and hatched chicks alive.
func lives(family: Family) -> int:
	return adults(family).size() + chicks_of(family).size()


## Is `p` full, with an egg to lay?
func is_full(p: Penguin) -> bool:
	return _full.has(p)


## A hungry chick begging from `p` right now, or null.
func begging_chick(p: Penguin) -> Chick:
	for node in get_tree().get_nodes_in_group(&"chicks"):
		var chick := node as Chick
		if chick != null and chick.begging_from == p:
			return chick
	return null


## How long the match has run (s), and how many bergs have broken up.
func elapsed() -> float:
	return _clock


func breaks() -> int:
	return _breaks


func is_over() -> bool:
	return _ended


## The family that won (-1: nobody, or not over yet).
func winner() -> int:
	return _winner


## This match's most prolific penguins, best first: {"name", "family", "colour", "eggs", "cuckoos",
## "raised", "alive", "player"} ("family" is the family's name).
func ranking() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for record in _all_records:
		var family: Family = families[record["family"]] if record["family"] < families.size() else null
		list.append({"name": record["name"], "family": family.name if family != null else "",
			"colour": family.colour.to_html(false) if family != null else "ffffff", "eggs": record["eggs"],
			"cuckoos": record["cuckoos"], "raised": record["raised"], "alive": record["alive"], "player": record["player"]})
	list.sort_custom(Leaderboard.better)
	return list


# --- The life loop -------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not active or _ended or families.is_empty():
		return
	_clock += delta
	for p: Variant in _family_of.keys():
		if not is_instance_valid(p):
			_family_of.erase(p)
			continue
		var penguin := p as Penguin
		if not penguin.is_inside_tree():
			continue
		_watch_for_eggs(penguin)
		_feed(penguin, delta)
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_INTERVAL
		for family in families:
			if family.out:
				continue
			var room := _has_room(family)
			for p in adults(family):
				var brain := _brain(p)
				if brain != null:
					brain.wants_egg = room
		_check_families()


## Filling up in the water makes you full (with an egg to lay, if your family has room); reaching a
## waddle full lays it there (a computer penguin, in the waddle it picked).
func _watch_for_eggs(p: Penguin) -> void:
	var family := family_of(p)
	if family == null:
		return
	if not _full.has(p) and p.state == Penguin.State.SWIM and p.energy >= tuning.hatch_energy and _has_room(family):
		var nest := _choose_nest(p, family)
		_full[p] = nest
		var brain := _brain(p)
		if brain != null and nest != null and nest != brain.berg:
			brain.visit(nest)
	if not _full.has(p):
		return
	var nest: IceBerg = _full[p]
	if nest != null and not is_instance_valid(nest):
		_full.erase(p)
		return
	var ice := WaddleIce.holding(get_tree(), p)
	if ice == null or ice.is_broken():
		return
	if p.is_in_group(&"player") or nest == null or ice.berg == nest:
		lay(p, ice)


## Where a computer penguin lays: at home while home would stay safe with the chick grown; else in a
## rival waddle within reach, picked at random, the nearer to breaking the likelier; else on the
## emptiest berg nobody lives on; else at home anyway. Null for a player (anywhere it likes).
func _choose_nest(p: Penguin, family: Family) -> IceBerg:
	var brain := _brain(p)
	if brain == null:
		return null
	var grown := tuning.size_weights[tuning.size_weights.size() - 1]
	var home := WaddleIce.of(get_tree(), brain.berg)
	if home != null and not home.is_broken() and home.share_with(_growth_left(home) + grown) < tuning.nest_safe:
		return home.berg
	var rivals: Array[WaddleIce] = []
	var odds: Array[float] = []
	var empty: WaddleIce = null
	var empty_weight := INF
	for ice in WaddleIce.all(get_tree()):
		if ice.is_broken() or ice == home or p.global_position.distance_to(ice.waddle_spot()) > tuning.errand_range:
			continue
		var colony := PenguinBrain.colony_of(ice.berg)
		if colony.is_empty():
			if ice.weight() < empty_weight:
				empty_weight = ice.weight()
				empty = ice
			continue
		if _is_rival_waddle(ice, family) or colony.any(func(b: Variant) -> bool: return is_instance_valid(b) and _family_of.get((b as PenguinBrain).get_parent(), -1) not in [family.id, -1]):
			rivals.append(ice)
			odds.append(0.05 + ice.progress() * ice.progress())
	if not rivals.is_empty():
		var total := 0.0
		for x in odds:
			total += x
		var roll := randf() * total
		for i in rivals.size():
			roll -= odds[i]
			if roll <= 0.0:
				return rivals[i].berg
		return rivals.back().berg
	if empty != null:
		return empty.berg
	return home.berg if home != null and not home.is_broken() else null


## How much more a waddle's chicks will weigh once they're all grown.
func _growth_left(ice: WaddleIce) -> float:
	var grown := tuning.size_weights[tuning.size_weights.size() - 1]
	var left := 0.0
	for chick in ice.chicks():
		left += grown - chick.weight()
	return left


func _has_room(family: Family) -> bool:
	return adults(family).size() + chicks_of(family, false).size() < tuning.family_cap


## `p` lays an egg in `ice`'s waddle, beside it, and returns it (null if `p` has no family). The
## match does this when a full penguin reaches a waddle; levels and tests can too.
func lay(p: Penguin, ice: WaddleIce) -> Chick:
	var family := family_of(p)
	if family == null or ice == null:
		return null
	_full.erase(p)
	p.vitals.spend(tuning.hatch_cost)
	var chick := CHICK_SCRIPT.new() as Chick
	chick.name = "Chick%d" % get_child_count()
	chick.tuning = tuning
	chick.family = family.id
	chick.tint = family.colour
	chick.berg = ice.berg
	# (This node isn't 3D, so its 3D children are placed in world space.)
	chick.position = _beside(p)
	chick.would_feed = _would_feed.bind(chick)
	add_child(chick)
	chick.fledged.connect(_on_fledged.bind(chick))
	chick.lost.connect(_on_chick_lost.bind(chick))
	var record: Dictionary = _records.get(p, {})
	_parent_of[chick] = record
	var cuckoo := _is_rival_waddle(ice, family)
	if not record.is_empty():
		record["eggs"] += 1
		if cuckoo:
			record["cuckoos"] += 1
	var brain := _brain(p)
	if brain != null and brain.visiting() != null:
		brain.end_visit()
	laid.emit(chick, p, cuckoo)
	if p.is_in_group(&"player"):
		var where := _berg_name(ice.berg)
		announced.emit(("A cuckoo egg on the %s!" if cuckoo else "You laid an egg on the %s") % where, family.colour)
	return chick


## Someone else's family lives in `ice`'s waddle (and not `family`).
func _is_rival_waddle(ice: WaddleIce, family: Family) -> bool:
	var colony := PenguinBrain.colony_of(ice.berg)
	var theirs := false
	for brain in colony:
		if not is_instance_valid(brain):
			continue
		var id: int = _family_of.get((brain as PenguinBrain).get_parent(), -1)
		if id == family.id:
			return false
		if id >= 0:
			theirs = true
	return theirs


## Would `p` feed `chick` now? A player feeds only its own family's chicks; a computer penguin feeds
## any (it can't tell). Either way only with energy to spare.
func _would_feed(p: Penguin, chick: Chick) -> bool:
	var family := family_of(p)
	if family == null:
		return false
	if p.is_in_group(&"player"):
		return family.id == chick.family and (p.infinite_energy or p.energy >= tuning.feed_min_energy + tuning.feed_energy)
	return p.energy >= tuning.npc_feed_min + tuning.feed_energy


## Standing (on its feet) beside a hungry chick it would feed, `p` feeds it every feed_interval. The
## first comes after half the wait.
func _feed(p: Penguin, delta: float) -> void:
	var chick := _hungry_chick_near(p) if p.state == Penguin.State.WALK else null
	if chick == null:
		_feed_clock.erase(p)
		return
	_feed_clock[p] = _feed_clock.get(p, tuning.feed_interval * 0.5) + delta
	if _feed_clock[p] < tuning.feed_interval:
		return
	_feed_clock[p] = 0.0
	p.vitals.spend(tuning.feed_energy)
	_beakful(p, chick)
	chick.feed()
	fed.emit(chick, p)


func _hungry_chick_near(p: Penguin) -> Chick:
	var best: Chick = null
	var best_d := tuning.feed_radius
	for node in get_tree().get_nodes_in_group(&"chicks"):
		var chick := node as Chick
		if chick == null or not chick.wants_food():
			continue
		var d := chick.global_position.distance_to(p.global_position)
		if d <= best_d and _would_feed(p, chick):
			best_d = d
			best = chick
	return best


## A spot on the ice beside `p` for an egg.
func _beside(p: Penguin) -> Vector3:
	var side := p.get_facing().rotated(Vector3.UP, PI * 0.5 if randf() < 0.5 else -PI * 0.5)
	var spot := p.global_position + side * 0.7
	var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP, spot + Vector3.DOWN * 2.0, GameWorld.WORLD_LAYER)
	var hit := p.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else p.global_position


## A little fish goes from `p`'s beak into the chick's.
func _beakful(p: Penguin, chick: Chick) -> void:
	if _meal_mesh == null:
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.03
		capsule.height = 0.15
		capsule.radial_segments = 8
		capsule.rings = 2
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.72, 0.78, 0.84)
		mat.metallic = 0.4
		mat.roughness = 0.3
		capsule.material = mat
		_meal_mesh = capsule
	var meal := MeshInstance3D.new()
	meal.mesh = _meal_mesh
	meal.top_level = true
	add_child(meal)
	var from := p.global_position + p.get_facing() * 0.3 + Vector3.UP * 0.2
	var to := chick.beak_position()
	meal.global_position = from
	var fly := create_tween()
	fly.tween_method(_fly_meal.bind(meal, from, to), 0.0, 1.0, 0.3)
	fly.tween_callback(meal.queue_free)


func _fly_meal(t: float, meal: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	if is_instance_valid(meal):
		meal.global_position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * 0.35
		meal.rotation = Vector3(t * 6.0, 0.0, PI * 0.5)


# --- Growing up, dying ----------------------------------------------------------------------

## A fledgling grows up: a young adult of its family takes its place (living where it grew up).
func _on_fledged(chick: Chick) -> void:
	if not is_instance_valid(chick) or chick.is_lost():
		return
	var family: Family = families[chick.family] if chick.family < families.size() else null
	if family == null:
		return
	var parent: Dictionary = _parent_of.get(chick, {})
	if not parent.is_empty():
		parent["raised"] += 1
	var adult := _grow_up(chick, family)
	if family.player:
		announced.emit("%s grew up" % name_of(adult), family.colour)
	grew_up.emit(adult)


## A computer penguin of `family` where `chick` is, in its place (the chick goes).
func _grow_up(chick: Chick, family: Family) -> Penguin:
	var adult := PENGUIN_SCENE.instantiate() as Penguin
	adult.name = "%sKin%d" % [String(family.home.name) if family.home != null else "Family", _all_records.size()]
	adult.player_controlled = false
	adult.start_energy = tuning.fledge_energy
	adult.position = chick.global_position + Vector3.UP * 0.5
	var brain := PenguinBrain.new()
	brain.name = "Brain"
	var home := WaddleIce.of(get_tree(), chick.berg)
	if home == null or home.is_broken():
		home = WaddleIce.nearest(get_tree(), chick.global_position)
	brain.berg = home.berg if home != null else family.home
	adult.add_child(brain)
	adult.add_to_group(&"npcs")
	_parent_of.erase(chick)
	chick.queue_free()
	var level := get_parent() if get_parent() != null else self
	level.add_child(adult)
	_join(adult, family)
	return adult


func _on_chick_lost(chick: Chick) -> void:
	var family: Family = families[chick.family] if chick.family < families.size() else null
	_parent_of.erase(chick)
	lost_chick.emit(chick)
	if family != null and chick.is_hatched():
		_lost_tally[family.id] = _lost_tally.get(family.id, 0) + 1
	_check_families.call_deferred()


func _on_berg_broke(ice: WaddleIce) -> void:
	_breaks += 1
	var text := "The %s broke up!" % _berg_name(ice.berg)
	var mine := player_family()
	var lost: int = _lost_tally.get(mine.id, 0) if mine != null else 0
	if lost > 0:
		text += " You lost %d %s" % [lost, "chick" if lost == 1 else "chicks"]
	_lost_tally.clear()
	announced.emit(text, Color.WHITE)


## A family penguin was caught: it's eaten. A player carries on as its fattest kin, or its biggest
## chick grown up on the spot; with none, its family is out. Anyone else (a dummy) respawns.
func penguin_caught(penguin: Penguin, by: Node3D) -> void:
	var family := family_of(penguin) if active else null
	if family == null:
		super(penguin, by)
		return
	var record: Dictionary = _records.get(penguin, {})
	if not record.is_empty():
		record["alive"] = false
	_full.erase(penguin)
	_feed_clock.erase(penguin)
	died.emit(penguin, family.id)
	if penguin.is_in_group(&"player"):
		_carry_on(penguin, family, record)
	else:
		if family.player:
			announced.emit("%s was eaten" % record.get("name", "Kin"), family.colour)
		_family_of.erase(penguin)
		_records.erase(penguin)
		penguin.queue_free()
		if adults(family).is_empty():
			_fledge_early(family)
	_check_families.call_deferred()


## The player was eaten: it carries on as its family's fattest grown penguin, or its biggest chick
## grown up on the spot. With neither, its family is out.
func _carry_on(player: Penguin, family: Family, was: Dictionary) -> void:
	var best: Penguin = null
	for p in adults(family):
		if p != player and (best == null or p.fatness() > best.fatness()):
			best = p
	if best != null:
		var record: Dictionary = _records[best]
		record["player"] = true
		player.place(best.global_position, best.facing_yaw(), best.state, best.swim_pitch(), best.swim_speed())
		player.energy = best.energy
		player.air = best.air
		player.set_spawn_point(best.global_position + Vector3.UP * 0.3)
		_records[player] = record
		_family_of.erase(best)
		_records.erase(best)
		best.queue_free()
		announced.emit("You were eaten! You're %s now" % record["name"], family.colour)
		took_over.emit(player, record["name"])
		return
	var chick := _biggest_chick(family)
	if chick != null:
		var record := {"name": _new_name(), "family": family.id, "eggs": 0, "cuckoos": 0, "raised": 0, "alive": true, "player": true}
		_all_records.append(record)
		var parent: Dictionary = _parent_of.get(chick, {})
		if not parent.is_empty():
			parent["raised"] += 1
		player.place(chick.global_position + Vector3.UP * 0.4, randf() * TAU, Penguin.State.AIR)
		player.energy = tuning.fledge_energy
		player.set_spawn_point(chick.global_position + Vector3.UP * 0.4)
		_records[player] = record
		_parent_of.erase(chick)
		chick.queue_free()
		announced.emit("You were eaten! Your chick %s grows up to carry on" % record["name"], family.colour)
		took_over.emit(player, record["name"])
		return
	# Nobody left.
	_records.erase(player)
	_family_of.erase(player)
	player.remove_from_group(&"penguins")
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	announced.emit("You were eaten, and your family's gone", family.colour)


## A computer family's last grown penguin is gone: its biggest chick grows up at once.
func _fledge_early(family: Family) -> void:
	var chick := _biggest_chick(family)
	if chick == null:
		return
	var parent: Dictionary = _parent_of.get(chick, {})
	if not parent.is_empty():
		parent["raised"] += 1
	_grow_up(chick, family)


func _biggest_chick(family: Family) -> Chick:
	var best: Chick = null
	for chick in chicks_of(family):
		if best == null or chick.size() > best.size() or (chick.size() == best.size() and chick.feedings > best.feedings):
			best = chick
	return best


## Families with nobody left are out (their eggs go too); a family whose grown penguins are all gone
## grows up its biggest chick. The last family left wins.
func _check_families() -> void:
	if _ended or not active:
		return
	for family in families:
		if family.out:
			continue
		if adults(family).is_empty() and not chicks_of(family).is_empty():
			_fledge_early(family)
		if lives(family) > 0:
			continue
		family.out = true
		for egg in chicks_of(family, false):
			egg.queue_free()
		announced.emit("%s is gone" % family.name, family.colour)
		family_out.emit(family.id)
	var left := families.filter(func(f: Family) -> bool: return not f.out)
	var mine := player_family()
	if mine != null and mine.out:
		_end(left[0].id if left.size() == 1 else -1)
	elif left.size() <= 1:
		_end(left[0].id if left.size() == 1 else -1)


func _end(winner_id: int) -> void:
	if _ended:
		return
	_ended = true
	_winner = winner_id
	Leaderboard.current().record(ranking())
	ended.emit(winner_id)


# --- Helpers ---------------------------------------------------------------------------------

func _brain(p: Penguin) -> PenguinBrain:
	if p == null:
		return null
	for child in p.get_children():
		if child is PenguinBrain:
			return child as PenguinBrain
	return null


## A berg's name for people ("Floe", "Mesa").
func berg_name(berg: IceBerg) -> String:
	return _berg_name(berg)


## The families living on `berg` (by their colonies), ids.
func families_on(berg: IceBerg) -> Array[int]:
	var ids: Array[int] = []
	for brain in PenguinBrain.colony_of(berg):
		if not is_instance_valid(brain):
			continue
		var id: int = _family_of.get((brain as PenguinBrain).get_parent(), -1)
		if id >= 0 and not ids.has(id):
			ids.append(id)
	return ids


func _berg_name(berg: IceBerg) -> String:
	if berg == null or not is_instance_valid(berg):
		return "ice"
	return BERG_NAMES.get(String(berg.name), String(berg.name))


func _sync_active() -> void:
	if not is_inside_tree():
		return
	if active:
		add_to_group(&"game_mode")
	elif is_in_group(&"game_mode"):
		remove_from_group(&"game_mode")
	for ice in WaddleIce.all(get_tree()):
		ice.active = active
