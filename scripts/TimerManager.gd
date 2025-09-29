extends Node2D

# ---- ПРЕСЕТЫ (ужаты под твои данные) ----
const DIFFICULTY_PRESETS := {
	"child": {
		"mult_max": 1.45, "mult_min": 1.05, "half_life": 3.0,
		"min_time": 15.0, "speed": 250.0, "per_coin_sec": 0.12, "global_scale": 1.00,
		"buf_cap_start": 9.0, "buf_cap_end": 3.5, "cap_half_life": 3.0
	},
	"regular": {
		# было 1.35→1.25; cap 10→7, 2.5→1.8
		"mult_max": 1.25, "mult_min": 1.00, "half_life": 2.3,
		"min_time": 12.0, "speed": 300.0, "per_coin_sec": 0.06, "global_scale": 0.94,
		"buf_cap_start": 7.0, "buf_cap_end": 1.8, "cap_half_life": 2.3
	},
	"hard": {
		"mult_max": 1.18, "mult_min": 1.00, "half_life": 2.0,
		"min_time": 10.0, "speed": 320.0, "per_coin_sec": 0.04, "global_scale": 0.90,
		"buf_cap_start": 5.5, "buf_cap_end": 1.6, "cap_half_life": 2.0
	},
	"challenge": {
		"mult_max": 1.10, "mult_min": 1.00, "half_life": 1.8,
		"min_time": 8.0, "speed": 360.0, "per_coin_sec": 0.00, "global_scale": 0.88,
		"buf_cap_start": 4.0, "buf_cap_end": 1.3, "cap_half_life": 1.8
	}
}

const BASE_TIME_PER_LEVEL := 22.0
var _difficulty: StringName = &"regular"

# ---- Автокалибровка по реальному запасу времени ----
const SURPLUS_WINDOW := 8              # храним последние N запасов
const SURPLUS_GAIN := 0.65             # сила коррекции (0.5–0.8 норм)
var _recent_surplus: Array[float] = [] # секунды запаса с последних уровней

func set_difficulty(level: String) -> void:
	if DIFFICULTY_PRESETS.has(level):
		_difficulty = level
	else:
		push_warning("Unknown difficulty '%s', keeping '%s'." % [level, _difficulty])

func _get_preset() -> Dictionary:
	return DIFFICULTY_PRESETS[_difficulty]

# экспоненциальная сходимость множителя к 1.0/мин
func _level_multiplier(level: int) -> float:
	var p := _get_preset()
	var mult_max: float = float(p["mult_max"])
	var mult_min: float = float(p["mult_min"])
	var half_life: float = max(float(p["half_life"]), 0.0001)
	var decay: float = pow(0.5, float(max(level, 1) - 1) / half_life)
	return mult_min + (mult_max - mult_min) * decay

# потолок буфера в секундах, плавно ужимающийся к поздним уровням
func _buffer_cap_sec(level: int) -> float:
	var p := _get_preset()
	var start: float = float(p["buf_cap_start"])
	var endv: float = float(p["buf_cap_end"])
	var half_life: float = max(float(p["cap_half_life"]), 0.0001)
	var decay: float = pow(0.5, float(max(level, 1) - 1) / half_life)
	return endv + (start - endv) * decay

# цель по запасу секунд (ранние уровни прощают больше)
func _target_surplus_sec(level: int) -> float:
	var t: float = clamp((float(level) - 1.0) / 6.0, 0.0, 1.0) # 1..7 → 0..1
	return lerp(6.0, 2.0, t)

# log2(1+n) = log(1+n)/log(2.0) — маленькая надбавка за «детуры» при многих монетах
func _route_detour_factor(coin_count: int) -> float:
	var n: float = float(max(coin_count, 0))
	var detour: float = log(1.0 + n) / log(2.0)
	return 1.0 + 0.05 * detour # чуть мягче (0.05)

# скользящее среднее запаса (секунды)
func _avg_surplus() -> float:
	if _recent_surplus.is_empty():
		return 0.0
	var s := 0.0
	for v in _recent_surplus:
		s += v
	return s / float(_recent_surplus.size())

# публичный вызов после завершения уровня: передай реальный запас секунд
# например из геймплея: TimerManager.register_level_result(level_time_given - level_time_used)
func register_level_result(time_left_sec: float) -> void:
	_recent_surplus.append(max(time_left_sec, 0.0))
	if _recent_surplus.size() > SURPLUS_WINDOW:
		_recent_surplus.pop_front()

# --- Основной расчёт времени ---
func calculate_level_time(level: int, coins: Array, exit_pos: Vector2, player_start: Vector2 = LevelUtils.PLAYER_START) -> float:
	var p := _get_preset()

	# путь: старт -> монеты -> выход (если монет нет — просто старт -> выход)
	var total_distance: float = 0.0
	var current_pos: Vector2 = player_start
	if coins.size() > 0:
		for coin in coins:
			total_distance += current_pos.distance_to(coin.position)
			current_pos = coin.position
	total_distance += current_pos.distance_to(exit_pos)

	var speed: float = float(p["speed"])
	var base_time: float = (total_distance / speed) * _route_detour_factor(coins.size())

	var per_coin_sec: float = float(p["per_coin_sec"])
	var pickup_time: float = float(coins.size()) * per_coin_sec

	var mult: float = _level_multiplier(level)
	var preset_scale: float = float(p["global_scale"])
	var min_time: float = float(p["min_time"])

	# буфер от множителя, но под потолком по секундам
	var multiplicative_buffer: float = base_time * max(mult - 1.0, 0.0)
	var cap_sec: float = _buffer_cap_sec(level)
	var capped_buffer: float = min(multiplicative_buffer, cap_sec)

	var planned: float = (base_time + pickup_time + capped_buffer) * preset_scale

	# --- АВТО-КОРРЕКТОР ПО ЛОГАМ ---
	# если недавний средний запас выше цели — отнимаем часть разницы (мягко)
	var avg_surplus := _avg_surplus()
	if avg_surplus > 0.0:
		var target := _target_surplus_sec(level)
		var over: float = max(avg_surplus - target, 0.0)
		# на высоких уровнях подрезаем сильнее (позволяем max 40% planned)
		var max_cut: float = max(0.4 * planned, cap_sec * 1.5)
		var cut: float = clamp(over * SURPLUS_GAIN, 0.0, max_cut)
		planned = max(planned - cut, min_time)

	return max(planned, min_time)

# фоллбек без данных монет/выхода
func get_time_for_level(level: int) -> float:
	var p := _get_preset()
	var mult: float = _level_multiplier(level)
	var preset_scale: float = float(p["global_scale"])
	var min_time: float = float(p["min_time"])

	var approx: float = BASE_TIME_PER_LEVEL * mult * preset_scale

	# тоже слегка авто-корректируем, чтобы старт уровня не был систематически жирным
	var avg_surplus := _avg_surplus()
	if avg_surplus > 0.0:
		var target := _target_surplus_sec(level)
		var over: float = max(avg_surplus - target, 0.0)
		var cut: float = clamp(over * 0.5, 0.0, 0.4 * approx)
		approx = max(approx - cut, min_time)

	return max(approx, min_time)
