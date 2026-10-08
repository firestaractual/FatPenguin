class_name ScreenFx
extends Control
## What one player's screen does when there's danger (part of GameHud):
##   - anxiety: the edges slowly darken, closing in from the sides, while a predator is near (you
##     sense it, in sight or not), more if one is hunting you, with a heartbeat throb at its worst;
##     it fades back out slowly once you're clear;
##   - tunnel vision: the edges close in a little while you boost;
##   - hits close the screen in hard and open it back up: a whale's body (dazed), a tail slap
##     (stunned), a lunge at you from close by, a hard bump; getting caught blacks it out;
##   - queasy (a sick fish): the picture swims, doubles and goes green.
## The numbers are in ScreenFxTuning (tuning/screen_fx.tres). The player's Screen effects setting
## (GameSettings.screen_effects) scales it all: full, half (no swimming picture) or off.
##
## It only reads the penguin (and the predators near it), never changes the game. The dark is a
## navy black, never the danger colour.

const DEFAULT_TUNING := preload("res://tuning/screen_fx.tres")

@export var tuning: ScreenFxTuning = DEFAULT_TUNING

## The penguin whose danger it shows (GameHud sets it).
var penguin: Penguin = null:
	set(value):
		_disconnect()
		penguin = value
		_connect()

var _anxiety := 0.0
var _boost := 0.0
## The current hit: how hard (0 to 1) and how long it takes to open back up (s).
var _hit := 0.0
var _hit_seconds := 1.0
var _black := 0.0
var _black_hold := 0.0
var _beat := 0.0
var _was_stunned := false
## Lunges already counted (by predator), so one lunge closes the screen in once.
var _lunges := {}

@onready var _vignette: ColorRect = $Vignette
@onready var _queasy: ColorRect = $Queasy


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_apply(0.0, 0.0, 0.0, 0.0)


func _process(delta: float) -> void:
	if penguin == null or not is_instance_valid(penguin) or penguin.tuning == null:
		_apply(0.0, 0.0, 0.0, 0.0)
		return
	var t := tuning
	# Anxiety creeps in and fades out slowly.
	var threat := threat_level()
	var rate := t.rise_rate if threat > _anxiety else t.fall_rate
	_anxiety = move_toward(_anxiety, threat, rate * delta)
	# Boost: quick in, slower out.
	var boosting := penguin.is_boosting()
	_boost = move_toward(_boost, 1.0 if boosting else 0.0, delta / (t.boost_in_seconds if boosting else t.boost_out_seconds))
	# Hits open back up over their length.
	_hit = move_toward(_hit, 0.0, delta / maxf(_hit_seconds, 0.05))
	if penguin.is_stunned() and not _was_stunned and not penguin.is_dazed():
		hit(t.stun_strength, 1.2)
	_was_stunned = penguin.is_stunned()
	_watch_lunges()
	# Caught: black, then back.
	if _black_hold > 0.0:
		_black_hold -= delta
	else:
		_black = move_toward(_black, 0.0, delta / maxf(t.caught_fade_seconds, 0.05))
	_beat += delta * t.heartbeat_bpm / 60.0 * TAU
	var throb := 1.0 + t.heartbeat * _anxiety * _anxiety * maxf(sin(_beat), 0.0)
	var dark := maxf(_anxiety * t.darkness * throb + _boost * t.boost_darkness, _hit * t.hit_darkness)
	var reach := maxf(_anxiety * t.reach + _boost * t.boost_reach, _hit * t.hit_reach)
	_apply(dark, reach, _black, penguin.queasiness())


# --- What it shows (for tests and other screens) -------------------------------

## How much danger it senses around the penguin right now (0 to 1): the anxiety it's heading for.
func threat_level() -> float:
	if penguin == null or not is_instance_valid(penguin):
		return 0.0
	var t := tuning
	var p := penguin
	var in_water := p.state == Penguin.State.SWIM or p.global_position.y < GameWorld.WATER_LEVEL
	var best := 0.0
	for node in get_tree().get_nodes_in_group(&"predators"):
		var predator := node as Predator
		if predator == null:
			continue
		var d := predator.global_position.distance_to(p.global_position)
		var level := clampf(1.0 - d / t.sense_range, 0.0, 1.0)
		if predator.is_hunting(p):
			level = maxf(level, t.hunted_level + (1.0 - t.hunted_level) * level)
		else:
			if predator.state == Predator.State.SATED:
				level *= t.sated_share
			if not in_water:
				level *= t.on_ice_share
		best = maxf(best, level)
	for node in get_tree().get_nodes_in_group(&"pods"):
		var pod := node as PredatorPod
		if pod != null and pod.attack != null and pod.attack.target == p:
			best = maxf(best, t.attack_level)
	return best


