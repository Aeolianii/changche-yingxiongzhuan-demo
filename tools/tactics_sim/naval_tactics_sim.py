#!/usr/bin/env python3
"""Deterministic headless model for the target 3v3 double-beacon rules.

This is deliberately isolated from the Godot runtime.  It is a falsification
tool for strategy and balance assumptions, not the production battle model.
"""

from __future__ import annotations

import argparse
import copy
import json
import math
import random
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Iterable, Optional


BOARD_WIDTH = 12
BOARD_HEIGHT = 8
MAX_ROUNDS = 6
SCORE_TO_WIN = 5
SIDES = ("A", "B")
DIRECTIONS = (
    (1, 0),
    (1, 1),
    (0, 1),
    (-1, 1),
    (-1, 0),
    (-1, -1),
    (0, -1),
    (1, -1),
)

CLASS_STATS = {
    "fast": {"hp": 50, "move": 3},
    "gunship": {"hp": 70, "move": 2},
    "escort": {"hp": 85, "move": 2},
}

POLICIES = ("balanced", "camp", "focus", "objective", "kite", "guard_spam")
SIGNATURE_ACTIONS = {
    "fast": {"disrupt", "ram"},
    "gunship": {"broadside"},
    "escort": {"short_cannon", "guard"},
}


@dataclass
class Ship:
    ship_id: str
    side: str
    kind: str
    position: tuple[int, int]
    facing: int
    hp: int
    max_hp: int
    move: int
    activated: bool = False
    ever_activated: bool = False
    destabilized: bool = False
    suppressed: bool = False
    braced: bool = False
    guard_source: Optional[str] = None

    @property
    def alive(self) -> bool:
        return self.hp > 0


@dataclass(frozen=True)
class Maneuver:
    position: tuple[int, int]
    facing: int
    kind: str
    distance: int


@dataclass(frozen=True)
class CombatAction:
    kind: str
    target_id: Optional[str] = None


@dataclass(frozen=True)
class ActivationChoice:
    ship_id: str
    maneuver: Maneuver
    combat: CombatAction


@dataclass
class MatchResult:
    seed: int
    map_variant: int
    policy_a: str
    policy_b: str
    winner: Optional[str]
    victory_type: str
    terminal_round: int
    complete_rounds: int
    score_a: int
    score_b: int
    hp_a: int
    hp_b: int
    sunk_ship_count: int
    preactivation_sink: bool
    action_counts: dict[str, int]
    signature_classes: list[str]
    opening_signature: list[str]


@dataclass
class BattleState:
    seed: int
    map_variant: int
    islands: set[tuple[int, int]]
    beacons: tuple[tuple[int, int], tuple[int, int]]
    ships: dict[str, Ship]
    round_number: int = 1
    score: dict[str, int] = field(default_factory=lambda: {"A": 0, "B": 0})
    action_counts: Counter = field(default_factory=Counter)
    signature_classes: set[str] = field(default_factory=set)
    opening_signature: list[str] = field(default_factory=list)
    preactivation_sink: bool = False

    def living(self, side: Optional[str] = None) -> list[Ship]:
        ships = [ship for ship in self.ships.values() if ship.alive]
        if side is not None:
            ships = [ship for ship in ships if ship.side == side]
        return ships

    def occupied(self, exclude: Optional[str] = None) -> set[tuple[int, int]]:
        return {
            ship.position
            for ship in self.living()
            if exclude is None or ship.ship_id != exclude
        }


MAP_VARIANTS = (
    ({(5, 3), (6, 4)}, ((5, 2), (6, 5))),
    ({(5, 3), (6, 4), (5, 4), (6, 3)}, ((5, 1), (6, 6))),
    ({(5, 2), (6, 5)}, ((4, 3), (7, 4))),
    ({(4, 3), (7, 4), (5, 4), (6, 3)}, ((5, 2), (6, 5))),
    ({(4, 2), (7, 5), (5, 4), (6, 3)}, ((5, 1), (6, 6))),
    ({(5, 3), (6, 4), (4, 5), (7, 2)}, ((4, 2), (7, 5))),
)


def other_side(side: str) -> str:
    return "B" if side == "A" else "A"


def chebyshev(a: tuple[int, int], b: tuple[int, int]) -> int:
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]))


def in_bounds(cell: tuple[int, int]) -> bool:
    return 0 <= cell[0] < BOARD_WIDTH and 0 <= cell[1] < BOARD_HEIGHT


def add_cell(a: tuple[int, int], b: tuple[int, int]) -> tuple[int, int]:
    return (a[0] + b[0], a[1] + b[1])


