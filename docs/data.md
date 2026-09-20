# Data

There's no external database in this project — card, hero, and bot data live as Godot `Resource` files (`.tres`) under `data/`, per `TDD.md` §3.2.

- `CardResource` is the base class; `CreatureResource`, `SpellResource`, `LandscapeResource` extend it. `HeroResource` extends `Resource` directly. `SpellResource` includes an optional `affinity: String` export to allow affinity-aligned spells.
- `CardDatabase` (autoload) loads every `.tres` under `data/cards/` at startup into `cards` (`CardResource`) and `heroes` (`HeroResource`). It provides lookup by `id` (`get_card`, `get_hero`) and affinity card filtering (`get_cards_by_affinity`, `get_eligible_cards_for_hero`). Nothing else should keep its own copy of card stats.
- `id` (String) must be unique per card. There's no database constraint to enforce this — it's a manual/review responsibility until an import/validation script exists. If duplicate IDs become a recurring problem, flag it under `TASKS.md` §5 rather than building a fix unprompted.
- Bot data (`BotArchetype`) follows the same pattern: weight tables live in `.tres` under `data/bot_profiles/`, not hardcoded in `BotAI`.
- Anti-pile-on combat balance uses `PileOnConfigResource` saved under `data/combat/` (e.g. `default_pile_on_config.tres`), exposing `threshold` and `attacker_multipliers` per concurrent attacker count on a single Kingdom.
- Alliance and pact rules use `PactConfigResource` saved under `data/pact/` (e.g. `default_pact_config.tres`), tuning `max_essence_lend_per_turn` and creature lending allowance.
- **Bulk authoring:** for 100+ cards, `TDD.md` §3.2 suggests a one-time import script generating `.tres` from a spreadsheet/CSV rather than hand-editing each Resource — this hasn't been built yet.
- **Decks and player progression use plain JSON.** Persist card and Hero IDs plus primitive values, then resolve card data through `CardDatabase` when loading. JSON keeps local saves inspectable and avoids serializing editor-owned Resource references.
- **Profile scope:** v1 supports one local profile per device. Do not add profile/account selection before a task explicitly expands this scope.
