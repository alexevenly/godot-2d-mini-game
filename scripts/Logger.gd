class_name Logger
extends Object

enum Category {
	GENERATION,
	GAME_MODE,
	ERROR
}

static var _enabled := {
	Category.GENERATION: true,
	Category.GAME_MODE: true,
	Category.ERROR: true,
}

static var _labels := {
	Category.GENERATION: "GENERATION",
	Category.GAME_MODE: "GAME_MODE",
	Category.ERROR: "ERROR",
}

static func set_category_enabled(category: Category, enabled: bool) -> void:
	_enabled[category] = enabled

static func log_generation(message: String, extra: Array = []) -> void:
	_log(Category.GENERATION, message, extra)

static func log_game_mode(message: String, extra: Array = []) -> void:
	_log(Category.GAME_MODE, message, extra)

static func log_error(message: String, extra: Array = []) -> void:
	_log(Category.ERROR, message, extra)

static func _log(category: Category, message: String, extra: Array) -> void:
	if not _enabled.get(category, false):
		return
	var parts: Array = [message]
	for value in extra:
		parts.append(str(value))
	var content := PackedStringArray(parts).join(" ")
	print("[%s] %s" % [_labels.get(category, str(category)), content])