def make_state(seed: int) -> BattleState:
    variant = seed % len(MAP_VARIANTS)
    islands, beacons = MAP_VARIANTS[variant]
    setup = {
        "A_fast": ("A", "fast", (1, 1), 0),
        "A_gunship": ("A", "gunship", (1, 3), 0),
        "A_escort": ("A", "escort", (1, 6), 0),
        "B_fast": ("B", "fast", (10, 6), 4),
        "B_gunship": ("B", "gunship", (10, 4), 4),
        "B_escort": ("B", "escort", (10, 1), 4),
    }
    ships: dict[str, Ship] = {}
    for ship_id, (side, kind, position, facing) in setup.items():
        stats = CLASS_STATS[kind]
        ships[ship_id] = Ship(
            ship_id=ship_id,
            side=side,
            kind=kind,
            position=position,
            facing=facing,
            hp=stats["hp"],
            max_hp=stats["hp"],
            move=stats["move"],
        )
    return BattleState(
        seed=seed,
        map_variant=variant,
        islands=set(islands),
        beacons=beacons,
        ships=ships,
    )


def _line_cells(a: tuple[int, int], b: tuple[int, int]) -> list[tuple[int, int]]:
    """Return Bresenham cells including endpoints."""
    x0, y0 = a
    x1, y1 = b
    dx = abs(x1 - x0)
    sx = 1 if x0 < x1 else -1
    dy = -abs(y1 - y0)
    sy = 1 if y0 < y1 else -1
    error = dx + dy
    cells: list[tuple[int, int]] = []
    while True:
        cells.append((x0, y0))
        if x0 == x1 and y0 == y1:
            break
        doubled = 2 * error
        if doubled >= dy:
            error += dy
            x0 += sx
        if doubled <= dx:
            error += dx
            y0 += sy
    return cells


def has_line_of_sight(state: BattleState, attacker: Ship, target: Ship) -> bool:
    blockers = state.islands | state.occupied(exclude=attacker.ship_id)
    blockers.discard(target.position)
    return not any(cell in blockers for cell in _line_cells(attacker.position, target.position)[1:-1])


def in_side_arc(attacker: Ship, target: Ship) -> bool:
    forward = DIRECTIONS[attacker.facing]
    right = (-forward[1], forward[0])
    relative = (
        target.position[0] - attacker.position[0],
        target.position[1] - attacker.position[1],
    )
    forward_projection = relative[0] * forward[0] + relative[1] * forward[1]
    side_projection = relative[0] * right[0] + relative[1] * right[1]
    return side_projection != 0 and abs(forward_projection) <= abs(side_projection)


def is_stern_hit(attacker: Ship, target: Ship) -> bool:
    forward = DIRECTIONS[target.facing]
    right = (-forward[1], forward[0])
    relative = (
        attacker.position[0] - target.position[0],
        attacker.position[1] - target.position[1],
    )
    forward_projection = relative[0] * forward[0] + relative[1] * forward[1]
    side_projection = relative[0] * right[0] + relative[1] * right[1]
    return forward_projection < 0 and abs(forward_projection) >= abs(side_projection)


def legal_maneuvers(state: BattleState, ship: Ship) -> list[Maneuver]:
    if not ship.alive:
        return []
    occupied = state.occupied(exclude=ship.ship_id)
    maneuvers = {
        Maneuver(ship.position, ship.facing, "wait", 0),
        Maneuver(ship.position, (ship.facing - 1) % 8, "pivot", 0),
        Maneuver(ship.position, (ship.facing + 1) % 8, "pivot", 0),
        Maneuver(ship.position, (ship.facing - 2) % 8, "pivot", 0),
        Maneuver(ship.position, (ship.facing + 2) % 8, "pivot", 0),
    }

    reverse = add_cell(ship.position, DIRECTIONS[(ship.facing + 4) % 8])
    if in_bounds(reverse) and reverse not in state.islands and reverse not in occupied:
        maneuvers.add(Maneuver(reverse, ship.facing, "reverse", 1))

    for distance in range(1, ship.move + 1):
        position = ship.position
        valid = True
        for _ in range(distance):
            position = add_cell(position, DIRECTIONS[ship.facing])
            if not in_bounds(position) or position in state.islands or position in occupied:
                valid = False
                break
        if valid:
            maneuvers.add(Maneuver(position, ship.facing, "sail", distance))

        if distance < 2:
            continue
        for turn_delta in (-1, 1):
            turned_facing = (ship.facing + turn_delta) % 8
            for straight_steps in range(1, distance):
                position = ship.position
                valid = True
                for step in range(distance):
                    direction = ship.facing if step < straight_steps else turned_facing
                    position = add_cell(position, DIRECTIONS[direction])
                    if not in_bounds(position) or position in state.islands or position in occupied:
                        valid = False
                        break
                if valid:
                    maneuvers.add(Maneuver(position, turned_facing, "sail_turn", distance))
    return sorted(maneuvers, key=lambda item: (item.kind, item.distance, item.position, item.facing))


