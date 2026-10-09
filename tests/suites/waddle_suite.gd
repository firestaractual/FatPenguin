extends "res://tests/smoke_suite.gd"
## The waddles and the match between the families (WaddleIce, WaddleMatch): families and lives,
## each waddle's weight, laying eggs in any waddle (cuckoos), who feeds which chicks, chicks growing
## up, bergs breaking up (and losing their chicks, the colony moving, a player on it thrown off), a
## player carrying on as its kin, the end of a match, and the leaderboards. It breaks bergs, so it
## runs last.

var _game: WaddleMatch
var _home: IceBerg
var _mesa: IceBerg
var _wedge: IceBerg
var _spawned: Array[Node] = []


func suite_name() -> String:
	return "waddle"


func run() -> void:
	_game = _level.waddle_match()
	_check(_game != null and WaddleIce.all(tree).size() >= 5, "the level has its match and a waddle on every berg (%d)" % WaddleIce.all(tree).size())
	if _game == null:
		return
	Leaderboard.use_memory()
	_home = _level.get_node("BergField/HomeFloe") as IceBerg
	_mesa = _level.get_node("BergField/Mesa") as IceBerg
	_wedge = _level.get_node("BergField/Wedge") as IceBerg
	_penguin.infinite_energy = false
	await _place_on_ice(_penguin, _home.waddle_spot() + Vector3(-2.0, 0.0, 3.0), 0.0, 60.0)
	# Three families: the player and two kin on the home floe, three on the mesa, one on the wedge.
	for i in 2:
		_colony_member(_home, i)
	for i in 3:
		_colony_member(_mesa, i)
	_colony_member(_wedge, 0)
	await _frames(90)
	_game.active = true
	_game.begin()
	await _test_families()
	await _test_eggs_anywhere()
	await _test_feeding()
	await _test_growing_up()
	await _test_rival_berg_breaks()
	await _test_winning()
	await _test_carrying_on()
	await _test_your_berg_breaks()
	for node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	await _frames(2)


## A computer penguin living on `berg`, not hungry (it huddles), in the colony.
func _colony_member(berg: IceBerg, i: int) -> Penguin:
	var a := TAU * i / 3.0
	var p := _spawn_npc(berg, berg.waddle_spot() + Vector3(cos(a) * 1.5, 0.5, sin(a) * 1.5), 60.0, true)
	p.add_to_group(&"npcs")
	_spawned.append(p)
	return p


## Waits until physics frame `frame`.
func _until_frame(frame: int) -> void:
	while Engine.get_physics_frames() < frame:
		await tree.physics_frame


## A stuffed stand-in standing at `at` (a dummy in the "npcs" group: it counts toward a waddle).
func _heavy(at: Vector3) -> Penguin:
	var p := await _spawn_standing(at, 100.0)
	p.add_to_group(&"npcs")
	_spawned.append(p)
	return p


func _family(name_part: String) -> WaddleMatch.Family:
	for family in _game.families:
		if family.name.contains(name_part):
			return family
	return null


func _test_families() -> void:
	var mine := _game.player_family()
	var mesa := _family("Mesa")
	var wedge := _family("Wedge")
	_check(_game.families.size() == 3 and mine != null and mine == _game.families[0] and mine.name == "Your family" and mesa != null and wedge != null,
		"each colony is a family, yours first (%s)" % str(_game.families.map(func(f: WaddleMatch.Family) -> String: return f.name)))
	_check(_game.lives(mine) == 3 and _game.lives(mesa) == 3 and _game.lives(wedge) == 1,
		"a family's lives are its kin alive: you 3, mesa 3, wedge 1 (%d, %d, %d)" % [_game.lives(mine), _game.lives(mesa), _game.lives(wedge)])
	var npc := _game.adults(mesa)[0]
	_check(npc.body_tint.a > 0.0 and npc.body_tint.b > npc.body_tint.g and not _game.name_of(npc).is_empty() and not _game.name_of(_penguin).is_empty(),
		"everyone has a silly name (%s, you're %s), and kin wear their family's colour" % [_game.name_of(npc), _game.name_of(_penguin)])
	var ice := WaddleIce.of(tree, _home)
	var expected := 0.0
	for p in _game.adults(mine):
		if ice.in_waddle(p):
			expected += p.fatness()
	_check(absf(ice.weight() - expected) < 0.01 and expected > 1.0, "a waddle weighs what its penguins weigh (%.2f)" % ice.weight())


