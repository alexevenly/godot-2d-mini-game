extends StaticBody2D

@export var door_id: int = 0
@export var required_keys: int = 1
@export var initially_open: bool = false
@export var door_color := Color(0.35, 0.35, 0.75, 1.0):
	set(value):
		_door_color = value
		_open_color = _compute_open_color(_door_color)
		_apply_visual_state()
	get:
		return _door_color

var _door_color: Color = Color(0.35, 0.35, 0.75, 1.0)
var _open_color: Color = _compute_open_color(_door_color)

var _collected_keys: int = 0
var _is_open: bool = false

@onready var collision: CollisionShape2D = $DoorCollision
@onready var body: ColorRect = $DoorBody

func _ready():
	if required_keys <= 0:
		required_keys = 0
		initially_open = true
	if initially_open:
		_open_door()
	else:
		_apply_closed_state()

func register_key() -> void:
	if _is_open:
		return
	_collected_keys += 1
	if _collected_keys >= max(required_keys, 1):
		_open_door()

func _open_door() -> void:
	_is_open = true
	_set_collision_disabled(true)
	_apply_body_color(_open_color)
	z_index = -5

func _apply_closed_state() -> void:
	_is_open = false
	_set_collision_disabled(false)
	_apply_body_color(_door_color)

func _apply_visual_state() -> void:
	if body == null:
		return
	if _is_open:
		_apply_body_color(_open_color)
	else:
		_apply_body_color(_door_color)

func _set_collision_disabled(disabled: bool) -> void:
	if collision == null:
		return
	collision.disabled = disabled
	collision.set_deferred("disabled", disabled)

func _compute_open_color(color: Color) -> Color:
	var result := color.lightened(0.35)
	result.a = color.a
	return result

func _apply_body_color(color: Color) -> void:
	if body:
		body.color = color
