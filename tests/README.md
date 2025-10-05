# Automated Test Suite

This project ships a lightweight GDScript test harness so core gameplay systems can be validated without opening the Godot editor.

## Running the tests

1. Ensure a Godot 4.2+ command line executable is available locally or allow the helper script to download it.
2. From the repository root run:

```
	tests/run_tests.sh
```

The script launches Godot in headless mode and executes `res://tests/test_runner.gd`, which discovers every `res://tests/unit/test_*.gd` file.

### Automatic Godot download

If `bin/godot` is missing and `GODOT_BIN` is not set, the helper downloads the official Godot 4.2.2 Linux build from the public GitHub release mirror and installs it to `bin/godot` before executing the tests.

Set `GODOT_BIN` to an existing executable if you prefer to use a previously installed binary or a different Godot version.

### Offline environment workaround

If the execution environment does not have internet access, download the official **Godot 4.2 (or newer)** headless build beforehand on a machine with connectivity and place it at `bin/godot` (or expose it via `GODOT_BIN`). Make sure it is executable (`chmod +x bin/godot`).

Once the binary is present, the test runner can be invoked in offline environments without further setup.

## Test coverage highlights

- `tests/unit/test_key_mode_generation.gd` exercises the nested key-ring planner, door spawner, and maze-with-keys pathing to ensure every barrier is blocking until its matching perimeter keys are collected.
- `tests/unit/test_utils.gd` now includes typed helpers such as `assert_between`, `assert_instanceof`, and `assert_array_size` so suites can express intent clearly while keeping indentation consistent with tabs.
