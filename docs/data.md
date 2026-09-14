# Data

There's no external database in this project — card, hero, and bot data live as Godot `Resource` files (`.tres`) under `data/`, per `TDD.md` §3.2.

- `CardResource` is the base class; `CreatureResource`, `SpellResource`, `LandscapeResource`, `HeroResource` extend it. All exported fields are defined in `TDD.md` §3.2 — don't add fields ad hoc without updating that section first.
- `CardDatabase` (autoload) loads every `.tres` under `data/cards/` at startup and is the only lookup point by `id`. Nothing else should keep its own copy of card stats.
- `id` (String) must be unique per card. There's no database constraint to enforce this — it's a manual/review responsibility until an import/validation script exists. If duplicate IDs become a recurring problem, flag it under `TASKS.md` §5 rather than building a fix unprompted.
- Bot data (`BotArchetype`) follows the same pattern: weight tables live in `.tres` under `data/bot_profiles/`, not hardcoded in `BotAI`.
- **Bulk authoring:** for 100+ cards, `TDD.md` §3.2 suggests a one-time import script generating `.tres` from a spreadsheet/CSV rather than hand-editing each Resource — this hasn't been built yet.
- **Save format for player decks/progression is still open** (`TDD.md` §6: `ResourceSaver` vs. plain JSON). Don't pick one mid-task without checking `TASKS.md` M2-03 first.
