# Achievement System — Integration Contract

## Overview

This document defines how the achievement system integrates with the game.
It is a **contract only** — engine-specific implementation is left to gameplay code.

---

## Data Source

- **File:** `achievements.json` (project root)
- **Format:** JSON, schema defined below
- **Runtime access:** Load at startup, write back on change
- **Godot path:** `res://achievements.json` (use `FileAccess` for read/write)

## Achievement Schema

```json
{
  "id": "string_id",
  "name": "Human Readable Name",
  "description": "Short description of unlock condition",
  "points": 10,
  "icon": "relative/path/to/icon.svg",
  "unlocked": false,
  "unlockedAt": null
}
```

- `id` — unique snake_case identifier, never reused
- `points` — positive integer, immutable after creation
- `unlocked` — boolean, only ever transitions `false → true`
- `unlockedAt` — ISO 8601 timestamp when unlocked, or `null`

---

## Menu Integration

### Status

| Property | Value |
|----------|-------|
| Label | **Achievements** |
| Location | N/A — no dedicated achievements tab in menu yet |
| Access | Achievements unlock via gameplay; toast notifications display in-race |

Menu-based achievement browsing is not yet implemented. Achievements are currently
viewable via `status.html` dashboard and `achievements.json` directly.

---

## Unlock Flow

```
Gameplay event occurs (e.g., lap completed, race finished)
    │
    ▼
Game logic calls AchievementManager.try_unlock("first_lap")
    │
    ▼
AchievementManager checks: already unlocked?
    │
    ├── Yes → no-op, return
    │
    └── No → set unlocked=true, unlockedAt=now
              update meta.totalPointsEarned
              update meta.lastUpdated
              save achievements.json to disk
              │
              ▼
        ui_controller.show_achievement_toast() displays notification
```

---

## Trigger Table

All 8 achievements with actual hooks from `achievements_integration.json`:

| Achievement | ID | Trigger | Hook | Status |
|-------------|-----|---------|------|--------|
| First Lap | `first_lap` | `lap_completed` signal — any player completes a lap | `race_manager._on_achievement_lap_completed()` | implemented |
| Finish Line | `first_race` | Race end — `_on_race_finished()` | `AchievementManager.try_unlock` in `_on_race_finished()` | implemented |
| Drift King | `drift_king` | `drift_released` signal — `drift_charge_time >= 3.0` | `race_manager._on_achievement_drift_check()` | implemented |
| Speed Demon | `speed_demon` | `speed_changed` signal — `speed >= CAR_MAX_SPEED` | `race_manager._on_achievement_speed_check()` | implemented |
| Clean Run | `clean_run` | Race end — winner `car.wall_hit_count == 0` | `AchievementManager.try_unlock` in `_on_race_finished()` | implemented |
| Checkpoint Ace | `checkpoint_ace` | `lap_completed` signal — lap completion requires all checkpoints | `race_manager._on_achievement_lap_completed()` | implemented |
| Personal Best | `personal_best` | Race end — `new_best_lap && prev_best_lap != INF` | `AchievementManager.try_unlock` in `_on_race_finished()` | implemented |
| Track Master | `track_master` | Race end — `LapHistory.get_total_race_count() >= 10` | `AchievementManager.try_unlock` in `_on_race_finished()` | implemented |

**Implementation notes:** AchievementManager is a static class (`class_name AchievementManager`, extends `RefCounted`). It loads/saves `achievements.json` at repo root. Toast notifications are handled by `ui_controller.show_achievement_toast()`. Callbacks are registered in `race_manager._ready()` with stale-callback safety via `clear_callbacks()`.

---

## Overlay Toast Specification

When an achievement unlocks, the game displays a transient notification.

### Visual Layout

```
┌──────────────────────────────────┐
│  [icon]  Achievement Unlocked!   │
│          First Lap               │
│          +10 pts                 │
└──────────────────────────────────┘
```

### Properties

| Property | Value |
|----------|-------|
| Position | Top-center of screen, offset ~80px from top edge |
| Width | 320px (scales on mobile) |
| Background | Semi-transparent dark panel (`Color(0.1, 0.15, 0.2, 0.92)`) |
| Border | 1px accent color (`#00d2ff`) with 8px border radius |
| Icon size | 48x48, left-aligned |
| Title line | "Achievement Unlocked!" — small, dim, uppercase |
| Name line | Achievement name — bold, white |
| Points line | "+{points} pts" — accent color |
| Animation | Slide in from top (0.3s ease-out), hold 3s, fade out (0.5s) |
| Layer | CanvasLayer with high z-index (above all game UI) |
| Queue | If multiple unlock simultaneously, show sequentially (0.5s gap) |
| Audio | Play unlock SFX via AudioManager |

### Godot Implementation Notes

- Toast is rendered by `ui_controller.show_achievement_toast()`
- Connected to AchievementManager unlock flow
- Tween-based animation: `create_tween()` for slide + fade
- Auto-dismiss via `get_tree().create_timer(3.0)`
- Queue system: Array of pending toasts, process one at a time

---

## Safe Update Rules

These rules apply whenever achievements are modified (by developers or tools):

1. **Only append** new achievements — never remove or reorder existing ones
2. **Never reset** `unlocked` from `true` back to `false`
3. **Never clear** `unlockedAt` timestamps
4. **Never change** `id` of an existing achievement
5. **Never change** `points` of an existing achievement (affects earned totals)
6. **Always recalculate** `meta.totalPointsEarned` from actual unlocked achievements
7. **Always update** `meta.totalPointsPossible` when adding new achievements
8. **Always update** `meta.lastUpdated` to current ISO timestamp
9. **Validate** unique `id` values before writing — reject duplicates