def legal_combat_actions(state: BattleState, ship: Ship) -> list[CombatAction]:
    if not ship.alive:
        return []
    enemies = state.living(other_side(ship.side))
    allies = [ally for ally in state.living(ship.side) if ally.ship_id != ship.ship_id]
    actions = [CombatAction("none"), CombatAction("brace")]

    if ship.kind == "fast":
        for target in enemies:
            distance = chebyshev(ship.position, target.position)
            if 1 <= distance <= 3 and in_side_arc(ship, target) and has_line_of_sight(state, ship, target):
                actions.append(CombatAction("disrupt", target.ship_id))
            if target.position == add_cell(ship.position, DIRECTIONS[ship.facing]):
                actions.append(CombatAction("ram", target.ship_id))
    elif ship.kind == "gunship":
        for target in enemies:
            distance = chebyshev(ship.position, target.position)
            if 1 <= distance <= 4 and in_side_arc(ship, target) and has_line_of_sight(state, ship, target):
                actions.append(CombatAction("broadside", target.ship_id))
    elif ship.kind == "escort":
        for target in enemies:
            distance = chebyshev(ship.position, target.position)
            if 1 <= distance <= 2 and in_side_arc(ship, target) and has_line_of_sight(state, ship, target):
                actions.append(CombatAction("short_cannon", target.ship_id))
        for ally in allies:
            if chebyshev(ship.position, ally.position) <= 2:
                actions.append(CombatAction("guard", ally.ship_id))
    return actions


def _clear_source_guards(state: BattleState, source_id: str) -> None:
    for ship in state.living():
        if ship.guard_source == source_id:
            ship.guard_source = None


def begin_activation(state: BattleState, ship: Ship) -> None:
    ship.braced = False
    _clear_source_guards(state, ship.ship_id)


def deal_damage(state: BattleState, target: Ship, raw_damage: int) -> int:
    reduction = max(6 if target.braced else 0, 8 if target.guard_source else 0)
    damage = max(1, raw_damage - reduction)
    if target.braced or target.guard_source:
        target.braced = False
        target.guard_source = None
    target.hp = max(0, target.hp - damage)
    if target.hp > 0:
        target.suppressed = True
    if target.hp == 0 and not target.ever_activated:
        state.preactivation_sink = True
    return damage


def resolve_combat(state: BattleState, ship: Ship, action: CombatAction) -> None:
    legal = legal_combat_actions(state, ship)
    if action not in legal:
        raise ValueError(f"illegal combat action: {ship.ship_id} {action}")
    state.action_counts[action.kind] += 1
    if action.kind in SIGNATURE_ACTIONS[ship.kind]:
        state.signature_classes.add(ship.kind)

    if action.kind == "none":
        return
    if action.kind == "brace":
        ship.braced = True
        return
    if action.target_id is None:
        raise ValueError(f"{action.kind} requires a target")
    target = state.ships[action.target_id]

    if action.kind == "guard":
        target.guard_source = ship.ship_id
        return
    if action.kind == "disrupt":
        deal_damage(state, target, 8)
        if target.alive:
            target.destabilized = True
        return
    if action.kind == "short_cannon":
        deal_damage(state, target, 12)
        return
    if action.kind == "broadside":
        damage = 18
        if is_stern_hit(ship, target):
            damage += 6
        if target.destabilized:
            damage += 6
            target.destabilized = False
        deal_damage(state, target, damage)
        return
    if action.kind == "ram":
        push_direction = DIRECTIONS[ship.facing]
        push_cell = add_cell(target.position, push_direction)
        deal_damage(state, target, 12)
        deal_damage(state, ship, 5)
        if not target.alive:
            return
        collision = next(
            (other for other in state.living() if other.ship_id != target.ship_id and other.position == push_cell),
            None,
        )
        if not in_bounds(push_cell) or push_cell in state.islands:
            deal_damage(state, target, 8)
        elif collision is not None:
            deal_damage(state, target, 5)
            deal_damage(state, collision, 5)
        else:
            target.position = push_cell
        if target.alive:
            target.destabilized = True
        return
    raise ValueError(f"unknown combat action: {action.kind}")


def expected_damage(state: BattleState, attacker: Ship, action: CombatAction) -> int:
    if action.target_id is None:
        return 0
    target = state.ships[action.target_id]
    raw = {
        "disrupt": 8,
        "ram": 12,
        "broadside": 18,
        "short_cannon": 12,
    }.get(action.kind, 0)
    if action.kind == "broadside":
        if is_stern_hit(attacker, target):
            raw += 6
        if target.destabilized:
            raw += 6
    reduction = max(6 if target.braced else 0, 8 if target.guard_source else 0)
    return max(1, raw - reduction) if raw else 0


