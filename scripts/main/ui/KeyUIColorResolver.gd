extends Object

class_name KeyUIColorResolver

static func resolve_door_identifier(source, fallback: int) -> int:
	if source and source.has_method("get"):
		var door_value = source.get("door_id")
		if door_value != null:
			return int(door_value)
	return fallback

static func resolve_key_color(key_node: Area2D, fallback: Color) -> Color:
	if key_node == null:
		return fallback
	if key_node.has_meta("group_color"):
		var meta_color = key_node.get_meta("group_color")
		if typeof(meta_color) == TYPE_COLOR:
			return meta_color
	if key_node.has_method("get"):
		var property_color = key_node.get("group_color")
		if typeof(property_color) == TYPE_COLOR:
			return property_color
	return fallback

static func resolve_key_metadata(key_node: Area2D, fallback_id: int, fallback_color: Color) -> Dictionary:
	var door_id := fallback_id
	var color := fallback_color
	if key_node:
		door_id = resolve_door_identifier(key_node, fallback_id)
		color = resolve_key_color(key_node, fallback_color)
	return {
		"id": door_id,
		"color": color
	}

static func resolve_door_color(door_body, fallback: Color) -> Color:
	if door_body == null:
		return fallback
	if door_body.has_method("get_door_color"):
		var door_color = door_body.get_door_color()
		if typeof(door_color) == TYPE_COLOR:
			return door_color
	if door_body.has_meta("group_color"):
		var meta_color = door_body.get_meta("group_color")
		if typeof(meta_color) == TYPE_COLOR:
			return meta_color
	if door_body.has_method("get"):
		var property_color = door_body.get("door_color")
		if typeof(property_color) == TYPE_COLOR:
			return property_color
	return fallback
