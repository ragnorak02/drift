# Loop Drift Racer — CLAUDE.md

## Overview
Top-down 2D overhead-view drift racing game built in Godot 4.4. Large winding track (~7200x4800px) with separated drift-boost and jump mechanics, homing missiles, item pickups, checkpoint-based lap validation, and a 3-lap 2-player race format. Single overhead camera shows the entire track. All track geometry, walls, and pickups are built procedurally in code.

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
├── Track (Node2D, track.gd)              — procedural track geometry + walls + pickups
├── CarPlayer (CharacterBody2D, car_controller.gd)  — P1 car, player_id=1, blue
├── CarPlayer2 (CharacterBody2D, car_controller.gd) — P2 car, player_id=2, red
├── LapManager (Node, lap_manager.gd)     — P1 lap/checkpoint/time tracking
├── LapManager2 (Node, lap_manager.gd)    — P2 lap/checkpoint/time tracking
├── ScreenLayout (Control)                — unused (hidden), legacy split-screen container
├── OverheadCamera (Camera2D)             — static camera centered on track, zoom 0.16 (created by race_manager)
└── UI (CanvasLayer, ui_controller.gd)    — dual HUDs, pause, race complete, debug, controls
```

### Scripts

| Script | Extends | Purpose |
|--------|---------|---------|
| `race_manager.gd` | Node2D | Orchestrator — wires 2 cars/track/2 lap managers/UI, overhead camera setup, countdown, missile spawning |
| `car_controller.gd` | CharacterBody2D | Car physics — acceleration, steering, separated drift+boost and jump mechanics, missiles, hit stun, P2 support via _action() |
| `track.gd` | Node2D | Procedural track from 65-point centerline — road, walls, elevation zones, checkpoints, boost+missile items, jump ramps |
| `lap_manager.gd` | Node | 3-lap race, 4 checkpoints per lap required, time tracking, best lap |
| `camera_follow.gd` | Camera2D | Smooth lerp follow camera with velocity lookahead |
| `ui_controller.gd` | CanvasLayer | Dual P1/P2 HUDs, countdown, pause menu, 2P race complete, debug overlay |
| `checkpoint.gd` | Area2D | Emits `checkpoint_triggered(index, car)` or `finish_line_crossed(car)` — signals pass car ref for filtering |
| `item_pickup.gd` | Area2D | Green diamond — grants boost charge, respawns after 8s |
| `missile_pickup.gd` | Area2D | Red diamond — grants 2 missiles, respawns after 10s |
| `missile.gd` | Area2D | Homing missile — LAUNCH (1s straight) → HOMING (4s tracking) → EXPIRED |
| `main_menu.gd` | Control | Title screen — New Run, Settings (placeholder), Exit |
| `input_highlight.gd` | PanelContainer | Bottom letterbox control hints that glow on input |

### Signal Flow
```
checkpoint.gd  ──checkpoint_triggered(idx, car)──►  (filtered in track.gd lambdas)
                                                      └──► lap_manager.register_checkpoint()
checkpoint.gd  ──finish_line_crossed(car)──────────►  (filtered in track.gd lambdas)
                                                      └──► lap_manager.cross_finish_line()
lap_manager    ──race_finished(time, best)──────────► race_manager._on_race_finished()
                                                       └──► cars.stop_race() + ui.show_race_complete_2p()
car_controller ──missile_fired(pos, dir, car)───────► race_manager._on_missile_fired()
                                                       └──► spawns missile.gd, targets other car
