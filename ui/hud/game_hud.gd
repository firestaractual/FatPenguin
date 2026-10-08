class_name GameHud
extends CanvasLayer
## The in-game HUD for one player's penguin: the air meter (only when short of breath), a pause
## button, control prompts at the bottom, and the screen effects behind them all (ScreenFx: the
## edges darkening near a predator, tunnel vision, black-outs, queasy). There's no energy bar on purpose: body size is the
## energy display (GDD §4.1). The debug numbers are a separate, normally hidden layer (DebugHud).
##
## It keeps clear of a phone's notch and rounded corners (the display's safe area).

## The penguin it shows. Empty: the first in the "player" group.
@export var penguin_path: NodePath

var penguin: Penguin = null

@onready var _root: Control = $Root
@onready var _air: AirMeter = %AirMeter
@onready var _prompts: ControlPrompts = %Prompts
@onready var _pause: Button = %PauseButton
@onready var _fx: ScreenFx = $ScreenFx


func _ready() -> void:
	_pause.pressed.connect(_on_pause_pressed)
	# Touches on these don't steer or boost (TouchControls skips them).
	_pause.add_to_group(&"touch_ui")
	get_viewport().size_changed.connect(_fit_safe_area)
	_fit_safe_area()
	_find_penguin.call_deferred()


func _process(_delta: float) -> void:
	if penguin == null or not is_instance_valid(penguin) or penguin.tuning == null:
		_air.show_air(1.0, 1.0, false)
		return
	var underwater := penguin.state == Penguin.State.SWIM and GameWorld.WATER_LEVEL - penguin.global_position.y > Penguin.BREATH_DEPTH
	_air.show_air(penguin.air, penguin.tuning.air_seconds, underwater or penguin.air < penguin.tuning.air_seconds - 0.05)


## The air meter (for tests and other screens).
func air_meter() -> AirMeter:
	return _air


func prompts() -> ControlPrompts:
	return _prompts


func screen_fx() -> ScreenFx:
	return _fx


func _find_penguin() -> void:
	if not penguin_path.is_empty():
		penguin = get_node_or_null(penguin_path) as Penguin
	if penguin == null:
		penguin = get_tree().get_first_node_in_group(&"player") as Penguin
	_prompts.penguin = penguin
	_fx.penguin = penguin


func _on_pause_pressed() -> void:
	var menu := PauseMenu.of(self)
	if menu != null:
		menu.open()


## Insets the HUD by the display's safe area (notches, rounded corners), in viewport units.
func _fit_safe_area() -> void:
	var window := get_viewport().get_visible_rect().size
	var screen := Vector2(DisplayServer.screen_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if not OS.has_feature("mobile") or screen.x <= 0.0 or safe.size.x <= 0.0:
		return
	var to_view := window / screen
	_root.offset_left = safe.position.x * to_view.x
	_root.offset_top = safe.position.y * to_view.y
	_root.offset_right = -(screen.x - safe.end.x) * to_view.x
	_root.offset_bottom = -(screen.y - safe.end.y) * to_view.y
