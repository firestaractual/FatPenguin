class_name GameMode
extends Node
## The rules of the level being played. So far: what happens to a penguin that's caught. As the
## game grows this is where a round starts and ends, who wins, and how the energy loop and the
## waddle's drain are set up for the level. A kind of game (free-for-all, a campaign level, coop)
## extends it and overrides what it changes.
##
## Put one in a level; it joins the "game_mode" group. A level without one plays by the movement
## toy's rule: a caught penguin is eaten and comes back at its spawn point (Penguin.reset()).


func _enter_tree() -> void:
	add_to_group(&"game_mode")


## The rules in play in `tree`, or null (then the movement toy's rule applies).
static func current(tree: SceneTree) -> GameMode:
	return tree.get_first_node_in_group(&"game_mode") as GameMode if tree != null else null


## `penguin` was just caught by `by` (a Predator). It has already played its effects and emitted
## Penguin.caught. The movement toy's rule: it's eaten and comes back at its spawn point with its
## starting energy. (Free-for-all: it's out. Campaign: it loses most of its energy, GDD §8.)
func penguin_caught(penguin: Penguin, _by: Node3D) -> void:
	penguin.reset()
