extends SceneTree
## Headless smoke test for the Prototype 0 movement toy.
## Loads the movement toy and runs the suites in tests/suites/, each driving the penguin and the
## predators and checking the results: movement (every verb, the plateau's chutes and steps),
## bumping, fish schools, leopard seals (hunting and the edge ambush), the orca pod's attacks and
## traps, the berg field (ways up, gap hops, tunnels, the lagoon, the spire), the NPC colonies,
## players (each reads only its own controls; the level decides what a catch does), and the UI
## (HUD, pause menu, settings, the title screen).
## Shared helpers are in tests/smoke_suite.gd.
##
## Run from the project folder:
##   godot --headless --fixed-fps 60 --path . --script res://tests/movement_smoke_test.gd
## Options (after a lone --):
##   --only=orcas,npcs   run only these suites (movement, bumping, fish, seals, orcas, bergs, npcs,
##                       players, ui)
##   --seed=12345        replay a run: predators, NPCs and fish make random choices, and every run
##                       prints the seed it used
## Exit code 0 = all checks passed.

const SmokeSuite := preload("res://tests/smoke_suite.gd")
const SUITES: Array[Script] = [
	preload("res://tests/suites/movement_suite.gd"),
	preload("res://tests/suites/bumping_suite.gd"),
	preload("res://tests/suites/fish_suite.gd"),
	preload("res://tests/suites/seals_suite.gd"),
	preload("res://tests/suites/orcas_suite.gd"),
	preload("res://tests/suites/bergs_suite.gd"),
	preload("res://tests/suites/npcs_suite.gd"),
	preload("res://tests/suites/players_suite.gd"),
	preload("res://tests/suites/ui_suite.gd"),
]

var _failures: Array[String] = []
var _states_seen: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var only: Array[String] = []
	var seed_value := randi()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			for part in arg.trim_prefix("--only=").split(",", false):
				only.append(part.strip_edges())
		elif arg.begins_with("--seed="):
			seed_value = arg.trim_prefix("--seed=").to_int()
	seed(seed_value)
	print("Seed %d (replay with: -- --seed=%d)" % [seed_value, seed_value])
	# Default settings, never read from or saved to the player's settings file.
	GameSettings.use_defaults()

	var level := load(SmokeSuite.LEVEL).instantiate() as MovementToy
	root.add_child(level)
	var penguin := level.get_node("Penguin") as Penguin
	penguin.state_changed.connect(func(s: Penguin.State) -> void: _states_seen.append(Penguin.State.keys()[s]))
	# The level's fish swim about in schools, so one could cross the penguin's path and skew an
	# energy or speed check. They stay in the level but can't be eaten during this test.
	for fish: Fish in level.get_node("Fish").get_children():
		fish.monitoring = false
	# The level's predators would hunt the test penguin. The predator checks bring their own.
	var kinds := {}
	for node in get_nodes_in_group(&"predators"):
		var kind := (node as Predator).tuning.display_name
		kinds[kind] = kinds.get(kind, 0) + 1
	_check(kinds.get("Leopard seal", 0) > 0 and kinds.get("Orca", 0) > 0 and get_nodes_in_group(&"pods").size() > 0,
		"the level spawns its predators from its spawn list (%s)" % str(kinds))
	for spawned in level.get_node("Predators").get_children():
		spawned.queue_free()
	# The colonies' NPC penguins would get in the way too. The NPC checks bring their own.
	var npcs := get_nodes_in_group(&"npcs").size()
	_check(npcs > 0, "the level spawns its colonies of NPC penguins (%d)" % npcs)
	for npc in get_nodes_in_group(&"npcs"):
		npc.queue_free()

	var known: Array[String] = []
	for script in SUITES:
		var suite: SmokeSuite = script.new()
		known.append(suite.suite_name())
		if not only.is_empty() and not only.has(suite.suite_name()):
			continue
		print("\n[%s]" % suite.suite_name())
		suite.setup(self, level, _failures)
		await suite.run()
	for suite_name in only:
		if not known.has(suite_name):
			_check(false, "--only=%s: there's no suite by that name (there are %s)" % [suite_name, ", ".join(known)])

	print("\nStates seen: ", " > ".join(_states_seen))
	print("Seed %d" % seed_value)
	if _failures.is_empty():
		print("SMOKE TEST PASSED")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("SMOKE TEST FAILED (%d)" % _failures.size())
		quit(1)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failures.append(what)
