import json,sys
d=json.load(open(sys.argv[1]))
rows=d["rows"]
def key(r): return (r["seed"], r["swap"])
for sc in ["local_opportunity","counterattack","sound_defence","chokepoint","repeated_assault"]:
    print("\n=====",sc)
    for r in rows:
        if r.get("scenario")!=sc: continue
        tag=f'seed{r["seed"]} {"swap" if r["swap"] else "    "} {r["mode"]:8}'
        if "skipped" in r: print(tag,"SKIPPED:",r["skipped"]); continue
        src=f'src n={len(r.get("sources",[]))} min={r.get("source_min")} <=half_s={r.get("source_secs_at_or_below_half")} <15_s={r.get("source_secs_below_15")}'
        if sc=="local_opportunity":
            print(tag, f'X={r["objective"]}({r["objective_type"]},{int(r["objective_bots"])})', "captured" if r["captured"] else "held", r["capture_s"], f'sent={r["bots_sent"]} intel={r["intel_spent_approx"]}', src)
        elif sc=="counterattack":
            print(tag, r["counter"][:7], "X taken" if r["objective_taken"] else "X held", f'origin={r["origin"]} bots@5s={r["origin_bots_at_response"]} counter_srcs={len(r["counter_sources"])}', "ORIGIN CAPTURED after" if r["origin_captured_after_s"] is not None else "origin held", r["origin_captured_after_s"], src)
        elif sc=="sound_defence":
            print(tag, "BROKE THROUGH" if r["captured"] else "held", f'X min={r["objective_min_bots"]} guards={len(r["guards"])} sent={r["bots_sent"]}', src)
        elif sc=="chokepoint":
            print(tag, f'X={r["objective"]} via {r["street_from"]} cap={r["street_cap_per_s"]}/s offered={r["attack_rate_offered"]}/s', "captured" if r["captured"] else "held", r["capture_s"], f'sent={r["bots_sent"]}', src)
        else:
            print(tag, r.get("reissue","spent"), f'avg={r["avg_bots_per_s"]}/s orders={r["orders"]} farms={r["source_farms"]}', src)