```

### Wiring
- `race_manager._ready()` sets ui refs (car, car2, lap_manager, lap_manager2)
- `track.connect_to_lap_manager(lm, car)` called twice — once per player with car filtering lambdas
- `race_manager._setup_overhead_camera()` creates a single Camera2D centered on the track at zoom 0.16

## Core Mechanics

### Driving
- WASD / mouse (click-to-steer + LMB accelerate + RMB brake) / gamepad (P1 device 0)
- P2: Arrow keys / gamepad device 1 (no mouse steering)
- Max speed 1200, acceleration 900, brake 600, reverse max 300

### Drift (Left Shift / LT — separate from jump)
1. **Hold drift button** while turning at speed > 200 → car enters drift slide
2. Traction drops to 0.15, speed decays at 0.97/frame, steering 1.8x multiplier
3. Charge builds while steer angle > threshold (2.5s to full)
4. Car color shifts: blue → orange (0.5) → red (1.0), pulse at full charge
5. **Release** → boost = 300 base + 500/s held, capped at 1400 (min 0.2s hold)
6. Tire mark Line2Ds appear at rear wheel positions during drift
7. Drift cancelled (no boost) if: jumped, too slow, or stopped turning

### Jump (Space / RT — one-shot arc)
1. **Press jump** at speed > 80 → high arc: scale to 3.0x, sprite rises -60px (0.25s ascent)
2. Brief hang at apex (0.05s)
3. Heavy descent with landing squash (1.15, 0.9) then bounce settle (0.35s)
4. While airborne: maintain momentum, no steering, minimal air drag (0.999)
5. Jump walls (layer 2) disabled during airborne, re-enabled on land
6. 0.4s cooldown between jumps
7. Cancels any active drift on jump

### Items
- 6 green diamond boost pickups on track — grants speed boost (E/B to activate, 2.5s duration)
- 5 red diamond missile pickups — grants 2 missiles each, 10s respawn

### Missiles (Q / Right Stick Click)
- Alternates firing from left/right headlight positions
- LAUNCH state (1s): straight forward at 1800 px/s
- HOMING state (4s): smooth turn toward target at 2.5 rad/s, speed 1400 px/s — dodgeable
- EXPIRED: explode animation + queue_free
- On hit: target spins out + velocity * 0.3 + 1.5s stun + red flash
- During stun: heavy drag, skip normal physics, spin deceleration
- Missiles pass through walls (collision layer 0, mask 1)

### Track Layout (~7200x4800px)
- 65-point clockwise centerline, 500px wide road, 35px thick walls
- Features: long start straight, sweeping Turn 1, downhill section, tight hairpin, S-curve complex, 2 jump ramps (ravine + pit), chicane, wide bottom hairpin, uphill tunnel, elevated return, fast final turn
- 4 checkpoints at indices [9, 18, 40, 54]
- 4 elevation zones (2 lower/darker, 2 elevated/lighter)
- 2 jump ramp sections with layer 2 walls at indices [28-29, 52-53]
- Finish line at centerline[0]

## Input Map (project.godot)

### P1 Controls
| Action | Keyboard | Gamepad (device 0) | Mouse |
|--------|----------|-------------------|-------|
| `accelerate` | W | A button (0) | LMB |
| `brake` | S | X button (2) | RMB |
| `steer_left/right` | A / D | Left stick X | Auto-steer to cursor |
| `jump` | Space | RT (button 5 + axis 5) | Middle click |
| `drift` | Left Shift | LT (button 4 + axis 4) | Middle click |
| `use_item` | E | B button (1) | — |
| `fire_missile` | Q | Right stick click (8) | — |
| `reset` | R | Y button (3) | — |
| `pause` | Escape | Button 11 | — |

### P2 Controls
| Action | Keyboard | Gamepad (device 1) |
|--------|----------|--------------------|
| `p2_accelerate` | Up Arrow | A button (0) |
| `p2_brake` | Down Arrow | X button (2) |
| `p2_steer_left/right` | Left / Right Arrow | Left stick X |
| `p2_jump` | Right Shift | RT (button 5 + axis 5) |
| `p2_drift` | Numpad 0 | LT (button 4 + axis 4) |
| `p2_use_item` | Numpad Enter | B button (1) |
| `p2_fire_missile` | Numpad Del | Right stick click (8) |
| `p2_reset` | Numpad + | Y button (3) |

## Key Patterns

- **All geometry is procedural** — track.gd builds road polygons, walls (StaticBody2D + CollisionPolygon2D), checkpoints, items, and visual elements in `_ready()`
- **No .tscn UI layouts for game content** — UI.tscn defined in scene file, but all track/car visuals are code-built
- **Overhead camera** — single static Camera2D at track center (3150, 2175) with zoom 0.16, shows entire track
- **Player abstraction via _action()** — `car_controller._action("jump")` returns `"p2_jump"` for player_id 2
- **Checkpoint filtering via lambdas** — track.gd connects checkpoint signals with closure that checks `body == car`
- **Tween-based animation** — jump arc, drift boost squash, shadow all use `create_tween()`
- **Input method auto-detection** — P1 only: `_unhandled_input()` switches between mouse/keyboard/gamepad
- **process_mode = 3** on UI CanvasLayer so it runs during pause

## File Structure
```
drift/
├── CLAUDE.md
├── game.config.json        — launcher metadata (id: "drift")
├── achievements.json       — 8 achievements defined, none integrated in-game
├── refImages/              — design reference screenshots
└── project/                — Godot project root
    ├── project.godot       — engine config, input mappings (P1 + P2), GL Compatibility renderer
    ├── icon.svg
    ├── scenes/
    │   ├── MainMenu.tscn   — title screen (run/main_scene)
    │   ├── Main.tscn       — race scene: 2 cars, 2 lap managers, overhead camera
    │   ├── CarPlayer.tscn  — car body + collision + polygons
    │   ├── Track.tscn       — empty node with track.gd
    │   └── UI.tscn         — dual P1/P2 HUDs, pause/complete/debug/letterbox
    └── scripts/
        ├── race_manager.gd
        ├── car_controller.gd
        ├── track.gd
        ├── lap_manager.gd
        ├── camera_follow.gd
        ├── ui_controller.gd
        ├── checkpoint.gd
        ├── item_pickup.gd
        ├── missile_pickup.gd
        ├── missile.gd
        ├── main_menu.gd
        └── input_highlight.gd
