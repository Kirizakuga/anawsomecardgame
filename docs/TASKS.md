# Task Breakdown & Collaboration Guide â€” [Working Title]

**Purpose:** This document breaks the project into discrete, ID-tagged tasks with specs and acceptance criteria, so any contributor â€” human or AI â€” can pick up a task independently without needing full prior context.

**Read first, always:** `GDD.md` (game design/rules) and `TDD.md` (technical architecture). This document assumes both as ground truth. If a task here conflicts with those docs, the conflict itself should be flagged (see Â§0) rather than silently resolved.

---

## 0. Guidance for AI Collaborators

If you are an AI picking up work on this project, follow these rules:

1. **Load context first.** Read `GDD.md` and `TDD.md` in full before writing code. Do not infer game rules or architecture from a task description alone â€” task specs assume that context.
2. **Work one task at a time.** Each task below has an ID (e.g. `M1-03`). State which task ID you're working on before starting, and don't silently expand scope into another task's territory.
3. **Respect the architecture boundaries in TDD.md Â§3**, especially:
   - Keep `scripts/core/` free of scene/Node dependencies.
   - Never have `ResolutionEngine` or game logic branch on "is this a bot or human" â€” always go through `DecisionSource`.
4. **Don't invent new systems not in GDD.md/TDD.md.** If a task seems to need a new mechanic or data field not covered by those docs, stop and flag it under "Open Questions Raised" (Â§5) rather than deciding unilaterally.
5. **Definition of Done = Acceptance Criteria, not "it runs."** Each task lists specific checks. All must pass before marking a task complete.
6. **Update task status inline** in this doc when you finish a task: change `Status: Not Started` â†’ `Status: Done (by [agent/person], [date])`. If blocked, use `Status: Blocked â€” [reason]`.
7. **Naming conventions:** `snake_case` for files/variables, `PascalCase` for class/scene names, matching existing Godot conventions already used in `TDD.md` Â§2â€“3.
8. **If a dependency task isn't done yet**, don't stub around it silently â€” note it in your task's status and either wait or complete the dependency first if trivial.
9. **No networking work** unless explicitly working on an M6 task â€” earlier phases assume local-only (human + bots).

---

## 1. Task ID Scheme

Format: `M{module}-{task number}`, e.g. `M2-04`.

| Module | Name | Maps to TDD.md Phase |
|---|---|---|
| M0 | Foundation | Phase 0 |
| M1 | Core Loop (2-Player) | Phase 1 |
| M2 | Deck Builder | Phase 2 |
| M3 | Bot AI | Phase 3 |
| M4 | FFA Scaling (4â€“6p) | Phase 4 |
| M5 | Content & Polish | Phase 5 |
| M6 | Networking / Later | Phase 6 |

---

## 2. Module Tasks

### M0 â€” Foundation

**M0-01 â€” Project & repo setup**
- Spec: Create Godot 4.x project matching folder structure in `TDD.md` Â§2. Initialize Git repo with `.gitattributes` treating `.tscn`/`.tres` as text.
- Deliverables: Empty but structured project committed to repo.
- Checkup: Folder tree matches `TDD.md` Â§2 exactly. `godot --headless --version` confirms 4.2+.
- Dependencies: None.
- Status: Done — agent, 2026-09-14

**M0-02 â€” `CardResource` base class + subclasses**
- Spec: Implement `CardResource`, `CreatureResource`, `SpellResource`, `LandscapeResource`, `HeroResource` per `TDD.md` Â§3.2. All exported fields from the doc must be present with correct types.
- Deliverables: `.gd` scripts in `scripts/data/`.
- Checkup: Can create a `.tres` instance of each subclass in the Godot editor Inspector without script errors. A `CreatureResource` correctly shows `attack`/`defense`/`affinity` fields in the Inspector.
- Dependencies: M0-01.
- Status: Not Started

**M0-03 â€” Placeholder card set (10 cards)**
- Spec: Create 10 `.tres` card instances (mix of Creature/Spell/Landscape) using M0-02 classes, for use in early testing. Stats/costs can be arbitrary but internally consistent (e.g. cost roughly scales with power).
- Deliverables: `.tres` files in `data/cards/`.
- Checkup: `CardDatabase` (once built in M1) can load and list all 10 without error.
- Dependencies: M0-02.
- Status: Not Started

**M0-04 â€” `KingdomState` plain object class**
- Spec: Implement per `TDD.md` Â§3.3 â€” Life total, lanes array, active landscapes, hand, deck, Essence pool. Pure GDScript object (`RefCounted` or similar), no scene/Node dependency.
- Deliverables: `scripts/core/kingdom_state.gd`.
- Checkup: Can instantiate `KingdomState`, add/remove a card from hand, modify Life, in a standalone test script with no scene tree running.
- Dependencies: M0-02.
- Status: Not Started

