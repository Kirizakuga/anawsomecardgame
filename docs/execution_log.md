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

## M1-06 — HumanDecisionSource
**Date:** 2026-09-19
**Model:** Planner=opus, Executioner=sonnet
**Files changed:**
- `scripts/core/human_decision_source.gd` — MODIFIED: Implemented action queueing methods (queue_card_play, queue_floop, queue_landscape, queue_attack_target, queue_pact_proposal, queue_betrayal), clear_actions, and submit signal emission. Pure RefCounted, zero Node dependencies.
- `scripts/ui/kingdom_view.gd` — MODIFIED: Added decision_source hook, wired lane card drop to queue_card_play, wired card floop_triggered to queue_floop.
- `scripts/ui/lane.gd` — MODIFIED: Wired current_card_view floop listener to KingdomView on occupant set.
- `scenes/match/HumanDecisionCheck.tscn` — NEW: Headless check scene.
- `scripts/ui/human_decision_check.gd` — NEW: Headless check script covering action initialization, queues, clearing, submit, and UI drop/floop integration.
- `docs/development.md` — MODIFIED: Added HumanDecisionCheck.tscn to verification scene list.
- `docs/TASKS.md` — MODIFIED: M1-06 status → Done, §5 entry added.

**Planner decisions applied:**
- Standardized RoundActions dictionary schemas for cards_to_play (`{"card": CardResource, "lane": int}`) and attack_targets (`{"attacker_lane": int, "target_player_id": int, "target_lane": int}`).
- M1-03 carry-forward resolved: KingdomView routes actions through HumanDecisionSource.decision_source while keeping local view updates for standalone test compatibility.

**Verification (headless check output, exit code 0):**
```
[CHECK] PASS: Case a: request_actions properly initializes pending_actions
[CHECK] PASS: Case a: pending_actions.player_id matches kingdom.player_id (42)
[CHECK] PASS: Test cards loaded from CardDatabase
[CHECK] PASS: Case b: cards_to_play has 1 entry
[CHECK] PASS: Case b: cards_to_play recorded correct card and lane
[CHECK] PASS: Case c: queue_floop recorded card
[CHECK] PASS: queue_landscape recorded landscape
[CHECK] PASS: Case d: queue_attack_target recorded 1 entry
[CHECK] PASS: Case d: attack_targets schema matches
[CHECK] PASS: queue_pact_proposal recorded entry
[CHECK] PASS: pact_proposals schema matches
[CHECK] PASS: queue_betrayal recorded betrayal_target
[CHECK] PASS: clear_actions cleared cards_to_play
[CHECK] PASS: clear_actions cleared cards_to_floop
[CHECK] PASS: clear_actions reset betrayal_target to -1
[CHECK] PASS: Case e: submit() emitted actions_ready signal
[CHECK] PASS: Case e: emitted actions matches pending_actions
[CHECK] PASS: Case e: emitted actions has correct player_id (7)
[CHECK] PASS: Case e: emitted actions has queued card play
[CHECK] PASS: Case e: emitted actions has queued floop
[CHECK] PASS: UI drop: hand contains CardView
[CHECK] PASS: Case f: dropping card into lane queues card play in HumanDecisionSource
[CHECK] PASS: Case f: queued entry contains correct card and lane index 1
[CHECK] PASS: UI floop: lane 0 contains CardView
[CHECK] PASS: Case g: triggering floop on lane CardView queues floop in HumanDecisionSource
[CHECK] PASS: Case g: queued floop card is goblin
[CHECK] SUMMARY: 26 passed, 0 failed, 0 manual
HumanDecisionCheck: PASS
```

**Failure detection verified:** Inverted player_id expectation (`player_id == 999`), produced `[CHECK] FAIL`, exit code 1, "HumanDecisionCheck: FAIL". Reverted to clean pass.

**[CHECK] MANUAL:** None — all criteria scriptable.

