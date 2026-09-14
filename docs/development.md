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

## Before submitting changes

- Confirm the relevant task's Checkup criteria pass (`TASKS.md`).
- Confirm `scripts/core/` still has no `Node`/scene dependencies (`architecture.md`).
- Update the task's `Status` in `TASKS.md`.
- Note which files you touched and why (`AGENTS.md`, rule 14).
