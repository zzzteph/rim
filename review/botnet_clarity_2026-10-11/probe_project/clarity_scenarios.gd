extends SceneTree

var horizon := 120.0
var fps := 60.0
var results := []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="): horizon=float(arg.trim_prefix("--seconds="))
		if arg.begins_with("--fps="): fps=float(arg.trim_prefix("--fps="))
	assert(horizon>=10 and fps>=30)
	_run.call_deferred()

func run_case(name: String, sources: Array, target: int, income_sources: Array, intel_start: float, chain := false, double_bot := false, locked := false) -> Dictionary:
	var game=load("res://scripts/botnet_proto.gd").new(); root.add_child(game); game.set_process(false)
	game._enemy_timer=horizon+100; game.intel=intel_start
	for i in sources:
		game.hosts[i].owned=true; game.hosts[i].bots=30.0; game.hosts[i].assign=target; game._next_depart[i]=0.0
	for i in income_sources: game.hosts[i].builds=["bot","intel"]
	if double_bot: game.hosts[0].builds=["bot","bot"]
	if locked:
		game.hosts[0].builds=["bot","bot"]; game.hosts[5].builds=["bot","cap"]
		game._build(0,"intel"); game._build(5,"intel")
		assert(game._intel_rate()==0.0)
	if chain: game.hosts[0].assign=5
	var seen := {}; var departures := {}; var capture_time := -1.0
	var spent_to_target := 0
	for tick in int(horizon*fps):
		game._process(1.0/fps)
		for f in game.flights:
			var src: int=f.route[0]
			var key := str(src)+":"+str(f.depart_t)
			if not seen.has(key):
				seen[key]=true; departures[str(src)]=int(departures.get(str(src),0))+1
				if f.route.back()==target: spent_to_target+=1
		for h in game.hosts: assert(h.bots>=-0.000001 and h.bots<=game.NODE_CAP+0.000001)
		if game.hosts[target].owned:
			capture_time=(tick+1)/fps; break
	var result := {"name":name,"sources":sources,"target":target,"initial_intel":intel_start,"intel_income":game._intel_rate(),
		"captured_at":capture_time,"final_target_bots":game.hosts[target].bots,"final_intel":game.intel,
		"departures_by_source":departures,"packets_sent_to_target":spent_to_target,"outstanding_packets":game.flights.size(),
		"source0_builds":game.hosts[0].builds.duplicate(),"source5_builds":game.hosts[5].builds.duplicate()}
	game.free(); print(JSON.stringify(result)); results.append(result); return result

func _run() -> void:
	var one:=run_case("one_funded_source_ordinary",[0],1,[0],50)
	var two:=run_case("two_funded_sources_ordinary",[0,5],1,[0,5],50)
	var three:=run_case("three_funded_sources_idle_hub",[0,5,6],7,[0,5,6],50)
	var four:=run_case("four_funded_sources_idle_hub",[0,1,5,6],7,[0,1,5,6],50)
	var unfunded:=run_case("two_sources_no_income_ordinary",[0,5],1,[],50)
	var weak:=run_case("two_sources_no_income_weakest_frontier",[0,5],10,[],50)
	var dead:=run_case("full_slots_zero_intel_no_recovery",[0,5],1,[],0,false,false,true)
	var scarce:=run_case("two_orders_one_income_zero_bank",[0,5],1,[0],0)
	var chain:=run_case("serial_reinforcement_then_attack",[0,5],1,[0,5],50,true)
	var building:=run_case("double_bot_source_still_one_stream",[0],1,[5],50,false,true)
	assert(one.captured_at<0 and three.captured_at<0 and unfunded.captured_at<0 and weak.captured_at<0 and chain.captured_at<0)
	assert(two.captured_at>0 and four.captured_at>0)
	assert(dead.packets_sent_to_target==0 and dead.intel_income==0)
	assert(scarce.departures_by_source.get("0",0)>0 and scarce.departures_by_source.get("5",0)==0)
	var output:=FileAccess.open("res://scenario_results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"model":"Frozen actual production script; controlled ownership/building fixtures; unchanged combat rates",
		"seconds":horizon,"fps":fps,"enemy_ai":"disabled: isolates whether the UI-described attack can progress against idle regeneration",
		"limitations":"Not a complete match or win-path proof. Outgoing enemy streams and changing ownership alter resistance. Known runtime timing approximations remain.","cases":results},"\t"))
	output.close(); print("CLARITY_SCENARIOS_COMPLETE ",results.size()); quit()
