# Mini 2D Game

Mini 2D Game is a top-down arena crawler built with Godot 4. Collect coins, manage your boost speed, and reach the exit before time runs out. The project now supports multiple procedurally generated level styles and records run statistics automatically.

## Requirements

- Godot 4.2 or newer
- Keyboard input (WASD / arrow keys)

## Getting Started

1. Open the project in the Godot editor (`mini_2d_game/project.godot`).
2. Run the project from the editor or export it for your target platform.
3. Use the main menu to choose a difficulty and level type, then press **Start Game**.

## Controls

- `W`, `A`, `S`, `D` or arrow keys  move the cube
- `Esc`  return to the main menu

Collecting a coin grants a temporary speed boost that now decays smoothly back to the base speed. While boosted, the cube leaves a ghost trail whose length reflects the remaining boost strength.

## Level Types

Select the desired level template in the main menu. Available options:

| Level Type | Description |
|------------|-------------|
| **Obstacles + Coins** | Classic mode with random obstacles, coin placement, and an exit. |
| **Keys** | Nested square arenas create multi-layer patrol routes. Each wall can host matching, color-coded doors that block progress until you collect the perimeter keys seeded before them. Obstacles populate each zone while clearing space around doorways and spawn. |
| **Maze** | Generates a procedural maze and places the exit at one of the farthest reachable cells from the spawn point. |
| **Maze + Coins** | Same maze generation as above, with coins scattered along reachable corridors. |
| **Maze + Keys** | Maze layout with a locked door near the exit. Collect the matching keys along the solution path to clear the door and finish. |
| **Maze Complex** | Dense labyrinth that fills the arena with thin wall lines, wide corridors, and multiple branches leading toward a central exit. |
| **Maze Complex + Coins** | Complex maze variant with additional coin placement tuned for its wider passages and branch density. |
| **Random** | Picks one of the above templates (including Maze + Keys and the complex variants) each time a new level is generated. |

When you restart a failed level, the same template is reused. Advancing to the next level rerolls a template if **Random** is selected.

## Gameplay Systems

### Speed Boost & Ghost Trail

The boost granted by coins is now configurable and fades out gradually instead of ending abruptly. A subtle ghost trail is spawned while boosted; its lifetime and spawn cadence scale with the current boost strength.

Edit `config/game.cfg` to tweak these values:

- `speed_boost_multiplier`  bonus applied per coin (default `1.5`).
- `speed_boost_decay_time`  seconds for a single coin's boost to fade.
- `speed_boost_max_stacks`  how many boosts can stack before clamping.
- `ghost_base_lifetime` / `ghost_extra_lifetime`  minimum and extra trail lifetime.
- `ghost_spawn_interval` / `ghost_spawn_interval_min`  spawn cadence range.

### Coin Placement Safety

Coins spawned by the standard generator are validated with a pathfinder to guarantee a traversable route from the spawn location to every coin. Obstacles are inflated by 5% over the player's width during validation to ensure a comfortable corridor.

### Keys & Doors

Key levels place doors across the arena. Locked doors require their assigned keys; each key is guaranteed to be reachable before the door it unlocks. Doors and keys now share matching colors to signal which collectibles unlock which barrier. Each door tracks how many keys remain, clears nearby obstacles for a smooth approach, and illuminates (disabling its collision) once its keys are collected to reveal the path toward the exit.

The dedicated **KEYS** mode now builds concentric square rings with consistent wall thickness so traversal requires walking the perimeter of each layer. Door planners can attach a second barrier to the same wall when there is enough space, and the door spawner keeps keys pinned to the surrounding walls while respecting obstacle spacing. Maze-based key modes continue to scatter doors along the solution path and now always spawn the matching keys so every barrier blocks progress until its key is collected.

Automated tests cover the door planner's spacing and obstacle avoidance guarantees along with the HUD's dynamic key and door indicators so future tweaks can detect regressions quickly (`tests/unit/test_level_generation_scripts.gd`, `tests/unit/test_main_systems.gd`).

### Maze Generation

Maze levels carve a depth-first search maze over the scaled play area, centre the grid, and ensure the player spawns inside a walkable cell. The exit is positioned on one of the farthest cells from that spawn. In the `Maze + Coins` variant, coins are distributed across distant open cells while avoiding the spawn and exit.

The new `Maze + Keys` mode keeps the same procedural layout but locks the final stretch behind a color-coded door. Keys are seeded along the optimal route so that unlocking the door requires exploring the maze rather than hugging the start area.

Complex maze modes generate a tighter grid with thinner walls and broader hallways to fill the entire arena. Their generator can optionally seed coins while maintaining clear sightlines to the exit, and the exit itself is scaled up to match the heightened density.

### Statistics Logging

Each completed or failed level appends a CSV row to `logs/statistics_*.log` capturing size, coin totals, timing, and completion metrics, making it easy to analyze difficulty tweaks.

### Adaptive Timer Balancing

Timer calculations have been retuned for every difficulty and level archetype. The system now blends route length, collectible detours, maze path data, and recent player surplus time to set a fair but tightening countdown as you advance.

## Project Structure Highlights

- `scripts/Main.gd`  core game loop, restart handling, and level orchestration.
- `scripts/LevelGenerator.gd`  dispatches generation for standard, key, and maze templates.
- `scripts/CoinSpawner.gd`  coin placement with path validation.
- `scripts/Player.gd`  movement, boost decay, and ghost trail logic.
- `scripts/GameState.gd`  level progression, difficulty, and level-type selection.
- `scripts/TimerManager.gd`  adaptive timer calculations.

## Contributing

Feel free to extend the project with new level templates or mechanics. When adding new generation styles, plug them into `LevelGenerator.gd`, update `GameState.LevelType`, and register them in the main menu selector.

Enjoy exploring the new level types and fine-tuning the boost system!
