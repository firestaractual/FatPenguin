class_name Leaderboard
extends RefCounted
## The most prolific penguins ever (GDD §4.12): the top ten by eggs laid (then chicks raised to
## grown-ups, then cuckoo eggs), from every match played on this device, saved to
## user://leaderboard.cfg. WaddleMatch records a match's penguins when it ends; the end screen and
## the pause menu show it (LeaderboardPanel). Tests use use_memory(), which never touches the file.

const PATH := "user://leaderboard.cfg"
## How many it keeps.
const KEEP := 10

## Each entry: {"name", "family", "colour" (html), "eggs", "raised", "cuckoos", "player" (bool:
## the player played it), "date" (yyyy-mm-dd)}, best first.
var entries: Array[Dictionary] = []

var _path := PATH

static var _current: Leaderboard = null


## The leaderboard (loaded from the file the first time).
static func current() -> Leaderboard:
	if _current == null:
		_current = Leaderboard.new()
		_current._load()
	return _current


## An empty leaderboard that's never saved (for tests).
static func use_memory() -> Leaderboard:
	_current = Leaderboard.new()
	_current._path = ""
	return _current


## Adds a match's penguins (entries like the ones above, without the date) and keeps the best
## KEEP. Penguins that laid no eggs aren't recorded. Saves, unless it's in memory only.
func record(penguins: Array) -> void:
	var date := Time.get_date_string_from_system()
	for entry: Dictionary in penguins:
		if int(entry.get("eggs", 0)) <= 0:
			continue
		var kept := entry.duplicate()
		kept["date"] = date
		entries.append(kept)
	entries.sort_custom(better)
	if entries.size() > KEEP:
		entries.resize(KEEP)
	_save()


## Ranks `a` above `b`: more eggs, then more chicks raised, then more cuckoo eggs.
static func better(a: Dictionary, b: Dictionary) -> bool:
	if int(a.get("eggs", 0)) != int(b.get("eggs", 0)):
		return int(a.get("eggs", 0)) > int(b.get("eggs", 0))
	if int(a.get("raised", 0)) != int(b.get("raised", 0)):
		return int(a.get("raised", 0)) > int(b.get("raised", 0))
	return int(a.get("cuckoos", 0)) > int(b.get("cuckoos", 0))


func _load() -> void:
	var file := ConfigFile.new()
	if file.load(_path) != OK:
		return
	var saved: Variant = file.get_value("leaderboard", "entries", [])
	if saved is Array:
		for entry: Variant in saved:
			if entry is Dictionary:
				entries.append(entry)
	entries.sort_custom(better)


func _save() -> void:
	if _path.is_empty():
		return
	var file := ConfigFile.new()
	file.set_value("leaderboard", "entries", entries)
	file.save(_path)
