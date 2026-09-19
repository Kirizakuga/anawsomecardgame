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
- `scenes/match/CardViewCheck.tscn` (M1-02: CardView rendering, stats, floop, and drag/snapback)
- `scenes/match/KingdomCheck.tscn` (M1-03: KingdomView life, lanes, essence deduction, and drop validation)
- `scenes/match/CombatCheck.tscn` (M1-04: Combat resolution, creature-vs-creature, and unblocked direct damage)
- `scenes/match/FloopCheck.tscn` (M1-05: Floop interaction logic, secondary effects, and cost deduction)
- `scenes/match/HumanDecisionCheck.tscn` (M1-06: HumanDecisionSource action queueing, submit signal, and KingdomView routing)
- `scenes/match/DummyAICheck.tscn` (M1-07: DummyAIDecisionSource random legal actions and full simulated match resolution)
- `scenes/match/WinConditionCheck.tscn` (M1-08: Win condition check, life <= 0, match-end state, and turn limit)
- `scenes/deckbuilder/HeroSelectCheck.tscn` (M2-01: Hero selection UI, HeroResource loading, and affinity-based card filtering)
- `scenes/deckbuilder/DeckBuilderCheck.tscn` (M2-02: Deck assembly UI, 30 main cards limit, max 3 copies, and separate 5-8 landscape deck)
- `scenes/deckbuilder/DeckSaveLoadCheck.tscn` (M2-03: Deck save/load to JSON, disk persistence, corruption handling, and CardDatabase resolution)
- `scenes/match/BotArchetypeCheck.tscn` (M3-01: BotArchetypeResource loading, archetype profiles, and weight differentiation)

## Before submitting changes

- Confirm the relevant task's Checkup criteria pass (`TASKS.md`).
- Confirm `scripts/core/` still has no `Node`/scene dependencies (`architecture.md`).
- Update the task's `Status` in `TASKS.md`.
- Note which files you touched and why (`AGENTS.md`, rule 14).
