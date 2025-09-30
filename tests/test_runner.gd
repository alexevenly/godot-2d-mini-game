extends SceneTree

const TEST_ROOT := "res://tests/unit"
const UnitTestSuite = preload("res://tests/unit/test_utils.gd")

func _initialize() -> void:
	var suites: Array[String] = _discover_suites()
	var total_tests := 0
	var total_failures := 0
	var suite_results: Array[Dictionary] = []
	for path in suites:
		var script := load(path)
		if script == null:
			push_error("Failed to load test suite at %s" % path)
			continue
		var suite: UnitTestSuite = script.new()
		if not suite is UnitTestSuite:
			push_error("%s does not extend UnitTestSuite" % path)
			continue
		var result: Dictionary = suite.run()
		total_tests += int(result.get("tests", 0))
		total_failures += result.get("failed", []).size()
		suite_results.append({
			"path": path,
			"result": result
		})
	for entry in suite_results:
		var entry_dict: Dictionary = entry
		var res: Dictionary = entry_dict["result"]
		var path_str: String = entry_dict["path"]
		var failed: Array = res.get("failed", [])
		print("Suite %s — %d tests, %d passed, %d failed" % [path_str, res.get("tests", 0), res.get("passed", 0), failed.size()])
		for failure in failed:
			var messages: Array = failure.get("messages", [])
			print("  ✗ %s: %s" % [failure.get("name"), " | ".join(messages)])
	if total_failures == 0:
		print("All %d tests passed." % total_tests)
	else:
		print("%d of %d tests failed." % [total_failures, total_tests])
	quit(0 if total_failures == 0 else 1)

func _discover_suites() -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(TEST_ROOT)
	if dir == null:
		push_error("Unable to open test directory %s" % TEST_ROOT)
		return found
	dir.list_dir_begin()
	while true:
		var file: String = dir.get_next()
		if file == "":
			break
		if dir.current_is_dir():
			continue
		if not file.ends_with(".gd"):
			continue
		if file == "test_utils.gd":
			continue
		found.append("%s/%s" % [TEST_ROOT, file])
	dir.list_dir_end()
	found.sort()
	return found
