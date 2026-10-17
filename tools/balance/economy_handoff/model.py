"""Deterministic economy budget projections; deliberately not a match simulator.

Run from any directory: python tools/balance/economy_handoff/model.py
Optional: --parameters PATH --output PATH
Uses only Python's standard library. See README.md for fidelity and omissions.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import json
import math
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
EPS = 1e-7


def require(condition, message):
    if not condition:
        raise ValueError(message)


def gd_dictionary(source, marker):
    """Parse a selected GDScript dictionary containing JSON/Python literals only."""
    start = source.index("{", source.index(marker))
    depth = 0
    for pos in range(start, len(source)):
        if source[pos] == "{":
            depth += 1
        elif source[pos] == "}":
            depth -= 1
            if depth == 0:
                return ast.literal_eval(source[start:pos + 1])
    raise ValueError(f"Unclosed config dictionary: {marker}")


def read_config(expected):
    files = {
        name: ROOT / "scripts" / "botnet_cfg" / f"{name}.gd"
        for name in ("tuning", "buildings", "types", "cards")
    }
    files["runtime"] = ROOT / "scripts" / "botnet_proto.gd"
    source = {name: path.read_text(encoding="utf-8") for name, path in files.items()}
    values = {}
    for name in expected:
        if name in ("BUILD_COSTS", "TYPE_CASH", "SUPPLY_COST", "SUPPLY_TIME"):
            continue
        haystack = source["buildings"] if name == "BUILD_TIME" else source["tuning"]
        match = re.search(r"const\s+" + re.escape(name) + r"\s*:=\s*([0-9.]+)", haystack)
        require(match is not None, f"Missing numeric source constant: {name}")
        values[name] = float(match.group(1))
    values["BUILD_COSTS"] = gd_dictionary(source["buildings"], "const BUILD_COSTS")
    values["TYPE_CASH"] = {}
    for host_type in expected["TYPE_CASH"]:
        type_line = re.search(r'^\s*"' + host_type + r'":\s*\{([^\n]+)', source["types"], re.M)
        require(type_line is not None, f"Missing host type: {host_type}")
        values["TYPE_CASH"][host_type] = float(re.search(r'"cash":\s*([0-9.]+)', type_line.group(1)).group(1))
    supply_line = re.search(r'^\s*"supply":\s*\{([^\n]+)', source["cards"], re.M)
    require(supply_line is not None, "Missing Supply card")
    values["SUPPLY_COST"] = gd_dictionary(supply_line.group(1), '"cost"')
    values["SUPPLY_TIME"] = float(re.search(r'"time":\s*([0-9.]+)', supply_line.group(1)).group(1))
    require(values == expected, "Config drift detected. Review model fidelity, then update config_expectations deliberately.\n"
            + json.dumps({"expected": expected, "actual": values}, indent=2))
    fidelity_tokens = {
        "price_required_at_queue": 'if not _can_afford_build(fac, kind): return false',
        "cost_stored_per_job": '"cost_total": price.duplicate()',
        "payment_over_build_time": 'float(total.get(res, 0.0)) / BUILD_TIME * dt',
        "miner_formula": 'float(_count(i, "cash")) * float(hosts[i].value) * _tmult(i, "cash") / CASH_INTERVAL',
        "lab_input_is_cash": 'var input := "cash" if kind == "lab" else "intel"',
        "intel_cap_clamps_stock": 'intel[fac] = minf(INTEL_CAP_BASE + INTEL_CAP_PER_BUILD * float(harvesters[fac])',
    }
    for name, token in fidelity_tokens.items():
        require(token in source["runtime"], f"Runtime fidelity marker changed: {name}; re-audit this model.")
    provenance = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in files.values()}
    return values, provenance, list(fidelity_tokens)


def budget_sim(*, price, income_rate, starting_bank, duration, dt, build_time=10.0, cadence=None,
               jobs_per_request=3, outage=None):
    """One fungible funding pool, equal-cost jobs; continuous averaged inflow.

    At each step: request -> queue every affordable job without reservation ->
    proportionally fund jobs -> credit income for this interval. Requests that
    cannot queue retry. Each queued job takes at least BUILD_TIME funded seconds.
    No slot/territory/Intel production model. Outages only stop new inflow.
    """
    require(price > 0 and dt > 0 and duration > 0 and build_time > 0, "Invalid budget sim input")
    require(income_rate >= 0 and starting_bank >= 0, "Negative source/stock")
    bank, spent, income, shortfall_time = starting_bank, 0.0, 0.0, 0.0
    waiting, active, completed = [], [], []
    next_request = 0.0
    count = 0
    traces = []
    steps = round(duration / dt)
    require(abs(steps * dt - duration) < EPS, "Horizon must be a whole number of steps")
    for step in range(steps):
        now = step * dt
        if now + EPS >= next_request:
            for _ in range(jobs_per_request):
                waiting.append({"id": count, "requested_at": round(now, 6)})
                count += 1
            next_request = next_request + cadence if cadence else math.inf
        # Runtime checks affordability without reserving or removing the quote.
        if bank + EPS >= price:
            for job in waiting:
                active.append({**job, "remaining_cost": price, "queued_at": now})
            waiting = []
        demand = sum(min(job["remaining_cost"], price / build_time * dt) for job in active)
        fraction = min(1.0, bank / demand) if demand > EPS else 1.0
        if demand > EPS and fraction < 1.0 - EPS:
            shortfall_time += dt
        for job in active:
            payment = min(job["remaining_cost"], price / build_time * dt) * fraction
            job["remaining_cost"] -= payment
            bank -= payment
            spent += payment
        unfinished = []
        for job in active:
            if job["remaining_cost"] < EPS:
                completed.append({"id": job["id"], "requested_at": job["requested_at"],
                                  "finished_at": round(now + dt, 6)})
            else:
                unfinished.append(job)
        active = unfinished
        rate = 0.0 if outage and outage[0] <= now < outage[1] else income_rate
        credited = rate * dt
        income += credited
        bank += credited
        require(bank >= -EPS, "Negative bank")
        bank = max(0.0, bank)
        require(abs(starting_bank + income - spent - bank) < EPS * max(1, count), "Conservation failed")
        if step == steps - 1 or (step + 1) % max(1, round(30 / dt)) == 0:
            traces.append({"time": round(now + dt, 6), "bank": round(bank, 6),
                           "completed": len(completed), "waiting_to_queue": len(waiting), "active": len(active)})
    return {"requested": count, "completed": len(completed), "waiting_to_queue": len(waiting),
            "unfinished_active": len(active), "remaining_liability": round(sum(j["remaining_cost"] for j in active), 6),
            "ending_bank": round(bank, 6), "source_income": round(income, 6), "spent": round(spent, 6),
            "underfunded_seconds": round(shortfall_time, 6), "trace_every_30_seconds": traces,
            "first_completion_at": completed[0]["finished_at"] if completed else None,
            "last_completion_at": completed[-1]["finished_at"] if completed else None}


def price_series(spec, count):
    return [min(spec["maximum"], spec["base"] + spec["increment"] * n) for n in range(count)]


def first_lockout(prices, base_cap, cap_gain):
    for owned, price in enumerate(prices):
        capacity = base_cap + owned * cap_gain
        if price > capacity + EPS:
            return {"owned_harvesters": owned, "purchase_number": owned + 1,
                    "price": round(price, 6), "capacity": capacity}
    return None


def checks(cfg):
    results = []
    def check(name, condition):
        require(condition, name)
        results.append({"name": name, "status": "pass"})
    check("outer miner produces one Crypto per three seconds", cfg["TYPE_CASH"]["pc"] / cfg["CASH_INTERVAL"] == 1 / 3)
    check("central ERP produces 1.5 Crypto/s", 3 * cfg["TYPE_CASH"]["erp"] / cfg["CASH_INTERVAL"] == 1.5)
    check("baseline eight harvesters capacity 500", cfg["INTEL_CAP_BASE"] + 8 * cfg["INTEL_CAP_PER_BUILD"] == 500)
    check("three fully funded farms complete in ten seconds", budget_sim(price=10, income_rate=0, starting_bank=30, duration=10, dt=0.1)["completed"] == 3)
    reused_quote = budget_sim(price=10, income_rate=0, starting_bank=10, duration=30, dt=0.1)
    check("one farm price can queue three jobs but cannot complete any without inflow", reused_quote["unfinished_active"] == 3 and reused_quote["completed"] == 0 and abs(reused_quote["spent"] - 10) < EPS)
    empty = budget_sim(price=10, income_rate=0, starting_bank=0, duration=30, dt=0.1)
    check("zero cash zero income leaves jobs unqueued, bank nonnegative", empty["waiting_to_queue"] == 3 and empty["ending_bank"] == 0)
    funded = budget_sim(price=10, income_rate=1, starting_bank=0, duration=40, dt=0.1)
    check("zero bank one Crypto/s queues at ten seconds and completes a three-farm burst near thirty", funded["completed"] == 3 and 30 <= funded["last_completion_at"] <= 30.2)
    check("Supply all-in marginal Crypto is 80 from zero Research", cfg["SUPPLY_COST"]["cash"] + cfg["SUPPLY_COST"]["research"] == 80)
    check("bounded escalation cannot exceed base Intel capacity", max(price_series({"base": 20, "increment": 5, "maximum": 50}, 100)) <= cfg["INTEL_CAP_BASE"])
    full_candidate = budget_sim(price=30, income_rate=0, starting_bank=90, duration=10, dt=0.1)
    check("candidate three farms cost 90 and finish in ten funded seconds", full_candidate["completed"] == 3 and abs(full_candidate["spent"] - 90) < EPS)
    shared_candidate = budget_sim(price=30, income_rate=0, starting_bank=30, duration=60, dt=0.1)
    check("candidate one-price bank cannot complete three simultaneous jobs", shared_candidate["completed"] == 0 and abs(shared_candidate["remaining_liability"] - 60) < EPS)
    for step in (0.05, 0.1, 0.5):
        run = budget_sim(price=30, income_rate=1, starting_bank=0, duration=100, dt=step)
        check(f"candidate rate-limited three-farm burst at dt={step}", run["completed"] == 3 and 90 - EPS <= run["last_completion_at"] <= 90 + 2 * step + EPS)
    longer_build = budget_sim(price=30, income_rate=0, starting_bank=90, duration=20, dt=0.1, build_time=20)
    check("build duration parameter changes funded work time", longer_build["completed"] == 3 and abs(longer_build["first_completion_at"] - 20) < EPS)
    check("exponential ninth purchase exceeds 220 capacity", first_lockout([10 * 1.5 ** n for n in range(20)], 100, 15)["purchase_number"] == 9)
    return results


def project(params, cfg):
    sc, sweeps = params["scenario_parameters"], params["sweeps"]
    build_time, base_cap = cfg["BUILD_TIME"], cfg["INTEL_CAP_BASE"]
    rates = {name: p["district_value"] * cfg["TYPE_CASH"][p["host_type"]] / cfg["CASH_INTERVAL"]
             for name, p in params["miner_profiles"].items()}
    capacity, migrations, harbor_prices, variants = {}, {}, {}, {}
    for name, variant in params["variants"].items():
        capacity[name] = {str(n): base_cap + n * variant["intel_cap_gain"] for n in [0, 1, 4, 8, 10, 20]}
        cap = base_cap + sc["ordinary_harvesters"] * variant["intel_cap_gain"]
        migrations[name] = [{"before": bank, "after_next_intel_tick": min(bank, cap), "clipped": max(0, bank - cap)} for bank in sc["migration_intel_banks"]]
        series = price_series(variant["harvester_price"], sweeps["harvester_count_max"])
        harbor_prices[name] = {"first_eight_prices": series[:8], "first_eight_total": sum(series[:8]),
                              "lockout_through_count": first_lockout(series, base_cap, variant["intel_cap_gain"])}
        farm_pool, farm_price = next(iter(variant["farm_cost"].items()))
        variants[name] = {"farm_resource": farm_pool, "farm_price": farm_price,
                          "marginal_upstream_intel_per_farm": farm_price,
                          "three_farm_host_price": 3 * farm_price,
                          "notes": "Crypto converts from Intel 1:1. Infrastructure, attack Intel and delivery time excluded."}
    rates_table = {name: {"crypto_per_second": rate, "intel_per_second_consumed_when_funded": rate,
                          "seconds_to_produce_10_crypto": 10 / rate,
                          "seconds_to_produce_30_crypto": 30 / rate} for name, rate in rates.items()}
    price_sweep, construction, outage, bursts = [], [], [], []
    for price in sweeps["farm_crypto_prices"]:
        for cadence in sc["host_cadences_seconds"]:
            demand = sc["farms_per_host"] * price / cadence
            price_sweep.append({"farm_price": price, "host_every_seconds": cadence,
                                "crypto_per_second_needed": demand,
                                "minimum_fully_funded_miners": {name: math.ceil(demand / rate - EPS) for name, rate in rates.items()}})
    for variant_name in ["baseline", "phase_a", "alternative_20", "superseded_10"]:
        pool, price = next(iter(params["variants"][variant_name]["farm_cost"].items()))
        incomes = {"available_intel": sc["baseline_available_intel_per_second"]} if pool == "intel" else rates
        bank = sc["baseline_starting_intel"] if pool == "intel" else sc["candidate_starting_cash"]
        for profile, rate in incomes.items():
            for cadence in sc["host_cadences_seconds"]:
                construction.append({"variant": variant_name, "pool": pool, "profile": profile,
                                     "income_per_second": rate, "starting_bank": bank,
                                     "host_every_seconds": cadence,
                                     "result": budget_sim(price=price, income_rate=rate, starting_bank=bank,
                                                          duration=sc["horizon_seconds"], dt=sc["step_seconds"], build_time=build_time,
                                                          cadence=cadence, jobs_per_request=sc["farms_per_host"])})
    candidate_price = params["variants"]["phase_a"]["farm_cost"]["cash"]
    for bank in sc["starting_cash_banks"]:
        for cadence in sc["host_cadences_seconds"]:
            outage.append({"starting_cash": bank, "host_every_seconds": cadence,
                           "crypto_only_upper_bound_completed_farms": math.floor(bank / candidate_price),
                           "result": budget_sim(price=candidate_price, income_rate=0, starting_bank=bank,
                                                duration=sc["outage_seconds"], dt=sc["step_seconds"], build_time=build_time,
                                                cadence=cadence, jobs_per_request=sc["farms_per_host"])})
    for profile, rate in {"no_income": 0.0, **rates}.items():
        for bank in sc["single_burst_cash_banks"]:
            bursts.append({"profile": profile, "starting_cash": bank,
                           "result": budget_sim(price=candidate_price, income_rate=rate, starting_bank=bank,
                                                duration=sc["horizon_seconds"], dt=sc["step_seconds"], build_time=build_time,
                                                jobs_per_request=sc["single_burst_jobs"])})
    exponential = [sweeps["exponential_harvester_base"] * sweeps["exponential_harvester_multiplier"] ** n
                   for n in range(sweeps["harvester_count_max"])]
    cap_sweep = [{"cap_gain": gain, "eight_harvesters_capacity": base_cap + 8 * gain,
                  "ten_harvesters_capacity": base_cap + 10 * gain,
                  "exponential_price_first_lockout": first_lockout(exponential, base_cap, gain),
                  "phase_b_price_first_lockout": first_lockout(price_series(params["variants"]["phase_b_optional"]["harvester_price"], len(exponential)), base_cap, gain)}
                 for gain in sweeps["intel_cap_gains"]]
    supply = cfg["SUPPLY_COST"]
    supply_crypto = supply["cash"] + supply["research"]
    price_comparison = []
    miner_price = cfg["BUILD_COSTS"]["cash"]["intel"]
    for price in sweeps["farm_crypto_prices"]:
        price_comparison.append({
            "farm_crypto_price": price,
            "source_intel_per_farm_after_setup": price,
            "ordinary_miner_saving_seconds": price / rates["outer_pc"],
            "one_miner_opening_order_seconds": 2 * build_time + price / rates["outer_pc"],
            "zero_bank_direct_one_miner_recovery_seconds": miner_price / cfg["RIG_INTEL"] + 2 * build_time + price / rates["outer_pc"],
            "supply_equivalent_farms": supply_crypto / price,
            "source_intel_with_one_miner": {str(n): miner_price + n * price for n in (1, 3, 10)},
            "baseline_direct_source_intel": {str(n): n * cfg["BUILD_COSTS"]["bot"]["intel"] for n in (1, 3, 10)},
            "first_packet_threshold_seconds_before_travel": {
                name: math.ceil(price / (rate * cfg["CASH_INTERVAL"]) - EPS) * cfg["CASH_INTERVAL"]
                for name, rate in rates.items()
            },
        })
    labs = []
    for miners in sc["lab_comparison_outer_miners"]:
        gross = miners * rates["outer_pc"]
        net = gross - sc["lab_research_per_second"]
        labs.append({"outer_miners": miners, "gross_crypto_per_second": gross,
                     "lab_crypto_per_second_for_full_output": sc["lab_research_per_second"],
                     "surplus_crypto_per_second_if_lab_fully_funded": net,
                     "lab_fully_fundable_without_using_bank": net >= 0,
                     "farms_per_minute_without_lab": gross * 60 / candidate_price,
                     "farms_per_minute_while_maintaining_lab_output": max(0, net) * 60 / candidate_price})
    return {"miner_rates": rates_table, "variants": variants, "intel_capacities": capacity,
            "stock_migration_if_new_cap_is_live": migrations, "harvester_prices": harbor_prices,
            "supply_card_opportunity_cost": {"direct_cost": supply, "crypto_including_research_conversion": supply_crypto,
                                             "intel_for_crypto_and_credentials": supply_crypto + supply["creds"],
                                             "equivalent_phase_a_farms": supply_crypto / candidate_price,
                                             "card_research_duration_seconds": cfg["SUPPLY_TIME"],
                                             "zero_research_one_pc_lab_seconds": supply["research"] / cfg["RESEARCH_PER_BUILD"],
                                             "notes": "Existing producers assumed; infrastructure, travel and possible overlap with card research excluded."},
            "lab_budget_comparison": labs, "farm_price_sweep": price_sweep, "farm_price_comparison": price_comparison, "cap_gain_sweep": cap_sweep,
            "repeated_construction_budget": construction, "sixty_second_miner_outage": outage,
            "three_farm_burst": bursts,
            "minimum_funded_build_seconds": build_time}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--parameters", type=Path, default=HERE / "parameters.json")
    parser.add_argument("--output", type=Path, default=HERE / "results.json")
    args = parser.parse_args()
    params = json.loads(args.parameters.read_text(encoding="utf-8"))
    cfg, provenance, markers = read_config(params["config_expectations"])
    validations = checks(cfg)
    metrics = project(params, cfg)
    candidate_price = params["variants"]["phase_a"]["farm_cost"]["cash"]
    baseline_price = cfg["BUILD_COSTS"]["bot"]["intel"]
    material_delta = candidate_price - baseline_price
    candidate_gain = params["variants"]["phase_a"]["intel_cap_gain"]
    supply_crypto = metrics["supply_card_opportunity_cost"]["crypto_including_research_conversion"]
    result = {
        "model_version": params["model_version"],
        "game_or_config_version": {"source": "working tree at execution, not a claim about HEAD", "sha256": provenance},
        "parameters": params,
        "model_validation_cases": validations,
        "runtime_fidelity_markers": markers,
        "seed_and_trial_count": {"randomness": "none", "scenario_execution": "deterministic"},
        "model_changes": ["1.0.0: initial budget/affordability model with source-value drift checks",
                          "1.1.0: candidate 30 Crypto, explicit 20/10 alternatives, opening/recovery and packet-threshold comparisons, large-wallet outage, build-time propagation and timestep regressions"],
        "metrics_by_scenario": metrics,
        "targets_and_guardrails": [
            {"name": "source values and known cases agree", "status": "pass"},
            {"name": "budget stocks nonnegative and money conserved", "status": "pass"},
            {"name": "bounded harvester prices remain affordable at full cap", "status": "pass"},
            {"name": "Phase A preserves the existing material cost per farm", "status": "pass" if abs(material_delta) < EPS else "warning", "upstream_intel_delta": material_delta, "reason": "Crypto converts from Intel 1:1; miner infrastructure and delivery add separate costs."},
            {"name": "Crypto-funded farms preserve useful card play", "status": "warning", "reason": f"Supply costs {supply_crypto / candidate_price:g} Phase A farms through both Crypto stages, excluding infrastructure; actual tactical value still needs playtests."},
            {"name": "snowball fixed or win-rate balance proven", "status": "warning", "reason": "Not measured. Construction demand is exogenous; farms remain free permanent bot sources."}
        ],
        "assumptions_and_omissions": [
            "All projections are for human rates, stable active slots, fully funded inputs and uninterrupted paths unless an outage is named.",
            "Steady miner output is district value times host cash multiplier divided by CASH_INTERVAL; per-second delivery is averaged.",
            "Budget simulation models one funding pool with externally supplied income; it does not reproduce the runtime resource pipeline or evaluate strategies.",
            "New-host requests occur at t=0 then every cadence until strictly before horizon. Unlimited eligible slots are assumed for this stress test.",
            "The no-reservation queue check and proportional payment over ten funded seconds are represented; queued jobs may stall.",
            "No routes, packet latency, buffering, link congestion, travel loss, combat, cards or ownership are simulated. Current control-stage labels do not disable slots.",
            "No evidence about win rate, match duration or whether an actual player reaches the forecast cadence is generated.",
            "Intel is consumed 1:1 by Crypto and Credentials; Crypto is consumed 1:1 by Research. Rates need that upstream support after attack spending.",
            "Lab surplus calculations assume maintaining full lab output. Runtime construction precedes lab conversion, so a shortage may suppress Research instead.",
            "The active-card research queue spends before construction, which precedes miner/Credential/lab production; that priority is not emulated here.",
            "Time-step timings are approximate within one 0.1-second step for ordinary cases; packet schedules can add further runtime delay.",
            "Outage forecasts start with the indicated cash bank and no active jobs; existing bots and completed farms are unaffected.",
            "Baseline construction scenarios use 10 Intel/s already available after all other uses; candidate rates assume fully funded miners. This is an affordability comparison, not equal total economic investment.",
            "Bounded escalation formula is proposed behavior; pending-job counting and quote locking require implementation and gameplay tests.",
            "Stock-migration entries describe the current clamp rule if the new cap is applied live; they are not a save migration implementation.",
            "Opening/recovery numbers describe a specified miner-first build order with no other spending; adding producers changes that order. They are not global pacing lower bounds.",
            "Packet threshold estimates assume one fully funded miner, zero initial packet credit, one emission each CASH_INTERVAL and no travel; actual tick phase and congestion are omitted."
        ]
    }
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"Model {params['model_version']}: {len(validations)} known-case checks passed; all scenario invariants passed.")
    print(f"Phase A: {candidate_price:g} Crypto/farm, +{candidate_gain:g} Intel cap/harvester; eight harvesters = {cfg['INTEL_CAP_BASE'] + 8 * candidate_gain:g} Intel cap.")
    print("One miner: outer 0.333, middle 0.667, central 1.0, central ERP 1.5 Crypto/s (same Intel/s input).")
    print("A three-farm host every 15/30/60 s requires " + "/".join(f"{3 * candidate_price / cadence:g}" for cadence in (15, 30, 60)) + " Crypto/s.")
    print(f"Supply opportunity cost = {supply_crypto:g} Crypto from zero Research = {supply_crypto / candidate_price:.3g} farms (existing infrastructure).")
    print(f"Three outer miners + one fully funded PC lab leave 0.5 Crypto/s = {0.5 * 60 / candidate_price:g} farms/minute.")
    print(f"Material cost delta per farm = {material_delta:g} upstream Intel; construction/card opportunity and match outcomes still need playtesting.")
    print(f"Saved {args.output}")


if __name__ == "__main__":
    main()