## The anxiety showing now (0 to 1).
func anxiety() -> float:
	return _anxiety


## The tunnel vision from boosting now (0 to 1).
func boost_tunnel() -> float:
	return _boost


## How closed in the screen is from a hit now (0 to 1), and how blacked out (0 to 1).
func hit_level() -> float:
	return _hit


func blackout() -> float:
	return _black


## How dark the edges are, how far in the dark reaches, and the black-out, as shown (after the
## Screen effects setting).
func shown() -> Dictionary:
	var m := _vignette.material as ShaderMaterial
	return {"darkness": m.get_shader_parameter(&"darkness"), "reach": m.get_shader_parameter(&"reach"), "blackout": m.get_shader_parameter(&"blackout")}


## Something hit the penguin: the screen closes in by `strength` (0 to 1) and opens back up over
## `seconds`.
func hit(strength: float, seconds: float) -> void:
	if strength >= _hit:
		_hit = strength
		_hit_seconds = seconds


# --- Inside ----------------------------------------------------------------------

func _apply(dark: float, reach: float, black: float, queasy: float) -> void:
	var strength := _setting_scale()
	var m := _vignette.material as ShaderMaterial
	m.set_shader_parameter(&"darkness", clampf(dark * strength, 0.0, 0.97))
	m.set_shader_parameter(&"reach", clampf(reach * strength, 0.0, 0.95))
	# A black-out isn't halved: it's on (Full, Reduced) or off.
	m.set_shader_parameter(&"blackout", clampf(black, 0.0, 1.0) if strength > 0.0 else 0.0)
	_vignette.visible = strength > 0.0 and (dark > 0.001 or black > 0.001)
	var q := _queasy.material as ShaderMaterial
	var amount := clampf(queasy * strength, 0.0, 1.0)
	q.set_shader_parameter(&"amount", amount)
	q.set_shader_parameter(&"wobble", tuning.queasy_wobble if _full() else 0.0)
	q.set_shader_parameter(&"tint", tuning.queasy_tint)
	# Only read the screen back while it's needed: it costs a copy of the screen every frame.
	_queasy.visible = amount > 0.001


func _setting_scale() -> float:
	match GameSettings.current().screen_effects:
		GameSettings.ScreenEffects.REDUCED:
			return 0.5
		GameSettings.ScreenEffects.OFF:
			return 0.0
	return 1.0


func _full() -> bool:
	return GameSettings.current().screen_effects == GameSettings.ScreenEffects.FULL


## A lunge at the penguin from close by closes the screen in, once per lunge, hit or miss.
func _watch_lunges() -> void:
	for node in get_tree().get_nodes_in_group(&"predators"):
		var predator := node as Predator
		if predator == null:
			continue
		var lunging := predator.state == Predator.State.LUNGE and predator.target == penguin
		if lunging and not _lunges.has(predator):
			_lunges[predator] = true
			if predator.global_position.distance_to(penguin.global_position) <= tuning.lunge_range:
				hit(tuning.lunge_strength, tuning.short_hit_seconds)
		elif not lunging:
			_lunges.erase(predator)


func _connect() -> void:
	if penguin == null:
		return
	penguin.dazed.connect(_on_dazed)
	penguin.caught.connect(_on_caught)
	penguin.bumped.connect(_on_bumped)


func _disconnect() -> void:
	if penguin == null or not is_instance_valid(penguin):
		return
	if penguin.dazed.is_connected(_on_dazed):
		penguin.dazed.disconnect(_on_dazed)
		penguin.caught.disconnect(_on_caught)
		penguin.bumped.disconnect(_on_bumped)


func _on_dazed(seconds: float) -> void:
	hit(tuning.daze_strength, seconds)


func _on_caught(_by: Node3D) -> void:
	_black = 1.0
	_black_hold = tuning.caught_black_seconds
	_anxiety = 0.0


func _on_bumped(_other: Penguin, _closing_speed: float, hard: bool) -> void:
	if hard:
		hit(tuning.bump_strength, tuning.short_hit_seconds)