def _nearest_beacon_distance(state: BattleState, position: tuple[int, int]) -> int:
    return min(chebyshev(position, beacon) for beacon in state.beacons)


def _nearest_enemy_distance(state: BattleState, ship: Ship) -> int:
    enemies = state.living(other_side(ship.side))
    return min((chebyshev(ship.position, enemy.position) for enemy in enemies), default=9)


def _home_distance(ship: Ship) -> int:
    home_x = 1 if ship.side == "A" else 10
    return abs(ship.position[0] - home_x)


def _incoming_threat(state: BattleState, ship: Ship) -> float:
    threat = 0.0
    for enemy in state.living(other_side(ship.side)):
        distance = chebyshev(enemy.position, ship.position)
        if enemy.kind == "gunship" and distance <= 4 and in_side_arc(enemy, ship) and has_line_of_sight(state, enemy, ship):
            threat += 18
        elif enemy.kind == "fast" and distance <= 3 and in_side_arc(enemy, ship) and has_line_of_sight(state, enemy, ship):
            threat += 8
        elif enemy.kind == "escort" and distance <= 2 and in_side_arc(enemy, ship) and has_line_of_sight(state, enemy, ship):
            threat += 12
    return threat


def _temporary_maneuver(state: BattleState, ship: Ship, maneuver: Maneuver):
    class Restore:
        def __enter__(self_nonlocal):
            self_nonlocal.old_position = ship.position
            self_nonlocal.old_facing = ship.facing
            ship.position = maneuver.position
            ship.facing = maneuver.facing
            return ship

        def __exit__(self_nonlocal, _type, _value, _traceback):
            ship.position = self_nonlocal.old_position
            ship.facing = self_nonlocal.old_facing

    return Restore()


def _target_priority(action: CombatAction, state: BattleState) -> float:
    if action.target_id is None:
        return 0.0
    target = state.ships[action.target_id]
    return (target.max_hp - target.hp) * 0.4 + (100 - target.hp) * 0.08


def choice_score(
    state: BattleState,
    ship: Ship,
    maneuver: Maneuver,
    action: CombatAction,
    policy: str,
) -> float:
    objective_distance = _nearest_beacon_distance(state, ship.position)
    on_beacon = ship.position in state.beacons
    enemy_distance = _nearest_enemy_distance(state, ship)
    home_distance = _home_distance(ship)
    damage = expected_damage(state, ship, action)
    kill = 0
    if action.target_id and damage >= state.ships[action.target_id].hp:
        kill = 1
    threat = _incoming_threat(state, ship)
    target_priority = _target_priority(action, state)
    brace_value = 1 if action.kind == "brace" else 0
    guard_value = 0.0
    if action.kind == "guard" and action.target_id:
        ally = state.ships[action.target_id]
        guard_value = (ally.max_hp - ally.hp) / ally.max_hp + _incoming_threat(state, ally) / 18.0

    if policy == "camp":
        return (
            damage * 3.0
            + kill * 60
            + brace_value * (18 + threat)
            - home_distance * 30
            - maneuver.distance * 2
            + target_priority
        )

    if policy == "focus":
        low_target_bonus = 0.0
        enemies = state.living(other_side(ship.side))
        if action.target_id and enemies:
            lowest_hp = min(enemy.hp for enemy in enemies)
            if state.ships[action.target_id].hp == lowest_hp:
                low_target_bonus = 35
        approach = -enemy_distance * 9
        return damage * 4 + kill * 80 + low_target_bonus + approach + target_priority - threat * 0.2

    if policy == "objective":
        return (
            (90 if on_beacon else 0)
            - objective_distance * 22
            + damage * 1.2
            + kill * 20
            + brace_value * (16 if on_beacon else 2)
            - threat * 0.25
        )

    if policy == "kite":
        desired = 4 if ship.kind == "gunship" else (3 if ship.kind == "fast" else 2)
        range_fit = -abs(enemy_distance - desired) * (18 if ship.kind == "gunship" else 7)
        objective = -objective_distance * (5 if ship.kind == "gunship" else 11)
        return damage * 3.2 + kill * 55 + range_fit + objective - threat * 0.45 + brace_value * 7

    if policy == "guard_spam":
        if ship.kind == "escort":
            return guard_value * 65 + (80 if action.kind == "guard" else 0) + damage - objective_distance * 5
        return damage * 3 + kill * 55 - objective_distance * 12 + target_priority - threat * 0.2

    # Balanced: objectives matter, but exposed ships and available attacks matter too.
    return (
        (52 if on_beacon else 0)
        - objective_distance * 13
        + damage * 2.7
        + kill * 65
        + target_priority
        + guard_value * 28
        + brace_value * (8 + threat * 0.4)
        - threat * 0.32
        - max(0, home_distance - 7) * 3
    )


