# Execution Log

## M1-04 — Combat resolution (creature-vs-creature, direct damage)
**Date:** 2026-09-19
**Model:** Planner=opus, Executioner=sonnet
**Files changed:**
- `scripts/core/combat_resolver.gd` — NEW: Pure RefCounted combat math (damage reduction, blocker destruction, unblocked life damage)
- `scripts/autoload/combat_check.gd` — NEW: Headless check script with `_check()` helper, summary, exit(1) on failure (moved from scripts/core/ during review)
- `scenes/match/CombatCheck.tscn` — NEW: Check scene wiring combat_check.gd
- `scripts/autoload/resolution_engine.gd` — MODIFIED: Wired CombatResolver into creature step of resolution order, kept stubs for other categories
- `docs/development.md` — MODIFIED: Added CombatCheck.tscn to verification scene list
- `docs/TASKS.md` — MODIFIED: M1-04 status → Done, added §5 resolution entry + DECIDED BY PLANNER entry

**Planner decisions applied:**
- Decision C: Defense = damage reduction (net = max(0, ATK - DEF)). Blocker destroyed if net > 0, no retaliation, no overflow to Life. Unblocked = ATK → Kingdom Life.
- DECIDED BY PLANNER: 2-player sequential both-attack (p0 then p1). TurnManager has no active-player concept. First-mover advantage acknowledged, acceptable for 2p MVP, revisit at M4.

**Verification (headless check output, exit code 0):**
```
[CHECK] PASS: Initial Life totals: attacker 25, defender 25
[CHECK] PASS: Combat resolution returns 3 lane log entries
[CHECK] PASS: Case a - Blocked lane destroyed (ATK 3 vs DEF 2, net=1>0, no life damage)
[CHECK] PASS: Case b - Blocked lane survived (ATK 2 vs DEF 3, net=0, no life damage)
[CHECK] PASS: Case c - Unblocked lane direct damage (ATK 4, Life 25 -> 21)
[CHECK] PASS: Exact Life totals after combat match expected (25 attacker, 21 defender)
[CHECK] PASS: Case d - Empty lane vs empty lane no-op
[CHECK] PASS: ResolutionEngine.resolve() 2-player combat step integration
[CHECK] PASS: CardDatabase test creatures loaded (drake, golem, treant)
[CHECK] PASS: Real CardDatabase .tres cards combat math verified
[CHECK] SUMMARY: 10 passed, 0 failed, 0 manual
CombatCheck: PASS
```

**Failure detection verified:** Temporarily changed `net_damage > 0` to `net_damage >= 0` — produced 2 FAIL lines, exit code 1, "CombatCheck: FAIL". Reverted.

**[CHECK] MANUAL:** None — all checks are scriptable.

**Review fixes applied (2026-09-19):**
1. Recorded sequential both-attack as DECIDED BY PLANNER in TASKS.md §5 and resolution_engine.gd
2. Moved combat_check.gd from scripts/core/ to scripts/autoload/ (AGENTS rule 3)
3. Replaced assert() with _check() helper, added [CHECK] SUMMARY + quit(1) on failure
4. Confirmed .gd.uid files committed, proved failure detection with exit code 1

## M1-05 — Floop interaction logic
**Date:** 2026-09-19
**Model:** Planner=opus, Executioner=sonnet
**Files changed:**
- `scripts/data/floop_effect_resource.gd` — MODIFIED: Added effect_type and effect_value exported fields
- `data/floop_effects/fl_scout_snoop.tres` — NEW: Floop effect for goblin scout (draw_card, value 1, cost 1 essence)
- `data/floop_effects/fl_golem_fortify.tres` — NEW: Floop effect for stone golem (heal_life, value 2, cost 1 essence)
- `data/floop_effects/fl_drake_breath.tres` — NEW: Floop effect for flame drake (direct_damage, value 2, cost 2 essence)
- `data/cards/creatures/cr_goblin_scout.tres` — MODIFIED: Wired fl_scout_snoop.tres
- `data/cards/creatures/cr_stone_golem.tres` — MODIFIED: Wired fl_golem_fortify.tres
- `data/cards/creatures/cr_flame_drake.tres` — MODIFIED: Wired fl_drake_breath.tres
- `scripts/core/floop_resolver.gd` — NEW: Pure RefCounted FloopResolver implementing can_floop and resolve_floop
- `scripts/ui/card_view.gd` — MODIFIED: Added card_data and floop_effect guards to _on_floop_pressed
- `scenes/match/FloopCheck.tscn` — NEW: Headless check scene
- `scripts/autoload/floop_check.gd` — NEW: Headless test runner with Cases 1–7 and summary output
- `docs/development.md` — MODIFIED: Added FloopCheck.tscn to verification scenes list
- `docs/TASKS.md` — MODIFIED: M1-05 status → Done, added §5 DECIDED BY PLANNER entry

**Planner decisions applied:**
- DECIDED BY PLANNER: FloopEffectResource extended with effect_type ("draw_card", "heal_life", "direct_damage", "buff_attack") and effect_value. Initial floop effects given to 3 placeholder cards: cr_goblin_scout (draw 1, cost 1), cr_stone_golem (heal 2, cost 1), cr_flame_drake (damage 2, cost 2). Recorded in TASKS.md §5.

**Verification (headless check output, exit code 0):**
```
[CHECK] PASS: Case 1: can_floop returns true for cr_goblin_scout with essence=2
[CHECK] PASS: Case 1: cr_goblin_scout draws card and deducts 1 essence (2 -> 1)
[CHECK] PASS: Case 2: can_floop returns true for cr_stone_golem with essence=1
[CHECK] PASS: Case 2: cr_stone_golem heals 2 life (20 -> 22) and deducts 1 essence (1 -> 0)
[CHECK] PASS: Case 3: can_floop returns true for cr_flame_drake with essence=3
[CHECK] PASS: Case 3: cr_flame_drake deals 2 direct damage (25 -> 23) and deducts 2 essence (3 -> 1)
[CHECK] PASS: Case 4: can_floop returns false when essence (1) < cost (2)
[CHECK] PASS: Case 4: resolve_floop fails with insufficient essence, essence unchanged
[CHECK] PASS: Case 5: can_floop returns false for card with no floop effect
[CHECK] PASS: Case 5: resolve_floop returns success=false for card with no floop effect
[CHECK] PASS: Case 6: CardView with floop effect card shows FloopButton
[CHECK] PASS: Case 6: CardView with no floop effect card hides FloopButton
[CHECK] PASS: Case 6: _on_floop_pressed on no-floop card does not toggle is_flooped
[CHECK] PASS: Case 7: CardDatabase loads 3 cards with floop effects intact
[CHECK] SUMMARY: 14 passed, 0 failed, 0 manual
FloopCheck: PASS
```

**Failure detection verified:** Inverted check condition, produced `[CHECK] FAIL`, exit code 1, "FloopCheck: FAIL". Reverted to clean pass.

**[CHECK] MANUAL:** None — all criteria scriptable.
