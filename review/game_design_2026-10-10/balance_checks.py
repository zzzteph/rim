"""Reproduce the narrow numerical checks in RIM's document review.

This reads current source and documents; it does not execute or change the game.
Run from anywhere: python review/game_design_2026-10-10/balance_checks.py
Optional: --output result.json --bot-damage 1 --ammo-damage 2.5
The combat model reproduces independent resource drains and per-node frame waste.
Card checks enumerate permitted defense bonuses, not real generated map seeds.
"""
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def constants(source: str) -> dict[str, float]:
    result = {}
    for name, value in re.findall(r"^const (\w+) := ([\d.]+(?:\s*/\s*[\d.]+)?)", source, re.M):
        parts = value.split("/")
        result[name] = float(parts[0]) / float(parts[1]) if len(parts) == 2 else float(value)
    return result


def catalogue(source: str, name: str) -> dict:
    match = re.search(rf"^const {name} := (\{{[^\n]*\}})", source, re.M)
    if not match:
        match = re.search(rf"^const {name} := (\{{.*?^\}})", source, re.M | re.S)
    if not match:
        raise ValueError(f"Missing source catalogue {name}")
    text = re.sub(r",\s*([}\]])", r"\1", match.group(1))
    return json.loads(text)


def assault(defenses: list[float], bots: float, intel: float, knobs: dict, dt: float) -> dict:
    """Instant player clicks between nodes; no incoming opponent or transit.

    Each frame consumes both available pools before damage is clamped, matching
    _tick_internal. Committed resources left on success are stranded on exit;
    global income while inside is deliberately outside this local model.
    """
    initial_bots, initial_intel = bots, intel
    elapsed = 0.0
    captured = 0
    for defense in defenses:
        while defense > 1e-9:
            if bots <= 1e-9 and intel <= 1e-9:
                return {"success": False, "seconds": round(elapsed, 4), "nodes_taken": captured,
                        "bots_used": round(initial_bots - bots, 4),
                        "intel_used": round(initial_intel - intel, 4)}
            b = min(bots, knobs["ASSAULT_BOTS"] * dt)
            a = min(intel, knobs["ASSAULT_INTEL"] * dt)
            bots -= b
            intel -= a
            defense = max(0.0, defense - b * knobs["BOT_DMG"] - a * knobs["AMMO_DMG"])
            elapsed += dt
            assert bots >= -1e-8 and intel >= -1e-8 and elapsed < 10000
        captured += 1
    return {"success": True, "seconds": round(elapsed, 4), "nodes_taken": captured,
            "bots_used": round(initial_bots - bots, 4),
            "intel_used": round(initial_intel - intel, 4),
            "bots_stranded": round(bots, 4), "intel_stranded": round(intel, 4)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--bot-damage", type=float)
    parser.add_argument("--ammo-damage", type=float)
    args = parser.parse_args()
    bot_path = ROOT / "scripts/botnet_proto.gd"
    net_path = ROOT / "scripts/netrun.gd"
    econ_path = ROOT / "data/economy.json"
    building_path = ROOT / "scripts/building.gd"
    econ_source_path = ROOT / "scripts/econ.gd"
    menu_path = ROOT / "scripts/menu.gd"
    bot_source, net_source = bot_path.read_text(encoding="utf-8"), net_path.read_text(encoding="utf-8")
    economy = json.loads(econ_path.read_text(encoding="utf-8"))
    building_source = building_path.read_text(encoding="utf-8")
    econ_source = econ_source_path.read_text(encoding="utf-8")
    sec_diff, type_mod = (catalogue(building_source, name) for name in ("SEC_DIFF", "TYPE_MOD"))
    assert "roll.randf_range(0.25, 0.9) * dur" in building_source
    assert "return 1.0 + CAPTURE_SCALE * float(maxi(0, controlled_total() - 1))" in econ_source
    knobs = constants(bot_source)
    if args.bot_damage is not None:
        knobs["BOT_DMG"] = args.bot_damage
    if args.ammo_damage is not None:
        knobs["AMMO_DMG"] = args.ammo_damage
    assert knobs["BOT_DMG"] > 0 and knobs["AMMO_DMG"] > 0
    # Fail if source no longer matches the reviewed rules rather than silently
    # claiming fidelity to a newer implementation.
    for fragment in ("var count: int = 6 if bool(hosts[t].hub) else 3 + (2 - mini(ring, 2))",
                     "70.0 if is_core else 16.0 + float(k) * 6.0",
                     "var dmg := b * BOT_DMG + a * AMMO_DMG",
                     "force_bots <= 0.0 and force_intel <= 0.0"):
        assert fragment in bot_source, "Botnet source changed: review the model contract"
    comp, cards, programs = (catalogue(net_source, name) for name in ("COMP", "CARDS", "PROGRAMS"))
    assert "var def_bonus := org" in net_source
    assert "int(card.power) < dv" in net_source
    defense_paths = {"outer": [22.0, 70.0], "inner": [22.0, 28.0, 70.0],
                     "hub": [22.0, 28.0, 34.0, 40.0, 70.0]}
    # Independent, hand-known fidelity cases, including per-node discarded damage.
    probe_knobs = dict(knobs, BOT_DMG=1.0, AMMO_DMG=2.5)
    assert assault([13.5], 6, 3, probe_knobs, 1)["success"]
    assert assault([13.5], 6, 3, probe_knobs, 1)["seconds"] == 1
    assert not assault([10, 1], 6, 3, probe_knobs, 1)["success"]
    assert not assault(defense_paths["outer"], 10, 15, probe_knobs, 0.001)["success"]
    cases = {}
    for target, defenses in defense_paths.items():
        total = sum(defenses)
        cases[target] = {"defense_total": total, "assault_nodes": len(defenses),
                         "displayed_global_defense": {"outer": 20, "inner": 40, "hub": 240}[target],
                         "ideal_both_pools_seconds": total / (knobs["ASSAULT_BOTS"] * knobs["BOT_DMG"]
                                                                    + knobs["ASSAULT_INTEL"] * knobs["AMMO_DMG"]),
                         "intel_only_requirement": total / knobs["AMMO_DMG"],
                         "balanced": assault(defenses, 6 * total / 13.5 + 1,
                                             3 * total / 13.5 + 1, knobs, 1 / 60),
                         "tiny_bot_ammo_rich": assault(defenses, 0.01, total / knobs["AMMO_DMG"] + 1,
                                                       knobs, 1 / 60),
                         "one_bot_ammo_rich": assault(defenses, 1.0, total / knobs["AMMO_DMG"] + 1,
                                                      knobs, 1 / 60),
                         "one_full_war_host_no_ammo": assault(defenses, knobs["BOT_CAP"], 0, knobs, 1 / 60)}
    start_intel = float(re.search(r"var _intel_store := ([\d.]+)", bot_source).group(1))
    initial_damage = knobs["BOT_START"] * knobs["BOT_DMG"] + start_intel * knobs["AMMO_DMG"]
    damage_income = knobs["BOT_RATE"] * knobs["BOT_DMG"] + knobs["INTEL_PER_HOST"] * knobs["AMMO_DMG"]
    card_cases = []
    for org in range(3):
        for component_type, base in comp.items():
            reachable, total = 0, 0
            basic_viable = set()
            minimum = {key: base[key] + org if key != "aware" or base[key] > 0 else 0
                       for key in ("pass", "vuln", "aware")}
            for offsets in itertools.product((0, 1), repeat=3):
                defense = {key: base[key] + org + delta if key != "aware" or base[key] > 0 else 0
                           for key, delta in zip(("pass", "vuln", "aware"), offsets)}
                options = [key for key, card in cards.items()
                           if card["req"] in base["traits"] and card["power"] >= defense[card["def"]]]
                basic_viable.update(key for key in options if not cards[key]["research"])
                reachable += bool(options)
                total += 1
            card_cases.append({"organization": org, "component": component_type,
                               "capturable_defense_combinations": reachable, "enumerated_combinations": total,
                               "basic_cards_ever_applicable_and_strong_enough": sorted(basic_viable),
                               "minimum_defenses": minimum})
    cash_spenders = [key for key, item in programs.items() if item["cost"].get("credits", 0) > 0]
    cash_spenders += [key for key, item in cards.items() if item["cost"].get("credits", 0) > 0]
    capture_scale_cases = []
    for controlled in (1, 5, 11, 24, 25, 50):
        price = economy["action_cost"]["take"] * (1 + economy["capture_scale_per_node"] * max(0, controlled - 1))
        capture_scale_cases.append({"controlled_nodes": controlled, "unburned_capture_cost": price,
                                   "affordable_at_base_cap": price <= economy["cap_base"]})
    chance_cases = []
    # Analytical expectations: stationary independent retries, no alarm events,
    # sufficient stock, no canceled actions, failures uniformly interrupt25-90%.
    # Do not treat these as observed player/session times.
    for security in ("Corporate ICE", "Lethal — black ICE"):
        chance = min(0.99, max(0.05, sec_diff[security] * type_mod["core"]))
        boost_chance = min(0.99, chance + economy["capture_boost"])
        for boosted, probability in ((False, chance), (True, boost_chance)):
            duration = economy["action_time"]["take"]
            chance_cases.append({"security": security, "type": "core", "boosted": boosted,
                                 "success_probability": probability,
                                 "expected_attempts": 1 / probability,
                                 "expected_take_seconds_excluding_affordability": duration * (1 + 0.575 * (1 - probability) / probability),
                                 "expected_take_intel_at_one_controlled_node": economy["action_cost"]["take"] / probability,
                                 "expected_boost_resources": 1 / probability if boosted else 0,
                                 "five_consecutive_failures_probability": (1 - probability) ** 5})
    link_failures = []
    doc_inventory = []
    for doc in sorted((ROOT / "design").glob("*.md")):
        content = doc.read_text(encoding="utf-8")
        doc_inventory.append({"file": doc.name, "lines": len(content.splitlines()),
                              "sha256": hashlib.sha256(doc.read_bytes()).hexdigest()})
        for line_no, line in enumerate(content.splitlines(), 1):
            for target in re.findall(r"!?\[[^\]]*\]\(([^)]+)\)", line):
                if re.match(r"(?:https?://|#|[A-Za-z]:[/\\])", target):
                    continue
                target = target.split("#", 1)[0].strip("<>")
                if not target:
                    continue
                if not (doc.parent / target).exists():
                    link_failures.append({"file": doc.name, "line": line_no, "target": target,
                                          "exists_relative_to_repo": (ROOT / target).exists()})
    result = {
        "model_version": "1.0", "date": "2026-10-10",
        "project_version": re.search(r'config/version="([^"]+)"', (ROOT / "project.godot").read_text()).group(1),
        "source_hashes": {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                          for path in (bot_path, net_path, econ_path, building_path, econ_source_path, menu_path)},
        "model_checks": "passed: hand-known tick, frame waste, insufficient opening, nonnegative pools, finite termination",
        "limitations": ["Static source plus isolated deterministic model; no rendered playtest or engine execution",
                        "Instant between-node input; no defense, transit, global income during assault, or map seed prevalence",
                        "Defense combinations enumerate valid offsets, not measured probabilities",
                        "Source fragments guard key assumptions; this is not a complete GDScript interpreter"],
        "parameters": knobs, "botnet_target_cases": cases,
        "new_game_economy": {"source": "data/economy.json",
                             "capture_scale_cases": capture_scale_cases,
                             "capture_retry_expectations": chance_cases,
                             "retry_assumptions": "Independent stationary attempts; sufficient stock; no alarms/cancellations; failed task duration mean0.575 of full duration; not engine or playtest timings",
                             "cash_spenders": [key for key, p in economy["programs"].items() if p["cost"].get("cash", 0) > 0]},
        "opening": {"bots": knobs["BOT_START"], "intel": start_intel, "maximum_damage": initial_damage,
                    "outer_target_damage": sum(defense_paths["outer"]),
                    "no_waste_minimum_wait_seconds": max(0, (sum(defense_paths["outer"]) - initial_damage) / damage_income),
                    "actual_isolated_model": assault(defense_paths["outer"], knobs["BOT_START"], start_intel, knobs, 1 / 60),
                    "test_candidate_10_bots_34_intel": assault(defense_paths["outer"], 10, 34, knobs, 1 / 60),
                    "test_candidate_42_bots_21_intel": assault(defense_paths["outer"], 42, 21, knobs, 1 / 60)},
        "ammo_damage_sweep": [
            {"ammo_damage": ammo,
             "hub_one_bot_with_sufficient_intel": assault(defense_paths["hub"], 1, 194 / ammo + 1,
                                                         dict(knobs, AMMO_DMG=ammo), 1 / 60)}
            for ammo in (1.25, 2.5, 5.0)],
        "damage_supply_per_second_per_host": {"bots": knobs["BOT_RATE"] * knobs["BOT_DMG"],
                                              "intel": knobs["INTEL_PER_HOST"] * knobs["AMMO_DMG"]},
        "war_building_damage_only_break_even_seconds":
            (knobs["WAR_COST"] * knobs["AMMO_DMG"] - knobs["BOT_START"] * knobs["BOT_DMG"])
            / (knobs["BOT_RATE"] * knobs["BOT_DMG"]),
        "card_reachability": card_cases, "cash_spenders_in_programs_and_cards": cash_spenders,
        "integrity_seconds_to_loss": {str(over): 100 / (constants(net_source)["DEGRADE_RATE"] * over) for over in (1, 2, 3)},
        "document_inventory": doc_inventory, "broken_relative_markdown_links": link_failures,
    }
    payload = json.dumps(result, indent=2, ensure_ascii=False)
    if args.output:
        args.output.write_text(payload + "\n", encoding="utf-8")
    print(payload)


if __name__ == "__main__":
    main()
