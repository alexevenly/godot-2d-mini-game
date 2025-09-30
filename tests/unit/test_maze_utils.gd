extends "res://tests/unit/test_utils.gd"

const MazeUtils = preload("res://scripts/level_generators/MazeUtils.gd")

func get_suite_name() -> String:
	return "MazeUtils"

func test_init_maze_grid_creates_closed_cells() -> void:
	var grid := MazeUtils.init_maze_grid(3, 4)
	assert_eq(grid.size(), 4)
	for row in grid:
		assert_eq(row.size(), 3)
		for cell in row:
			assert_true(cell)

func test_carve_maze_marks_cells_as_open() -> void:
	var cols := 5
	var rows := 5
	var grid := MazeUtils.init_maze_grid(cols, rows)
	var start := Vector2i(1, 1)
	MazeUtils.carve_maze(grid, start, cols, rows)
	assert_false(grid[start.y][start.x])

func test_find_farthest_cell_in_open_area() -> void:
	var cols := 5
	var rows := 5
	var grid := []
	for y in range(rows):
		var row := []
		for x in range(cols):
			row.append(false)
		grid.append(row)
	var result := MazeUtils.find_farthest_cell(grid, Vector2i(0, 0), cols, rows)
	assert_eq(result["cell"], Vector2i(4, 4))
	assert_true(result["distance"] > 0)

func test_reconstruct_maze_path_returns_sequence() -> void:
	var cols := 4
	var rows := 4
	var grid := []
	for y in range(rows):
		var row := []
		for x in range(cols):
			row.append(false)
		grid.append(row)
	var start := Vector2i(0, 0)
	var goal := Vector2i(3, 0)
	var path := MazeUtils.reconstruct_maze_path(grid, start, goal, cols, rows)
	assert_eq(path[0], start)
	assert_eq(path[path.size() - 1], goal)
	assert_true(path.size() >= 2)

func test_pick_maze_key_cells_excludes_special_cells() -> void:
	var cols := 5
	var rows := 5
	var grid := []
	for y in range(rows):
		var row := []
		for x in range(cols):
			row.append(false)
		grid.append(row)
	var path := [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3), Vector2i(4, 4)]
	var start := Vector2i(1, 1)
	var door := Vector2i(2, 2)
	var exit := Vector2i(3, 3)
	var picked := MazeUtils.pick_maze_key_cells(grid, path, start, door, exit, 2)
	assert_eq(picked.size(), 2)
	for cell in picked:
		assert_false(cell == start)
		assert_false(cell == door)
		assert_false(cell == exit)

func test_maze_cell_world_conversions_are_inverse() -> void:
	var offset := Vector2(10, 20)
	var cell_size := 32.0
	var cell := Vector2i(2, 3)
	var world := MazeUtils.maze_cell_to_world(cell, offset, cell_size)
	var back := MazeUtils.world_to_maze_cell(world, offset, cell_size)
	assert_eq(back, cell)

func test_ensure_odd_cell_clamps_even_values() -> void:
	var result := MazeUtils.ensure_odd_cell(Vector2i(0, 0), 7, 7)
	assert_true(result.x % 2 == 1)
	assert_true(result.y % 2 == 1)
	assert_true(result.x >= 1)
	assert_true(result.y >= 1)
