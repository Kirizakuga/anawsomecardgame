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
- [ ] Support 2-player local match (human vs 1 bot) — headless simulated; pending human verification
- [ ] Support 4–6 player local match (human vs multiple bots), FFA with Pacts/Betrayal (board layout and simultaneous submission done; combat resolution/Pacts in progress)
- [x] Deck builder screen (select Hero, build 30-card deck + landscape sub-deck)
- [x] Full turn loop: Essence gain → Play/Floop → Battle → Cleanup
- [x] Simultaneous action submission + resolution for 4–6p mode
- [x] Bot decision-making for all 4 archetypes
- [x] Card rarity/collection data model (even if progression/economy UI comes later)
- [ ] Win condition detection (last Kingdom standing / turn-limit highest Life) (basic life <= 0 done; turn limit in M4-07)

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
│   ├── floop_effects/            # FloopEffectResource .tres instances
│   ├── board/                    # BoardLayoutConfigResource .tres instances
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
Define base classes and subclasses so designers can create new cards, hero profiles, bot archetypes, and layout configs as `.tres` files in the editor — no code changes needed per card.

```gdscript
# scripts/data/card_resource.gd
class_name CardResource
extends Resource

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

@export var id: String = ""
@export var display_name: String = ""
@export var essence_cost: int = 0
@export var rarity: Rarity = Rarity.COMMON
@export var art: Texture2D
@export var floop_effect: FloopEffectResource # nullable
```

```gdscript
# scripts/data/creature_resource.gd
class_name CreatureResource
extends CardResource

@export var attack: int = 0
@export var defense: int = 0
@export var affinity: String = "" # ties to Hero class/affinity
```

```gdscript
# scripts/data/spell_resource.gd
class_name SpellResource
extends CardResource

@export var effect_ref: String = ""
@export var affinity: String = ""
```

```gdscript
# scripts/data/landscape_resource.gd
class_name LandscapeResource
extends CardResource

@export var affected_affinity: String = ""
@export var buff_restriction_rules: String = ""
```

```gdscript
# scripts/data/hero_resource.gd
# Hero card type (GDD §3) chosen at deck-build time; defines affinity, starting Life, and signature Ultimate; extends Resource directly (sits in kingdom commander slot, not shuffled into 30-card main deck)
class_name HeroResource
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var affinity: String = ""
@export var portrait: Texture2D
@export var passive_trait: String = ""
@export var starting_life: int = 25
@export var ultimate_card: CardResource
@export var friend_name: String = ""
@export var flavor_text: String = ""
```

```gdscript
# scripts/data/floop_effect_resource.gd
class_name FloopEffectResource
extends Resource

@export var id: String = ""
@export var description: String = ""
@export var cost_type: String = "essence"
@export var cost_amount: int = 0
@export var effect_type: String = ""
@export var effect_value: int = 0
```

```gdscript
# scripts/data/bot_archetype_resource.gd
class_name BotArchetypeResource
extends Resource

@export var id: String = ""
@export var archetype_name: String = ""
@export var description: String = ""
@export var aggression_weight: float = 1.0
@export var defense_weight: float = 1.0
@export var pact_loyalty_weight: float = 1.0
@export var betrayal_opportunism_weight: float = 1.0
@export var floop_preference_weight: float = 1.0
```

```gdscript
# scripts/data/board_layout_config.gd
class_name BoardLayoutConfigResource
extends Resource

@export var radius_x: float = 420.0
@export var radius_y: float = 195.0
@export var center_offset: Vector2 = Vector2(0.0, -45.0)
@export var bot_scale: Vector2 = Vector2(0.55, 0.55)
@export var human_scale: Vector2 = Vector2(0.72, 0.72)
@export var target_viewport_size: Vector2 = Vector2(1152.0, 648.0)
@export var arc_start_degrees: float = 165.0
@export var arc_end_degrees: float = 15.0
@export var human_bottom_margin: float = 8.0
```

*(Note: `PileOnConfigResource` is planned for M4-03 to hold tunable damage reduction factors per concurrent attacker.)*