## M1-07 — Dummy AI opponent (random legal move)
**Date:** 2026-09-19
**Model:** Planner=opus, Executioner=sonnet
**Files changed:**
- `scripts/ai/dummy_ai_decision_source.gd` — NEW: DummyAIDecisionSource extending DecisionSource, picks random affordable creature plays into empty lanes and affordable floops. Pure RefCounted, zero Node dependencies.
- `scripts/autoload/resolution_engine.gd` — MODIFIED: Applies submitted cards_to_play and cards_to_floop from RoundActions before creature combat.
- `scenes/match/DummyAICheck.tscn` — NEW: Headless check scene.
- `scripts/autoload/dummy_ai_check.gd` — NEW: Headless test runner testing move legality, 0-essence, full-lane limits, and 3 full matches to completion.
- `docs/development.md` — MODIFIED: Added DummyAICheck.tscn to verification scene list.
- `docs/TASKS.md` — MODIFIED: M1-07 status → Done, §5 DECIDED BY PLANNER entry added.

**Planner decisions applied:**
- DECIDED BY PLANNER: DummyAIDecisionSource in scripts/ai/dummy_ai_decision_source.gd randomly plays affordable creature cards into empty lanes and queues affordable floops. ResolutionEngine.resolve() applies submitted cards_to_play and cards_to_floop before creature combat pass. Recorded in TASKS.md §5.

**Verification (headless check output, exit code 0):**
```
[CHECK] PASS: Unit test cards loaded
[CHECK] PASS: DummyAI emits actions_ready
[CHECK] PASS: Emitted actions has correct player_id
[CHECK] PASS: Total cost of played cards (5) does not exceed starting essence (5)
[CHECK] PASS: Played cards assigned to unique, valid lanes (0..2)
[CHECK] PASS: DummyAI makes no plays when essence is 0 and card is unaffordable
[CHECK] PASS: DummyAI makes no plays when all lanes are full
[CHECK] PASS: Match 1 completed cleanly without crash or infinite loop
[CHECK] PASS: Match 1: all Dummy AI moves were strictly legal
[CHECK] PASS: Match 1: life totals and elimination state remained valid
[CHECK] PASS: Match 2 completed cleanly without crash or infinite loop
[CHECK] PASS: Match 2: all Dummy AI moves were strictly legal
[CHECK] PASS: Match 2: life totals and elimination state remained valid
[CHECK] PASS: Match 3 completed cleanly without crash or infinite loop
[CHECK] PASS: Match 3: all Dummy AI moves were strictly legal
[CHECK] PASS: Match 3: life totals and elimination state remained valid
[CHECK] SUMMARY: 16 passed, 0 failed, 0 manual
DummyAICheck: PASS
```

**Failure detection verified:** Inverted player_id check condition (`emitted_actions.player_id == 999`), produced `[CHECK] FAIL`, exit code 1, "DummyAICheck: FAIL". Reverted to clean pass.

**[CHECK] MANUAL:** None — all criteria scriptable.

## M1-08 — Win condition check
**Date:** 2026-09-19
**Model:** Planner=opus, Executioner=sonnet
**Files changed:**
- `scripts/autoload/game_manager.gd` — MODIFIED: Added match_ended signal, is_match_over, winner, reset_match, end_match, and updated check_win_condition to handle Life <= 0 elimination, turn limit resolution by highest life, tie handling, and double-emission guard.
- `scripts/autoload/resolution_engine.gd` — MODIFIED: Checks win conditions after floop and combat steps, stops further combat when match ends.
- `scenes/match/WinConditionCheck.tscn` — NEW: Headless check scene.
- `scripts/autoload/win_condition_check.gd` — NEW: Headless test runner testing combat lethal damage, floop lethal damage, turn-limit highest-life/tie, no double-trigger on subsequent calls/damage, active non-terminal state, and direct elimination.
- `docs/development.md` — MODIFIED: Added WinConditionCheck.tscn to verification scene list.
- `docs/TASKS.md` — MODIFIED: M1-08 status → Done, §5 DECIDED BY PLANNER entry added.

**Planner decisions applied:**
- DECIDED BY PLANNER: GameManager handles match-end lifecycle via signal match_ended(winner_id), is_match_over, and winner. check_win_condition() eliminates kingdoms with life <= 0, declares single survivor as winner, resolves turn limit by unique highest life total (or -1 on tie/simultaneous elimination), and guards against double emissions. ResolutionEngine checks win condition after lethal floop damage and creature attacks. Recorded in TASKS.md §5.