def choose_activation(state: BattleState, side: str, policy: str, rng: random.Random) -> ActivationChoice:
    if policy not in POLICIES:
        raise ValueError(f"unknown policy: {policy}")
    choices: list[tuple[float, ActivationChoice]] = []
    for ship in state.living(side):
        if ship.activated:
            continue
        for maneuver in legal_maneuvers(state, ship):
            with _temporary_maneuver(state, ship, maneuver):
                actions = legal_combat_actions(state, ship)
                if policy == "objective":
                    actions = [action for action in actions if action.kind in {"none", "brace"}]
                for action in actions:
                    score = choice_score(state, ship, maneuver, action, policy)
                    # Prefer using scarce class actions when the strategic score ties.
                    if action.kind in SIGNATURE_ACTIONS[ship.kind]:
                        score += 0.15
                    choices.append((score, ActivationChoice(ship.ship_id, maneuver, action)))
    if not choices:
        raise RuntimeError(f"side {side} has no legal activation")
    best_score = max(item[0] for item in choices)
    tied = [choice for score, choice in choices if math.isclose(score, best_score, abs_tol=1e-9)]
    return tied[rng.randrange(len(tied))]


def execute_activation(state: BattleState, choice: ActivationChoice) -> None:
    ship = state.ships[choice.ship_id]
    if not ship.alive or ship.activated:
        raise ValueError(f"ship cannot activate: {ship.ship_id}")
    if choice.maneuver not in legal_maneuvers(state, ship):
        raise ValueError(f"illegal maneuver: {choice.maneuver}")
    begin_activation(state, ship)
    ship.position = choice.maneuver.position
    ship.facing = choice.maneuver.facing
    resolve_combat(state, ship, choice.combat)
    ship.activated = True
    ship.ever_activated = True
    if len(state.opening_signature) < 6:
        state.opening_signature.append(
            f"{ship.side}:{ship.kind}:{choice.maneuver.kind}:{choice.combat.kind}"
        )


def score_beacons(state: BattleState) -> None:
    for beacon in state.beacons:
        occupants = {
            ship.side
            for ship in state.living()
            if ship.position == beacon and not ship.suppressed
        }
        if len(occupants) == 1:
            state.score[next(iter(occupants))] += 1
    for ship in state.ships.values():
        ship.suppressed = False


def _build_result(
    state: BattleState,
    policy_a: str,
    policy_b: str,
    winner: Optional[str],
    victory_type: str,
    terminal_round: int,
    complete_rounds: int,
) -> MatchResult:
    hp = {
        side: sum(ship.hp for ship in state.living(side))
        for side in SIDES
    }
    return MatchResult(
        seed=state.seed,
        map_variant=state.map_variant,
        policy_a=policy_a,
        policy_b=policy_b,
        winner=winner,
        victory_type=victory_type,
        terminal_round=terminal_round,
        complete_rounds=complete_rounds,
        score_a=state.score["A"],
        score_b=state.score["B"],
        hp_a=hp["A"],
        hp_b=hp["B"],
        sunk_ship_count=sum(not ship.alive for ship in state.ships.values()),
        preactivation_sink=state.preactivation_sink,
        action_counts=dict(state.action_counts),
        signature_classes=sorted(state.signature_classes),
        opening_signature=list(state.opening_signature),
    )


def run_match(policy_a: str, policy_b: str, seed: int) -> MatchResult:
    state = make_state(seed)
    # A separate stream prevents changing a map from changing tie-break behavior.
    rng = random.Random(seed * 1009 + POLICIES.index(policy_a) * 37 + POLICIES.index(policy_b) * 101)
    for round_number in range(1, MAX_ROUNDS + 1):
        state.round_number = round_number
        # The target rules explicitly keep the mission's public first side for
        # every round; ship losses must not silently transfer initiative.
        next_side = "A"
        for ship in state.living():
            ship.activated = False

        while any(not ship.activated for ship in state.living()):
            available = [ship for ship in state.living(next_side) if not ship.activated]
            if available:
                policy = policy_a if next_side == "A" else policy_b
                choice = choose_activation(state, next_side, policy, rng)
                execute_activation(state, choice)
                enemy = other_side(next_side)
                if not state.living(enemy):
                    return _build_result(
                        state, policy_a, policy_b, next_side, "elimination", round_number, round_number - 1
                    )
            next_side = other_side(next_side)

        score_beacons(state)
        if state.score["A"] >= SCORE_TO_WIN or state.score["B"] >= SCORE_TO_WIN:
            if state.score["A"] == state.score["B"]:
                winner = None
                victory_type = "draw"
            else:
                winner = "A" if state.score["A"] > state.score["B"] else "B"
                victory_type = "objective"
            return _build_result(state, policy_a, policy_b, winner, victory_type, round_number, round_number)

        for ship in state.living():
            ship.destabilized = False

    if state.score["A"] == state.score["B"]:
        return _build_result(state, policy_a, policy_b, None, "draw", MAX_ROUNDS, MAX_ROUNDS)
    winner = "A" if state.score["A"] > state.score["B"] else "B"
    return _build_result(state, policy_a, policy_b, winner, "objective", MAX_ROUNDS, MAX_ROUNDS)


