# Loop Drift Racer — CLAUDE.md

## Overview
Top-down 2D drift racing game built in Godot 4.4. Single winding track with hop-drift-boost mechanics, item pickups, checkpoint-based lap validation, and a 3-lap race format. All track geometry, walls, and pickups are built procedurally in code.

## Running
```
# Via launcher
node Z:/Development/launcher/server.js  →  launch from Studio dashboard

# Direct
"C:\Users\nick\Downloads\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64.exe" --path project
```
Godot project root is `project/` (not repo root). Main scene: `res://scenes/MainMenu.tscn`.

## Architecture

### Scene Tree (Main.tscn)
```
Main (Node2D, race_manager.gd)
├── Track (Node2D, track.gd)           — procedural track geometry + walls + pickups
├── CarPlayer (CharacterBody2D, car_controller.gd) — player car at (900, 590) rot 90°
├── LapManager (Node, lap_manager.gd)  — lap/checkpoint/time tracking
├── RaceCamera (Camera2D, camera_controller.gd)    — static full-track view
└── UI (CanvasLayer, ui_controller.gd) — HUD, pause, race complete, debug, controls
```

### Scripts

| Script | Extends | Lines | Purpose |
|--------|---------|-------|---------|
| `race_manager.gd` | Node2D | 35 | Orchestrator — wires car/track/lap/UI, countdown sequence, race finish handler |
| `car_controller.gd` | CharacterBody2D | 419 | Car physics — acceleration, steering (kb/mouse/gamepad), hop-drift-boost, item boost, trails, visuals |
| `track.gd` | Node2D | 323 | Procedural track from 30-point centerline — road, walls, elevation zones, checkpoints, items, jump ramps |
| `lap_manager.gd` | Node | 82 | 3-lap race, 3 checkpoints per lap required, time tracking, best lap |
| `camera_controller.gd` | Camera2D | 13 | Static camera at (1950, 1400), zoom 0.28 |
| `ui_controller.gd` | CanvasLayer | 122 | HUD (lap/time/speed/item), countdown, pause menu, race complete, debug overlay (F1) |
| `checkpoint.gd` | Area2D | 18 | Emits `checkpoint_triggered` or `finish_line_crossed` on car entry |
| `item_pickup.gd` | Area2D | 59 | Diamond pickup — grants boost charge, respawns after 8s |
| `main_menu.gd` | Control | 24 | Title screen — New Run, Settings (placeholder), Exit |
| `input_highlight.gd` | PanelContainer | 65 | Bottom letterbox control hints that glow on input |

### Signal Flow
```
checkpoint.gd  ──checkpoint_triggered──►  lap_manager.register_checkpoint()
checkpoint.gd  ──finish_line_crossed───►  lap_manager.cross_finish_line()
lap_manager    ──race_finished──────────►  race_manager._on_race_finished()
                                           └──► car.stop_race() + ui.show_race_complete()
car_controller ──speed_changed──────────►  (unused, available for UI)
car_controller ──drift_state_changed────►  (unused, available for UI)
```

### Wiring
- `race_manager._ready()` sets `ui.car` and `ui.lap_manager`, then calls `track.connect_to_lap_manager()` which iterates child Area2Ds to connect checkpoint/finish signals
- UI reads car and lap_manager state directly each frame in `_process()`

## Core Mechanics

### Driving
- WASD / mouse (click-to-steer + LMB accelerate + RMB brake) / gamepad
- Max speed 1200, acceleration 900, brake 600, reverse max 300
- Traction-based lateral grip (0.85 normal, 0.03 while drifting)

### Hop-Drift-Boost (main mechanic)
1. **Hold jump** (Space / RT / LT / middle mouse) at speed > 80 → car hops (scale tween + shadow)
2. While held: traction drops to 0.03 (car slides), speed decays at 600/s, charge builds over 2s
3. Car color shifts: blue → orange (0.5) → red (1.0), pulse at full charge
4. **Release** → boost = 225 base + 375/s held, capped at 1050. Fire trail appears
5. While hopping, car ignores collision layer 2 (jump walls in chicane)

### Items
- 5 diamond pickups on track (green, rotating, pulsing glow)
- Collecting sets `car.has_item = true`, using (E / B) activates 2.5s speed boost (+500/s, 1.5x max speed)
- Green trail while boosting, pickups respawn after 8s