**Verification (headless check output, exit code 0):**
```
[CHECK] PASS: Test 1 - Combat damage reduced opponent life to <= 0 (life: -5)
[CHECK] PASS: Test 1 - Opponent is_eliminated marked true after lethal combat damage
[CHECK] PASS: Test 1 - GameManager.is_match_over is true
[CHECK] PASS: Test 1 - GameManager.winner declared player 0
[CHECK] PASS: Test 1 - match_ended signal emitted exactly once (count: 1)
[CHECK] PASS: Test 1 - match_ended signal emitted winner_id 0
[CHECK] PASS: Test 2 - cr_flame_drake loaded with floop effect
[CHECK] PASS: Test 2 - Floop direct damage reduced opponent life to <= 0 (life: 0)
[CHECK] PASS: Test 2 - Opponent is_eliminated marked true after lethal floop damage
[CHECK] PASS: Test 2 - GameManager.is_match_over is true
[CHECK] PASS: Test 2 - GameManager.winner declared player 0
[CHECK] PASS: Test 2 - match_ended signal emitted exactly once (count: 1)
[CHECK] PASS: Test 2 - match_ended signal emitted winner_id 0
[CHECK] PASS: Test 3 - Turn limit reached declared player 0 as winner by highest life (20 > 14)
[CHECK] PASS: Test 3 - GameManager.is_match_over is true
[CHECK] PASS: Test 3 - GameManager.winner is 0
[CHECK] PASS: Test 3 - match_ended signal emitted exactly once (count: 1)
[CHECK] PASS: Test 3 - match_ended signal emitted winner_id 0
[CHECK] PASS: Test 3 - Tie in life totals at turn limit resolves to draw (-1)
[CHECK] PASS: Test 3 - Tie ends match (is_match_over is true)
[CHECK] PASS: Test 3 - match_ended emitted once on tie (count: 1)
[CHECK] PASS: Test 3 - match_ended emitted -1 on tie
[CHECK] PASS: Test 4 - Initial check_win_condition ended match with winner 0
[CHECK] PASS: Test 4 - First trigger emitted match_ended exactly once
[CHECK] PASS: Test 4 - Subsequent check_win_condition calls return winner 0
[CHECK] PASS: Test 4 - Subsequent check_win_condition calls did NOT re-emit match_ended
[CHECK] PASS: Test 4 - GameManager.end_match(1) after match over did NOT re-emit match_ended
[CHECK] PASS: Test 4 - Winner was NOT overwritten by end_match call
[CHECK] PASS: Test 4 - ResolutionEngine.resolve() after match over did NOT re-emit match_ended
[CHECK] PASS: Test 4 - Winner remains 0 after subsequent combat resolution
[CHECK] PASS: Test 5 - check_win_condition returns -1 when both players alive and turn limit not reached
[CHECK] PASS: Test 5 - GameManager.is_match_over is false
[CHECK] PASS: Test 5 - GameManager.winner is -1
[CHECK] PASS: Test 5 - match_ended was NOT emitted (count: 0)
[CHECK] PASS: Test 5 - Neither player is marked eliminated
[CHECK] PASS: Test 6 - Before check_win_condition, p0.is_eliminated is false
[CHECK] PASS: Test 6 - check_win_condition marked p0.is_eliminated true
[CHECK] PASS: Test 6 - check_win_condition declared survivor player 1 as winner
[CHECK] PASS: Test 6 - GameManager.is_match_over is true
[CHECK] PASS: Test 6 - GameManager.winner is 1
[CHECK] PASS: Test 6 - match_ended emitted exactly once for direct elimination
[CHECK] PASS: Test 6 - match_ended emitted winner 1
[CHECK] SUMMARY: 42 passed, 0 failed, 0 manual
WinConditionCheck: PASS
```

**Failure detection verified:** Inverted check condition (`p1.life > 0`), produced `[CHECK] FAIL`, exit code 1, "WinConditionCheck: FAIL". Reverted to clean pass.

**[CHECK] MANUAL:** None — all criteria scriptable.


