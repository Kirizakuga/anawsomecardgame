# Technical Design Document — [Working Title]

**Engine:** Godot 4.x (GDScript)
**Rendering:** 2D
**Companion doc:** See `GDD.md` for game design/rules this document implements.

---

## 1. Requirements

### 1.1 Software / Tooling
- Godot 4.2+ (LTS recommended once available; avoid Godot 3.x — different node/Resource APIs)
- Version control: Git (Godot projects diff reasonably well as text; use `.gitattributes` to treat `.tscn`/`.tres` as text)
- Art tool for card art/UI (Aseprite, Krita, Photoshop — whatever you're using for friend-character art)
- Optional: a spreadsheet or small script for bulk card data entry, since you'll have 100+ cards eventually

### 1.2 Functional Requirements (MVP scope)
- [ ] Support 2-player local match (human vs 1 bot) — build and prove this first
- [ ] Support 4–6 player local match (human vs multiple bots), FFA with Pacts/Betrayal
- [ ] Deck builder screen (select Hero, build 30-card deck + landscape sub-deck)
- [ ] Full turn loop: Essence gain → Play/Floop → Battle → Cleanup
- [ ] Simultaneous action submission + resolution for 4–6p mode
- [ ] Bot decision-making for all 4 archetypes
- [ ] Card rarity/collection data model (even if progression/economy UI comes later)
- [ ] Win condition detection (last Kingdom standing / turn-limit highest Life)

### 1.3 Non-Functional Requirements
- Card data must be **designer-editable without touching code** (Resources/`.tres` files or an import pipeline from a spreadsheet/JSON)
- Game logic must not care whether a "player" is human or bot (shared decision-source interface — see §3.4)
- Architecture must not assume local-only play forever — avoid hardcoding singleplayer assumptions into the resolution engine, even though networking is out of scope for now
- Target: stable 60fps on mid-range mobile/desktop; this is a UI-heavy 2D game, so performance risk is low but avoid overly complex shaders on every card

---

## 2. Project Structure

```
res://
├── assets/
│   ├── art/
│   │   ├── cards/              # per-card illustrations
│   │   ├── heroes/              # friend-character portraits
│   │   └── ui/
│   ├── audio/
│   └── fonts/
├── data/
│   ├── cards/                    # CardResource .tres instances
│   │   ├── creatures/
│   │   ├── spells/
│   │   ├── landscapes/
│   │   └── heroes/
│   └── bot_profiles/              # BotArchetype .tres instances
├── scenes/
│   ├── main/
│   │   └── Main.tscn              # top-level scene, mode select
│   ├── match/
│   │   ├── MatchBoard.tscn        # whole-match container
│   │   ├── Kingdom.tscn           # one player's board (lanes + life)
│   │   ├── Lane.tscn
│   │   ├── Hand.tscn
│   │   └── CardView.tscn          # visual card, used in hand/board/preview
│   ├── deckbuilder/
│   │   └── DeckBuilder.tscn
│   └── ui/
│       ├── PactProposalPopup.tscn
│       └── ResolutionLog.tscn      # shows what happened after simultaneous reveal
├── scripts/
│   ├── autoload/                  # singletons, see §3.1
│   ├── core/                      # engine-agnostic game logic (rules, resolution)
│   ├── data/                      # Resource class definitions
│   ├── ai/                        # bot scoring logic
│   └── ui/
└── resources/
    └── card_resource.gd, hero_resource.gd, etc. (class_name definitions)
```

**Key principle:** keep `scripts/core/` free of any `Node`/scene references where possible — pure game-state logic (turn resolution, combat math, pact rules) should be testable without the scene tree running. UI scripts translate that state into visuals.

---

## 3. Core Architecture

### 3.1 Autoloads (Singletons)
| Autoload | Responsibility |
|---|---|
| `GameManager` | Match setup, player count, current phase, win/loss detection |
| `TurnManager` | Turn/round counter, phase sequencing (Essence → Play → Battle → Cleanup) |
| `ResolutionEngine` | Collects all submitted actions for a round, resolves simultaneously, emits results |
| `CardDatabase` | Loads all `CardResource` files at startup, provides lookup by ID |
| `BotAI` | Given a bot's Kingdom + board state, returns its chosen actions using archetype scoring |
| `PactManager` | Tracks active Pacts, handles proposal/accept/break logic including Betrayal bonus |

### 3.2 Card Data as Resources
Define a base class and subclasses so designers can create new cards as `.tres` files in the editor — no code changes needed per card.

```gdscript
# scripts/data/card_resource.gd
class_name CardResource
extends Resource

@export var id: String
@export var display_name: String
@export var essence_cost: int
@export var rarity: Rarity  # enum: COMMON, RARE, EPIC, LEGENDARY
@export var art: Texture2D
@export var floop_effect: FloopEffectResource  # nullable

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }
```

```gdscript
# scripts/data/creature_resource.gd
class_name CreatureResource
extends CardResource

@export var attack: int
@export var defense: int
@export var affinity: String  # ties to Hero class/affinity
```

Similarly: `SpellResource` (effect script reference or effect enum + params), `LandscapeResource` (buff/restriction rules + affected affinities), `HeroResource` (passive trait, `ultimate_card: CardResource`, portrait, friend's name/flavor text).

**Why Resources over JSON/CSV:** Godot Resources get you free Inspector-based editing, type safety, and easy references between cards (e.g. a Hero resource directly referencing its Ultimate CardResource) without a custom parser. If you later want bulk-editing via spreadsheet, write a one-time import script that generates `.tres` files from a CSV — best of both worlds.

### 3.3 Kingdom / Board State
Each player (human or bot) has a `KingdomState` (plain object, not a scene) holding: Life total, lanes (creatures in play), active Landscapes, hand, deck, Essence pool. The `Kingdom.tscn` scene is purely a *view* of a `KingdomState` — keeps logic/UI separated per the non-functional requirement.

### 3.4 Decision Source Interface
This is the piece that makes bots and (future) networked humans interchangeable.

```gdscript
# scripts/core/decision_source.gd
class_name DecisionSource
extends RefCounted

# Override in subclasses. Returns a RoundActions object once ready.
func get_actions(kingdom_state: KingdomState, match_context: MatchContext) -> RoundActions:
    push_error("Not implemented")
    return null
```

- `HumanDecisionSource` — waits for UI input, packages selections into `RoundActions`
- `BotDecisionSource` — calls `BotAI.decide(kingdom_state, match_context, archetype)`

`ResolutionEngine` only ever talks to `DecisionSource` instances — it never knows or cares which is human vs bot. This is the seam where a future `NetworkDecisionSource` slots in without touching resolution logic.

### 3.5 Bot Scoring (per archetype)
Simple weighted-sum scoring, no ML needed:

```
score(action) = Σ (weight_i * feature_i(action, board_state))
```

Each `BotArchetype` Resource stores its own weight table (e.g. `aggression_weight`, `pact_loyalty_weight`, `betrayal_opportunism_weight`). `BotAI` generates candidate actions, scores each with the bot's archetype weights, picks the highest (with some randomness/noise to avoid fully predictable bots).

### 3.6 Simultaneous Resolution Flow
1. `TurnManager` enters Play/Floop phase → requests actions from all `DecisionSource`s in parallel (UI stays open for human; bots resolve instantly)
2. Once all sources return `RoundActions`, `ResolutionEngine.resolve(all_actions)` runs deterministically (fixed order: e.g. Landscapes → Spells → Creatures → Pact changes → Betrayals) to avoid ambiguity
3. Results emitted as a signal (`resolution_finished(log: Array)`) — UI plays out animations/log from this data, it doesn't decide outcomes itself

---

## 4. Scene/Node Breakdown (MVP)

| Scene | Key Nodes | Notes |
|---|---|---|
| `Main.tscn` | Mode select UI | Entry point: choose player count, bot archetypes |
| `MatchBoard.tscn` | N × `Kingdom.tscn`, `ResolutionLog.tscn` | Instantiates one Kingdom per player (human or bot) |
| `Kingdom.tscn` | `Lane.tscn` × N, Life label, Hand (if human) | Purely a view over `KingdomState` |
| `CardView.tscn` | Sprite/Texture, stat labels, floop animation | Reused everywhere a card is shown |
| `PactProposalPopup.tscn` | Player list, propose/accept buttons | Only active in 4–6p mode |
| `DeckBuilder.tscn` | Hero select, card grid, deck list | Standalone screen before match start |

---

## 5. Build Roadmap / To-Do List

### Phase 0 — Foundation
- [ ] Set up Godot project, folder structure, Git repo
- [ ] Define `CardResource` + subclasses, create ~10 placeholder cards to test with
- [ ] Build `KingdomState` plain-object class (no scene yet)

### Phase 1 — Core Loop, 2-Player Only
- [ ] `TurnManager` phase sequencing (Essence → Play → Battle → Cleanup)
- [ ] `CardView.tscn` + `Hand.tscn` with drag-to-play
- [ ] `Kingdom.tscn` with lanes, life display
- [ ] Basic combat resolution (creature vs creature, direct Kingdom damage)
- [ ] Floop interaction (flip card → secondary effect) on at least a few test cards
- [ ] `HumanDecisionSource` fully wired for one human player
- [ ] Hardcoded "dummy AI" (random legal move) just to have an opponent — full archetype AI comes later
- [ ] Win condition check (Life ≤ 0)

### Phase 2 — Deck Builder
- [ ] `DeckBuilder.tscn`: Hero selection, affinity-filtered card pool, 30-card deck assembly
- [ ] Save/load a deck as a simple resource or save-file

### Phase 3 — Real Bot AI
- [ ] `BotArchetype` Resource + weight tables
- [ ] `BotAI.decide()` scoring implementation for the 4 archetypes
- [ ] Playtest 2-player vs each archetype individually for balance/feel

### Phase 4 — Scale to 4–6 Players (FFA)
- [ ] `MatchBoard.tscn` supporting N Kingdoms in a circular layout
- [ ] Simultaneous action submission across all `DecisionSource`s
- [ ] `ResolutionEngine` deterministic resolution order + pile-on damage reduction
- [ ] `PactManager`: propose/accept Pact UI + logic
- [ ] Betrayal action (attack ally same-turn as breaking Pact) + bonus effect
- [ ] Comeback Essence bonus for last place
- [ ] Turn-limit win condition (highest Life) alongside last-Kingdom-standing

### Phase 5 — Content & Polish
- [ ] Build out full card set (Commons → Legendaries) per Hero affinity
- [ ] Hero passive traits + Ultimate cards implemented for each friend-character
- [ ] Card art pass
- [ ] Juice: floop flip animation, attack animations, Pact/Betrayal VFX
- [ ] Progression loop: currency, packs, Bond system (optional for v1)

### Phase 6 — Later / Not MVP
- [ ] `NetworkDecisionSource` for real online play with friends
- [ ] Friend-code-locked unlocks
- [ ] Public release considerations (if ever)

---

## 6. Open Technical Questions
- [ ] Exact deterministic resolution order for simultaneous actions (needs finalizing before Phase 4)
- [ ] How Floop's "hidden secondary ability" is represented in `CardResource` — separate effect resource vs. script reference
- [ ] Save system format for decks/progression (Godot's `ResourceSaver` vs. plain JSON for easier debugging)
