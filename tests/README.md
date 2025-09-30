# Automated Test Suite

This project ships a lightweight GDScript test harness so core gameplay systems can be validated without opening the Godot editor.

## Running the tests

1. Ensure a Godot 4.2+ command line executable is available locally.
   - Preferred location: place the headless binary at `bin/godot` (added to `.gitignore`).
   - Alternative: set the `GODOT_BIN` environment variable to the executable path.
2. From the repository root run:

   ```bash
   tests/run_tests.sh
   ```

   The script launches Godot in headless mode and executes `res://tests/test_runner.gd`, which discovers every `res://tests/unit/test_*.gd` file.

### Offline environment workaround

Because the execution environment does not allow internet access, the repository includes the `tests/run_tests.sh` helper and expects a vendored Godot binary:

- Download the official **Godot 4.2 (or newer) headless** build on a machine with internet access.
- Copy the executable into the repository at `bin/godot` (or expose it via `GODOT_BIN`). Make sure it is executable (`chmod +x bin/godot`).
- Commit the binary if you want the CI environment to run the tests without network access, or keep it local if the binary must not be checked in.

Once the binary is present, the test runner can be invoked in offline environments without further setup.
