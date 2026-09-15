# Task Breakdown & Collaboration Guide — [Working Title]

**Purpose:** This document breaks the project into discrete, ID-tagged tasks with specs and acceptance criteria, so any contributor — human or AI — can pick up a task independently without needing full prior context.

**Read first, always:** `GDD.md` (game design/rules) and `TDD.md` (technical architecture). This document assumes both as ground truth. If a task here conflicts with those docs, the conflict itself should be flagged (see §0) rather than silently resolved.

---

## 0. Guidance for AI Collaborators

If you are an AI picking up work on this project, follow these rules:

1. **Load context first.** Read `GDD.md` and `TDD.md` in full before writing code. Do not infer game rules or architecture from a task description alone — task specs assume that context.
2. **Work one task at a time.** Each task below has an ID (e.g. `M1-03`). State which task ID you're working on before starting, and don't silently expand scope into another task's territory.
3. **Respect the architecture boundaries in TDD.md §3**, especially:
   - Keep `scripts/core/` free of scene/Node dependencies.
   - Never have `ResolutionEngine` or game logic branch on "is this a bot or human" — always go through `DecisionSource`.
4. **Don't invent new systems not in GDD.md/TDD.md.** If a task seems to need a new mechanic or data field not covered by those docs, stop and flag it under "Open Questions Raised" (§5) rather than deciding unilaterally.
5. **Definition of Done = Acceptance Criteria, not "it runs."** Each task lists specific checks. All must pass before marking a task complete.
6. **Update task status inline** in this doc when you finish a task: change `Status: Not Started` → `Status: Done (by [agent/person], [date])`. If blocked, use `Status: Blocked — [reason]`.
7. **Naming conventions:** `snake_case` for files/variables, `PascalCase` for class/scene names, matching existing Godot conventions already used in `TDD.md` §2–3.
8. **If a dependency task isn't done yet**, don't stub around it silently — note it in your task's status and either wait or complete the dependency first if trivial.
9. **No networking work** unless explicitly working on an M6 task — earlier phases assume local-only (human + bots).

---

## 1. Task ID Scheme

Format: `M{module}-{task number}`, e.g. `M2-04`.

| Module | Name | Maps to TDD.md Phase |
|---|---|---|
| M0 | Foundation | Phase 0 |
| M1 | Core Loop (2-Player) | Phase 1 |
| M2 | Deck Builder | Phase 2 |
| M3 | Bot AI | Phase 3 |
| M4 | FFA Scaling (4–6p) | Phase 4 |
| M5 | Content & Polish | Phase 5 |
| M6 | Networking / Later | Phase 6 |

---

## 2. Module Tasks

### M0 — Foundation

**M0-01 — Project & repo setup**
- Spec: Create Godot 4.x project matching folder structure in `TDD.md` §2. Initialize Git repo with `.gitattributes` treating `.tscn`/`.tres` as text.
- Deliverables: Empty but structured project committed to repo. Do not add gameplay, data-model, AI, autoload, or UI implementation code; those belong to their own task IDs.
- Checkup: Folder tree matches `TDD.md` §2 exactly. `godot --headless --version` confirms 4.2+.
- Dependencies: None.
- Status: Done — agent, 2026-09-14

**M0-02 — `CardResource` base class + subclasses**
- Spec: Implement `CardResource`, `CreatureResource`, `SpellResource`, `LandscapeResource`, `HeroResource` per `TDD.md` §3.2. All exported fields from the doc must be present with correct types.
- Deliverables: `.gd` scripts in `scripts/data/`.
- Checkup: Can create a `.tres` instance of each subclass in the Godot editor Inspector without script errors. A `CreatureResource` correctly shows `attack`/`defense`/`affinity` fields in the Inspector.
- Dependencies: M0-01.
- Status: Done — agent, 2026-09-15