---

### M1 â€” Core Loop (2-Player Only)

**M1-01 â€” `TurnManager` phase sequencing**
- Spec: Autoload implementing Essence â†’ Play/Floop â†’ Battle â†’ Cleanup sequencing per `TDD.md` Â§3.1 and `GDD.md` Â§4. Must emit signals on phase change (e.g. `phase_changed(new_phase)`).
- Checkup: A test scene can subscribe to `phase_changed` and log all 4 phases occurring in order across 3 full turns.
- Dependencies: M0-04.
- Status: Not Started

**M1-02 â€” `CardView.tscn` + drag-to-play**
- Spec: Visual card scene showing art, cost, stats. Supports drag-from-hand-to-lane interaction. Must support a "floop" flip animation trigger (visual only at this stage â€” logic comes in M1-05).
- Checkup: Dragging a card from hand to a valid lane visually moves it and removes it from hand. Invalid drop (e.g. insufficient Essence) snaps back.
- Dependencies: M0-02, M0-03.
- Status: Not Started

**M1-03 â€” `Kingdom.tscn` (lanes + life display)**
- Spec: View over a single `KingdomState`. Renders lanes (per `GDD.md` Â§5, 2-player facing-lanes layout), Life total, and hosts `Hand.tscn` for the human player's Kingdom only.
- Checkup: Given a `KingdomState` with 2 creatures in lanes and Life = 15, the scene visually reflects both without manual wiring per-instance.
- Dependencies: M0-04, M1-02.
- Status: Not Started

**M1-04 â€” Combat resolution (creature-vs-creature, direct damage)**
- Spec: Implement combat math for 2-player facing lanes: creature vs opposing creature in same lane, and unblocked lanes dealing damage to enemy Kingdom Life directly. Lives in `scripts/core/`.
- Checkup: Unit-style test scene: two `KingdomState`s with known creature stats produce the exact expected Life totals and creature survival/death after one Battle phase.
- Dependencies: M1-01, M0-04.
- Status: Not Started

**M1-05 â€” Floop interaction logic**
- Spec: Implement flipping a card (in hand or in play, per `GDD.md` Â§3) to trigger its secondary effect at defined Essence/tempo cost. At minimum, wire this for 2â€“3 of the M0-03 placeholder cards.
- Checkup: Flooping a test card produces its documented secondary effect and correctly deducts cost; flooding a card with no floop effect is a no-op/disabled in UI.
- Dependencies: M1-02, M0-03.
- Status: Not Started

**M1-06 â€” `HumanDecisionSource`**
- Spec: Implement per `TDD.md` Â§3.4. Must package UI selections (cards played, floops, targets) into a `RoundActions` object matching what `ResolutionEngine` expects (even if `ResolutionEngine` itself is simplified for 2p at this stage).
- Checkup: Manually playing a full turn through the UI produces a `RoundActions` object with correct contents (verify via debug print).
- Dependencies: M1-02, M1-03.
- Status: Not Started

**M1-07 â€” Dummy AI opponent (random legal move)**
- Spec: Temporary stand-in for `BotDecisionSource` (real archetype AI is M3) â€” picks a random legal action each phase. Exists only so 2-player games are playable end-to-end before real AI exists.
- Checkup: A full match can be played human-vs-dummy-AI to a win/loss without crashes.
- Dependencies: M1-06, M1-04.
- Status: Not Started

**M1-08 â€” Win condition check**
- Spec: Detect Life â‰¤ 0, end match, declare winner. Per `GDD.md` Â§6 (2-player subset â€” full FFA win conditions are M4).
- Checkup: Reducing a `KingdomState`'s Life to 0 or below during a test triggers match-end state correctly, exactly once (no double-trigger).
- Dependencies: M1-04.
- Status: Not Started

---

### M2 â€” Deck Builder

**M2-01 â€” Hero selection screen**
- Spec: UI listing available `HeroResource`s with portrait, name, passive trait description. Selecting one filters the card pool by affinity per `GDD.md` Â§7.
- Checkup: Selecting each of the placeholder Heroes correctly filters to only affinity-matching cards from `CardDatabase`.
- Dependencies: M0-02, M0-03 (or expanded card set).
- Status: Not Started

**M2-02 â€” Deck assembly UI**
- Spec: Grid of eligible cards, add/remove to a 30-card deck list, enforce max-copies-per-card limit (default 3) and separate Landscape sub-deck (5â€“8) per `GDD.md` Â§7.
- Checkup: Cannot exceed 30 main-deck cards, cannot add a 4th copy of any card, Landscape sub-deck enforced separately from main deck count.
- Dependencies: M2-01.
- Status: Not Started

