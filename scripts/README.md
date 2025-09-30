# Scripts Overview

This folder contains all gameplay scripts for the 2D mini game. The modules below are grouped by their responsibilities and include the most important signal flows and dependencies to help you navigate the code base quickly.

## Core Gameplay Orchestration
- **`Main.gd`** – Root scene controller that wires together the player, UI labels, timers, and spawners. It instantiates the dedicated controllers under `scripts/main/` to manage UI, level lifecycle, game flow, and statistics logging. The scene triggers `generate_new_level()` on start or after wins, connects run-time signals (coin pickups, exit activation, restart/menu buttons), and keeps authoritative counters for coins, keys, and timers while coordinating with `GameState` and `TimerManager`.
- **`GameState.gd`** – Authoritative store for game progression. It tracks the current level, chosen level type, state (playing / won / lost), and tuning flags (obstacle & coin toggles, exit distance, coverage). `Main.gd` reads these values when preparing each level and updates them when the player wins or loses.
- **`TimerManager.gd`** – Central difficulty balancer. After every generation `Main.gd` calls `calculate_level_time()` to compute the allowed time based on difficulty presets, distance to coins and exit, recent player surplus, and level-type heuristics. It also records time left at level completion through `register_level_result()` for future adjustments.

### Main Scene Controllers (`scripts/main/`)
- **`LevelController.gd`** – Generates new levels via `LevelGenerator`, wires coin/key/exit signals, positions the player, and synchronizes UI state such as coins, keys, and exit activation. It also clears previously spawned content when restarting.
- **`UIController.gd`** – Owns HUD updates (timer, coin counts, level progress) and manages dynamic key indicators plus endgame buttons/labels. The controller exposes helpers for showing win/lose states and toggling restart/menu buttons.
- **`GameFlowController.gd`** – Orchestrates transitions between playing, win, and loss states. It controls timer behavior, advances or resets `GameState`, pauses/resumes the player, and invokes level generation through `LevelController`.
- **`StatisticsLogger.gd`** – Creates timestamped log files, records per-level metrics (size, coins, timings, player/exit distance), and notifies `TimerManager` about remaining time for balancing feedback loops.

## Level Generation Pipeline
- **`LevelGenerator.gd`** – Facade for all procedural content. It coordinates `ObstacleSpawner`, `CoinSpawner`, and `ExitSpawner` for standard levels, and delegates to the specialized generators under `level_generators/` for key puzzles and mazes. It keeps references to generated nodes (coins, doors, keys, maze walls), exposes getters that `Main.gd` uses for wiring signals, and remembers spawn overrides or maze path lengths for `TimerManager` calculations.
- **`ObstacleSpawner.gd`** – Produces rectangular static bodies distributed across the play area while respecting player start clearance and inter-obstacle spacing. Obstacles are registered back with `LevelGenerator` to support later cleanup or removal by helper utilities.
- **`CoinSpawner.gd`** – Creates collectible coins using `LevelNodeFactory`, validates placement with `CoinPlacementValidator`, and uses `CoinNavigation` to ensure a traversable path from the player start. Coin counts scale with level size and prior progress, and the results are returned to `LevelGenerator` and then to `Main.gd`.
- **`ExitSpawner.gd`** – Places the level exit in a safe location that respects the requested minimum distance from the player start, avoids obstacles, and falls back to a deterministic corner if no placement succeeds.

### Specialized Generators (`scripts/level_generators/`)
- **`KeyLevelGenerator.gd`** – Builds multi-door arenas that gate progress behind colored keys. It allocates door layouts, spawns barrier segments, uses `LevelNodeFactory` to emit keyed doors and matching collectibles, and clears or repositions conflicting obstacles through `ObstacleUtilities`.
- **`MazeGenerator.gd`** – Generates odd-dimension mazes using `MazeUtils` helpers, populates walls, positions the exit at the farthest carved cell, and optionally scatters coins or keys along the maze path. It also registers maze path length and player spawn overrides back to `LevelGenerator`.
- **`MazeUtils.gd`** – Pure utility for maze grid creation, carving, path reconstruction, key placement, and coordinate conversions between maze cells and world positions.
- **`LevelNodeFactory.gd`** – Centralized constructors for dynamic nodes (doors, barriers, keys, coins, maze walls). Every spawner and generator relies on it to keep visuals, collision, and script binding consistent.
- **`ObstacleUtilities.gd`** – Shared helper owned by `LevelGenerator` that removes existing obstacles inside rectangles or near important points (doors, keys, exits) to guarantee navigability in specialized layouts.

## Collectibles, Doors, and Interactions
- **`Door.gd`** – Static barrier that unlocks after receiving the required key count via `register_key()`. Visual state and collision toggles update automatically and door colors are coordinated with matching keys.
- **`Key.gd`** – Area2D collectible that notifies its paired door (through a cached reference or exported path) and emits a `key_collected` signal consumed by `Main.gd` for UI updates.
- **`coin/` helpers** – `CoinNavigation.gd` builds a grid-based walkability map and checks that coins are reachable, while `CoinPlacementValidator.gd` enforces spacing from the player start, exits, and obstacles.

## Player & Camera
- **`Player.gd`** – Handles movement input, optional speed-boost stacking on coin pickup (invoked by `Main.gd`), ghost trail effects, and gameplay tuning loaded from `config/game.cfg`.
- **`SmoothCamera.gd`** – Camera2D that follows the player with velocity-based look-ahead and lerped movement to keep the action centered.

## UI & Entry Points
- **`MainMenu.gd`** – Front-end menu that sets the difficulty on `TimerManager`, persists the preferred level type via `Engine` metadata, and transitions into the main scene.
- **HUD nodes managed by `UIController.gd`** – Labels, buttons, and key indicators updated through the controller to reflect timer countdowns, coin totals, key status, level progress, and win/lose states.

## State, Timing, and Metrics Flow
1. `Main.gd` asks `GameState` for the current level settings and delegates level creation to `LevelGenerator`.
2. `LevelGenerator` spawns content through its spawners or specialized generators, records metadata (coins, exit, keys, maze length), and hands it back.
3. `Main.gd` connects signals from coins (`body_entered`), keys (`key_collected`), exits, and UI buttons. Coin pickups trigger player speed boosts and update progression counters; once all coins are collected the exit visuals change state.
4. `TimerManager.calculate_level_time()` uses the freshly generated content plus historical surplus data from `register_level_result()` to set `Timer.wait_time`. When a level ends, `Main.gd` logs statistics, updates `GameState`, and informs `TimerManager` so future levels adjust accordingly.

## Logging and Statistics
- **`Logger.gd`** – Lightweight category-based logging utility used across generators and state managers for consistent console output.
- **`StatisticsLogger.gd`** – Initializes timestamped log files under `/logs`, writes per-level metrics (dimensions, coins, completion time, remaining time, player-to-exit distance, completion rate), and forwards remaining-time data to `TimerManager` for balancing tweaks.

### Extending the System
- Add new level archetypes by creating a generator that mirrors the `MazeGenerator`/`KeyLevelGenerator` pattern and exposing it through `GameState.LevelType` and `LevelGenerator.generate_level()`.
- New collectibles or interactables should provide signals similar to `Key.gd` or `CoinSpawner` and let `Main.gd` act as the integration point for UI and state updates.
