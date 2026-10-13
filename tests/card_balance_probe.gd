extends SceneTree
## Deterministic upper-bound economy model for repeated card tuning.
## godot --headless --path . --script tests/card_balance_probe.gd
## Uses current configuration. Assumes all slots active, no storage caps,
## no interruption/capture, value 1 or 3, player economy (no AI multiplier).
## Resource vectors are NOT converted to a single fungible currency.
const Cards = preload("res://scripts/botnet_cfg/cards.gd")
const Types = preload("res://scripts/botnet_cfg/types.gd")
const Tuning = preload("res://scripts/botnet_cfg/tuning.gd")
var failures: Array = []

func allocations(slots: int) -> Array:
	var rows := []
	for markets in range(slots + 1):
		for credentials in range(slots - markets + 1):
			for labs in range(slots - markets - credentials + 1):
				rows.append([markets, credentials, labs, slots - markets - credentials - labs])
	return rows

func _initialize() -> void:
	var scenarios := []; var sweep := []; var damage := []
	var price: Dictionary = Cards.CARDS.supply.cost
	for duration in [5.0, 10.0, 15.0, 20.0]:
		var profitable := []
		for type in Types.NODE_TYPES:
			var stats: Dictionary = Types.NODE_TYPES[type]
			var seconds: float = duration * (1 - float(Types.RESIST[type].supply))
			for value in [1, 3]:
				for allocation in allocations(int(stats.slots)):
					var gross := {"cash": float(allocation[0]) * value * float(stats.cash) / Tuning.CASH_INTERVAL * seconds, "creds": float(allocation[1]) * Tuning.CRED_PER_BUILD * float(stats.cred) * seconds, "research": float(allocation[2]) * Tuning.RESEARCH_PER_BUILD * float(stats.research) * seconds, "intel": float(allocation[3]) * Tuning.INTEL_PER_BUILD * float(stats.intel) * seconds}
					var repays := true
					for resource in price:
						if float(gross[resource]) + 0.00001 < float(price[resource]): repays = false
					if repays: profitable.append({"type": type, "value": value, "allocation": allocation, "gross": gross})
					if type == "erp" and value == 3 and allocation == [1, 1, 1, 2]: scenarios.append({"duration": duration, "effective_seconds": seconds, "gross": gross, "resource_swing": "twice gross: stolen from enemy and gained by player"})
		var row := {"duration": duration, "self_repaying_loadouts": profitable.size(), "examples": profitable.slice(0, 2)}
		sweep.append(row)
		if duration == 15.0 and not profitable.is_empty(): failures.append("15-second candidate self-finances all inputs")
	# Hand-check: one ordinary PC market produces 1/3 cash per second.
	if not is_equal_approx(1.0 / Tuning.CASH_INTERVAL * 15, 5.0): failures.append("PC market fidelity")
	for card in Cards.CARD_ORDER:
		var cd: Dictionary = Cards.CARDS[card]
		var effects := {}
		for type in Types.NODE_TYPES:
			var scale := 1 - float(Types.RESIST[type].get(str(cd.fam), 0))
			effects[type] = {"defenders_removed_from_30": 30 * clampf(float(cd.power) * scale, 0, 1), "seconds": float(cd.dur) * scale}
		damage.append({"card": card, "cost": cd.cost, "research_seconds": cd.time, "type_effects": effects})
	var result := {"model_version": 1, "scope": "Full active production, no caps or recapture; upper bounds, not observed player utility", "supply_cost": price, "supply_duration_sweep": sweep, "erp_mixed_producer": scenarios, "card_roles": damage, "failures": failures}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://review/implemented_ui"))
	var file := FileAccess.open("res://review/implemented_ui/card_balance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t")); file.close()
	print(JSON.stringify({"sweep": sweep, "examples": scenarios, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