**M0-03 — Placeholder card set (10 cards)**
- Spec: Create 10 `.tres` card instances (mix of Creature/Spell/Landscape) using M0-02 classes, for use in early testing. Stats/costs can be arbitrary but internally consistent (e.g. cost roughly scales with power).
- Deliverables: `.tres` files in `data/cards/`.
- Checkup: `CardDatabase` (once built in M1) can load and list all 10 without error.
- Dependencies: M0-02.
- Status: Blocked — CardDatabase is required by this task's Checkup but has no implementation task; see §5. Generated-card loading passed interim verification on 2026-09-15.

**M0-04 — `KingdomState` plain object class**
- Spec: Implement per `TDD.md` §3.3 — Life total, lanes array, active landscapes, hand, deck, Essence pool. Pure GDScript object (`RefCounted` or similar), no scene/Node dependency.
- Deliverables: `scripts/core/kingdom_state.gd`.
- Checkup: Can instantiate `KingdomState`, add/remove a card from hand, modify Life, in a standalone test script with no scene tree running.
- Dependencies: M0-02.
- Status: Done — agent, 2026-09-15

---

### M1 — Core Loop (2-Player Only)

**M1-01 — `TurnManager` phase sequencing**
- Spec: Autoload implementing Essence → Play/Floop → Battle → Cleanup sequencing per `TDD.md` §3.1 and `GDD.md` §4. Must emit signals on phase change (e.g. `phase_changed(new_phase)`).
- Checkup: A test scene can subscribe to `phase_changed` and log all 4 phases occurring in order across 3 full turns.
- Dependencies: M0-04.
- Status: Not Started

**M1-02 — `CardView.tscn` + drag-to-play**
- Spec: Visual card scene showing art, cost, stats. Supports drag-from-hand-to-lane interaction. Must support a "floop" flip animation trigger (visual only at this stage — logic comes in M1-05).
- Checkup: Dragging a card from hand to a valid lane visually moves it and removes it from hand. Invalid drop (e.g. insufficient Essence) snaps back.
- Dependencies: M0-02, M0-03.
- Status: Not Started

**M1-03 — `Kingdom.tscn` (lanes + life display)**
- Spec: View over a single `KingdomState`. Renders lanes (per `GDD.md` §5, 2-player facing-lanes layout), Life total, and hosts `Hand.tscn` for the human player's Kingdom only.
- Checkup: Given a `KingdomState` with 2 creatures in lanes and Life = 15, the scene visually reflects both without manual wiring per-instance.
- Dependencies: M0-04, M1-02.
- Status: Not Started

**M1-04 — Combat resolution (creature-vs-creature, direct damage)**
- Spec: Implement combat math for 2-player facing lanes: creature vs opposing creature in same lane, and unblocked lanes dealing damage to enemy Kingdom Life directly. Lives in `scripts/core/`.
- Checkup: Unit-style test scene: two `KingdomState`s with known creature stats produce the exact expected Life totals and creature survival/death after one Battle phase.
- Dependencies: M1-01, M0-04.
- Status: Not Started

**M1-05 — Floop interaction logic**
- Spec: Implement flipping a card (in hand or in play, per `GDD.md` §3) to trigger its secondary effect at defined Essence/tempo cost. At minimum, wire this for 2–3 of the M0-03 placeholder cards.
- Checkup: Flooping a test card produces its documented secondary effect and correctly deducts cost; flooding a card with no floop effect is a no-op/disabled in UI.
- Dependencies: M1-02, M0-03.
- Status: Not Started

**M1-06 — `HumanDecisionSource`**
- Spec: Implement per `TDD.md` §3.4. Must package UI selections (cards played, floops, targets) into a `RoundActions` object matching what `ResolutionEngine` expects (even if `ResolutionEngine` itself is simplified for 2p at this stage).
- Checkup: Manually playing a full turn through the UI produces a `RoundActions` object with correct contents (verify via debug print).
- Dependencies: M1-02, M1-03.
- Status: Not Started

**M1-07 — Dummy AI opponent (random legal move)**
- Spec: Temporary stand-in for `BotDecisionSource` (real archetype AI is M3) — picks a random legal action each phase. Exists only so 2-player games are playable end-to-end before real AI exists.
- Checkup: A full match can be played human-vs-dummy-AI to a win/loss without crashes.
- Dependencies: M1-06, M1-04.
- Status: Not Started

