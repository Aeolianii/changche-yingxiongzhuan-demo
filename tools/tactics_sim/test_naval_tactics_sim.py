import copy
import unittest

from naval_tactics_sim import (
    ActivationChoice,
    CombatAction,
    Maneuver,
    aggregate_results,
    begin_activation,
    deal_damage,
    execute_activation,
    choose_activation,
    legal_combat_actions,
    legal_maneuvers,
    make_state,
    resolve_combat,
    render_markdown,
    run_batch,
    run_match,
    score_beacons,
)


class GeometryAndActionTests(unittest.TestCase):
    def test_maneuver_supports_pivot_reverse_and_single_turn_sailing(self):
        state = make_state(0)
        ship = state.ships["A_fast"]
        maneuvers = legal_maneuvers(state, ship)
        kinds = {maneuver.kind for maneuver in maneuvers}
        self.assertTrue({"wait", "pivot", "reverse", "sail", "sail_turn"}.issubset(kinds))
        self.assertTrue(all(maneuver.distance <= ship.move for maneuver in maneuvers))

    def test_broadside_requires_side_arc_and_line_of_sight(self):
        state = make_state(0)
        gunship = state.ships["A_gunship"]
        target = state.ships["B_fast"]
        gunship.position = (4, 3)
        gunship.facing = 0
        target.position = (4, 1)
        self.assertIn(CombatAction("broadside", target.ship_id), legal_combat_actions(state, gunship))
        target.position = (7, 3)
        self.assertNotIn(CombatAction("broadside", target.ship_id), legal_combat_actions(state, gunship))

    def test_activation_allows_only_one_combat_resolution(self):
        state = make_state(0)
        ship = state.ships["A_fast"]
        maneuver = Maneuver(ship.position, ship.facing, "wait", 0)
        execute_activation(state, ActivationChoice(ship.ship_id, maneuver, CombatAction("brace")))
        self.assertTrue(ship.activated)
        with self.assertRaises(ValueError):
            execute_activation(state, ActivationChoice(ship.ship_id, maneuver, CombatAction("none")))

    def test_objective_policy_never_selects_an_attack(self):
        import random

        state = make_state(0)
        state.ships["A_gunship"].position = (4, 3)
        state.ships["B_fast"].position = (4, 1)
        choice = choose_activation(state, "A", "objective", random.Random(1))
        self.assertIn(choice.combat.kind, {"none", "brace"})


class CombatRuleTests(unittest.TestCase):
    def test_effective_damage_suppresses_surviving_ship(self):
        state = make_state(0)
        target = state.ships["A_fast"]
        damage = deal_damage(state, target, 8)
        self.assertEqual(8, damage)
        self.assertTrue(target.alive)
        self.assertTrue(getattr(target, "suppressed", False))

    def test_guard_and_brace_do_not_stack_and_both_end_on_hit(self):
        state = make_state(0)
        target = state.ships["A_fast"]
        target.braced = True
        target.guard_source = "A_escort"
        damage = deal_damage(state, target, 18)
        self.assertEqual(10, damage)
        self.assertEqual(40, target.hp)
        self.assertFalse(target.braced)
        self.assertIsNone(target.guard_source)

    def test_guard_expires_when_escort_next_activates(self):
        state = make_state(0)
        target = state.ships["A_fast"]
        escort = state.ships["A_escort"]
        target.guard_source = escort.ship_id
        begin_activation(state, escort)
        self.assertIsNone(target.guard_source)

    def test_destabilized_broadside_gets_six_and_consumes_status(self):
        state = make_state(0)
        gunship = state.ships["A_gunship"]
        target = state.ships["B_fast"]
        gunship.position = (4, 3)
        gunship.facing = 0
        target.position = (4, 1)
        target.facing = 4
        target.destabilized = True
        resolve_combat(state, gunship, CombatAction("broadside", target.ship_id))
        self.assertEqual(26, target.hp)
        self.assertFalse(target.destabilized)

    def test_beacons_score_only_single_side_occupancy(self):
        state = make_state(0)
        first, second = state.beacons
        state.ships["A_fast"].position = first
        state.ships["B_fast"].position = second
        score_beacons(state)
        self.assertEqual({"A": 1, "B": 1}, state.score)

    def test_suppressed_beacon_occupant_does_not_score(self):
        state = make_state(0)
        first, second = state.beacons
        state.ships["A_fast"].position = first
        state.ships["A_fast"].suppressed = True
        state.ships["B_fast"].position = second
        score_beacons(state)
        self.assertEqual({"A": 0, "B": 1}, state.score)
        self.assertFalse(state.ships["A_fast"].suppressed)


class BatchTests(unittest.TestCase):
    def test_match_is_deterministic(self):
        first = run_match("balanced", "focus", 7)
        second = run_match("balanced", "focus", 7)
        self.assertEqual(first, second)

    def test_smoke_batch_has_all_ordered_pairs_and_metrics(self):
        results = run_batch(seeds=1)
        self.assertEqual(36, len(results))
        report = aggregate_results(results, seeds=1)
        self.assertEqual(36, report["configuration"]["total_matches"])
        self.assertEqual(10, len(report["checks"]))
        checks_by_name = {check["name"]: check for check in report["checks"]}
        objective_name = "no-attack objective win rate versus non-camp is 25%-45%"
        self.assertIn(objective_name, checks_by_name)
        objective_check = checks_by_name[objective_name]
        self.assertEqual(
            25 <= objective_check["value"] <= 45,
            objective_check["pass"],
        )
        self.assertIn("受压制船本轮不计航标", render_markdown(report))


if __name__ == "__main__":
    unittest.main()
