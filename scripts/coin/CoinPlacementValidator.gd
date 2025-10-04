extends Object
class_name CoinPlacementValidator

const LEVEL_UTILS := preload("res://scripts/LevelUtils.gd")

static func is_valid_position(position: Vector2, existing_coins: Array, obstacles: Array, exit_pos: Vector2, relax: float) -> bool:
	var player_margin_strict: float = 24.0
	var player_margin_relaxed: float = 10.0
	var coin_radius: float = 10.0
	var min_coin_gap_strict: float = 40.0
	var min_coin_gap_relaxed: float = 26.0
	var exit_gap_strict: float = 80.0
	var exit_gap_relaxed: float = 40.0

	var player_margin: float = lerp(player_margin_strict, player_margin_relaxed, relax)
	var min_coin_gap: float = lerp(min_coin_gap_strict, min_coin_gap_relaxed, relax)
	var exit_gap: float = lerp(exit_gap_strict, exit_gap_relaxed, relax)

	if position.distance_to(LEVEL_UTILS.PLAYER_START) < (60.0 - 20.0 * relax):
		return false

	for obstacle in obstacles:
		var rect: Rect2 = LEVEL_UTILS.get_obstacle_rect(obstacle)
		var grown := rect.grow(player_margin + coin_radius)
		if grown.has_point(position):
			return false

	for coin in existing_coins:
		if position.distance_to(coin.position) < min_coin_gap:
			return false

	if exit_pos != Vector2.ZERO and position.distance_to(exit_pos) < exit_gap:
		return false

	return true
