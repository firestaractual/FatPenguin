extends SceneTree
## Tuning trials for the match between the families (WaddleMatch): plays whole matches headless,
## with the player's penguin driven by a brain like its kin, and prints how they go: lives over time,
## eggs, cuckoo eggs, chicks raised, bergs broken, who was eaten, and who won (or who was ahead when
## time ran out). Not pass/fail. See docs/TUNING.md (Families and waddles) for the results the
## numbers come from.
##
##   godot --headless --fixed-fps 60 --path . --script res://tests/trials/match_trials.gd -- --runs=3 --minutes=10 --seed=1
##
## Options: --runs=N matches (each a fresh level, seeds seed, seed+1, ...), --minutes=M each at most,
## --seed=S the first seed, --idle (the player's penguin does nothing instead of living like its kin),
## --verbose (every minute, what each family's penguins are doing and where they live).

const LEVEL := "res://levels/movement_toy/movement_toy.tscn"

## --verbose: every minute, where each family's penguins are and what they're doing.
var verbose := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var runs := 3
	var minutes := 10.0
	var first := 1
	var idle := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--verbose":
			verbose = true
		if arg.begins_with("--runs="):
			runs = arg.trim_prefix("--runs=").to_int()
		elif arg.begins_with("--minutes="):
			minutes = arg.trim_prefix("--minutes=").to_float()
		elif arg.begins_with("--seed="):
			first = arg.trim_prefix("--seed=").to_int()
		elif arg == "--idle":
			idle = true
	GameSettings.use_defaults()
	Leaderboard.use_memory()
	var totals := {"breaks": 0, "eggs": 0, "cuckoos": 0, "raised": 0, "eaten": 0, "lost": 0, "ended": 0, "length": 0.0}
	var eaten_by_family := {}
	for run in runs:
		var result := await _play(first + run, minutes, idle)
		for key in ["breaks", "eggs", "cuckoos", "raised", "eaten", "lost"]:
			totals[key] += result[key]
		totals["length"] += result["length"]
		if result["over"]:
			totals["ended"] += 1
		for family: String in result["eaten_by"]:
			eaten_by_family[family] = eaten_by_family.get(family, 0) + result["eaten_by"][family]
	print("\n== %d matches of up to %.0f min: %d ended (average %.1f min); per match: %.1f bergs broke, %.1f eggs (%.1f cuckoo), %.1f raised, %.1f eaten, %.1f chicks lost" % [
		runs, minutes, totals["ended"], totals["length"] / runs / 60.0, float(totals["breaks"]) / runs, float(totals["eggs"]) / runs,
		float(totals["cuckoos"]) / runs, float(totals["raised"]) / runs, float(totals["eaten"]) / runs, float(totals["lost"]) / runs])
	print("   eaten by family (all matches): ", eaten_by_family)
	quit(0)


func _play(match_seed: int, minutes: float, idle: bool) -> Dictionary:
	seed(match_seed)
	var level := (load(LEVEL) as PackedScene).instantiate() as MovementToy
	root.add_child(level)
	await physics_frame
	var game := level.waddle_match()
	var player := level.get_node("Penguin") as Penguin
	if not idle:
		var brain := PenguinBrain.new()
		brain.name = "Brain"
		brain.berg = game.player_family().home
		player.add_child(brain)
	var result := {"breaks": 0, "eggs": 0, "cuckoos": 0, "raised": 0, "eaten": 0, "lost": 0, "over": false, "length": 0.0, "eaten_by": {}}
	game.died.connect(func(_p: Penguin, family: int) -> void:
		result["eaten"] += 1
		var name := game.families[family].name
		result["eaten_by"][name] = result["eaten_by"].get(name, 0) + 1)
	game.laid.connect(func(_c: Chick, _p: Penguin, cuckoo: bool) -> void:
		result["eggs"] += 1
		if cuckoo:
			result["cuckoos"] += 1)
	game.grew_up.connect(func(_a: Penguin) -> void: result["raised"] += 1)
	game.lost_chick.connect(func(_c: Chick) -> void: result["lost"] += 1)
	game.announced.connect(func(text: String, _c: Color) -> void:
		if text.contains("broke up"):
			result["breaks"] += 1)
	print("\n[seed %d]" % match_seed)
	var frames := roundi(minutes * 60.0 * 60.0)
	for i in frames:
		await physics_frame
		if i % (60 * 60) == 0:
			var line := "  %2d min " % (i / 3600)
			for family in game.families:
				line += " %s %d(%d)" % [family.name.get_slice(" ", 1) if family.name.begins_with("The") else "You", game.lives(family), game.adults(family).size()]
			print(line)
			if verbose:
				print("         ", _whereabouts(game))
		if game.is_over():
			result["over"] = true
			break
	result["length"] = game.elapsed()
	var line := "  end %.1f min: " % (game.elapsed() / 60.0)
	for family in game.families:
		line += " %s %d" % [family.name, game.lives(family)]
	line += "  winner: %s" % (game.families[game.winner()].name if game.winner() >= 0 else "-")
	print(line)
	var top := game.ranking()
	if not top.is_empty():
		print("  most prolific: %s (%s) %d eggs, %d cuckoo, %d raised" % [top[0]["name"], top[0]["family"], top[0]["eggs"], top[0]["cuckoos"], top[0]["raised"]])
	level.queue_free()
	await physics_frame
	await physics_frame
	return result


## Each family's grown penguins: how many in each brain mode, and which bergs they live on.
func _whereabouts(game: WaddleMatch) -> String:
	var parts: Array[String] = []
	for family in game.families:
		var modes := {}
		var homes := {}
		for p in game.adults(family):
			var brain := p.get_node_or_null("Brain") as PenguinBrain
			if brain == null:
				continue
			var mode: String = PenguinBrain.Mode.keys()[brain.mode]
			modes[mode] = modes.get(mode, 0) + 1
			var home := String(brain.berg.name) if brain.berg != null else "-"
			homes[home] = homes.get(home, 0) + 1
		parts.append("%s %s %s" % [family.name.get_slice(" ", 1), str(modes), str(homes)])
	return " | ".join(parts)
