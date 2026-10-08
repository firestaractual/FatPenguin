class_name GameSettings
extends RefCounted
## The player's settings, kept in user://settings.cfg between sessions: control preferences, the
## control hints and how far through them the player is, how strong the screen effects are, and
## whether the debug numbers show. Not
## balance numbers (those are in tuning/). There's one set: GameSettings.current().
##
## Change a setting by assigning it; that saves the file and emits `changed`.
##   GameSettings.current().invert_pitch = true

## Some setting changed (its name).
signal changed(setting: StringName)

const PATH := "user://settings.cfg"

## How strong the screen effects are (ScreenFx: dimming when a predator's near, tunnel vision,
## black-outs, the queasy wobble): full, reduced (half as strong, no wobble) or off.
enum ScreenEffects { FULL, REDUCED, OFF }

static var _current: GameSettings = null

## Swimming, pushing the stick up dives (like a flight stick). PlayerInput applies it.
var invert_pitch := false:
	set(value):
		invert_pitch = value
		_changed(&"invert_pitch")
## Touch controls swapped: steer with the right thumb, act with the left.
var left_handed := false:
	set(value):
		left_handed = value
		_changed(&"left_handed")
## Show control prompts ("tap to boost") and warnings in the HUD.
var control_hints := true:
	set(value):
		control_hints = value
		_changed(&"control_hints")
## How strong the screen effects are (ScreenEffects).
var screen_effects := ScreenEffects.FULL:
	set(value):
		screen_effects = clampi(value, ScreenEffects.FULL, ScreenEffects.OFF) as ScreenEffects
		_changed(&"screen_effects")
## Show the debug numbers and tester notes (F1 toggles this too).
var show_debug := false:
	set(value):
		show_debug = value
		_changed(&"show_debug")

## Saved to and loaded from PATH. Off for tests.
var persist := true
## How many times the player has done each thing a control prompt teaches (by prompt id), so a
## prompt stops once it's been learned, this session and the next.
var _learned := {}


## The settings in use (loaded from the file the first time).
static func current() -> GameSettings:
	if _current == null:
		_current = GameSettings.new()
		_current.load_file()
	return _current


## Fresh defaults that never touch the file (the smoke test uses these).
static func use_defaults(persisted := false) -> GameSettings:
	_current = GameSettings.new()
	_current.persist = persisted
	return _current


## How many times the player has done what prompt `id` teaches.
func learned(id: StringName) -> int:
	return int(_learned.get(id, 0))


## Counts one more time the player did what prompt `id` teaches.
func note_learned(id: StringName) -> void:
	_learned[id] = learned(id) + 1
	_save()


## Forget what the control prompts have taught, so they show again.
func reset_hints() -> void:
	_learned.clear()
	_changed(&"hints")


func load_file() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	var was := persist
	persist = false # don't save back while loading
	invert_pitch = cfg.get_value("controls", "invert_pitch", invert_pitch)
	left_handed = cfg.get_value("controls", "left_handed", left_handed)
	control_hints = cfg.get_value("hud", "control_hints", control_hints)
	screen_effects = int(cfg.get_value("hud", "screen_effects", screen_effects)) as ScreenEffects
	show_debug = cfg.get_value("debug", "show_debug", show_debug)
	for key in (cfg.get_section_keys("learned") if cfg.has_section("learned") else PackedStringArray()):
		_learned[StringName(key)] = int(cfg.get_value("learned", key, 0))
	persist = was


func _changed(setting: StringName) -> void:
	_save()
	changed.emit(setting)


func _save() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "invert_pitch", invert_pitch)
	cfg.set_value("controls", "left_handed", left_handed)
	cfg.set_value("hud", "control_hints", control_hints)
	cfg.set_value("hud", "screen_effects", int(screen_effects))
	cfg.set_value("debug", "show_debug", show_debug)
	for id: StringName in _learned:
		cfg.set_value("learned", String(id), _learned[id])
	cfg.save(PATH)