**M2-03 â€” Deck save/load**
- Spec: Persist a built deck (Hero + card list + landscape list) to disk and reload it. Format decision (Resource vs JSON) should follow whatever is resolved in TDD.md Â§6 open question â€” flag if unresolved.
- Checkup: Save a deck, restart the game/scene, load it back with identical contents.
- Dependencies: M2-02.
- Status: Not Started

---

### M3 â€” Bot AI

**M3-01 â€” `BotArchetype` Resource + weight tables**
- Spec: Resource class holding named weight fields per `TDD.md` Â§3.5 (e.g. `aggression_weight`, `pact_loyalty_weight`, `betrayal_opportunism_weight`). Create 4 `.tres` instances: Aggressive, Opportunist, Loyalist, Turtle, with distinct weight values reflecting `GDD.md` Â§10 descriptions.
- Checkup: Each archetype `.tres` has clearly differentiated weights (e.g. Aggressive has high attack-weight, near-zero pact-weight).
- Dependencies: M0-01.
- Status: Not Started

**M3-02 â€” `BotAI.decide()` scoring implementation**
- Spec: Given a `KingdomState`, `MatchContext`, and `BotArchetype`, generate candidate actions and score via the weighted-sum formula in `TDD.md` Â§3.5, return the highest-scoring `RoundActions` (with minor randomness to avoid total predictability).
- Checkup: Given a fixed board state, an Aggressive archetype and a Turtle archetype produce visibly different chosen actions in test logs.
- Dependencies: M3-01, M0-04.
- Status: Not Started

**M3-03 â€” `BotDecisionSource`**
- Spec: Wraps `BotAI.decide()` to conform to the `DecisionSource` interface from `TDD.md` Â§3.4, replacing the M1-07 dummy AI.
- Checkup: Swapping `BotDecisionSource` in for the dummy AI in a 2-player match requires zero changes to `ResolutionEngine` or `TurnManager`.
- Dependencies: M3-02, M1-06 (interface parity).
- Status: Not Started

**M3-04 â€” Balance playtesting pass (2-player vs each archetype)**
- Spec: Not code â€” structured playtesting. Play multiple matches against each of the 4 archetypes, log outcomes/impressions, adjust weights in M3-01 as needed.
- Checkup: A short written summary of at least 5 matches per archetype with adjustments made and rationale.
- Dependencies: M3-03.
- Status: Not Started

---

### M4 â€” FFA Scaling (4â€“6 Players)

**M4-01 â€” `MatchBoard.tscn` circular N-Kingdom layout**
- Spec: Instantiate 4â€“6 `Kingdom.tscn` instances arranged per `GDD.md` Â§5 ("Kingdoms in a circle"). Layout must scale cleanly for 4, 5, and 6 players.
- Checkup: Visual test with 4, then 6, dummy Kingdoms shows no overlap/clipping at target resolution.
- Dependencies: M1-03.
- Status: Not Started

**M4-02 â€” Simultaneous action submission (all `DecisionSource`s)**
- Spec: `TurnManager`/`ResolutionEngine` must collect `RoundActions` from all N players' `DecisionSource`s before resolving, per `TDD.md` Â§3.6. Human UI must clearly show "waiting for others" state.
- Checkup: In a 4-bot + 1-human test match, resolution does not proceed until all 5 `RoundActions` are collected, regardless of order of arrival.
- Dependencies: M1-06, M3-03.
- Status: Not Started

**M4-03 â€” `ResolutionEngine` deterministic multi-player resolution + pile-on reduction**
- Spec: Fixed resolution order (Landscapes â†’ Spells â†’ Creatures â†’ Pact changes â†’ Betrayals per `TDD.md` Â§3.6). Implement diminishing damage for 3+ simultaneous attackers on one Kingdom per `GDD.md` Â§6.
- Checkup: Test case with 3 bots attacking one Kingdom in the same round produces documented reduced damage on the 2nd/3rd attacker, matching the specified formula (finalize exact numbers if not yet set â€” flag as open question if so).
- Dependencies: M4-02, M1-04.
- Status: Not Started

**M4-04 â€” `PactManager` (propose/accept)**
- Spec: UI + logic for proposing/accepting Pacts per `GDD.md` Â§6. Active Pacts block attacks between members and allow 1 Essence/creature-lend per turn.
- Checkup: Two players in an active Pact cannot select each other as an attack target in the UI; lending 1 Essence correctly transfers.
- Dependencies: M4-01, M4-02.
- Status: Not Started

**M4-05 â€” Betrayal action**
- Spec: Attacking a Pact ally in the same turn as breaking the Pact triggers the Betrayal bonus per `GDD.md` Â§6.
- Checkup: Executing a same-turn break+attack grants the documented bonus exactly once; breaking a Pact without attacking that turn does NOT grant the bonus.
- Dependencies: M4-04, M4-03.
- Status: Not Started