**M1-08 — Win condition check**
- Spec: Detect Life ≤ 0, end match, declare winner. Per `GDD.md` §6 (2-player subset — full FFA win conditions are M4).
- Checkup: Reducing a `KingdomState`'s Life to 0 or below during a test triggers match-end state correctly, exactly once (no double-trigger).
- Dependencies: M1-04.
- Status: Not Started

---

### M2 — Deck Builder

**M2-01 — Hero selection screen**
- Spec: UI listing available `HeroResource`s with portrait, name, passive trait description. Selecting one filters the card pool by affinity per `GDD.md` §7.
- Checkup: Selecting each of the placeholder Heroes correctly filters to only affinity-matching cards from `CardDatabase`.
- Dependencies: M0-02, M0-03 (or expanded card set).
- Status: Not Started

**M2-02 — Deck assembly UI**
- Spec: Grid of eligible cards, add/remove to a 30-card deck list, enforce max-copies-per-card limit (default 3) and separate Landscape sub-deck (5–8) per `GDD.md` §7.
- Checkup: Cannot exceed 30 main-deck cards, cannot add a 4th copy of any card, Landscape sub-deck enforced separately from main deck count.
- Dependencies: M2-01.
- Status: Not Started

**M2-03 — Deck save/load**
- Spec: Persist a built deck (Hero + card list + landscape list) to disk as JSON and reload it for the single local profile. Save IDs and primitive values; resolve card data through `CardDatabase` when loading.
- Checkup: Save a deck, restart the game/scene, load it back with identical contents.
- Dependencies: M2-02.
- Status: Not Started

---

### M3 — Bot AI

**M3-01 — `BotArchetype` Resource + weight tables**
- Spec: Resource class holding named weight fields per `TDD.md` §3.5 (e.g. `aggression_weight`, `pact_loyalty_weight`, `betrayal_opportunism_weight`). Create 4 `.tres` instances: Aggressive, Opportunist, Loyalist, Turtle, with distinct weight values reflecting `GDD.md` §10 descriptions.
- Checkup: Each archetype `.tres` has clearly differentiated weights (e.g. Aggressive has high attack-weight, near-zero pact-weight).
- Dependencies: M0-01.
- Status: Not Started

**M3-02 — `BotAI.decide()` scoring implementation**
- Spec: Given a `KingdomState`, `MatchContext`, and `BotArchetype`, generate candidate actions and score via the weighted-sum formula in `TDD.md` §3.5, return the highest-scoring `RoundActions` (with minor randomness to avoid total predictability).
- Checkup: Given a fixed board state, an Aggressive archetype and a Turtle archetype produce visibly different chosen actions in test logs.
- Dependencies: M3-01, M0-04.
- Status: Not Started

**M3-03 — `BotDecisionSource`**
- Spec: Wraps `BotAI.decide()` to conform to the `DecisionSource` interface from `TDD.md` §3.4, replacing the M1-07 dummy AI.
- Checkup: Swapping `BotDecisionSource` in for the dummy AI in a 2-player match requires zero changes to `ResolutionEngine` or `TurnManager`.
- Dependencies: M3-02, M1-06 (interface parity).
- Status: Not Started

**M3-04 — Balance playtesting pass (2-player vs each archetype)**
- Spec: Not code — structured playtesting. Play multiple matches against each of the 4 archetypes, log outcomes/impressions, adjust weights in M3-01 as needed.
- Checkup: A short written summary of at least 5 matches per archetype with adjustments made and rationale.
- Dependencies: M3-03.
- Status: Not Started

---

### M4 — FFA Scaling (4–6 Players)

**M4-01 — `MatchBoard.tscn` circular N-Kingdom layout**
- Spec: Instantiate 4–6 `Kingdom.tscn` instances arranged per `GDD.md` §5 ("Kingdoms in a circle"). Layout must scale cleanly for 4, 5, and 6 players.
- Checkup: Visual test with 4, then 6, dummy Kingdoms shows no overlap/clipping at target resolution.
- Dependencies: M1-03.
- Status: Not Started

