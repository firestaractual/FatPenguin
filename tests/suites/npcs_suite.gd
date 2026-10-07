extends "res://tests/smoke_suite.gd"
## NPC colonies: huddling and turning over, fishing parties, getting home.


func suite_name() -> String:
	return "npcs"


func run() -> void:
	await _test_huddle()
	await _test_npc_fishing()


func _test_huddle() -> void:
	# A colony of 8 on the home floe, not hungry: they huddle round its waddle spot, and the
	# huddle keeps turning over.
	var home := _level.get_node("BergField/HomeFloe") as IceBerg
	var spot := home.waddle_spot()
	var colony: Array[Penguin] = []
	for i in 8:
		var a := TAU * i / 8.0
		colony.append(_spawn_npc(home, spot + Vector3(cos(a), 0.5, sin(a)) * 3.0, 60.0, true))
	await _frames(25 * 60)
	var tuning: NpcTuning = (colony[0].get_node("Brain") as PenguinBrain).tuning
	var wind := Vector3(tuning.wind.x, 0.0, tuning.wind.z).normalized()
	var core := {}
	var edge := {}
	var samples := 0
	var spread := 0.0
	var off_spot := 0.0
	var drain := 0.0
	for i in 90 * 60:
		await tree.physics_frame
		if i % 30 != 0:
			continue
		samples += 1
		var middle := Vector3.ZERO
		for p in colony:
			middle += p.global_position
		middle /= colony.size()
		off_spot = maxf(off_spot, Vector2(middle.x - spot.x, middle.z - spot.z).length())
		for p in colony:
			spread += Vector2(p.global_position.x - middle.x, p.global_position.z - middle.z).length()
			drain += p.drain_mult
			var near := 0
			var sheltered := false
			for other in colony:
				var rel := other.global_position - p.global_position
				rel.y = 0.0
				if other == p:
					continue
				if rel.length() < tuning.neighbour_range:
					near += 1
				if rel.length() < tuning.neighbour_range * 1.3 and rel.dot(-wind) > 0.3 * rel.length():
					sheltered = true
			if near >= 3:
				core[p] = core.get(p, 0) + 1
			if not sheltered:
				edge[p] = edge.get(p, 0) + 1
	var mean_spread := spread / (samples * colony.size())
	var took_turns := 0
	var got_warm := 0
	for p in colony:
		if edge.get(p, 0) >= samples * 0.1:
			took_turns += 1
		if core.get(p, 0) >= samples * 0.05:
			got_warm += 1
	_check(mean_spread < 2.0 and off_spot < 3.0, "NPC penguins huddle in the middle of their berg (%.1f m from the huddle's middle on average, which stays within %.1f m of the spot)" % [mean_spread, off_spot])
	_check(took_turns >= 6 and got_warm >= 6, "the huddle turns over: %d of 8 took turns on the windward edge, %d of 8 got in among the others" % [took_turns, got_warm])
	_check(drain / (samples * colony.size()) < 0.6, "huddled, they burn energy slower (×%.2f on average)" % (drain / (samples * colony.size())))
	for p in colony:
		p.queue_free()
	await _frames(2)


func _test_npc_fishing() -> void:
	# Four hungry NPCs on the home floe: they gather at the edge, go in together, eat and come
	# home. And one knocked into the water swims back.
	for fish: Fish in _level.get_node("Fish").get_children():
		fish.monitoring = true
	var home := _level.get_node("BergField/HomeFloe") as IceBerg
	var spot := home.waddle_spot()
	var party: Array[Penguin] = []
	var went_in := {}
	var best := {}
	for i in 4:
		var p := _spawn_npc(home, spot + Vector3(i * 0.9 - 1.3, 0.5, 0.0), 25.0, false)
		party.append(p)
		p.state_changed.connect(func(s: Penguin.State) -> void:
			if s == Penguin.State.SWIM and not went_in.has(p):
				went_in[p] = Engine.get_physics_frames())
	var home_again := 0
	for i in 150 * 60:
		await tree.physics_frame
		for p in party:
			best[p] = maxf(best.get(p, 0.0), p.energy)
		if i % 60 == 0:
			home_again = 0
			for p in party:
				var brain := p.get_node("Brain") as PenguinBrain
				if went_in.has(p) and brain.mode == PenguinBrain.Mode.HUDDLE:
					home_again += 1
			if home_again >= 3:
				break
	var entries: Array = went_in.values()
	entries.sort()
	var together := entries.size() >= 3 and float(entries[2] - entries[0]) / 60.0 < 4.0
	var fed := 0
	for p in party:
		if best.get(p, 0.0) > 50.0:
			fed += 1
	_check(together, "hungry NPCs gather at the edge and go in together (%d went in%s)" % [entries.size(), "" if entries.size() < 3 else ", the first three within %.1f s" % (float(entries[2] - entries[0]) / 60.0)])
	_check(fed >= 3, "they catch fish out there (%d of 4 got past 50 energy)" % fed)
	_check(home_again >= 3, "and come home to the huddle (%d of 4 back)" % home_again)
	for p in party:
		p.queue_free()

	# Knocked in off the east side: it swims back, gets out and walks back to the huddle.
	var swimmer := _spawn_npc(home, Vector3(38.0, -0.2, 8.0), 60.0, true)
	swimmer.force_state(Penguin.State.SWIM)
	var brain := swimmer.get_node("Brain") as PenguinBrain
	var out := false
	for i in 60 * 60:
		await tree.physics_frame
		if brain.mode == PenguinBrain.Mode.HUDDLE and swimmer.state == Penguin.State.WALK:
			out = true
			break
	_check(out, "an NPC knocked into the water swims back, climbs out and rejoins the huddle")
	swimmer.queue_free()
	for fish: Fish in _level.get_node("Fish").get_children():
		fish.monitoring = false
	await _frames(2)


# --- Helpers ----------------------------------------------------------------

## Leaves `pod` with just its attack called `attack_name`, and returns that attack.
