# Loop Drift Racer — Test Plan

## Test Strategy
Automated headless tests via GDScript test runner. Tests validate core mechanics, race logic, and input handling without requiring visual rendering.

## Test Runner
- **Location:** `tests/run-tests.gd`
- **Command:** `godot --headless --script tests/run-tests.gd`
- **Output:** JSON to stdout → `tests/test_results.json`

## Test Categories

### 1. Car Physics
- [ ] Acceleration increases speed up to max (1200)
- [ ] Braking reduces speed; reverse caps at 300
- [ ] Steering changes car rotation proportional to speed
- [ ] Traction recovery after drift release
- [ ] Reset teleports car to spawn position

### 2. Drift Mechanic
- [ ] Drift activates when holding drift button + turning at speed > 200
- [ ] Drift charge accumulates over time (0 to 1.0 over 2.5s)
- [ ] Releasing drift grants boost proportional to charge (min 0.2s hold)
- [ ] Drift cancels with no boost if: jumped, too slow, stopped turning
- [ ] Tire marks appear during active drift

### 3. Jump Mechanic
- [ ] Jump triggers at speed > 80
- [ ] Car is airborne during jump arc (no steering, no wall collision on layer 2)
- [ ] Jump cooldown prevents rapid re-jumping (0.4s)
- [ ] Jump cancels active drift
- [ ] Landing applies squash animation

### 4. Items & Missiles
- [ ] Boost pickup grants item; activating gives 2.5s speed boost
- [ ] Boost pickups respawn after 8s
- [ ] Missile pickup grants 2 missiles
- [ ] Missile pickup respawns after 10s
- [ ] Missile transitions: LAUNCH (1s) → HOMING (4s) → EXPIRED
- [ ] Missile hit applies stun (1.5s) + spin-out + velocity reduction

### 5. Lap & Checkpoint System
- [ ] Checkpoints register in order (4 per lap)
- [ ] Finish line only counts if all checkpoints hit
- [ ] 3 laps completes the race
- [ ] Race time and best lap tracked correctly
- [ ] Shortcutting (skipping checkpoints) does not count lap

### 6. Race Manager
- [ ] Countdown sequence runs before race starts (3-2-1-GO)
- [ ] Cars cannot move during countdown
- [ ] Race ends when first player completes 3 laps
- [ ] Race complete screen shows winner + both times
- [ ] Pause menu pauses game and resumes correctly

### 7. Split-Screen
- [ ] Both SubViewports render correctly
- [ ] Each camera follows its respective car
- [ ] P1 and P2 HUDs show independent data

### 8. Input
- [ ] P1 actions map to WASD + mouse + gamepad device 0
- [ ] P2 actions map to arrow keys + gamepad device 1
- [ ] _action() correctly prefixes "p2_" for player_id 2
- [ ] Input method detection switches P1 HUD hints

## Acceptance Criteria
- All critical path tests pass (car physics, drift, lap system)
- No crashes in headless mode
- JSON output matches contract in `tests/test_results.json`
