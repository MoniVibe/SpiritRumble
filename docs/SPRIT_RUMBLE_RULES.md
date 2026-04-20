# Sprit Rumble Rules Baseline (MVP)

This document captures the deterministic rules currently implemented in `puredots_turn_engine`.

## Turn Phases

1. `startTurn` (internal)
2. `draftFromPool`
3. `mainActions`
4. `resolveCombat` (internal, immediate after attack command)
5. `chooseDefenders`
6. `endTurn` (internal handoff)
7. `gameOver`

## Shared State

- Shared public pool size: `5`
- Active player drafts from pool:
  - Turn 1 / first player: `1` pick
  - All other turns: `2` picks (configurable by `MatchRules`)
- Pool refills deterministically from catalog order.

## Command Set

- `DraftFromPoolMove`
- `PlayToNewUnitMove`
- `AddToExistingUnitMove`
- `ChooseAttackerMove`
- `AttackUnitMove`
- `ChooseDefenderMove`
- `EndTurnMove`

All commands are validated through `TurnEngine.canApply(...)` before state transition.

## Unit Model

- A unit is a list of piece instances.
- Each unit can select:
  - one attacking piece index
  - one defending piece index
- Each unit may attack at most once per turn.

## Combat Resolution

### Inputs

- Attacker piece: `Element`, `AttackMode`, `Attack`
- Defender piece: `Element`, `DefenseMode`, `Defense`

### Advantages

- Element cycle:
  - Blue > Red
  - Red > Green
  - Green > Blue
- Mode advantage:
  - Physical > Magical
  - Magical > Physical

### Kill Rule

Defender piece is destroyed only if all are true:

1. attacker has element advantage
2. attacker has mode advantage
3. attacker `Attack >= defender Defense`

If any check fails, defender survives.

## Win Conditions

- Opposing shaman health reaches `0`
- Opposing side has no units remaining on field

## Command/History

- Every successful command is recorded in `GameState.history`.
- Human-readable events are appended to `GameState.eventLog`.
