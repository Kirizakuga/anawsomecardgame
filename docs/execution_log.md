# Execution Log

## M1-04 — Combat resolution (creature-vs-creature, direct damage)
**Date:** 2026-09-19
**Files changed:**
- `scripts/core/combat_resolver.gd` — NEW: Pure RefCounted combat math (damage reduction, blocker destruction, unblocked life damage)
- `scripts/core/combat_check.gd` — NEW: Headless check script with 4 test cases + ResolutionEngine integration + real .tres card verification
- `scenes/match/CombatCheck.tscn` — NEW: Check scene wiring combat_check.gd
- `scripts/autoload/resolution_engine.gd` — MODIFIED: Wired CombatResolver into creature step of resolution order, kept stubs for other categories
- `docs/development.md` — MODIFIED: Added CombatCheck.tscn to verification scene list
- `docs/TASKS.md` — MODIFIED: M1-04 status → Done, added §5 resolution entry

**Planner decisions applied:**
- Decision C: Defense = damage reduction (net = max(0, ATK - DEF)). Blocker destroyed if net > 0, no retaliation, no overflow to Life. Unblocked = ATK → Kingdom Life.
- 2-player resolution is sequential (p0 attacks p1, then p1 attacks p0) — ponytail for M4 simultaneous resolution.

**Verification (headless check output):**
```
[CHECK] PASS: Case a - Blocked lane destroyed (ATK 3 vs DEF 2, net=1>0, no life damage)
[CHECK] PASS: Case b - Blocked lane survived (ATK 2 vs DEF 3, net=0, no life damage)
[CHECK] PASS: Case c - Unblocked lane direct damage (ATK 4, Life 25 -> 21)
[CHECK] PASS: Exact Life totals after combat match expected (25 attacker, 21 defender)
[CHECK] PASS: Case d - Empty lane vs empty lane no-op
[CHECK] PASS: ResolutionEngine.resolve() 2-player combat step integration
[CHECK] PASS: Real CardDatabase .tres cards combat math verified
CombatCheck: PASS
```

**[CHECK] MANUAL:** None — all checks are scriptable.