**Why Resources over JSON/CSV:** Godot Resources get you free Inspector-based editing, type safety, and easy references between cards (e.g. a Hero resource directly referencing its Ultimate CardResource) without a custom parser. If you later want bulk-editing via spreadsheet, write a one-time import script that generates `.tres` files from a CSV — best of both worlds.

### 3.3 Kingdom / Board State
Each player (human or bot) has a `KingdomState` (plain object, not a scene) holding: Life total, lanes (creatures in play), active Landscapes, hand, deck, Essence pool. The `Kingdom.tscn` scene is purely a *view* of a `KingdomState` — keeps logic/UI separated per the non-functional requirement.

### 3.4 Decision Source Interface
This is the piece that makes bots and (future) networked humans interchangeable. It operates as an asynchronous request-response pattern.

```gdscript
# scripts/core/decision_source.gd
class_name DecisionSource
extends RefCounted

signal actions_ready(actions: RoundActions)

func request_actions(kingdom: KingdomState, context: MatchContext) -> void:
    push_error("DecisionSource.request_actions() not implemented")
```

- `HumanDecisionSource` — connects to UI input, packages player selections, emits `actions_ready(actions)` upon submission
- `BotDecisionSource` — delegates to `BotAI.decide(kingdom, context)`, emits `actions_ready(actions)` synchronously

`ResolutionEngine` and `TurnManager` only ever interact with `DecisionSource` instances via `request_actions()` and `actions_ready` — they never know or care which is human vs bot. This is the seam where a future `NetworkDecisionSource` slots in without touching resolution logic.

### 3.5 Bot Scoring (per archetype)
Simple weighted-sum scoring, no ML needed:

```
score(action) = Σ (weight_i * feature_i(action, board_state))
```

Each `BotArchetype` Resource stores its own weight table (e.g. `aggression_weight`, `pact_loyalty_weight`, `betrayal_opportunism_weight`). `BotAI` generates candidate actions, scores each with the bot's archetype weights, picks the highest (with some randomness/noise to avoid fully predictable bots).

### 3.6 Simultaneous Resolution Flow
1. `TurnManager` enters Play/Floop phase → requests actions from all `DecisionSource`s in parallel (UI stays open for human; bots resolve instantly)
2. Once all sources return `RoundActions`, `ResolutionEngine.resolve(all_actions)` runs deterministically in this fixed category order: Landscapes → Spells → Creatures → Pact changes → Betrayals. Tie-breaking within a category remains an open technical question.
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
- [x] Set up Godot project, folder structure, Git repo
- [x] Define `CardResource` + subclasses, create ~10 placeholder cards to test with
- [x] Build `KingdomState` plain-object class (no scene yet)

### Phase 1 — Core Loop, 2-Player Only
- [x] `TurnManager` phase sequencing (Essence → Play → Battle → Cleanup)
- [x] `CardView.tscn` + `Hand.tscn` with drag-to-play
- [x] `Kingdom.tscn` with lanes, life display
- [x] Basic combat resolution (creature vs creature, direct Kingdom damage)
- [x] Floop interaction (flip card → secondary effect) on at least a few test cards
- [x] `HumanDecisionSource` fully wired for one human player
- [x] Hardcoded "dummy AI" (random legal move) just to have an opponent — full archetype AI comes later
- [x] Win condition check (Life ≤ 0)

### Phase 2 — Deck Builder
- [x] `DeckBuilder.tscn`: Hero selection, affinity-filtered card pool, 30-card deck assembly
- [x] Save/load a deck as a simple resource or save-file

### Phase 3 — Real Bot AI
- [x] `BotArchetype` Resource + weight tables
- [x] `BotAI.decide()` scoring implementation for the 4 archetypes
- [ ] Playtest 2-player vs each archetype individually for balance/feel (deferred; pending human verification M3-04)

### Phase 4 — Scale to 4–6 Players (FFA)
- [x] `MatchBoard.tscn` supporting N Kingdoms in a circular layout
- [x] Simultaneous action submission across all `DecisionSource`s
- [x] `ResolutionEngine` deterministic resolution order + pile-on damage reduction
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
- [ ] Deterministic tie-breaking within each simultaneous-resolution category (for example, two Spells resolving in the same round) needs finalizing before Phase 4.
