extends SceneTree
## Persistent four-card model. Run: godot --headless --path . --script tests/card_balance_probe.gd
## Independent effect/economy predictions; runtime fidelity is checked by four_card_effect_test.gd.
## Full active production, no caps, travel, recapture or rival AI policies. No price/metagame verdict.
const Cards = preload("res://scripts/botnet_cfg/cards.gd")
const Types = preload("res://scripts/botnet_cfg/types.gd")
const Tuning = preload("res://scripts/botnet_cfg/tuning.gd")
const EXPECTED_ORDER := ["phishworm", "zeroday", "ddos", "supply"]
const SCHEDULES := {"phishworm": [30.0, 20.0, 10.0], "zeroday": [20.0], "ddos": [30.0, 20.0, 10.0, 5.0, 2.0], "supply": [0.0]}
const POWERS := {"phishworm": 0.1, "zeroday": 0.75, "ddos": 0.0, "supply": 0.0}
var checks := 0
var failures: Array = []

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description)

func resources(type: String, builds: Array, defenders: float, value: int, native_rig := false) -> Dictionary:
	var stats: Dictionary = Types.NODE_TYPES[type]
	var standing := builds.filter(func(kind): return str(kind) != "")
	var inactive := 0 if defenders >= 20.0 else (1 if defenders >= 10.0 else 2)
	var active := standing.slice(0, maxi(1, standing.size() - inactive))
	return {"cash": active.count("cash") * value * float(stats.cash) / Tuning.CASH_INTERVAL,
		"creds": active.count("cred") * Tuning.CRED_PER_BUILD * float(stats.cred),
		"research": active.count("lab") * Tuning.RESEARCH_PER_BUILD * float(stats.research),
		"intel": active.count("intel") * Tuning.INTEL_PER_BUILD * float(stats.intel) + (Tuning.RIG_INTEL if native_rig else 0.0)}

func _initialize() -> void:
	check(Cards.CARD_ORDER == EXPECTED_ORDER and Cards.CARDS.size() == 4, "Exactly four requested cards")
	var predictions := []
	for key in EXPECTED_ORDER:
		var card: Dictionary = Cards.CARDS[key]
		var schedule: Array = card.get("durations", [card.dur])
		check(schedule == SCHEDULES[key], "%s durations match the requested successive-node schedule" % key)
		check(is_equal_approx(float(card.power), float(POWERS[key])), "%s defender fraction matches the requested value" % key)
		for type in Types.NODE_TYPES:
			for defenders in [0.0, 1.0, 20.0, 30.0, 100.0]:
				for index in schedule.size():
					var after: float = defenders * (1.0 - float(POWERS[key]))
					check(after >= 0.0 and after <= defenders, "%s bounds at %s/%s/level%d" % [key, type, defenders, index + 1])
					predictions.append({"card": key, "type": type, "level": index + 1, "defenders_before": defenders, "defenders_after": after, "seconds": schedule[index], "type_resistance_applied": false})
	# Hand case: ordinary PC market outputs 1/3 Cash each second, hence 10 Cash in 30s.
	var pc := resources("pc", ["cash"], 30.0, 1)
	check(is_equal_approx(float(pc.cash) * 30.0, 10.0), "PC market known case")
	var ordinary_builds := ["cash", "cred", "lab", "intel", "intel"]
	var erp := resources("erp", ordinary_builds, 27.0, 3)
	check(erp == {"cash": 1.5, "creds": 0.75, "research": 0.75, "intel": 3.0}, "ERP post-Phishing production known case")
	var campaign := []
	for seconds in SCHEDULES.phishworm:
		var gross := {}
		for resource in erp: gross[resource] = float(erp[resource]) * float(seconds)
		campaign.append({"level": campaign.size() + 1, "seconds": seconds, "defenders_after_from_30": 27.0, "resource_gross_upper_bound": gross})
	var boundary := resources("erp", ordinary_builds, 18.0, 3)
	check(is_equal_approx(float(boundary.intel), 1.5), "Damage crossing Stable to Shaky deactivates the last Intel slot")
	var result := {"model_version": 2, "game_or_config_version": "four fixed-effect cards", "checks": checks, "failures": failures,
		"parameters": Cards.CARDS, "levels": "Initial target is level 1; one distinct linked foreign node per level; stop at dead ends",
		"predictions": predictions, "erp_mixed_producer_campaign": campaign,
		"boundary_after_damage": boundary, "slot_wipe": {"installed_slots_after": 0, "construction_jobs_after": 0, "ownership_and_defenders": "preserved", "native_rig_intel": "preserved"},
		"assumptions_and_omissions": "No caps, travel, recapture or interruptions in economy upper bounds; bots remain local; resistance bypassed; prices retained; no match balance or player utility claim",
		"model_changes": "Replaced obsolete Supplychain theft tuning with four-card effect and post-damage output model. Runtime integration has a separate executable regression suite."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://review/implemented_ui"))
	var file := FileAccess.open("res://review/implemented_ui/card_balance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t")); file.close()
	print(JSON.stringify({"checks": checks, "failures": failures, "campaign": campaign, "boundary": boundary}))
	quit(0 if failures.is_empty() else 1)
