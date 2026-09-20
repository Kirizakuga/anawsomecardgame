# Development

## Requirements

- Godot 4.2+ editor (LTS once available)
- Git, with `.gitattributes` treating `.tscn`/`.tres` as text

## Running the project

1. Open `project.godot` in the Godot editor.
2. Run `Main.tscn` (mode select) for a full playthrough, or open the specific scene/test scene relevant to the task you're on.
3. From the command line, confirm the installed engine version with:
   ```
   godot --headless --version
   ```

## Verifying a task

This project doesn't yet have an automated test runner — each task in `TASKS.md` defines its own **Checkup** (a manual or scripted verification step, e.g. "a test scene subscribes to `phase_changed` and logs all 4 phases in order"). Build and run that checkup before marking a task `Done`. If the team later adopts an automated GDScript test framework, document the convention here — don't introduce one silently mid-task.

Available verification test scenes:
- `scenes/main/CardDatabaseCheck.tscn` (M0-03: CardDatabase loading and lookups)
- `scenes/main/TurnManagerCheck.tscn` (M1-01: TurnManager phase sequencing, signals, and turn lifecycle)
- `scenes/match/CardViewCheck.tscn` (M1-02: CardView rendering, stats, floop, and drag/snapback)
- `scenes/match/KingdomCheck.tscn` (M1-03: KingdomView life, lanes, essence deduction, and drop validation)
- `scenes/match/CombatCheck.tscn` (M1-04: Combat resolution, creature-vs-creature, and unblocked direct damage)
- `scenes/match/FloopCheck.tscn` (M1-05: Floop interaction logic, secondary effects, and cost deduction)
- `scenes/match/HumanDecisionCheck.tscn` (M1-06: HumanDecisionSource action queueing, submit signal, and KingdomView routing)
- `scenes/match/DummyAICheck.tscn` (M1-07: DummyAIDecisionSource random legal actions and full simulated match resolution)
- `scenes/match/WinConditionCheck.tscn` (M1-08: Win condition check, life <= 0, match-end state, and turn limit)
- `scenes/deckbuilder/HeroSelectCheck.tscn` (M2-01: Hero selection UI, HeroResource loading, and affinity-based card filtering)
- `scenes/deckbuilder/DeckBuilderCheck.tscn` (M2-02: Deck assembly UI, 30 main cards limit, max 3 copies, and separate 5-8 landscape deck)
- `scenes/deckbuilder/DeckSaveLoadCheck.tscn` (M2-03: Deck save/load to JSON, disk persistence, corruption handling, and CardDatabase resolution — **Warning:** writes to real `user://saved_deck.json`, which overwrites any deck saved by hand)
- `scenes/match/BotArchetypeCheck.tscn` (M3-01: BotArchetypeResource loading, archetype profiles, and weight differentiation)
- `scenes/match/BotAIScoringCheck.tscn` (M3-02: Bot AI candidate generation, weighted-sum scoring, and archetype differentiation)
- `scenes/match/BotDecisionSourceCheck.tscn` (M3-03: BotDecisionSource DecisionSource interface conformance, 2p match swapping parity, and archetype compatibility)
- `scenes/match/MatchBoardCheck.tscn` (M4-01: MatchBoard circular N-Kingdom layout for 4-6 players, scaling, bounds, and no-overlap verification)
- `scenes/match/SimultaneousSubmissionCheck.tscn` (M4-02: Simultaneous action collection from all DecisionSources, TurnManager coordination, waiting UI overlay, and resolution gating)
- `scenes/match/ResolutionEngineCheck.tscn` (M4-03: ResolutionEngine deterministic multi-player resolution, 5-stage order, floop routing, and anti-pile-on reduction)

### Running checks headless

Run a single check:
```bash
godot --headless --path . scenes/<area>/<Name>Check.tscn
```

Run all checks from command line (bash):
```bash
for scene in scenes/*/*Check.tscn; do
  echo "Running $scene..."
  godot --headless --path . "$scene" || exit 1
done
```
Each check scene exits with code 0 on clean pass and code 1 on failure. Supporting `-- --negative-test` verifies failure detection by demonstrating exit code 1.

## Before submitting changes

- Confirm the relevant task's Checkup criteria pass (`TASKS.md`).
- Confirm `scripts/core/` still has no `Node`/scene dependencies (`architecture.md`).
- Update the task's `Status` in `TASKS.md`.
- Note which files you touched and why (`AGENTS.md`, rule 14).