def run_batch(seeds: int = 20, policies: Iterable[str] = POLICIES) -> list[MatchResult]:
    selected = tuple(policies)
    results: list[MatchResult] = []
    for policy_a in selected:
        for policy_b in selected:
            for seed in range(seeds):
                results.append(run_match(policy_a, policy_b, seed))
    return results


def _percentage(numerator: float, denominator: float) -> float:
    return round(numerator * 100.0 / denominator, 2) if denominator else 0.0


def aggregate_results(results: list[MatchResult], seeds: int) -> dict:
    total = len(results)
    decisive = [result for result in results if result.winner]
    objective = [result for result in decisive if result.victory_type == "objective"]
    eliminations = [result for result in decisive if result.victory_type == "elimination"]

    policy_stats: dict[str, dict] = {}
    for policy in POLICIES:
        appearances = 0
        wins = 0
        losses = 0
        draws = 0
        first_wins = 0
        first_games = 0
        second_wins = 0
        second_games = 0
        for result in results:
            if result.policy_a == policy:
                appearances += 1
                first_games += 1
                if result.winner == "A":
                    wins += 1
                    first_wins += 1
                elif result.winner == "B":
                    losses += 1
                else:
                    draws += 1
            if result.policy_b == policy:
                appearances += 1
                second_games += 1
                if result.winner == "B":
                    wins += 1
                    second_wins += 1
                elif result.winner == "A":
                    losses += 1
                else:
                    draws += 1
        policy_stats[policy] = {
            "appearances": appearances,
            "wins": wins,
            "losses": losses,
            "draws": draws,
            "win_rate_percent": _percentage(wins, appearances),
            "first_side_win_rate_percent": _percentage(first_wins, first_games),
            "second_side_win_rate_percent": _percentage(second_wins, second_games),
        }

    matchup: dict[str, dict[str, dict]] = defaultdict(dict)
    for policy_a in POLICIES:
        for policy_b in POLICIES:
            subset = [
                result
                for result in results
                if result.policy_a == policy_a and result.policy_b == policy_b
            ]
            matchup[policy_a][policy_b] = {
                "A_wins": sum(result.winner == "A" for result in subset),
                "B_wins": sum(result.winner == "B" for result in subset),
                "draws": sum(result.winner is None for result in subset),
            }

    same_policy = [result for result in decisive if result.policy_a == result.policy_b]
    camp_games = [
        result
        for result in results
        if (result.policy_a == "camp") != (result.policy_b == "camp")
    ]
    camp_wins = sum(
        (result.policy_a == "camp" and result.winner == "A")
        or (result.policy_b == "camp" and result.winner == "B")
        for result in camp_games
    )
    objective_only_games = [
        result
        for result in results
        if (
            result.policy_a == "objective"
            and result.policy_b not in {"objective", "camp"}
        )
        or (
            result.policy_b == "objective"
            and result.policy_a not in {"objective", "camp"}
        )
    ]
    objective_only_wins = sum(
        (result.policy_a == "objective" and result.winner == "A")
        or (result.policy_b == "objective" and result.winner == "B")
        for result in objective_only_games
    )
    signature_presence = {
        kind: _percentage(sum(kind in result.signature_classes for result in results), total)
        for kind in CLASS_STATS
    }
    opening_counts = Counter(tuple(result.opening_signature) for result in results)

    metrics = {
        "average_terminal_round": round(sum(result.terminal_round for result in results) / total, 3),
        "average_complete_rounds": round(sum(result.complete_rounds for result in results) / total, 3),
        "same_policy_first_side_win_rate_decisive_percent": _percentage(
            sum(result.winner == "A" for result in same_policy), len(same_policy)
        ),
        "same_policy_decisive_matches": len(same_policy),
        "preactivation_sink_match_rate_percent": _percentage(
            sum(result.preactivation_sink for result in results), total
        ),
        "camp_win_rate_vs_noncamp_percent": _percentage(camp_wins, len(camp_games)),
        "objective_share_of_decisive_percent": _percentage(len(objective), len(decisive)),
        "matches_with_any_sink_percent": _percentage(
            sum(result.sunk_ship_count > 0 for result in results), total
        ),
        "no_attack_objective_win_rate_vs_noncamp_percent": _percentage(
            objective_only_wins, len(objective_only_games)
        ),
        "signature_action_match_presence_percent": signature_presence,
        "most_common_opening_share_percent": _percentage(
            opening_counts.most_common(1)[0][1] if opening_counts else 0, total
        ),
    }

    checks = [
        {
            "name": "average terminal round is 4-6",
            "value": metrics["average_terminal_round"],
            "pass": 4 <= metrics["average_terminal_round"] <= 6,
        },
        {
            "name": "same-policy first-side decisive win rate is 45%-55%",
            "value": metrics["same_policy_first_side_win_rate_decisive_percent"],
            "pass": 45 <= metrics["same_policy_first_side_win_rate_decisive_percent"] <= 55,
        },
        {
            "name": "pre-activation sink match rate is below 5%",
            "value": metrics["preactivation_sink_match_rate_percent"],
            "pass": metrics["preactivation_sink_match_rate_percent"] < 5,
        },
        {
            "name": "camp win rate versus non-camp is at most 40%",
            "value": metrics["camp_win_rate_vs_noncamp_percent"],
            "pass": metrics["camp_win_rate_vs_noncamp_percent"] <= 40,
        },
        {
            "name": "objective endings are at least 40% of decisive matches",
            "value": metrics["objective_share_of_decisive_percent"],
            "pass": metrics["objective_share_of_decisive_percent"] >= 40,
        },
        {
            "name": "at least one ship sinks in at least 20% of matches",
            "value": metrics["matches_with_any_sink_percent"],
            "pass": metrics["matches_with_any_sink_percent"] >= 20,
        },
        {
            "name": "no-attack objective win rate versus non-camp is 25%-45%",
            "value": metrics["no_attack_objective_win_rate_vs_noncamp_percent"],
            "pass": 25 <= metrics["no_attack_objective_win_rate_vs_noncamp_percent"] <= 45,
        },
    ]
    for kind, value in signature_presence.items():
        checks.append(
            {
                "name": f"{kind} signature action appears in at least 60% of matches",
                "value": value,
                "pass": value >= 60,
            }
        )

    return {
        "schema_version": 1,
        "configuration": {
            "board": [BOARD_WIDTH, BOARD_HEIGHT],
            "max_rounds": MAX_ROUNDS,
            "score_to_win": SCORE_TO_WIN,
            "policies": list(POLICIES),
            "seeds_per_ordered_pair": seeds,
            "map_variants": len(MAP_VARIANTS),
            "total_matches": total,
        },
        "outcomes": {
            "A_wins": sum(result.winner == "A" for result in results),
            "B_wins": sum(result.winner == "B" for result in results),
            "draws": sum(result.winner is None for result in results),
            "objective": len(objective),
            "elimination": len(eliminations),
        },
        "metrics": metrics,
        "checks": checks,
        "policy_stats": policy_stats,
        "matchups": dict(matchup),
        "limitations": [
            "Reference policies are heuristics, not optimal solvers or human players.",
            "The model validates rule exploits and balance proxies; it cannot prove fun, readability, pacing in minutes, or perceived choice.",
            "Currents, animation time, campaign upgrades, mission variety and production AI are outside this simulation.",
        ],
        "matches": [asdict(result) for result in results],
    }