func _test_eggs_anywhere() -> void:
	var t := _game.tuning
	var mine := _game.player_family()
	var mesa_ice := WaddleIce.of(tree, _mesa)
	var water := _mesa.waddle_spot() + Vector3(-35.0, -3.3, 0.0)
	_penguin.energy = t.hatch_energy - 20.0
	_place_swimming(water, 0.0, 0.0)
	await _frames(10)
	_check(not _game.is_full(_penguin), "not full: no egg on its way")
	_penguin.energy = t.hatch_energy + 8.0
	_place_swimming(water, 0.0, 0.0)
	await _frames(10)
	_check(_game.is_full(_penguin), "full out in the water: an egg on its way")
	var laid := []
	var cb := func(chick: Chick, parent: Penguin, cuckoo: bool) -> void: laid.append([chick, parent, cuckoo])
	_game.laid.connect(cb)
	var before := mesa_ice.weight()
	_penguin.place(_mesa.waddle_spot() + Vector3(-1.5, 0.8, 1.5), 0.0, Penguin.State.AIR)
	for i in 120:
		await tree.physics_frame
		if not laid.is_empty():
			break
	_game.laid.disconnect(cb)
	var chick: Chick = laid[0][0] if not laid.is_empty() else null
	_check(chick != null and laid[0][1] == _penguin and laid[0][2] and chick.family == mine.id and chick.berg == _mesa,
		"you can lay in any waddle: in a rival's it's a cuckoo egg, still your family's")
	if chick == null:
		return
	var lives := _game.lives(mine)
	await _frames(roundi((t.hatch_seconds + 0.3) * 60.0))
	_check(chick.is_hatched() and _game.lives(mine) == lives + 1 and mesa_ice.weight() > before + t.size_weights[0] - 0.2,
		"it hatches (one more life for you) and weighs down their ice (%.1f → %.1f)" % [before, mesa_ice.weight()])
	var top := _game.ranking()[0]
	_check(top["eggs"] == 1 and top["cuckoos"] == 1 and top["player"], "the match's leaderboard counts it (%s: %d egg, %d cuckoo)" % [top["name"], top["eggs"], top["cuckoos"]])
	var hud := _level.get_node_or_null("GameHud") as GameHud
	_check(hud != null and hud.waddle_meter().is_showing() and hud.waddle_meter().feed_lines().any(func(l: String) -> bool: return l.contains("cuckoo")),
		"the HUD shows the families and says so (%s)" % str(hud.waddle_meter().feed_lines() if hud else []))


func _test_feeding() -> void:
	var t := _game.tuning
	var mine := _game.player_family()
	var mesa := _family("Mesa")
	var cuckoo: Chick = null
	for chick in _game.chicks_of(mine):
		if chick.berg == _mesa:
			cuckoo = chick
	# Their computer penguins can't tell: they raise your cuckoo.
	var fed_by := {}
	var cb := func(chick: Chick, by: Penguin) -> void: fed_by[chick] = fed_by.get(chick, []) + [by]
	_game.fed.connect(cb)
	_penguin.place(_mesa.waddle_spot() + Vector3(-25.0, -0.3, 0.0), 0.0, Penguin.State.SWIM)
	for i in 12 * 60:
		await tree.physics_frame
		_penguin.set_swim_speed(0.0)
		if fed_by.has(cuckoo):
			break
	var raised_by_rival: bool = fed_by.has(cuckoo) and (fed_by[cuckoo] as Array).all(func(p: Penguin) -> bool: return _game.family_of(p) == mesa)
	_check(raised_by_rival, "the rival's penguins feed your cuckoo chick: they can't tell")
	# Players feed only their own: one of the mesa's chicks begs, but you won't feed it.
	var theirs := _game.lay(_game.adults(mesa)[0], WaddleIce.of(tree, _mesa))
	theirs.hatch_now()
	await _place_on_ice(_penguin, theirs.global_position + Vector3(0.8, 0.0, 0.0), 0.0, 90.0)
	await _frames(roundi(t.feed_interval * 3.0 * 60.0))
	var by_you: Array = (fed_by.get(theirs, []) as Array).filter(func(p: Penguin) -> bool: return p == _penguin)
	_check(by_you.is_empty(), "you only feed your own family's chicks (not theirs: %d times)" % by_you.size())
	# Your own chick at home: you feed it.
	await _place_on_ice(_penguin, _home.waddle_spot() + Vector3(-2.0, 0.0, 3.0), 0.0, 90.0)
	var own := _game.lay(_penguin, WaddleIce.of(tree, _home))
	own.hatch_now()
	for i in roundi(t.feed_interval * 2.5 * 60.0):
		await tree.physics_frame
		if (fed_by.get(own, []) as Array).has(_penguin):
			break
	_check((fed_by.get(own, []) as Array).has(_penguin), "you feed your own chicks")
	_game.fed.disconnect(cb)


