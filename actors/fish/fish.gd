class_name Fish
extends Area3D
## A single fish (Prototype 0: no AI). Swims a small lazy circle around where it was placed.
## Swim into it to eat it. Respawns after a delay so the toy never runs dry.

@export var circle_radius := 0.8
@export var circle_speed := 0.6
@export var respawn_seconds := 8.0
## Spilled fish (knocked loose in a bump) are eaten once and gone.
@export var one_shot := false
## Can't be eaten by anyone for this long after appearing.
@export var pickup_delay := 0.0
## This body (the penguin that spilled the fish) can't eat it for ignore_seconds.
var ignore_body: Node = null
@export var ignore_seconds := 0.0

var _home := Vector3.ZERO
var _phase := 0.0
var _age := 0.0


func _ready() -> void:
	_home = position
	_phase = randf() * TAU
	collision_layer = 0
	collision_mask = Penguin.PENGUIN_LAYER
	body_entered.connect(_on_body_entered)
	if pickup_delay > 0.0:
		monitoring = false
		get_tree().create_timer(pickup_delay).timeout.connect(func() -> void: monitoring = true)


func _physics_process(delta: float) -> void:
	_age += delta
	_phase += circle_speed * delta
	var offset := Vector3(cos(_phase), sin(_phase * 2.0) * 0.15, sin(_phase)) * circle_radius
	position = _home + offset
	# Face along the circle.
	var forward := Vector3(-sin(_phase), 0.0, cos(_phase))
	basis = Basis.looking_at(forward, Vector3.UP)


func _on_body_entered(body: Node3D) -> void:
	if body == ignore_body and _age < ignore_seconds:
		return
	if body is Penguin and visible:
		(body as Penguin).eat_fish()
		if one_shot:
			queue_free()
			return
		_set_active(false)
		get_tree().create_timer(respawn_seconds).timeout.connect(_set_active.bind(true))


func _set_active(active: bool) -> void:
	visible = active
	set_deferred(&"monitoring", active)
