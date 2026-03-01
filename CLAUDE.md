# DRIFT — Loop Drift Racer
AMARIS Development Specification

Engine: Godot 4.4  
Platform: PC  
Renderer: 2D  
Genre: Top-Down Drift Combat Racing  
Studio: AMARIS  
Controller Required: Yes (Xbox required standard)

---

# AMARIS Studio Rules (Non-Negotiable)

- `project_status.json` is the single source of truth for dashboard metrics.
- CLAUDE.md defines architecture, development structure, and execution contract only.
- Completion percentages MUST NOT be duplicated here.
- Controller-first design is mandatory.
- All major systems must be testable.
- Debug flags must default to false in production.
- If checklist item does not apply, mark **N/A** (never delete).

AMARIS dashboard reads JSON only.
CLAUDE.md is human + AI guidance only.

---

# Godot Execution Contract (MANDATORY)

Godot is installed at:

Z:/godot

Claude MUST use:

Z:/godot/godot.exe

Never assume PATH.
Never use user Downloads directory.
Never attempt reinstall.

Headless smoke test:
Z:/godot/godot.exe --path project --headless --quit-after 1

Scene execution:
Z:/godot/godot.exe --path project --scene res://scenes/Main.tscn

If PowerShell:
& "Z:/godot/godot.exe" --path project

If launch fails:
1. Verify path exists.
2. Verify working directory is repo root.
3. Do NOT modify PATH.
4. Do NOT reinstall engine.

---

# Project Overview

2-player top-down drift combat racer.

Core Loop:

MainMenu  
→ Countdown  
→ Racing  
→ RaceComplete  
→ Return to Menu  

Primary Mechanics:
- Drift charge → tiered boost release (hold-to-drift state machine)
- Homing missile combat
- Procedural track generation
- 3-lap checkpoint validation
- Full overhead camera (entire track visible)

---

# Architecture

## Scene Structure (Main.tscn)

Main (race_manager.gd)
├── Track (track.gd — procedural geometry)
├── CarPlayer (P1)
├── CarPlayer2 (P2)
├── LapManager (P1)
├── LapManager2 (P2)
├── OverheadCamera
└── UI (CanvasLayer)

---

## Core Systems

race_manager.gd — Orchestrator
car_controller.gd — Car physics + abilities
track.gd — Procedural road, walls, ramps, checkpoints
lap_manager.gd — Checkpoint validation + lap timing
ui_controller.gd — Dual HUD + pause + complete
missile.gd — Homing projectile logic
item_pickup.gd — Boost system
missile_pickup.gd — Missile grant system
game_constants.gd — Centralized balance constants (class_name GameConstants)
logger.gd — Timestamped logging utility (class_name Logger)
input_remapper.gd — Input remap framework (class_name InputRemapper)
settings_manager.gd — Settings persistence (class_name SettingsManager)
lap_history.gd — Lap time persistence + PB tracking (class_name LapHistory)
audio_manager.gd — Procedural audio singleton (class_name AudioManager, autoload)

---

# State Flow

MENU  
COUNTDOWN  
RACING  
PAUSED  
RACE_COMPLETE  

All state transitions must be deterministic and testable.

---

# Structured Development Checklist
AMARIS STANDARD — 70 Checkpoints

---

## Macro Phase 1 — Foundation (1–10)

- [x] 1. Repo standardized
- [x] 2. Godot project boots clean
- [x] 3. Input mappings validated
- [x] 4. P1 controller verified
- [x] 5. P2 controller verified
- [x] 6. Scene tree structured
- [x] 7. Countdown system stable
- [x] 8. Reset-to-spawn stable
- [x] 9. Version/build identifier visible
- [x] 10. Error logging pattern standardized

---

## Macro Phase 2 — Input & Control Integrity (11–18)

- [x] 11. Acceleration stable
- [x] 12. Steering stable
- **N/A** 13. Drift input separation from jump (jump removed — drift uses all buttons)
- **N/A** 14. Jump cooldown enforced (jump system removed in v0.3.0)
- [x] 15. Input abstraction clean (_action pattern)
- [x] 16. Input remap support
- [x] 17. Controller disconnect handling
- [x] 18. Pause input consistency

