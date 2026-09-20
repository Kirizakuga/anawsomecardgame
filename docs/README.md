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

Modules M0 through M3 and initial M4 scaffolding are complete:
- **M0 (Foundation):** Project structure, `CardResource` hierarchy, placeholder cards, `KingdomState` core model.
- **M1 (Core 2-Player Loop):** `TurnManager`, `CardView`, `Kingdom.tscn`, `CombatResolver`, `FloopResolver`, `HumanDecisionSource`, `DummyAIDecisionSource`, and win condition detection.
- **M2 (Deck Builder):** Hero selection UI, affinity filtering, 30-card main deck + 5–8 card landscape sub-deck assembly, and JSON disk save/load persistence.
- **M3 (Bot Archetype AI):** `BotArchetypeResource` profiles (Aggressive, Opportunist, Loyalist, Turtle), `BotAI.decide()` weighted heuristic scoring, and `BotDecisionSource` interface conformance. (Human balance playtesting M3-04 deferred.)
- **M4 (FFA Scaling — in progress):** `MatchBoard.tscn` circular N-Kingdom layout (4–6p, M4-01) and simultaneous action collection across all `DecisionSource`s with waiting overlay (M4-02) are complete.

See `TASKS.md` §2 for per-task details and current progress.

## Intentionally not yet implemented

Per `TDD.md` roadmap (Phases 1–6) and `TASKS.md` (M1–M6), these are deliberately deferred and should not be built ahead of their task/phase:

- Remaining Phase 4 / M4 FFA gameplay mechanics: multi-player resolution + pile-on damage reduction (M4-03), `PactManager` (M4-04), Betrayal action (M4-05), Comeback Essence bonus (M4-06), turn-limit win condition (M4-07).
- Human balance playtesting pass (M3-04) — pending human verification.
- Full card set, Hero passives/Ultimates, card art pass, VFX polish, progression loop — Phase 5 / M5.
- Any networking (`NetworkDecisionSource`, friend-code unlocks) — out of scope until M6, and only with explicit go-ahead (`TASKS.md` §0, rule 9).
