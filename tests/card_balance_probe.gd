extends SceneTree
## Independent first-pass economy model: one ordinary PC market, harvester and lab.
## No combat, transport delay or caps. Produces limits, not a claim of PvP balance.
const Cards = preload("res://scripts/botnet_cfg/cards.gd")
const Tuning = preload("res://scripts/botnet_cfg/tuning.gd")
var checks := 0
var failures := []
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description)
func project(seconds: float, intel_rate: float, boost: float) -> Dictionary:
	var intel := 0.0; var crypto := 0.0; var credentials := 0.0; var research := 0.0
	var spent_intel := 0.0; var spent_crypto := 0.0; var made_crypto := 0.0
	for tick in int(seconds * 60):
		intel += intel_rate / 60.0
		var market := boost / (Tuning.CASH_INTERVAL * 60.0)
		var harvest := boost * Tuning.CRED_PER_BUILD / 60.0
		var fraction := minf(1, intel / (market + harvest))
		market *= fraction; harvest *= fraction
		intel -= market + harvest; spent_intel += market + harvest
		crypto += market; made_crypto += market; credentials += harvest
		var work := minf(crypto, boost * Tuning.RESEARCH_PER_BUILD / 60.0)
		crypto -= work; research += work; spent_crypto += work
	return {"intel":intel,"crypto":crypto,"credentials":credentials,"research":research,"spent_intel":spent_intel,"spent_crypto":spent_crypto,"made_crypto":made_crypto}
func _initialize() -> void:
	var predictions := []
	for input in [0.0, 0.25, 1.0, 2.0]:
		for boost in [1.0, 2.0]:
			var model := project(30, input, boost)
			check(absf(model.spent_intel-model.made_crypto-model.credentials)<0.00001,"Intel conversion conserves inputs")
			check(absf(model.spent_crypto-model.research)<0.00001,"Research conserves Crypto")
			check(absf(model.intel+model.spent_intel-input*30)<0.00001,"Source budget is conserved")
			check(model.intel >= -0.000001 and model.crypto >= -0.000001,"Inputs never go negative")
			predictions.append({"seconds":30,"intel_per_second":input,"production_multiplier":boost,"outputs":model})
	var standard := project(30,1,1)
	check(absf(standard.made_crypto-10)<0.00001 and absf(standard.credentials-15)<0.00001 and absf(standard.research-10)<0.00001,"Known case: 10 Crypto made, 15 Credentials, 10 Research from 30 Intel over 30s")
	check(absf(standard.intel-5)<0.00001 and absf(standard.crypto)<0.00001,"An always-on lab consumes all ordinary market profit until Research fills")
	var bounds := []
	for key in Cards.CARD_ORDER:
		var card: Dictionary = Cards.CARDS[key]
		var crypto_needed: float = card.cost.cash + card.cost.research
		bounds.append({"card":key,"crypto_including_research_conversion":crypto_needed,"intel_including_credentials_and_crypto":crypto_needed+float(card.cost.creds),"single_pc_market_seconds_lower_bound":crypto_needed*Tuning.CASH_INTERVAL})
		if card.get("defense",false):
			for resource in card.cost: check(card.cost[resource] == Cards.CARDS[card.pair].cost[resource]*2,"Defense paired price: "+key+"/"+resource)
	var report := {"model_version":3,"checks":checks,"failures":failures,"predictions":predictions,"card_resource_lower_bounds":bounds,"limits":"Full active slots. No caps, transport, travel, combat or interrupted funding. Retained prices/rates; no match pacing or metagame balance verdict. Pause labs to save Crypto."}
	var file := FileAccess.open("res://review/implemented_ui/card_balance.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print(JSON.stringify({"checks":checks,"failures":failures,"ordinary_pc_30s":standard})); quit(0 if failures.is_empty() else 1)