**M4-02 — Simultaneous action submission (all `DecisionSource`s)**
- Spec: `TurnManager`/`ResolutionEngine` must collect `RoundActions` from all N players' `DecisionSource`s before resolving, per `TDD.md` §3.6. Human UI must clearly show "waiting for others" state.
- Checkup: In a 4-bot + 1-human test match, resolution does not proceed until all 5 `RoundActions` are collected, regardless of order of arrival.
- Dependencies: M1-06, M3-03, M4-01.
- Status: Not Started

**M4-03 — `ResolutionEngine` deterministic multi-player resolution + pile-on reduction**
- Spec: Fixed resolution order (Landscapes → Spells → Creatures → Pact changes → Betrayals per `TDD.md` §3.6). Implement diminishing damage for 3+ simultaneous attackers on one Kingdom per `GDD.md` §6.
- Checkup: Test case with 3 bots attacking one Kingdom in the same round produces documented reduced damage on the 2nd/3rd attacker, matching the specified formula (finalize exact numbers if not yet set — flag as open question if so).
- Dependencies: M4-02, M1-04.
- Status: Not Started

**M4-04 — `PactManager` (propose/accept)**
- Spec: UI + logic for proposing/accepting Pacts per `GDD.md` §6. Active Pacts block attacks between members and allow 1 Essence/creature-lend per turn.
- Checkup: Two players in an active Pact cannot select each other as an attack target in the UI; lending 1 Essence correctly transfers.
- Dependencies: M4-01, M4-02.
- Status: Not Started

**M4-05 — Betrayal action**
- Spec: Attacking a Pact ally in the same turn as breaking the Pact triggers the Betrayal bonus per `GDD.md` §6. If its exact damage or Essence amount is still unset when this task starts, add the question to §5 and block implementation until it is decided.
- Checkup: Executing a same-turn break+attack grants the documented bonus exactly once; breaking a Pact without attacking that turn does NOT grant the bonus.
- Dependencies: M4-04, M4-03.
- Status: Not Started

**M4-06 — Comeback Essence bonus**
- Spec: Player in last place (lowest Life) receives bonus Essence per turn per `GDD.md` §6. If the exact bonus amount is still unset when this task starts, add the question to §5 and block implementation until it is decided.
- Checkup: In a test match with uneven Life totals, only the lowest-Life player receives the bonus each round; a tie for last is handled without duplicate/missing bonuses.
- Dependencies: M4-01.
- Status: Not Started

**M4-07 — Turn-limit win condition**
- Spec: Alongside last-Kingdom-standing (from M1-08), implement highest-Life-at-turn-limit win condition per `GDD.md` §6.
- Checkup: A match forced to the turn limit correctly ends and declares the highest-Life player winner, including tie-handling (define tie rule if not yet specified — flag if open).
- Dependencies: M1-08, M4-01.
- Status: Not Started

---

### M5 — Content & Polish

**M5-01 — Full card set per Hero affinity**
- Spec: Build out Commons → Legendaries for each Hero/friend affinity per `GDD.md` §8.
- Checkup: Each Hero affinity has a playable curve (enough low/mid/high-cost cards to build a full 30-card deck without filler from other affinities, unless design intends cross-affinity splashing — confirm).
- Dependencies: M2-01, M0-02.
- Status: Not Started

**M5-02 — Hero passives + Ultimates**
- Spec: Implement each friend-Hero's unique passive trait and signature Ultimate card per `GDD.md` §1/§3.
- Checkup: Each Hero's passive measurably affects gameplay in a test match; each Ultimate is playable and produces its documented effect.
- Dependencies: M5-01.
- Status: Not Started

**M5-03 — Card art integration**
- Spec: Replace placeholder art with final card/hero art assets.
- Checkup: No card/hero displays placeholder/missing-texture art in a full playthrough.
- Dependencies: M0-03, M5-01.
- Status: Not Started

