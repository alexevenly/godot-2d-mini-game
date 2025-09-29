extends Area2D

@export var door_path: NodePath
@export var door_id: int = 0
@export var required_key_count: int = 1

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if not body.is_class("CharacterBody2D"):
		return
	if body.name != "Player":
		return
	var door = _get_door()
	if door:
		door.register_key()
	queue_free()

func _get_door():
	if door_path.is_empty():
		return null
	return get_node_or_null(door_path)