---

## Macro Phase 3 — Core Physics & Handling (19–28)

- [x] 19. Traction model stable
- [x] 20. Drift charge build system
- [x] 21. Drift boost release logic
- **N/A** 22. Jump arc tween stability (jump system removed in v0.3.0)
- **N/A** 23. Landing squash animation (jump system removed in v0.3.0)
- **N/A** 24. Airborne physics state separation (jump system removed in v0.3.0)
- [x] 25. Hit stun system stable
- [x] 26. Physics tuning pass
- [x] 27. Balance constants centralized
- [x] 28. Edge-case physics audit

---

## Macro Phase 4 — Combat Systems (29–36)

- [x] 29. Missile pickup logic
- [x] 30. Missile alternating fire positions
- [x] 31. Missile launch state
- [x] 32. Missile homing state
- [x] 33. Missile expiration state
- [x] 34. Spin-out + stun integration
- [x] 35. Combat balance pass
- [x] 36. Combat test scenarios

---

## Macro Phase 5 — Track & World Systems (37–46)

- [x] 37. Procedural track generator complete
- [x] 38. 65-point centerline stable
- [x] 39. Wall collision integrity
- **N/A** 40. Jump ramp sections (jump system removed in v0.3.0)
- [x] 41. Elevation zones
- [x] 42. Checkpoint validation
- [x] 43. 3-lap enforcement
- [x] 44. Track decoration pass
- [x] 45. Alternate track layout
- [x] 46. Track generator refactor pass

---

## Macro Phase 6 — UI & UX (47–54)

- [x] 47. Dual HUD clarity baseline
- [x] 48. Countdown UI
- [x] 49. Pause menu
- [x] 50. Race complete screen
- [x] 51. Input highlight letterbox
- [x] 52. Settings menu baseline
- [x] 53. UX clarity polish pass
- [x] 54. Controller navigation polish

---

## Macro Phase 7 — Progression & Depth (55–60)

- [x] 55. Achievement system integration
- [x] 56. achievements.json hook validation
- [x] 57. Single-player mode
- [x] 58. AI opponent prototype
- [x] 59. Lap history tracking
- [x] 60. Ghost replay prototype

---

## Macro Phase 8 — Audio & Feedback (61–64)

- [x] 61. Engine SFX
- [x] 62. Drift SFX
- [x] 63. Missile SFX
- [x] 64. Music integration

---

## Macro Phase 9 — Testing & Automation (65–68)

- [x] 65. Headless smoke test
- [x] 66. test_results.json contract
- [x] 67. Performance baseline verification
- [x] 68. Stress test (large track load)

---

## Macro Phase 10 — Release & Compliance (69–70)

- [x] 69. Launcher compliance verified
- [x] 70. Packaging/export validated

---

# Debug Flags (Required)

Must exist in code:

- DEBUG_TRACK
- DEBUG_PHYSICS
- DEBUG_CHECKPOINTS
- DEBUG_COMBAT
- DEBUG_UI

All default to false in production.

---

# Automation Contract

After major updates:

1. Update `project_status.json`
   - macroPhase
   - subphaseIndex
   - completionPercent
   - timestamps (ISO8601 minute precision)
   - testStatus

2. Run headless smoke test
3. Validate no console errors
4. Commit
5. Push

AMARIS dashboard depends on this contract.

---

# Current Focus

Current Goal: Phase 10 complete — Release & Compliance
Current Task: All phases complete (1–10)
Work Mode: Development
Next Milestone: Content & polish iteration

---

# Known Gaps

- Export templates not installed (packaging config exists but templates need manual install)

---

# Long-Term Vision

Drift should evolve into:

- Multi-track championship mode
- Online-ready deterministic race logic
- AI difficulty tiers
- Track editor
- Ranked drift scoring mode
- Tournament mode

---

END OF FILE