extends RefCounted
class_name MazeDebugLogger

const DEBUG_LOG_DIR := "user://logs"
const DEBUG_LOG_FILE := "maze_debug.log"

var _enabled := false
var _file: FileAccess = null

func configure() -> void:
	_enabled = true
	if Engine.has_meta("maze_debug_logging"):
		_enabled = bool(Engine.get_meta("maze_debug_logging"))
	if not _enabled:
		return
	_open_file_if_needed()
	if _file:
		_file.store_line("MazeGenerator debug log started")
		_file.flush()

func is_enabled() -> bool:
	return _enabled

func log(message: String) -> void:
	if not _enabled:
		return
	_open_file_if_needed()
	if _file:
		_file.store_line(message)
		_file.flush()

func _open_file_if_needed() -> void:
	if _file:
		return
	DirAccess.make_dir_recursive_absolute(DEBUG_LOG_DIR)
	var path := "%s/%s" % [DEBUG_LOG_DIR, DEBUG_LOG_FILE]
	_file = FileAccess.open(path, FileAccess.WRITE)
