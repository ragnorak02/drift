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
- Drift charge → boost release
- Jump arc system
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
- [ ] 9. Version/build identifier visible
- [ ] 10. Error logging pattern standardized

---

## Macro Phase 2 — Input & Control Integrity (11–18)

- [x] 11. Acceleration stable
- [x] 12. Steering stable
- [x] 13. Drift input separation from jump
- [x] 14. Jump cooldown enforced
- [x] 15. Input abstraction clean (_action pattern)
- [ ] 16. Input remap support
- [ ] 17. Controller disconnect handling
- [x] 18. Pause input consistency

---

## Macro Phase 3 — Core Physics & Handling (19–28)

- [x] 19. Traction model stable
- [x] 20. Drift charge build system
- [x] 21. Drift boost release logic
- [x] 22. Jump arc tween stability
- [x] 23. Landing squash animation
- [x] 24. Airborne physics state separation
- [x] 25. Hit stun system stable
- [ ] 26. Physics tuning pass
- [ ] 27. Balance constants centralized
- [ ] 28. Edge-case physics audit

---

## Macro Phase 4 — Combat Systems (29–36)

- [x] 29. Missile pickup logic
- [x] 30. Missile alternating fire positions
- [x] 31. Missile launch state
- [x] 32. Missile homing state
- [x] 33. Missile expiration state
- [x] 34. Spin-out + stun integration
- [ ] 35. Combat balance pass
- [ ] 36. Combat test scenarios

---

## Macro Phase 5 — Track & World Systems (37–46)

- [x] 37. Procedural track generator complete
- [x] 38. 65-point centerline stable
- [x] 39. Wall collision integrity
- [x] 40. Jump ramp sections
- [x] 41. Elevation zones
- [x] 42. Checkpoint validation
- [x] 43. 3-lap enforcement
- [ ] 44. Track decoration pass
- [ ] 45. Alternate track layout
- [ ] 46. Track generator refactor pass

---

## Macro Phase 6 — UI & UX (47–54)

- [x] 47. Dual HUD clarity baseline
- [x] 48. Countdown UI
- [x] 49. Pause menu
- [x] 50. Race complete screen
- [x] 51. Input highlight letterbox
- [ ] 52. Settings menu baseline
- [ ] 53. UX clarity polish pass
- [ ] 54. Controller navigation polish

---

## Macro Phase 7 — Progression & Depth (55–60)

- [ ] 55. Achievement system integration
- [ ] 56. achievements.json hook validation
- [ ] 57. Single-player mode
- [ ] 58. AI opponent prototype
- [ ] 59. Lap history tracking
- [ ] 60. Ghost replay prototype

---

## Macro Phase 8 — Audio & Feedback (61–64)

- [ ] 61. Engine SFX
- [ ] 62. Drift SFX
- [ ] 63. Missile SFX
- [ ] 64. Music integration

---

## Macro Phase 9 — Testing & Automation (65–68)

- [ ] 65. Headless smoke test
- [ ] 66. test_results.json contract
- [ ] 67. Performance baseline verification
- [ ] 68. Stress test (large track load)

---

## Macro Phase 10 — Release & Compliance (69–70)

- [ ] 69. Launcher compliance verified
- [ ] 70. Packaging/export validated

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

Current Goal: Polish & stabilize core loop
Current Task: Remaining Phase 1-6 gaps (version ID, error logging, input remap, physics tuning, combat balance, settings menu, UX polish)
Work Mode: Development
Next Milestone: All Phase 1–6 checkpoints complete

---

# Known Gaps

- No AI opponents
- No audio system
- No achievement hooks
- No settings persistence
- No single-player mode
- No automated test runner

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