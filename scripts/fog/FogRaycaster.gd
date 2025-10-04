class_name FogRaycaster
extends RefCounted

const MIN_RAY_COUNT := 32
const ANGLE_JITTER := 0.0006
const MIN_ANGLE_DELTA := 0.0001

static func build_angles(ray_count: int) -> PackedFloat32Array:
	var clamped: int = max(ray_count, MIN_RAY_COUNT)
	var step: float = TAU / float(clamped)
	var angles := PackedFloat32Array()
	for i in range(clamped):
		var base := step * float(i)
		angles.push_back(_wrap_angle(base))
		angles.push_back(_wrap_angle(base + ANGLE_JITTER))
		angles.push_back(_wrap_angle(base - ANGLE_JITTER))
	return angles

static func cast_rays(space_state: PhysicsDirectSpaceState2D, origin: Vector2, radius: float, angles: PackedFloat32Array, excluded: Array[RID]) -> Array:
	var results: Array = []
	for angle in angles:
		var direction := Vector2.RIGHT.rotated(angle)
		var target := origin + direction * radius
		var params := PhysicsRayQueryParameters2D.create(origin, target)
		params.exclude = excluded
		params.collide_with_bodies = true
		params.collide_with_areas = false
		var hit: Dictionary = space_state.intersect_ray(params)
		var hit_point: Vector2 = hit.get("position", target)
		results.append([angle, hit_point])
	if results.size() > 1:
		results.sort_custom(Callable(FogRaycaster, "_sort_hits"))
	return results

static func build_polygon(hit_results: Array, origin: Vector2, fallback: PackedVector2Array, use_fallback: bool) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var last_angle := -1.0
	for entry in hit_results:
		var angle := float(entry[0])
		if last_angle >= 0.0 and abs(angle - last_angle) < MIN_ANGLE_DELTA:
			continue
		last_angle = angle
		var point: Vector2 = entry[1]
		polygon.push_back(point - origin)
	if polygon.size() < 3:
		return fallback if use_fallback else PackedVector2Array()
	return polygon

static func create_fallback_circle(radius: float, segments: int = 48) -> PackedVector2Array:
	var fallback := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		fallback.push_back(Vector2.RIGHT.rotated(angle) * radius)
	return fallback

static func _wrap_angle(angle: float) -> float:
	return fposmod(angle, TAU)

static func _sort_hits(a, b) -> bool:
	return float(a[0]) < float(b[0])
