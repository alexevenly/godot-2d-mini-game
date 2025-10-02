class_name UnitTestSuite
extends RefCounted

var _current_test := ""
var _current_failures: Array[String] = []
var _assertions := 0
var _nodes_to_free: Array[Node] = []
var _objects_to_free: Array[Object] = []

func run() -> Dictionary:
	var summary := {
		"name": get_suite_name(),
		"tests": 0,
		"passed": 0,
		"failed": []
	}
	var methods := get_method_list()
	methods.sort_custom(func(a, b): return a.name < b.name)
	for method in methods:
		if not method.name.begins_with("test_"):
			continue
		summary.tests += 1
		_current_test = method.name
		_current_failures.clear()
		_assertions = 0
		_before_each()
		call(method.name)
		_after_each()
		if _current_failures.is_empty():
			summary.passed += 1
		else:
			summary.failed.append({
				"name": method.name,
				"messages": _current_failures.duplicate()
			})
	return summary

func get_suite_name() -> String:
	return get_script().resource_path

func _before_each() -> void:
	_nodes_to_free.clear()
	_objects_to_free.clear()

func _after_each() -> void:
	for node in _nodes_to_free:
		if is_instance_valid(node):
			node.free()
	_nodes_to_free.clear()
	for obj in _objects_to_free:
		if is_instance_valid(obj):
			obj.free()
	_objects_to_free.clear()

func assert_true(condition: bool, message := "") -> void:
	_assertions += 1
	if not condition:
		_register_failure(message if message != "" else "Expected condition to be true.")

func assert_false(condition: bool, message := "") -> void:
	assert_true(not condition, message if message != "" else "Expected condition to be false.")

func assert_eq(actual, expected, message := "") -> void:
	_assertions += 1
	if actual != expected:
		var detail := "Expected %s but got %s" % [str(expected), str(actual)]
		_register_failure(_compose_message(message, detail))

func assert_near(actual: float, expected: float, tolerance := 0.001, message := "") -> void:
	_assertions += 1
	if abs(actual - expected) > tolerance:
		var detail := "Expected %.5f ± %.5f but got %.5f" % [expected, tolerance, actual]
		_register_failure(_compose_message(message, detail))

func assert_vector_near(actual: Vector2, expected: Vector2, tolerance := 0.001, message := "") -> void:
	_assertions += 1
	if actual.distance_to(expected) > tolerance:
		var detail := "Expected %s near %s (±%.5f)" % [str(expected), str(actual), tolerance]
		_register_failure(_compose_message(message, detail))

func assert_array_contains(collection: Array, value, message := "") -> void:
	_assertions += 1
	if not collection.has(value):
		var detail := "Expected collection to contain %s" % str(value)
		_register_failure(_compose_message(message, detail))

func track_node(node: Node) -> Node:
	_nodes_to_free.append(node)
	return node

func track_object(obj: Object) -> Object:
	_objects_to_free.append(obj)
	return obj

func _compose_message(prefix: String, detail: String) -> String:
	return detail if prefix == "" else "%s: %s" % [prefix, detail]

func _register_failure(message: String) -> void:
	_current_failures.append(message)
