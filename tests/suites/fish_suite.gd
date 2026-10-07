extends "res://tests/smoke_suite.gd"
## Fish schools: single-species schools, strays joining, eaten fish coming back beside their school.


func suite_name() -> String:
	return "fish"


func run() -> void:
	await _test_fish_schools()


func _test_fish_schools() -> void:
	# The level puts most of its fish in single-species schools.
	var level_fish := _level.get_node("Fish").get_children()
	var schooled := 0
	for f: Fish in level_fish:
		if _school_mates_in_range(f, level_fish) >= 2:
			schooled += 1
	_check(schooled >= level_fish.size() * 0.75, "most of the level's fish swim in a school (%d of %d)" % [schooled, level_fish.size()])

	# Far from the level's fish: a school of silverfish, plus a lone silverfish and a lone
	# lanternfish, each just inside school range of it.
	var silverfish: FishSpecies = load("res://tuning/fish/silverfish.tres")
	var lanternfish: FishSpecies = load("res://tuning/fish/lanternfish.tres")
	var centre := Vector3(0.0, -6.0, -110.0)
	var school: Array[Fish] = []
	for i in 6:
		var fish := _spawn_fish(silverfish, centre + Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3), randf_range(-1.0, 1.0)))
		fish.home = centre
		school.append(fish)
	var stray := _spawn_fish(silverfish, centre + Vector3(4.5, 0.0, 0.0))
	var stranger := _spawn_fish(lanternfish, centre + Vector3(-4.5, 0.0, 0.0))
	var stranger_home := stranger.home
	await _frames(15 * 60)

	var middle := _middle_of(school)
	var widest := 0.0
	for fish in school:
		widest = maxf(widest, fish.global_position.distance_to(middle))
	_check(widest < 2.5, "a school stays together (widest fish %.1f m from the middle)" % widest)
	var stray_gap := stray.global_position.distance_to(middle)
	_check(stray_gap < 2.5, "a lone fish in range is pulled into a school of its own kind (%.1f m from the middle)" % stray_gap)
	var stray_home := stray.home.distance_to(centre)
	_check(stray_home < 2.0, "and it stays: it now shares the school's home spot (%.1f m away)" % stray_home)
	var stranger_mates := stranger.school_mate_count()
	_check(stranger_mates == 0 and stranger.home == stranger_home, "a fish of another kind is never pulled in (school mates=%d)" % stranger_mates)

	# An eaten fish comes back beside its school, wherever it was eaten.
	var eaten := school[0]
	eaten.get_eaten()
	eaten.global_position = centre + Vector3(30.0, 0.0, 0.0)
	eaten.respawn()
	await _frames(2)
	var eaten_gap := eaten.global_position.distance_to(_middle_of(school))
	_check(eaten.visible and eaten_gap < 2.5, "an eaten fish respawns beside its school (%.1f m from the middle)" % eaten_gap)

	for fish in school:
		fish.queue_free()
	stray.queue_free()
	stranger.queue_free()
