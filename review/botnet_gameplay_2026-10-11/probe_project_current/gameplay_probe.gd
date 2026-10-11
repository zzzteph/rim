extends SceneTree

var game
var results := []

func _initialize() -> void:
	_run.call_deferred()

func fresh() -> void:
	if is_instance_valid(game):
		game.free()
	game = load("res://scripts/botnet_proto.gd").new()
	root.add_child(game)
	game.set_process(false)
	game._enemy_timer = 9999.0

func record(case_name: String, observed: Dictionary) -> void:
	results.append({"case": case_name, "observed": observed})
	print(case_name, " ", JSON.stringify(observed))

func packet(target: int, player: bool, time_left: float) -> Dictionary:
	# Sources 2 and 8 border HUB 7; vary remaining time, not the route duration.
	return {"route": [2 if player else 8, target], "t": 1.5-time_left, "dur": 1.5, "count": 1.0, "player": player}

func _run() -> void:
	fresh()
	var rate: float = game.SEND_RATE
	var frame_counts := {}
	for fps in [60, 10, 1, 0.5]:
		fresh(); game.hosts[0].assign = 1
		for tick in int(8 * fps): game._emit(1.0 / float(fps))
		frame_counts[str(fps)] = game.flights.size()
	assert(int(frame_counts["60"]) > int(frame_counts["0.5"]))
	record("01_dispatch_depends_on_frame_rate", {"send_rate":rate,"seconds":8,"emitted_by_fps":frame_counts})

	fresh(); game.hosts[0].assign = 1
	var travel: float = game._travel_time([0,1])
	game._process(travel)
	assert(game.flights.is_empty() and game.hosts[1].bots < 20.0+travel)
	record("02_new_packet_aged_before_emission_time", {"frame_seconds":travel,"first_emission_due":1.0/rate,"earliest_valid_arrival":travel+1.0/rate,"already_delivered":true,"target_bots":game.hosts[1].bots})

	fresh(); game.hosts[1].assign = 0
	game._cancel_at(0)
	assert(game.hosts[1].assign == -1)
	record("03_cancel_friendly_stops_enemy_attack", {"enemy_order_after_cancel":game.hosts[1].assign})

	fresh(); game.hosts[1].assign = 0
	game._cancel_at(1)
	assert(game.hosts[1].assign == -1)
	record("04_cancel_enemy_stops_enemy_attack", {"enemy_order_after_cancel":game.hosts[1].assign})

	fresh(); game.hosts[0].assign = 5
	game._emit(1.0/rate + 0.00001)
	assert(game.flights.size() == 1)
	game._deliver(game.flights[0])
	assert(game.hosts[0].bots == 29 and game.hosts[5].bots == 30)
	record("05_full_friendly_discards_supply", {"source_before":30,"source_after":game.hosts[0].bots,"destination_before":30,"destination_after":game.hosts[5].bots})

	fresh()
	for h in game.hosts: h.owned = false; h.bots = 0.0; h.assign = -1
	game.hosts[6].owned = true; game.hosts[6].bots = 30.0
	game.hosts[1].bots = 30.0; game.hosts[1].assign = 0
	game._enemy_timer = 0.0; game._enemy_ai(0.01)
	assert(game.hosts[1].assign == 0)
	record("06_enemy_keeps_friendly_target", {"enemy_source":1,"assigned_friendly_target":game.hosts[1].assign,"available_hostile_neighbor":6})

	fresh(); game.hosts[1].owned = true
	game.hosts[0].assign = 2
	game._emit(1.0/rate + 0.00001)
	assert(game.flights.size() == 1)
	game.hosts[1].owned = false
	game._emit(0.01)
	assert(game.hosts[0].assign == -1)
	var target_before: float = game.hosts[2].bots
	game._advance_flights(10.0)
	assert(game.hosts[2].bots == target_before-1)
	game.hosts[1].owned = true
	game._emit(1.0/rate + 0.00001)
	assert(game.hosts[0].assign == -1)
	record("07_relay_loss_erases_order_packet_continues", {"restored_route_assignment":game.hosts[0].assign,"packet_delivered_through_lost_relay":true})

	var arrival_outcomes := []
	for chronological in [false,true]:
		fresh(); game.hosts[game.hub].bots = 1.0; game.hosts[2].owned = true
		var attack := packet(game.hub,true,0.5)
		var reinforcement := packet(game.hub,false,0.1)
		game.flights = [reinforcement,attack] if chronological else [attack,reinforcement]
		game._advance_flights(0.5)
		arrival_outcomes.append({"list_chronological":chronological,"won":game.won,"hub_owned":game.hosts[game.hub].owned,"hub_bots":game.hosts[game.hub].bots})
	assert(arrival_outcomes[0].won and not arrival_outcomes[1].won)
	record("08_later_arrival_processed_first_can_grant_false_win", {"enemy_reinforcement_arrives_at":0.1,"player_attack_arrives_at":0.5,"outcomes":arrival_outcomes})

	fresh(); game.hosts[game.hub].bots = 1.0; game.hosts[2].owned = true
	game.flights = [packet(game.hub,true,0.1),packet(game.hub,false,0.2)]
	game._advance_flights(0.5)
	assert(game.won and not game.hosts[game.hub].owned)
	record("09_packets_mutate_board_after_win", {"won":game.won,"hub_owned":game.hosts[game.hub].owned})

	fresh(); game.hosts[0].assign = 1
	game._emit(1.0/rate+0.00001)
	game.paused = true
	var prior := JSON.stringify({"hosts":game.hosts,"flights":game.flights,"enemy_timer":game._enemy_timer})
	game._process(5.0)
	assert(prior == JSON.stringify({"hosts":game.hosts,"flights":game.flights,"enemy_timer":game._enemy_timer}))
	record("10_pause_preserves_simulation", {"passed":true})

	fresh(); game.hosts[0].assign = 1
	game._emit(1.0/rate+0.00001)
	game.hosts[0].assign = 5
	assert(game.flights[0].route.back() == 1)
	record("11_retarget_preserves_dispatched_destination", {"future_target":5,"packet_target":game.flights[0].route.back()})

	var output := FileAccess.open("res://results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"method":"Controlled engine fixtures using frozen production script; no human playtest or balance verdict", "send_rate":rate,"cases":results},"\t"))
	output.close()
	print("GAMEPLAY_AUDIT_COMPLETE ",results.size()," cases")
	quit()
