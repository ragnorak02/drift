# Loop Drift Racer — Game Direction

## Game Identity
- **Title:** Loop Drift Racer
- **Engine:** Godot 4.4
- **Genre:** Racing
- **Setting:** Top-down 2D split-screen drift racing on a large procedural track
- **Phase:** Development
- **Target:** Local multiplayer arcade racer with drift-boost, jumps, and missile combat

## Core Pillars
1. **Satisfying Drift-to-Boost** — Hold drift while turning to charge, release for speed burst. Risk/reward: longer drift = bigger boost but harder control.
2. **Accessible 2-Player Split-Screen** — Drop-in local multiplayer with keyboard+gamepad support. No online needed.
3. **Arcade Combat Racing** — Homing missiles add a Mario Kart-style combat layer on top of pure racing skill.
4. **Procedural Track Variety** — Track geometry built in code, enabling future track generation and variety.

## Current State (v0.1.0)
- Full 2-player split-screen racing with drift, jump, boost pickups, and missiles
- 1 track (~7200x4800px), 3-lap races, checkpoint validation
- Dual HUDs, pause menu, race complete screen, countdown
- Controller support complete (P1 keyboard+mouse+gamepad, P2 keyboard+gamepad)
- No audio, no AI opponents, no save system

## Phase Plan

### Phase 1 — Polish & Single Player (Current Target)
- [ ] AI opponents (at least 1 bot for single-player mode)
- [ ] Sound effects (engine, drift, boost, missile, hit, countdown)
- [ ] Background music (menu + race)
- [ ] Settings menu (volume, controls display)
- [ ] Track decorations (trees, barriers, grandstands)

### Phase 2 — Content & Progression
- [ ] Achievement system integration (8 achievements already defined in JSON)
- [ ] Minimap overlay
- [ ] Lap time history / personal best tracking
- [ ] Save system (best times, achievements, settings)
- [ ] Additional track(s)

### Phase 3 — Vertical Slice
- [ ] Ghost replay system
- [ ] First graphics pass (proper sprites, particle effects)
- [ ] UI polish (animated menus, transitions)
- [ ] Test runner integration
- [ ] Performance profiling and optimization

## Design Notes
- Keep the arcade feel — no simulation physics, no tire temperature, no fuel
- Drift mechanic is the star: charge visualization (color shift) and boost payoff should feel great
- Missiles are meant to be dodgeable — homing is smooth-turn, not instant-lock
- Jump is a commitment (no steering while airborne) — use for shortcuts and ramp sections only
- Track should feel like a complete circuit with varied sections (straights, hairpins, S-curves, elevation changes)

## Next Step
Implement AI opponents for single-player racing.