```

## Completion Checklist

### Done
- [x] Car physics (acceleration, braking, steering, traction)
- [x] Drift mechanic with charge-to-boost (separate from jump)
- [x] Jump mechanic — one-shot high arc with landing weight
- [x] Procedural track with walls, road surface, elevation zones (~7200x4800px)
- [x] Checkpoint + lap validation system (4 checkpoints, 3 laps)
- [x] Boost item pickup system with timed speed boost
- [x] Missile pickup + homing missile combat
- [x] Hit stun system (spin-out + slowdown)
- [x] 2 jump ramp sections with layer 2 walls
- [x] 2-player overhead view (full track visible, single camera)
- [x] Dual P1/P2 HUDs (P1 top, P2 bottom — lap, time, speed, items, missiles)
- [x] Pause menu with resume/restart/main menu
- [x] Race complete screen (shows winner + both players' times)
- [x] Debug overlay (F1) — speed, drift/airborne/stun state, traction, steer input
- [x] Control letterbox with input-reactive highlights (drift + missile added)
- [x] Main menu (New Run, Settings placeholder, Exit)
- [x] Full input support: P1 keyboard+mouse+gamepad, P2 keyboard+gamepad
- [x] Countdown sequence (3-2-1-GO)
- [x] Reset to spawn (R / Y for P1, Numpad+ / Y for P2)
- [x] Tire mark trails during drift

### Not Yet Built
- [ ] Achievement system integration (JSON exists, no in-game hooks)
- [ ] AI opponents (currently 2-player only)
- [ ] Sound effects and music
- [ ] Additional tracks
- [ ] Minimap
- [ ] Settings menu (volume, controls, camera)
- [ ] Lap time history / ghost replay
- [ ] Track decorations (trees, buildings, grandstands)
- [ ] Test runner
- [ ] Single-player mode (race against AI)
