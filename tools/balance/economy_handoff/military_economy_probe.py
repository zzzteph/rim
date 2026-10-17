"""Independent rate checks for MILITARY_ECONOMY_ADDENDUM.md; no game mutation.

Run: python tools/balance/economy_handoff/military_economy_probe.py
Continuous sustained-flow formulas only: no AI, routes, combat packets or match outcomes.
"""
import json
import math
from pathlib import Path


def depletion(garrison, attack, regen, guards=0, outward=0):
    net = attack - regen - guards + outward
    return None if net <= 0 else garrison / net


def paid_output(potential, capacity_room, crypto, dt, rig=False, price=0.25):
    demand = min(potential * dt, capacity_room)
    free = min(demand, 2 * dt) if rig else 0
    paid = min(demand - free, crypto / price)
    return free + paid, paid * price


def run():
    checks = []

    def check(name, condition):
        if not condition:
            raise AssertionError(name)
        checks.append(name)

    check("current four-farm host stalls four attackers", depletion(120, 4, 4) is None)
    check("capped four-farm host depletes in sixty seconds", depletion(120, 4, 2) == 60)
    check("capped ERP depletes in seventy-five seconds", depletion(150, 4, 2) == 75)
    check("three attackers are insufficient for ERP siege budget", depletion(150, 3, 2) > 120)
    check("two guards sustain capped ERP against four attackers", depletion(150, 4, 2, 2) is None)
    check("diminishing curve leaves ERP at two hundred forty seconds", depletion(150, 4, 2.25 * 1.5) == 240)
    check("full host spends nothing", paid_output(2, 0, 100, 1) == (0, 0))
    check("zero Crypto gives no paid production", paid_output(2, 30, 0, 1) == (0, 0))
    check("partial funding buys only actual output", paid_output(2, 30, 0.25, 1) == (1, 0.25))
    check("rig allowance requires available production", paid_output(0, 30, 0, 1, True) == (0, 0))
    check("starting rig can regenerate two for free", paid_output(2, 60, 0, 1, True) == (2, 0))
    check("rig boost beyond allowance costs Crypto", paid_output(4, 60, 1, 1, True) == (4, 0.5))
    check("one Crypto buys four bots", paid_output(20, 100, 1, 1) == (4, 1))

    economics = [{"price_per_bot": price, "paid_bots_per_second": bots,
                  "crypto_per_second": price * bots,
                  "outer_miners_required": math.ceil(price * bots * 3 - 1e-9)}
                 for price in (0.15, 0.25, 0.5) for bots in (4, 8, 12, 20)]
    combat = []
    for name, farms, multiplier in (("ordinary_3", 3, 1), ("ordinary_4", 4, 1), ("erp_5", 5, 1.5)):
        for attackers in (3, 4):
            for guards in (0, 1, 2):
                combat.append({"host": name, "attack_arrivals_per_s": attackers, "guards_per_s": guards,
                               "garrison": 30 * farms, "current_regen": farms * multiplier,
                               "proposed_regen": min(2, farms * multiplier),
                               "current_depletion_s": depletion(30 * farms, attackers, farms * multiplier, guards),
                               "proposed_depletion_s": depletion(30 * farms, attackers, min(2, farms * multiplier), guards)})
    result = {"model_version": "1.0.0", "checks_passed": checks, "economics": economics, "combat": combat,
              "status": "Independent continuous-rate predictions; not runtime or playtest validation.",
              "assumptions": ["Snapshot baseline: 30 bots capacity per farm, 1 base bot/s per farm, ERP bot multiplier1.5, 1 arrival/s per funded attack source.",
                              "Ordinary outer miner1/3 Crypto/s; no labs, cards, travel or other spending in miner requirements.",
                              "Regeneration cap applies after permanent host modifiers and before temporary boosts. Tables assume no boosts.",
                              "Attackers can continuously fund Intel and bots; defenders can fund any proposed paid regeneration.",
                              "No garrison outflow in combat tables. Null depletion means nonpositive net damage, not immunity to cards or alternative attacks.",
                              "paid_output checks one allocation only; shared-funding order independence still needs Godot tests."]}
    path = Path(__file__).with_name("military_economy_results.json")
    path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"{len(checks)} rate and boundary checks passed; {len(economics)} economic scenarios; {len(combat)} combat scenarios.")
    print("Four sources vs unsupported full hosts: 3 farms90->45s; 4 farms stalled->60s; 5-farm ERP stalled->75s.")
    print("At0.25 Crypto/bot, six outer miners support8 paid bots/s before competing uses. Not a match-balance verdict.")
    print(f"Saved {path}")


if __name__ == "__main__":
    run()