def render_markdown(report: dict) -> str:
    configuration = report["configuration"]
    outcomes = report["outcomes"]
    metrics = report["metrics"]
    lines = [
        "# 3v3 双航标无界面压力测试",
        "",
        "> 结论边界：这份报告用于淘汰明显坏规则，不用于宣称玩法已经有趣。",
        "",
        "## 运行范围",
        "",
        f"- 对局数：{configuration['total_matches']}（六策略有序全组合 × 每组 {configuration['seeds_per_ordered_pair']} 个种子）",
        f"- 地图：{configuration['board'][0]}×{configuration['board'][1]}，{configuration['map_variants']} 个对称变体",
        f"- 规则：3v3、单船交替激活、双航标、受压制船本轮不计航标、先得 {configuration['score_to_win']} 分、最多 {configuration['max_rounds']} 回合",
        "- 策略：均衡、蹲守、最低耐久集火、纯抢点、风筝、无脑护航",
        "",
        "## 总结果",
        "",
        f"- 先行方胜 / 后行方胜 / 平局：{outcomes['A_wins']} / {outcomes['B_wins']} / {outcomes['draws']}",
        f"- 任务胜利 / 全歼胜利：{outcomes['objective']} / {outcomes['elimination']}",
        f"- 平均结束回合：{metrics['average_terminal_round']}",
        f"- 同策略镜像先行方胜率（只计分出胜负）：{metrics['same_policy_first_side_win_rate_decisive_percent']}%",
        f"- 首次激活前沉没对局率：{metrics['preactivation_sink_match_rate_percent']}%",
        f"- 蹲守对非蹲守胜率：{metrics['camp_win_rate_vs_noncamp_percent']}%",
        f"- 任务胜利占有效胜局：{metrics['objective_share_of_decisive_percent']}%",
        f"- 至少发生一次击沉的对局：{metrics['matches_with_any_sink_percent']}%",
        f"- 完全不攻击的纯抢点策略对非蹲守胜率：{metrics['no_attack_objective_win_rate_vs_noncamp_percent']}%",
        "",
        "## 通过线",
        "",
        "| 检查 | 数值 | 结果 |",
        "|---|---:|:---:|",
    ]
    for check in report["checks"]:
        lines.append(f"| {check['name']} | {check['value']} | {'通过' if check['pass'] else '失败'} |")

    lines.extend(
        [
            "",
            "## 策略表现",
            "",
            "| 策略 | 总胜率 | 先行胜率 | 后行胜率 | 胜/负/平 |",
            "|---|---:|---:|---:|---:|",
        ]
    )
    labels = {
        "balanced": "均衡",
        "camp": "出生区蹲守",
        "focus": "最低耐久集火",
        "objective": "纯抢点",
        "kite": "风筝",
        "guard_spam": "无脑护航",
    }
    for policy in POLICIES:
        stats = report["policy_stats"][policy]
        lines.append(
            f"| {labels[policy]} | {stats['win_rate_percent']}% | "
            f"{stats['first_side_win_rate_percent']}% | {stats['second_side_win_rate_percent']}% | "
            f"{stats['wins']}/{stats['losses']}/{stats['draws']} |"
        )

    lines.extend(["", "## 需要盯住的黄灯", ""])
    warnings = []
    if metrics["no_attack_objective_win_rate_vs_noncamp_percent"] > 45:
        warnings.append(
            "完全不攻击的纯抢点策略仍高于 45%。真人原型必须重点验证压制、卡位和开炮是否足以形成清楚反制。"
        )
    elif metrics["no_attack_objective_win_rate_vs_noncamp_percent"] < 25:
        warnings.append(
            "完全不攻击的纯抢点策略低于 25%。航标压制可能过强，真人原型必须确认占点没有退化成单纯先开炮。"
        )
    if metrics["objective_share_of_decisive_percent"] >= 95:
        warnings.append(
            "几乎所有胜负都由任务分数结算。任务驱动符合目标，但需要结合击沉对局比例确认炮战不是无关动作。"
        )
    if warnings:
        lines.extend(f"- {warning}" for warning in warnings)
    else:
        lines.append("- 当前自动数据没有接近否决线的指标。")

    failed = [check for check in report["checks"] if not check["pass"]]
    lines.extend(["", "## 自动判定", ""])
    if failed:
        lines.append(f"当前有 {len(failed)} 项量化门槛失败，不能进入‘规则已经稳定’结论。下一轮应先按任务参数、动作限制、基础数值的顺序处理红项。")
    else:
        lines.append("自动量化门槛全部通过，可以制作 3v3 Godot 内部原型；仍不能宣称已经有趣。")
    lines.extend(["", "失败项："])
    if failed:
        lines.extend(f"- {check['name']}（{check['value']}）" for check in failed)
    else:
        lines.append("- 无")

    lines.extend(
        [
            "",
            "## 不能由本测试回答",
            "",
            "- 一次点击与转舵是否顺手，动画等待是否拖沓。",
            "- 玩家是否理解失败原因，是否觉得多数激活存在两个有吸引力的选择。",
            "- 经营成长、不同任务和后期舰船是否能长期维持变化。",
            "- 固定策略只是探针，不是最优解证明；通过后仍需真人试玩。",
            "",
        ]
    )
    return "\n".join(lines)


def write_report(report: dict, output_dir: Path) -> tuple[Path, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    json_path = output_dir / "naval_tactics_simulation.json"
    markdown_path = output_dir / "naval_tactics_simulation.md"
    json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    markdown_path.write_text(render_markdown(report), encoding="utf-8")
    return json_path, markdown_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seeds", type=int, default=20, help="seeds per ordered policy pair")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("artifacts/simulation"),
        help="directory for JSON and Markdown reports",
    )
    args = parser.parse_args()
    if args.seeds < 1:
        parser.error("--seeds must be positive")

    results = run_batch(args.seeds)
    report = aggregate_results(results, args.seeds)
    json_path, markdown_path = write_report(report, args.output_dir)
    passed = sum(check["pass"] for check in report["checks"])
    print(f"matches={len(results)} checks={passed}/{len(report['checks'])}")
    print(json_path)
    print(markdown_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
