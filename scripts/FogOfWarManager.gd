extends Node2D

@export var visibility_radius := 220.0
@export var darkness_color := Color(0, 0, 0, 0.92)
@export var ray_count := 720
@export var update_interval := 0.05
@export var invert_border_margin := 512.0
@export var overlay_z_index: int = 3200: set = set_overlay_z_index
@export var debug_logging := false

var player: Node2D = null
var _fog_root: Node2D = null
var _fog_polygon: Polygon2D = null
var _time_since_update := 0.0
var _ray_angles := PackedFloat32Array()
var _excluded_rids: Array[RID] = []
var _log_file: FileAccess = null

func _ready() -> void:
	set_overlay_z_index(overlay_z_index)
	_create_overlay()
	_refresh_ray_angles()
	_update_excluded_rids()
	set_physics_process(true)
	_update_visibility_polygon(true)

func _exit_tree() -> void:
	_fog_root = null
	_fog_polygon = null
	_ray_angles = PackedFloat32Array()
	_excluded_rids.clear()
	if _log_file:
		_log_file.close()
		_log_file = null

func set_player(target: Node) -> void:
	if target is Node2D:
		player = target
		_update_excluded_rids()
		_time_since_update = update_interval
		_update_visibility_polygon(true)

func set_visibility_radius(radius: float) -> void:
	visibility_radius = max(radius, 32.0)
	if _fog_polygon:
		_fog_polygon.invert_border = _compute_invert_border()
	_update_visibility_polygon(true)

func set_overlay_z_index(value: int) -> void:
	overlay_z_index = _clamp_overlay_z(value)
	z_as_relative = false
	z_index = overlay_z_index
	if _fog_polygon:
		_fog_polygon.z_index = overlay_z_index

func set_darkness_color(color: Color) -> void:
	darkness_color = color
	if _fog_polygon:
		_fog_polygon.color = darkness_color

func set_ray_count(count: int) -> void:
	ray_count = max(count, 32)
	_refresh_ray_angles()

func _physics_process(delta: float) -> void:
	if not _is_player_valid():
		return
	_time_since_update += delta
	if _time_since_update < update_interval:
		return
	_time_since_update = 0.0
	_update_visibility_polygon()

func _is_player_valid() -> bool:
	return player != null and is_instance_valid(player)

func _create_overlay() -> void:
	if _fog_root == null:
		_fog_root = Node2D.new()
		_fog_root.name = "FogRoot"
		add_child(_fog_root)
	if _fog_polygon == null:
		_fog_polygon = Polygon2D.new()
		_fog_polygon.name = "FogOfWarPolygon"
		_fog_polygon.color = darkness_color
		_fog_polygon.invert_enabled = true
		_fog_polygon.antialiased = true
		_fog_polygon.z_as_relative = false
		_fog_polygon.z_index = overlay_z_index
		_fog_polygon.invert_border = _compute_invert_border()
		_fog_root.add_child(_fog_polygon)
	if debug_logging and _log_file == null:
		var dir := "user://logs"
		DirAccess.make_dir_recursive_absolute(dir)
		var path := dir + "/fog_debug.log"
		_log_file = FileAccess.open(path, FileAccess.WRITE)
		if _log_file:
			_log_file.store_line("FogOfWarManager ready; radius=%f" % visibility_radius)
			_log_file.flush()

func _compute_invert_border() -> float:
	return max(visibility_radius + invert_border_margin, visibility_radius * 1.5)

func _clamp_overlay_z(value: int) -> int:
	var min_limit := RenderingServer.CANVAS_ITEM_Z_MIN
	var max_limit := RenderingServer.CANVAS_ITEM_Z_MAX
	return clamp(value, min_limit, max_limit)

func _refresh_ray_angles() -> void:
	var clamped_count: int = max(ray_count, 32)
	var step: float = TAU / float(clamped_count)
	var angles: PackedFloat32Array = PackedFloat32Array()
	for i in range(clamped_count):
		var base_angle: float = step * float(i)
		angles.push_back(_wrap_angle(base_angle))
		angles.push_back(_wrap_angle(base_angle + 0.0006))
		angles.push_back(_wrap_angle(base_angle - 0.0006))
	_ray_angles = angles

func _update_excluded_rids() -> void:
	_excluded_rids.clear()
	if player is CollisionObject2D:
		_excluded_rids.append(player.get_rid())

func _update_visibility_polygon(force_fallback := false) -> void:
	if not _fog_polygon:
		return
	if not _is_player_valid():
		if force_fallback:
			_fog_polygon.polygon = PackedVector2Array()
		return
	var origin: Vector2 = player.global_position
	var space_state := _find_space_state()
	if space_state == null:
		return
	var hit_results: Array = []
	for angle in _ray_angles:
		var direction: Vector2 = Vector2.RIGHT.rotated(angle)
		var target: Vector2 = origin + direction * visibility_radius
		var params := PhysicsRayQueryParameters2D.create(origin, target)
		params.exclude = _excluded_rids
		params.collide_with_bodies = true
		params.collide_with_areas = false
		var result: Dictionary = space_state.intersect_ray(params)
		var hit_point: Vector2 = target
		if result and result.has("position"):
			hit_point = result["position"]
		hit_results.append([angle, hit_point])
	if hit_results.is_empty():
		if force_fallback:
			_fog_root.global_position = origin
			_fog_polygon.polygon = _create_fallback_circle()
		return
	hit_results.sort_custom(Callable(self, "_sort_hits"))
	var polygon_points := PackedVector2Array()
	var last_angle := -1.0
	for entry in hit_results:
		var angle := float(entry[0])
		if last_angle >= 0.0 and abs(angle - last_angle) < 0.0001:
			continue
		last_angle = angle
		var point: Vector2 = entry[1]
		polygon_points.push_back(point - origin)
	if polygon_points.size() < 3:
		if force_fallback:
			polygon_points = _create_fallback_circle()
		else:
			return
	_fog_root.global_position = origin
	_fog_polygon.polygon = polygon_points
	if _log_file:
		_log_file.store_line("update origin=%s points=%d" % [str(origin), polygon_points.size()])
		_log_file.flush()

func _find_space_state() -> PhysicsDirectSpaceState2D:
	var world := get_world_2d()
	if world:
		return world.direct_space_state
	if player and player.get_world_2d():
		return player.get_world_2d().direct_space_state
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop
		var root := tree.root
		if root and root.world_2d:
			return root.world_2d.direct_space_state
	return null

func _create_fallback_circle() -> PackedVector2Array:
	var segments: int = 48
	var fallback: PackedVector2Array = PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		fallback.push_back(Vector2.RIGHT.rotated(angle) * visibility_radius)
	return fallback

func _wrap_angle(angle: float) -> float:
	return fposmod(angle, TAU)

static func _sort_hits(a, b) -> bool:
	return float(a[0]) < float(b[0])