func _test_growing_up() -> void:
	var t := _game.tuning
	var mine := _game.player_family()
	var own: Chick = null
	for chick in _game.chicks_of(mine):
		if chick.berg == _home:
			own = chick
	if own == null:
		_check(false, "there's a chick to grow up")
		return
	_penguin.place(Vector3(10.0, -0.3, -62.0), 0.0, Penguin.State.SWIM)
	var lives := _game.lives(mine)
	var adults := _game.adults(mine).size()
	var grown := []
	var cb := func(adult: Penguin) -> void:
		if _game.family_of(adult) == mine and adult.global_position.distance_to(own.global_position) < 2.0:
			grown.append(adult)
	_game.grew_up.connect(cb)
	while own.wants_food():
		own.feed()
	for i in roundi((t.fledge_seconds + 1.0) * 60.0):
		await tree.physics_frame
		_penguin.set_swim_speed(0.0)
		if not grown.is_empty():
			break
	_game.grew_up.disconnect(cb)
	var adult: Penguin = grown[0] if not grown.is_empty() else null
	_check(adult != null and _game.family_of(adult) == mine and _game.adults(mine).size() >= adults + 1 and _game.lives(mine) == lives,
		"full grown for %.0f s, a chick grows up into a young adult of its family (same lives: %d)" % [t.fledge_seconds, _game.lives(mine)])
	if adult == null:
		return
	_spawned.append(adult)
	var brain := adult.get_node_or_null("Brain") as PenguinBrain
	var you: Dictionary = _game.ranking().filter(func(r: Dictionary) -> bool: return r["player"])[0]
	_check(brain != null and brain.berg == _home and adult.is_in_group(&"npcs") and you["raised"] >= 1,
		"it lives where it grew up, like any of its kin, and you raised it (%d raised)" % you["raised"])


func _test_rival_berg_breaks() -> void:
	var t := _game.tuning
	var mine := _game.player_family()
	var mesa := _family("Mesa")
	var ice := WaddleIce.of(tree, _mesa)
	var seal := _spawn_seal(_mesa.waddle_spot() + Vector3(-60.0, -4.0, 0.0))
	_spawned.append(seal)
	# A fresh cuckoo of yours on the mesa (laid by hand), then away from it.
	await _place_on_ice(_penguin, _mesa.waddle_spot() + Vector3(-1.5, 0.0, 1.5), 0.0, 90.0)
	_game.lay(_penguin, ice).hatch_now()
	_penguin.place(Vector3(10.0, -0.3, -62.0), 0.0, Penguin.State.SWIM)
	var events := {"breaking": false, "broke": false, "at": 0, "lives": 0, "yours": 0}
	ice.breaking.connect(func() -> void:
		events["breaking"] = true
		events["at"] = Engine.get_physics_frames()
		events["lives"] = _game.lives(mine)
		events["yours"] = ice.chicks().filter(func(c: Chick) -> bool: return c.family == mine.id and c.is_hatched()).size())
	ice.broke_through.connect(func() -> void: events["broke"] = true)
	var lost_yours := [0]
	_game.lost_chick.connect(func(c: Chick) -> void:
		if c.family == mine.id and c.is_hatched():
			lost_yours[0] += 1)
	var colony := PenguinBrain.colony_of(_mesa).duplicate()
	var k := 0
	while not events["breaking"] and k < 10:
		var a := 0.5 + k * 1.1
		await _heavy(_mesa.waddle_spot() + Vector3(cos(a), 0.0, sin(a)) * (2.0 + 0.3 * k))
		k += 1
		await _frames(15)
		_penguin.set_swim_speed(0.0)
	_check(events["breaking"], "too heavy, a rival's berg gives way (the mesa holds %.1f)" % ice.holds())
	_check(_penguin.input is PlayerInput, "you're not on it: you carry on")
	await _until_frame(events["at"] + roundi((t.beat_seconds + 0.4) * 60.0))
	_check(events["broke"] and ice.pieces().size() >= 4 and not _mesa.is_in_group(&"bergs") and ice.chicks().is_empty(),
		"it bursts into %d pieces, and every egg and chick on it is lost" % ice.pieces().size())
	_check(lost_yours[0] >= 1 and _game.lives(mine) < events["lives"], "your cuckoos with them (%d): you're down (%d → %d)" % [lost_yours[0], events["lives"], _game.lives(mine)])
	var moved := colony.all(func(b: Variant) -> bool: return not is_instance_valid(b) or ((b as PenguinBrain).berg != _mesa and (b as PenguinBrain).berg.holds_waddle()))
	_check(moved and not colony.is_empty(), "its colony is homeless: they move to the nearest berg still standing")
	var hud := _level.get_node_or_null("GameHud") as GameHud
	_check(hud != null and hud.waddle_meter().feed_lines().any(func(l: String) -> bool: return l.contains("Mesa broke up")),
		"the feed says so (%s)" % str(hud.waddle_meter().feed_lines() if hud else []))
	await _frames(240)
	_check(seal.is_frenzied(), "and the predators come")
	seal.queue_free()