**M5-04 — Juice pass (animations/VFX)**
- Spec: Floop flip animation, attack animations, Pact/Betrayal visual effects per `TDD.md` §5.
- Checkup: Each listed interaction has a distinct visual/animation, verified by manual playthrough checklist.
- Dependencies: M1-05, M4-04, M4-05.
- Status: Not Started

**M5-05 — Progression loop (optional for v1)**
- Spec: Currency, card packs, Bond system per `GDD.md` §9.
- Checkup: Playing matches accrues currency; opening a pack grants cards respecting rarity odds (define odds if unset — flag if open); Bond progress increases with repeated Hero use.
- Dependencies: M5-01.
- Status: Not Started

---

### M6 — Networking / Later (not MVP — do not start without explicit go-ahead)

**M6-01 — `NetworkDecisionSource`**
- Spec: Implement a `DecisionSource` subclass backed by real network communication, per the seam described in `TDD.md` §3.4.
- Checkup: A human player on a second machine/instance can submit actions that resolve identically to a local `HumanDecisionSource` in a test match.
- Dependencies: All of M1–M4 stable.
- Status: Not Started (explicitly deferred)

**M6-02 — Friend-code-locked unlocks**
- Spec: Per `GDD.md` §9.
- Dependencies: M5-05, M6-01.
- Status: Not Started (explicitly deferred)

---

## 3. Task Dependency Summary (quick reference)

```
M0-01 → M0-02 → M0-03
              → M0-04
M0-04 → M1-01
M0-02, M0-03 → M1-02 → M1-03, M1-05, M1-06
M1-01, M0-04 → M1-04 → M1-08
M1-06, M1-04 → M1-07
M0-02/03 → M2-01 → M2-02 → M2-03
M0-01 → M3-01 ─┐
M0-04 ─────────┴→ M3-02 → M3-03 → M3-04
M1-03 → M4-01 → M4-02 → M4-03 → M4-05
                       → M4-04 → M4-05
M4-01 → M4-06
M1-08, M4-01 → M4-07
M2-01, M0-02 → M5-01 → M5-02, M5-03, M5-05
M1-05, M4-04, M4-05 → M5-04
(all M1–M4 stable) → M6-01 → M6-02
```

---

## 4. Status Legend
- `Not Started`
- `In Progress — [agent/person], started [date]`
- `Blocked — [reason]`
- `Done — [agent/person], [date]`

---

## 5. Open Questions Raised (append here as work proceeds)

- [M0-02] — TDD §3.2 requires HeroResource.portrait: Texture2D while card_battler_schema.dbml omits a portrait field from heroes. Code follows TDD; decide whether to add portrait_path to DBML or intentionally document the omission. — raised by agent on 2026-09-15
- [M0-02] — TDD §3.2 decides that CardResource references nullable FloopEffectResource but does not define that Resource's fields. Current code uses DBML fields: id, description, cost_type, cost_amount. Confirm this field shape in TDD or revise code before Floop logic starts. — raised by agent on 2026-09-15
- [M0-03] — Task Checkup requires CardDatabase to load and list all 10 generated cards, but no task owns CardDatabase even though architecture.md and data.md require it as an autoload. Add an owning task before M0-03 can pass its final Checkup. — raised by agent on 2026-09-15
- [M0-03] — Four pre-existing sample .tres files under data/cards have no IDs; three declare CreatureResource while residing in heroes, spells, or landscapes folders. They violate data.md uniqueness rules and may affect future CardDatabase loading. Decide whether to delete, repair, or explicitly exclude them; do not change them without owner approval. — raised by agent on 2026-09-15

*(This section exists so any contributor, human or AI, has a designated place to flag ambiguity in GDD.md/TDD.md instead of guessing. Format: `[Task ID] — [Question] — raised by [agent/person] on [date]`)*

- `[M2-03]` — `card_battler_schema.dbml` models a `decks.owner` field ("player/profile identity"), but no player/profile/account concept exists anywhere in `GDD.md` or `TDD.md`. Deck save/load (M2-03) will need to know what a deck belongs to. Needs a design decision: single local profile only for now, or multiple named profiles on one device? — raised by agent on 2026-09-14
