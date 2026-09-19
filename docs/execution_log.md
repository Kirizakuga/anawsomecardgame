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