func _test_winning() -> void:
	var mine := _game.player_family()
	var by := Node3D.new()
	_level.add_child(by)
	_spawned.append(by)
	var outs := []
	_game.family_out.connect(func(id: int) -> void: outs.append(id))
	var ended := [-2]
	_game.ended.connect(func(winner: int) -> void: ended[0] = winner, CONNECT_ONE_SHOT)
	for family in _game.families:
		if family == mine:
			continue
		for chick in _game.chicks_of(family, false):
			chick.lose()
		for p in _game.adults(family):
			p.get_caught(by)
		await _frames(3)
	_check(outs.size() == 2, "a family with nobody left is out (%d out)" % outs.size())
	_check(ended[0] == mine.id and _game.is_over(), "the last family alive wins: yours")
	var end := _level.get_node_or_null("MatchEnd") as MatchEnd
	for i in 150:
		await tree.process_frame
		if end != null and end.is_open():
			break
	_check(end != null and end.is_open() and tree.paused and end.headline().begins_with("Your family wins!"),
		"a moment later the game stops: %s" % (end.headline().replace("\n", " / ") if end else "no end screen"))
	var board := Leaderboard.current().entries
	_check(not board.is_empty() and board[0]["player"] and board[0]["eggs"] >= 2, "the match's penguins go on the all-time leaderboard (%d)" % board.size())
	if end != null:
		end.dismiss()
	await _frames(2)
	var menu := PauseMenu.of(_level)
	menu.open()
	menu.open_leaderboard()
	await tree.process_frame
	var table := menu.get_node("Root/Board").find_children("*", "LeaderboardTable", true, false)
	_check(menu.leaderboard_showing() and not table.is_empty() and (table[0] as LeaderboardTable).row_count() > 0,
		"the pause menu shows the most prolific penguins (%d)" % ((table[0] as LeaderboardTable).row_count() if not table.is_empty() else 0))
	menu.close()
	await _frames(2)