**M4-06 â€” Comeback Essence bonus**
- Spec: Player in last place (lowest Life) receives bonus Essence per turn per `GDD.md` Â§6.
- Checkup: In a test match with uneven Life totals, only the lowest-Life player receives the bonus each round; a tie for last is handled without duplicate/missing bonuses.
- Dependencies: M4-01.
- Status: Not Started

**M4-07 â€” Turn-limit win condition**
- Spec: Alongside last-Kingdom-standing (from M1-08), implement highest-Life-at-turn-limit win condition per `GDD.md` Â§6.
- Checkup: A match forced to the turn limit correctly ends and declares the highest-Life player winner, including tie-handling (define tie rule if not yet specified â€” flag if open).
- Dependencies: M1-08, M4-01.
- Status: Not Started

---

### M5 â€” Content & Polish

**M5-01 â€” Full card set per Hero affinity**
- Spec: Build out Commons â†’ Legendaries for each Hero/friend affinity per `GDD.md` Â§8.
- Checkup: Each Hero affinity has a playable curve (enough low/mid/high-cost cards to build a full 30-card deck without filler from other affinities, unless design intends cross-affinity splashing â€” confirm).
- Dependencies: M2-01, M0-02.
- Status: Not Started

**M5-02 â€” Hero passives + Ultimates**
- Spec: Implement each friend-Hero's unique passive trait and signature Ultimate card per `GDD.md` Â§1/Â§3.
- Checkup: Each Hero's passive measurably affects gameplay in a test match; each Ultimate is playable and produces its documented effect.
- Dependencies: M5-01.
- Status: Not Started

**M5-03 â€” Card art integration**
- Spec: Replace placeholder art with final card/hero art assets.
- Checkup: No card/hero displays placeholder/missing-texture art in a full playthrough.
- Dependencies: M0-03, M5-01.
- Status: Not Started

**M5-04 â€” Juice pass (animations/VFX)**
- Spec: Floop flip animation, attack animations, Pact/Betrayal visual effects per `TDD.md` Â§5.
- Checkup: Each listed interaction has a distinct visual/animation, verified by manual playthrough checklist.
- Dependencies: M1-05, M4-04, M4-05.
- Status: Not Started

**M5-05 â€” Progression loop (optional for v1)**
- Spec: Currency, card packs, Bond system per `GDD.md` Â§9.
- Checkup: Playing matches accrues currency; opening a pack grants cards respecting rarity odds (define odds if unset â€” flag if open); Bond progress increases with repeated Hero use.
- Dependencies: M5-01.
- Status: Not Started

---

### M6 â€” Networking / Later (not MVP â€” do not start without explicit go-ahead)

**M6-01 â€” `NetworkDecisionSource`**
- Spec: Implement a `DecisionSource` subclass backed by real network communication, per the seam described in `TDD.md` Â§3.4.
- Checkup: A human player on a second machine/instance can submit actions that resolve identically to a local `HumanDecisionSource` in a test match.
- Dependencies: All of M1â€“M4 stable.
- Status: Not Started (explicitly deferred)

**M6-02 â€” Friend-code-locked unlocks**
- Spec: Per `GDD.md` Â§9.
- Dependencies: M5-05, M6-01.
- Status: Not Started (explicitly deferred)

---

## 3. Task Dependency Summary (quick reference)

```
M0-01 â†’ M0-02 â†’ M0-03
              â†’ M0-04
M0-04 â†’ M1-01
M0-02, M0-03 â†’ M1-02 â†’ M1-03, M1-05, M1-06
M1-01, M0-04 â†’ M1-04 â†’ M1-08
M1-06, M1-04 â†’ M1-07
M0-02/03 â†’ M2-01 â†’ M2-02 â†’ M2-03
M0-01 â†’ M3-01 â†’ M3-02 â†’ M3-03 â†’ M3-04
M1-03 â†’ M4-01 â†’ M4-02 â†’ M4-03 â†’ M4-05
                       â†’ M4-04 â†’ M4-05
M4-01 â†’ M4-06
M1-08, M4-01 â†’ M4-07
M2-01, M0-02 â†’ M5-01 â†’ M5-02, M5-03, M5-05
M1-05, M4-04, M4-05 â†’ M5-04
(all M1â€“M4 stable) â†’ M6-01 â†’ M6-02
```

---

## 4. Status Legend
- `Not Started`
- `In Progress â€” [agent/person], started [date]`
- `Blocked â€” [reason]`
- `Done â€” [agent/person], [date]`

---

## 5. Open Questions Raised (append here as work proceeds)

*(Empty at time of writing â€” this section exists so any contributor, human or AI, has a designated place to flag ambiguity in GDD.md/TDD.md instead of guessing. Format: `[Task ID] â€” [Question] â€” raised by [agent/person] on [date]`)*
