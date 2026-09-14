# [Working Title] — Card Battler Project

Godot 4.x (GDScript), 2D fantasy card battler skeleton. Local human-vs-bot now; FFA (4–6p) with Pacts/Betrayal and online play are planned in later phases.

## Docs

- `GDD.md` — game design: rules, card types, the Floop mechanic, FFA/Pact/Betrayal systems, bot archetypes.
- `TDD.md` — technical architecture: autoloads, Resource-based card data, the `DecisionSource` abstraction, build roadmap.
- `TASKS.md` — task breakdown (`M{module}-{task}`) with specs, acceptance criteria, dependencies, status.
- `AGENTS.md` — rules for any contributor (human or AI) working in this repo.
- `architecture.md` — quick-reference summary of the engine architecture.
- `development.md` — how to open, run, and verify the project locally.
- `data.md` — how card/hero/bot data is modeled and where it lives.

Read `GDD.md` and `TDD.md` before touching code; read `AGENTS.md` before touching anything as an AI collaborator.

## Requirements

- Godot 4.2+ (avoid 3.x — different Node/Resource APIs)
- Git

## Quick start

1. Clone the repo.
2. Open `project.godot` in Godot 4.2+.
3. Run `Main.tscn` (mode select) via F5, or open the specific test scene for the task you're working on.

## Status

This is a pre-Phase-0/early build. Nothing in `TASKS.md` is marked `Done` yet — see `TASKS.md` §2 for current status per task.

## Intentionally not yet implemented

Per `TDD.md`'s roadmap (Phases 1–6) and `TASKS.md` (M1–M6), these are deliberately deferred and should not be built ahead of their task/phase:

- Real bot archetype AI — Phase 1 uses a dummy random-move AI only (M1-07); real scoring is Phase 3 / M3.
- 4–6 player FFA, Pacts, Betrayal, comeback bonus — Phase 4 / M4.
- Full card set, Hero passives/Ultimates, art, VFX polish, progression loop — Phase 5 / M5.
- Any networking (`NetworkDecisionSource`, friend-code unlocks) — out of scope until M6, and only with explicit go-ahead (`TASKS.md` §0, rule 9).