func _test_carrying_on() -> void:
	# A new match, with a rival family on the wedge.
	for i in 3:
		_colony_member(_wedge, i + 1)
	_colony_member(_home, 5)
	await _frames(60)
	_game.begin()
	var mine := _game.player_family()
	var by := Node3D.new()
	_level.add_child(by)
	_spawned.append(by)
	var kin := _game.adults(mine).filter(func(p: Penguin) -> bool: return p != _penguin)
	var fattest: Penguin = null
	for p: Penguin in kin:
		if fattest == null or p.fatness() > fattest.fatness():
			fattest = p
	var lives := _game.lives(mine)
	var name := _game.name_of(fattest)
	var spot := fattest.global_position
	var took := [""]
	_game.took_over.connect(func(_p: Penguin, new_name: String) -> void: took[0] = new_name)
	_penguin.get_caught(by)
	await _frames(2)
	_check(took[0] == name and _game.name_of(_penguin) == name and _penguin.global_position.distance_to(spot) < 1.0 and not is_instance_valid(fattest),
		"eaten, you carry on as your fattest kin (%s), in its place" % name)
	_check(_game.lives(mine) == lives - 1, "and your family is a life down (%d → %d)" % [lives, _game.lives(mine)])
	var hud := _level.get_node_or_null("GameHud") as GameHud
	_check(hud != null and hud.waddle_meter().banner_text().contains(name), "a banner says who you are now")
	# Only a chick left: it grows up on the spot, and you're it.
	for p in _game.adults(mine):
		if p != _penguin:
			p.get_caught(by)
	await _frames(2)
	var chick := _game.lay(_penguin, WaddleIce.nearest(tree, _penguin.global_position))
	chick.hatch_now()
	_penguin.get_caught(by)
	await _frames(2)
	_check(not is_instance_valid(chick) or chick.is_queued_for_deletion(), "with only a chick left, it grows up on the spot to carry on")
	_check(_game.lives(mine) == 1 and not _game.is_over(), "still in it (1 life)")
	var ended := [-2]
	_game.ended.connect(func(winner: int) -> void: ended[0] = winner, CONNECT_ONE_SHOT)
	_penguin.get_caught(by)
	await _frames(3)
	_check(mine.out and ended[0] == _family("Wedge").id, "with nobody left, your family is out, and the match is over")
	var end := _level.get_node_or_null("MatchEnd") as MatchEnd
	for i in 150:
		await tree.process_frame
		if end != null and end.is_open():
			break
	_check(end != null and end.is_open() and end.headline().begins_with("Your family is gone"), "the end screen says so")
	if end != null:
		end.dismiss()
	# Back in play for the last check.
	_penguin.add_to_group(&"penguins")
	_penguin.visible = true
	_penguin.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(2)


func _test_your_berg_breaks() -> void:
	var t := _game.tuning
	_game.begin()
	var ice := WaddleIce.of(tree, _home)
	await _place_on_ice(_penguin, _home.waddle_spot() + Vector3(-2.0, 0.0, 2.5), 0.0, 90.0)
	_penguin.infinite_energy = true
	var events := {"breaking": false, "over": false, "at": 0}
	ice.breaking.connect(func() -> void:
		events["breaking"] = true
		events["at"] = Engine.get_physics_frames())
	ice.scene_over.connect(func() -> void: events["over"] = true)
	var k := 0
	while not events["breaking"] and k < 16:
		var a := 0.3 + k * 0.8
		await _heavy(_home.waddle_spot() + Vector3(cos(a), 0.0, sin(a)) * (2.0 + 0.25 * k))
		k += 1
		await _frames(15)
	_check(events["breaking"] and not (_penguin.input is PlayerInput), "when your own berg gives way, you freeze for the scene")
	await _until_frame(events["at"] + roundi((t.beat_seconds + 0.4) * 60.0))
	var hud := _level.get_node_or_null("GameHud") as GameHud
	_check(_penguin.state == Penguin.State.AIR and _penguin.is_flailing() and hud != null and hud.waddle_meter().banner_showing(),
		"thrown up off it, flailing, with a banner (%s)" % (hud.waddle_meter().banner_text().replace("\n", " / ") if hud else ""))
	await _frames(roundi((t.scene_seconds + 0.5) * 60.0))
	_check(events["over"] and _penguin.state == Penguin.State.SWIM and _penguin.input is PlayerInput, "you get control back, in the water")
	await _frames(roundi(t.spread_seconds * 60.0))
	var spawn := _penguin.spawn_point()
	_check(ice.pieces().any(func(piece: FloePiece) -> bool: return piece.covers(spawn, 0.3)), "you'd respawn on a piece of it")
	var tippable := ice.pieces().filter(func(piece: FloePiece) -> bool: return TippableIce.under(piece.get_world_3d(), piece.waddle_spot()) != null)
	_check(tippable.size() == ice.pieces().size(), "and its pieces are ice an orca can tip (%d of %d)" % [tippable.size(), ice.pieces().size()])
	_penguin.infinite_energy = false
