# Implementation Plan - Telegraphed Reactive AI

This plan outlines the transition from static, repeating enemy patterns to a telegraphed, reactive AI system inspired by games like *Into the Breach*. Improvements will make the game more tactical and turn the "Planning Phase" into a puzzle of countering known enemy intents.

## Proposed AI Architecture: "Intent System"

### 1. Planning Step (Turn Start)
At the beginning of each planning phase:
- Each Enemy evaluates the board state.
- They select a sequence of 3 instructions (one for each sub-round).
- These chosen instructions are stored as their "Intent".

### 2. Telegraphed UI
- Enemies visually indicate their intended actions on the floor or via floating icons.
- Fire actions show a target line/zone.
- Move actions show a path arrow.

## Components to Modify

### `Enemy.gd`
- Add `intent_buffer: Array[Instruction]`
- Implement `plan_actions(robots: Array[Robot], level: LevelGenerator)`
- Add visual indicators (ghosted meshes or 3D lines) for intents.

### `TurnEngine.gd`
- Current: Loops through `pattern`.
- New: Uses `intent_buffer` populated by the `GameManager` at the start of the turn.

### `GameManager.gd`
- Trigger `enemy.plan_actions()` at the start of `PLANNING_PHASE`.

## AI Logic Options

### Level 1: Heuristic Scorer
For each possible action sequence (or a subset of "smart" sequences):
1. Simulate the result (position after 3 steps).
2. Score based on:
   - Proximity to nearest robot.
   - Line-of-sight for weapons.
   - Avoidance of gaps.
3. Highest score Wins.

### Level 2: Goal-Based
- **Type A (Chaser):** If far, Move towards robot; If close, Shove/Melee.
- **Type B (Gunner):** Stay 3-5 tiles away, Turn to line up Laser.

## Task Breakdown

- [ ] **Task 1: Core Intent Logic** - Modify Enemy to hold an intent buffer and provide a basic "Plan" function that picks instructions based on simple logic (e.g. Turn to face nearest robot).
- [ ] **Task 2: Visual Telegraphs** - Implement 3D lines or arrows that appear on the board during the Planning Phase showing where enemies will move/fire.
- [ ] **Task 3: Heuristic Solver** - Implement the scoring system so enemies actually try to "win" the sub-rounds.
- [ ] **Task 4: HUD Updates** - Show enemy intents in the execution order panel (e.g. "Enemy 1: Fire Laser -> Move Forward -> Wait").