### Track Layout
- 30-point clockwise centerline, 220px wide road, 20px thick walls
- Notable sections: long start straight, sweeping Turn 1, chicane (with jump shortcut), hairpin, S-curve
- Elevation zones: S-curve = elevated (lighter road), hairpin = lower (darker road)
- 3 checkpoints at indices [8, 16, 24] (Turn 1, chicane, hairpin exit)
- Finish line at centerline[0]

## Input Map (project.godot)

| Action | Keyboard | Gamepad | Mouse |
|--------|----------|---------|-------|
| `accelerate` | W | A button (0) | LMB |
| `brake` | S | X button (2) | RMB |
| `steer_left` / `steer_right` | A / D | Left stick X | Auto-steer to cursor |
| `jump` | Space | RT/LT (buttons 4,5 + axes 4,5) | Middle click |
| `use_item` | E | B button (1) | — |
| `reset` | R | Y button (3) | — |
| `pause` | Escape | Start (11) | — |
| `debug_toggle` | F1 | — | — |
| `ui_accept` | Enter, Space | A button (0) | — |
| `ui_cancel` | Escape | B button (1) | — |
| `ui_up` / `ui_down` | Arrow keys | D-pad + left stick Y | — |

## Key Patterns

- **All geometry is procedural** — track.gd builds road polygons, walls (StaticBody2D + CollisionPolygon2D), checkpoints, items, and visual elements in `_ready()`
- **No .tscn UI layouts** — UI.tscn is the exception (defined in scene file), but all track/car visuals are code-built
- **Tween-based animation** — hop, boost squash, shadow all use `create_tween()`
- **Input method auto-detection** — `car_controller._unhandled_input()` switches between mouse/keyboard/gamepad based on last input event
- **process_mode = 3** on UI CanvasLayer so it runs during pause

## File Structure
```
drift/
├── CLAUDE.md
├── game.config.json        — launcher metadata (id: "drift")
├── achievements.json       — 8 achievements defined, none integrated in-game
├── refImages/              — design reference screenshots
│   ├── designReference.png — top-down racer inspiration images
│   ├── control.png         — in-game screenshot with controller overlay
│   └── data.png            — spreadsheet data (unrelated)
└── project/                — Godot project root
    ├── project.godot       — engine config, input mappings, GL Compatibility renderer
    ├── icon.svg
    ├── scenes/
    │   ├── MainMenu.tscn   — title screen (run/main_scene)
    │   ├── Main.tscn       — race scene (orchestrator)
    │   ├── CarPlayer.tscn  — car body + collision + polygons
    │   ├── Track.tscn      — empty node with track.gd
    │   └── UI.tscn         — full HUD/pause/complete/debug/letterbox layout
    └── scripts/
        ├── race_manager.gd
        ├── car_controller.gd
        ├── track.gd
        ├── lap_manager.gd
        ├── camera_controller.gd
        ├── ui_controller.gd
        ├── checkpoint.gd
        ├── item_pickup.gd
        ├── main_menu.gd
        └── input_highlight.gd
```

## Completion Checklist

### Done
- [x] Car physics (acceleration, braking, steering, traction)
- [x] Hop-drift-boost mechanic with visual feedback
- [x] Procedural track with walls, road surface, elevation zones
- [x] Checkpoint + lap validation system (3 checkpoints, 3 laps)
- [x] Item pickup system with timed speed boost
- [x] Jump shortcut (chicane walls on layer 2)
- [x] HUD (lap counter, timer, best lap, speed, item indicator)
- [x] Pause menu with resume/restart/main menu
- [x] Race complete screen with total time and best lap
- [x] Debug overlay (F1) — speed, drift state, traction, steer input
- [x] Control letterbox with input-reactive highlights
- [x] Main menu (New Run, Settings placeholder, Exit)
- [x] Full input support: keyboard + mouse + Xbox controller
- [x] Countdown sequence (3-2-1-GO)
- [x] Reset to spawn (R / Y)

### Not Yet Built
- [ ] Achievement system integration (JSON exists, no in-game hooks)
- [ ] AI opponents
- [ ] Sound effects and music
- [ ] Additional tracks
- [ ] Minimap
- [ ] Follow-camera mode (currently static full-track view)
- [ ] Settings menu (volume, controls, camera)
- [ ] Lap time history / ghost replay
- [ ] Track decorations (trees, buildings, grandstands)
- [ ] Test runner
