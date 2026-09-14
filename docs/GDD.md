# [Working Title] — Game Design Document

**Genre:** Fantasy Card Battler (inspired by Card Wars Kingdom)
**Platform:** Digital app, built in Godot
**Multiplayer scope:** Bot-vs-human now; online (friend-group only) planned for later
**Player count:** 2 players now, scalable to 4–6 (Free-for-All with Alliances)

---

## 1. Concept & Pillars

- Fantasy card battler inspired by *Card Wars Kingdom*, but not a clone.
- Every playable Hero is a fantasy-reskinned version of a real-life friend, with a personality-driven kit.
- Core social hook: Free-for-all matches with a **Pact/Betrayal** system, so real friend-group dynamics (trust, betrayal, banter) become part of the gameplay.
- Architecture built so bots and future human network players share the same "decision source" interface — no rewrite needed to add online play later.

---

## 2. Core Resource: Essence

- Players gain a fixed amount of **Essence** per turn (scaling per turn number, similar to standard CCG mana curves).
- Cards cost Essence to play.
- Essence is the main pacing lever: early turns are simple, later turns allow bigger plays.

---

## 3. Card Types

| Type | Description |
|---|---|
| **Creature** | Main combat units. Have Attack/Defense stats, occupy a lane. |
| **Spell** | One-time effects: burst damage, buffs, disruption. |
| **Landscape** | Persistent board-affecting cards (this game's take on Card Wars' terrain/floop mechanic). Buff/restrict certain creature types while in play. |
| **Hero** | One per player. Chosen at deck-build time. Has a passive trait and a unique signature Ultimate card only they can use. |

### The Floop Mechanic (reinterpreted)
- Originally: turning a building card sideways to flip it into play as a hologram.
- Our version: **any card** has a front side (normal stats/effect) and can be **flooped** (flipped/turned) to activate a hidden secondary ability, at a cost (Essence or tempo).
- Keeps the tactile, signature "flip" hook from the original as an homage without directly copying it.

---

## 4. Turn Structure

1. **Gain Essence**
2. **Play/Floop Phase** — play creatures, spells, landscapes, or floop existing cards
3. **Battle Phase** — creatures attack based on lane position and chosen target
4. **Cleanup**

### Resolution Model (Important for FFA)
For 4–6 player matches, turns are **not** strictly sequential. Instead:
- All players privately submit their plays (cards, targets, Pact offers) for the round.
- All actions resolve **simultaneously**, revealed together (Diplomacy-style).
- This avoids slow turn order and prevents players from reactively ganging up once they see who's weak.

---

## 5. Board Layout

- **2-player mode:** Classic facing lanes (Card Wars-style), each player has a row of lanes with creatures facing off directly.
- **4–6 player mode ("Kingdoms in a circle"):** Each player has their own mini-board (**Kingdom**) with its own lanes and Life total, arranged in a circle/hex arena. When a creature attacks, the player chooses *which opponent's Kingdom* to target — not locked to a single facing opponent.

---

## 6. Free-for-All Systems (4–6 Players)

### Anti-Pile-On Mechanics
- **Diminishing returns on ganging up:** if 3+ players attack the same Kingdom in one round, each attacker beyond the first deals reduced damage.
- **Comeback bonus:** the player currently in last place gets a small Essence bonus each turn, to stay competitive.

### Pacts (Alliances)
- Any two players can propose a **Pact** at the start of a round via simple tap-to-propose UI.
- While active: Pact members cannot attack each other, and can share 1 Essence or lend a creature per turn.

### Betrayal
- Breaking a Pact is not a passive toggle — it's a deliberate **card-driven action**.
- A "Betrayal" move only triggers if the player attacks their ally in the *same turn* they break the Pact.
- Betraying grants a one-time damage or Essence burst, rewarding the risk and making it a visible, telegraphed play rather than a quiet rule change.

### Win Condition
- Last Kingdom standing, **or** highest Life total when a turn limit is reached (recommended default for casual sessions, avoids overly long battle royales).

---

## 7. Deck Building

- Deck size: ~30 cards, max copies per card (suggested: 3), to prevent one-trick decks.
- Landscapes: separate sub-deck of ~5–8 cards (function more like slow-changing board state than a hand resource).
- Choosing a Hero locks the player into that Hero's affinity/class, determining which creatures/spells are eligible for the deck.

---

## 8. Card Rarity Tiers

| Rarity | Role |
|---|---|
| Common | Filler creatures/spells, needed for curve |
| Rare | Solid stat lines or minor unique effects |
| Epic | Build-around cards, strong but situational |
| Legendary | Tied to a specific Hero/friend's personality — their "signature move" as a card |

---

## 9. Progression Loop

- Match rewards → currency → card packs.
- Optional: friend-code-locked unlock system, since the roster is personal to your friend group rather than public.
- **Bond system:** playing more matches with a specific friend's Hero unlocks alternate art or evolved card versions — rewards inside jokes and history with that character over time.

---

## 10. Bot / AI Design

Bots fill empty seats in 4–6 player matches (and are the sole opponents for now, pre-online-multiplayer). They use **archetype-based heuristics**, not machine learning — a scoring function per archetype is enough for this genre and easy to tune.

### Bot Archetypes
| Archetype | Behavior |
|---|---|
| **Aggressive** | Attacks whoever's weakest; rarely proposes Pacts |
| **Opportunist** | Proposes Pacts freely, breaks them the moment it's profitable |
| **Loyalist** | Keeps Pacts unless attacked first; reliable ally |
| **Turtle** | Defensive, builds board state, avoids conflict until late game |

### Decision Model
- Each bot scores possible actions (attack X, propose Pact with Y, play card Z) using weighted heuristics based on archetype + current board state.
- **Architecture note:** the turn/resolution engine should treat "decision source" abstractly — human UI input and bot scoring functions both implement the same interface. This lets a future networked human player slot in without reworking the core engine.

---

## 11. Open Design Questions / To Do
- [ ] Final Essence-per-turn curve (numbers/scaling)
- [ ] Exact lane count per Kingdom, and how many creatures can occupy a lane
- [ ] Full rules for Landscape placement (limits per board, replacement rules)
- [ ] Hero roster: friend characters, passive traits, Ultimate cards (next step)
- [ ] Tutorial/onboarding flow for new (non-friend-group) players, if ever made public
- [ ] Godot technical architecture: card data as Resources, scene structure, decision-source interface implementation

---

## 12. Appendix — Inspiration Notes (Card Wars Kingdom)
- Creature-based combat with Attack/Defense stats, energy system, and hero-specific special cards.
- Original "floop" mechanic: turning a building card sideways to place it as a board-affecting hologram.
- Turn had two stages: Floop Stage and Battle Stage.
- Servers for Card Wars and Card Wars Kingdom were shut down in January 2020; used here purely as a design inspiration, not shared assets or IP.
