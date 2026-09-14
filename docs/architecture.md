# Architecture

Single Godot 4.x project (GDScript), 2D. Logic is split into two layers per `TDD.md` §2–3:

- `scripts/core/` — engine-agnostic game-state logic (turn resolution, combat math, Pact/Betrayal rules). No `Node`/scene dependencies, so it's testable with no scene tree running.
- `scenes/` + `scripts/ui/` — pure views over that state. A scene (e.g. `Kingdom.tscn`) renders a `KingdomState` object; it never decides outcomes itself.

Autoloads (singletons) own cross-cutting concerns:

| Autoload | Responsibility |
|---|---|
| `GameManager` | Match setup, player count, phase, win/loss detection |
| `TurnManager` | Turn/round counter, phase sequencing |
| `ResolutionEngine` | Collects submitted actions, resolves them simultaneously and deterministically |
| `CardDatabase` | Loads all `CardResource` files at startup, lookup by ID |
| `BotAI` | Archetype-weighted scoring → chosen actions for a bot |
| `PactManager` | Pact propose/accept/break + Betrayal logic |

Two rules protect this architecture from drifting:

- **`DecisionSource` is the only seam between game logic and "who's playing."** `ResolutionEngine` talks to `HumanDecisionSource` / `BotDecisionSource` interchangeably and never checks which one it has. This is what lets a future `NetworkDecisionSource` (Phase 6) slot in without touching resolution logic — nothing in `core/` should special-case bot vs. human.
- **Card/hero/bot data is not duplicated in code.** `.tres` Resources (`CardResource` and subclasses, `HeroResource`, `BotArchetype`) are the source of truth; `CardDatabase` loads them, and nothing hardcodes a parallel stat table. See `data.md`.

Resolution order for simultaneous actions is fixed (`TDD.md` §3.6): Landscapes → Spells → Creatures → Pact changes → Betrayals. This ordering is deliberate and is what makes multiplayer resolution deterministic — it shouldn't change casually.
