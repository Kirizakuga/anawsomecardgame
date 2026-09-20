# Rules for AI (and human) collaborators

These rules apply to anyone — human or AI — making changes in this repo. They exist to keep the architecture in `TDD.md` intact and to stop contributors, especially AI, from silently overwriting or reorganizing each other's work.

1. Read `GDD.md` and `TDD.md` in full before writing any code. Don't infer game rules or architecture from a `TASKS.md` entry alone — task specs assume that context.
2. Work one task ID at a time (e.g. `M1-04`). State which task you're working on before starting, and don't expand scope into another task's territory.
3. Keep `scripts/core/` free of `Node`/scene references (`TDD.md` §2, §3.3). If logic needs the scene tree, it belongs in `scripts/ui/` or a scene script, not `core/`.
4. Never make `ResolutionEngine`, `TurnManager`, or any core logic branch on "is this a bot or a human." Everything goes through the `DecisionSource` interface (`TDD.md` §3.4).
5. Card, hero, and bot-archetype data lives in `.tres` Resources under `data/` — don't hardcode stats, costs, or effects directly in scripts. See `data.md`.
6. Don't invent new mechanics, fields, or systems that aren't in `GDD.md`/`TDD.md`. If a task seems to need one, stop and add it to `TASKS.md` §5 (Open Questions Raised) instead of deciding unilaterally. Exception: in an orchestrated run, the Planner may pick a simple default for a
   documented gap; it must record it in §5 as `DECIDED BY PLANNER (review later)`.
7. Definition of Done = the task's Checkup/Acceptance Criteria in `TASKS.md`, not "it runs" or "it compiles."
8. When you finish or get stuck on a task, update its `Status` inline in `TASKS.md` (`Not Started` → `In Progress` / `Blocked — [reason]` / `Done — [agent/person], [date]`). In an orchestrated run, the Planner updates Status.
9. Naming: `snake_case` for files/variables, `PascalCase` for class/scene names, matching existing conventions in `TDD.md` §2–3.
10. Only touch files inside the scope of the task you're doing. If a dependency task isn't done yet, say so in your task's status rather than stubbing around it silently — or finish the dependency first if it's trivial.
11. Don't delete, rename, or overwrite existing `.tres` cards, scenes, or another in-progress task's files without being explicitly asked to. If something looks wrong or stale, flag it — don't "fix" it silently.
12. No networking work unless explicitly working an `M6` task (`TASKS.md` §0, rule 9) — everything before that assumes local-only human + bots.
13. Keep `ResolutionEngine`'s resolution order deterministic per `TDD.md` §3.6 (Landscapes → Spells → Creatures → Pact changes → Betrayals) — don't reorder it just to make a feature easier to implement.
14. Before finishing, state plainly which files you created or changed and why, so the next contributor (human or AI) doesn't have to diff-hunt to find out.
15. Prefer simple, readable GDScript over clever abstractions. Don't add plugins/addons, change project settings, or restructure the folders in `TDD.md` §2 unless the task explicitly calls for it.
16. When implementation makes `README.md`, `architecture.md`, `data.md`, or `development.md` factually stale, update the affected companion doc in the same task and state that change in the handoff.
17. Run every Checkup you can headless and record the output. Work that genuinely needs a
    human or manual Godot-editor check (drag/drop feel, layout, animation) must be listed
    in `execution_log.md` under "Pending human verification" with exact steps and the
    acceptance condition. The task may be marked Done before that check happens, but the
    pending item must be logged, and an agent must never claim a manual check passed
    when it did not run it.
18. In each execution_log.md entry, record the model name you are running as. If it is not
    the primary model, mark the entry "REVIEWED BY FALLBACK MODEL".
If you're ever unsure whether something is in scope: ask, or flag it in `TASKS.md` §5 — don't guess and proceed.
