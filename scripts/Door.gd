extends StaticBody2D

@export var door_id: int = 0
@export var required_keys: int = 1
@export var initially_open: bool = false

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
	if collision:
		collision.disabled = true
	if body:
		body.color = Color(0.3, 0.75, 0.4, 0.9)
	z_index = -5

func _apply_closed_state() -> void:
	_is_open = false
	if collision:
		collision.disabled = false
	if body:
		body.color = Color(0.35, 0.35, 0.75, 1.0)
