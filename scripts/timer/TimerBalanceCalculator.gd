class_name TimerBalanceCalculator
extends RefCounted

static func level_multiplier(level: int, preset: Dictionary) -> float:
	var mult_max: float = float(preset.get("mult_max", 1.0))
	var mult_min: float = float(preset.get("mult_min", 1.0))
	var half_life: float = max(float(preset.get("half_life", 1.0)), 0.0001)
	var decay: float = pow(0.5, float(max(level, 1) - 1) / half_life)
	return mult_min + (mult_max - mult_min) * decay

static func buffer_cap_sec(level: int, preset: Dictionary) -> float:
	var start: float = float(preset.get("buf_cap_start", 0.0))
	var endv: float = float(preset.get("buf_cap_end", start))
	var half_life: float = max(float(preset.get("cap_half_life", 1.0)), 0.0001)
	var decay: float = pow(0.5, float(max(level, 1) - 1) / half_life)
	return endv + (start - endv) * decay

static func target_surplus_sec(level: int) -> float:
	var t: float = clamp((float(level) - 1.0) / 6.0, 0.0, 1.0)
	return lerp(6.0, 2.0, t)

static func route_detour_factor(coin_count: int) -> float:
	var n: float = float(max(coin_count, 0))
	var detour: float = log(1.0 + n) / log(2.0)
	return 1.0 + 0.05 * detour

static func level_type_scale(profile: Dictionary, level: int) -> float:
	var start: float = float(profile.get("scale_start", 1.0))
	var endv: float = float(profile.get("scale_end", start))
	var t = clamp((float(level) - 1.0) / 8.0, 0.0, 1.0)
	return lerp(start, endv, t)

static func maze_overhead(is_maze: bool, profile: Dictionary, maze_path_length: float, player_start: Vector2, exit_pos: Vector2, speed: float) -> Dictionary:
	if not is_maze:
		return {"factor": 1.0, "slack": 0.0, "base_path": 0.0}
	var straight: float = player_start.distance_to(exit_pos)
	var fallback_factor: float = float(profile.get("maze_fallback_factor", 1.35))
	var base_path: float = 0.0
	if straight > 0.0:
		base_path = straight * fallback_factor
	if maze_path_length > 0.0:
		var floor_scale: float = float(profile.get("maze_path_floor", 1.0))
		base_path = max(maze_path_length, straight * floor_scale)
		var ratio = clamp(maze_path_length / max(straight, 1.0), 1.0, 4.5)
		var base_scale: float = float(profile.get("maze_base_scale", 0.6))
		var factor = 1.0 + (ratio - 1.0) * base_scale
		var ratio_span: float = max(float(profile.get("maze_ratio_span", 2.5)), 0.5)
		var ratio_t = clamp((ratio - 1.0) / ratio_span, 0.0, 1.0)
		var slack_curve: Vector2 = profile.get("maze_slack_curve", Vector2.ZERO)
		var slack = 0.0
		if slack_curve != Vector2.ZERO:
			slack += lerp(slack_curve.x, slack_curve.y, ratio_t)
		var path_scale: float = float(profile.get("maze_path_scale", 0.8))
		var path_cap: float = float(profile.get("maze_path_cap", 8.0))
		var path_bonus = clamp((maze_path_length - straight) / max(speed, 1.0), 0.0, path_cap)
		slack += path_bonus * path_scale
		return {"factor": factor, "slack": slack, "base_path": base_path}
	var fallback_slack: float = float(profile.get("maze_fallback_slack", 5.0))
	return {"factor": fallback_factor, "slack": fallback_slack, "base_path": base_path}
