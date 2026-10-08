extends RefCounted
## Procedural lore for the city map. MEGACORPS are the only organisations: they own the corporate
## districts (one corp often owns two or three) and run some commercial ones through retail arms; every
## corp has a profile (industry, founding year, CEO, HQ, holdings, slogan). Housing is plain information:
## a landlord, a population, and — Watch Dogs-style — named RESIDENTS with an age, a job, an income and
## one personal detail, so you can see how the city lives. Every building gets a name, an occupant, a
## flavour security level and a short story.
##
## ALL WRITTEN CONTENT lives in res://data/city_lore.json (see data/LORE_GUIDE.md) — this script only
## assembles it. Deterministic from the map seed on its OWN rng, so lore never perturbs the layout.

const DATA_PATH := "res://data/city_lore.json"
# every {placeholder} a template may use — ALL are filled for EVERY template (see _ctx)
const PLACEHOLDERS := ["district", "org", "corp", "corp2", "landlord", "year", "event", "old", "old_small",
	"floors", "f", "n", "div", "biz_l"]

static var _data := {}
static var loaded_ok := false   # false = the content file was missing/broken and the fallback is in use

var D: Dictionary        # the loaded content
var rng := RandomNumberGenerator.new()
var corp_info := {}      # corp name -> {industry, label, founded, ceo, slogan, blurb, districts, buildings, hq}
var _used := {}          # every corp / building name handed out (unique per map)


func _init(map_seed: int) -> void:
	rng.seed = map_seed * 104729 + 3
	D = data()


# The content file, loaded once. A missing or broken file never stops the game: it falls back to a
# minimal built-in set and says so in the log.
static func data() -> Dictionary:
	if not _data.is_empty(): return _data
	var txt := FileAccess.get_file_as_string(DATA_PATH)
	var parsed = JSON.parse_string(txt) if txt != "" else null
	if parsed is Dictionary and parsed.has("stories") and parsed.has("people"):
		_data = parsed; loaded_ok = true
	else:
		push_error("city_lore: could not load %s — using the minimal fallback content" % DATA_PATH)
		_data = _fallback()
	return _data


static func _fallback() -> Dictionary:
	var st := {"history": ["Built in {year}."], "now": ["It stands in {district}."], "rumour": []}
	return {"district_names": {"prefixes": ["Neon"], "suffixes": {"bus": ["Core"], "com": ["Market"], "res": ["Blocks"], "park": ["Green"]}, "standalone": []},
		"corp_name_prefixes": ["Default"],
		"industries": {"data": {"label": "data", "blurb": "data", "name_suffixes": ["Data"], "divisions": ["operations"],
			"building_names": ["Tower"], "jobs": ["clerk"], "slogans": ["..."]}},
		"people": {"first_names": ["Alex"], "surnames": ["Doe"], "jobs": [{"text": "clerk", "min": 20000, "max": 30000}],
			"details": ["Lives here."], "kid_details": ["Goes to school."], "elder_details": ["Retired."]},
		"places": {"old_buildings": ["warehouse"], "small_old_buildings": ["kiosk"], "events": ["crash of {year}"],
			"shop_types": ["Shop"], "tower_words": ["Tall"], "mall_words": ["Mall"]},
		"stories": {"corporate": st, "shop": st, "housing": st, "home": st, "mall": st, "hub": st},
		"security": {}}


# ------------------------------------------------------------------ megacorps
# Every district gets its information: corporate → an owning megacorp (a small pool, so corps own
# several districts); commercial → a corp's retail arm or independent traders; residential → a landlord
# (a corp's housing trust or the city); parks → public green.
func make_orgs(districts: Array) -> void:
	var n_bus := 0
	for d in districts:
		if str(d.type) == "bus": n_bus += 1
	var corps := []
	for i in maxi(2, int(ceil(n_bus / 2.0))): corps.append(_new_corp())
	for d in districts:
		d["org"] = ""; d["org_kind"] = ""; d["landlord"] = ""
		match str(d.type):
			"bus":
				d.org = _pick(corps); d.org_kind = "megacorp"
			"com":
				if rng.randf() < 0.55:
					d.org = _pick(corps); d.org_kind = "retail arm"
				else:
					d.org_kind = "independent traders"
			"res":
				d.landlord = ("%s Housing Trust" % str(_pick(corps)).split(" ")[0]) if rng.randf() < 0.6 else "City Housing Authority"
			_:
				d.org_kind = "public green"


func _new_corp() -> String:
	var inds: Dictionary = D.industries
	var ind: String = inds.keys()[rng.randi() % inds.size()]
	var I: Dictionary = inds[ind]
	var nm := "%s %s" % [_pick(D.corp_name_prefixes), _pick(I.name_suffixes)]
	for attempt in 30:
		if not _used.has(nm): break
		nm = "%s %s" % [_pick(D.corp_name_prefixes), _pick(I.name_suffixes)]
	_used[nm] = true
	corp_info[nm] = {"industry": ind, "label": str(I.label), "founded": rng.randi_range(2004, 2049),
		"ceo": "%s %s" % [_pick(D.people.first_names), _pick(D.people.surnames)], "slogan": _pick(I.slogans),
		"blurb": str(I.blurb), "districts": 0, "buildings": 0, "hq": ""}
	return nm


func _industry(corp: String) -> Dictionary:
	var inds: Dictionary = D.industries
	var key := str(corp_info.get(corp, {}).get("industry", ""))
	return inds[key] if inds.has(key) else inds.values()[0]


# corp holdings (districts, buildings, HQ = its tallest building) once every building has an occupant
func finish(lots: Dictionary, districts: Array) -> void:
	var hq_h := {}
	for d in districts:
		if corp_info.has(str(d.org)): corp_info[d.org].districts += 1
	for k in lots:
		var b = lots[k]
		var o := str(b.get("occupant", ""))
		if not corp_info.has(o): continue
		corp_info[o].buildings += 1
		if float(b.h) > float(hq_h.get(o, -1.0)):
			hq_h[o] = float(b.h); corp_info[o].hq = str(b.bname)


# ------------------------------------------------------------------ people (Watch Dogs-style profiles)
func _person(ctx: Dictionary, age_lo: int, age_hi: int, surname := "") -> Dictionary:
	var P: Dictionary = D.people
	var first: String = _pick(P.first_names)
	var last: String = surname if surname != "" else str(_pick(P.surnames))
	var age := rng.randi_range(age_lo, age_hi)
	var job: String; var income := 0; var detail: String
	if age < 18:
		job = "student"; detail = str(_pick(P.kid_details)).format(ctx)
	elif age >= 68:
		job = "retired"; income = rng.randi_range(9, 24) * 1000; detail = str(_pick(P.elder_details)).format(ctx)
	else:
		var j: Dictionary = _pick(P.jobs)
		var ind := _industry(str(ctx.corp))
		job = str(j.text).format(ctx.merged({"corp_job": _pick(ind.jobs)}))
		income = (rng.randi_range(int(j.min), int(j.max)) / 100) * 100
		detail = str(_pick(P.details)).format(ctx)
	return {"name": "%s %s" % [first, last], "age": age, "job": job, "income": income, "detail": detail}


# ------------------------------------------------------------------ buildings
# The placeholder values for one building. Every key in PLACEHOLDERS is always present, so any
# template in the content file may use any of them.
func _ctx(b: Dictionary, d: Dictionary) -> Dictionary:
	var corps: Array = corp_info.keys()
	var ll := str(d.get("landlord", ""))
	var c1: String = _pick(corps) if not corps.is_empty() else "a long-dead corp"
	var others := corps.filter(func(o): return o != c1)
	var ctx := {"district": str(d.name), "org": str(d.get("org", "")) if str(d.get("org", "")) != "" else c1,
		"corp": c1, "corp2": _pick(others) if not others.is_empty() else c1,
		"landlord": ll if ll != "" else "the building's owners",
		"year": str(rng.randi_range(2041, 2079)), "n": str(rng.randi_range(2, 9)), "f": str(rng.randi_range(13, 88)),
		"old": _pick(D.places.old_buildings), "old_small": _pick(D.places.small_old_buildings),
		"floors": str(maxi(1, int(round(float(b.h) / 11.0)))), "div": "operations", "biz_l": "food"}
	ctx["event"] = str(_pick(D.places.events)).format(ctx)
	return ctx


# Fill a building record with lore: bname, occupant, occ_kind, sec, story; homes also get residents
# (people), pop and a city-life line; shops get their owner (people).
func describe(b: Dictionary, d: Dictionary) -> void:
	var kind := str(b.kind)
	var corps: Array = corp_info.keys()
	var ctx := _ctx(b, d)
	var floors := int(ctx.floors)
	var sec: Dictionary = D.get("security", {})
	b["sec"] = str(sec.get(kind, "Unknown"))
	match kind:
		"hub":
			b["bname"] = "Central HUB"
			b["occupant"] = "NetGrid Authority"
			b["occ_kind"] = "city network authority"
			b["story"] = _story("hub", ctx, 1.0)
		"corp", "off_m", "off_s":
			var owner := str(d.get("org", "")) if corp_info.has(str(d.get("org", ""))) else str(ctx.corp)
			var tag := "megacorp"
			if rng.randf() > 0.8 and corps.size() > 1:   # a rival corp's outpost inside this territory
				owner = _pick(corps.filter(func(o): return o != owner)); tag = "rival megacorp"
			ctx.org = owner
			var ind := _industry(owner)
			ctx.div = _pick(ind.divisions)
			var short := owner.split(" ")[0]
			if kind == "off_s": b["bname"] = _unique("%s Annex %s" % [short, ctx.n])
			else:   # a corp owns many towers: vary with a tower word before ever falling back to a number
				var bn: String = _pick(ind.building_names)
				var nm := "%s %s" % [short, bn]
				for attempt in 6:
					if not _used.has(nm): break
					nm = "%s %s %s" % [short, _pick(D.places.tower_words), _pick(ind.building_names)]
				b["bname"] = _unique(nm)
			b["occupant"] = owner
			b["occ_kind"] = "%s · %s division" % [tag, ctx.div]
			b["story"] = _story("corporate", ctx, 0.75)
		"shop_s", "shop_b":
			var biz: String = _pick(D.places.shop_types)
			ctx.biz_l = biz.to_lower()
			var p := _person(ctx, 24, 74)
			b["bname"] = _unique("%s's %s" % [str(p.name).split(" ")[0], biz])
			b["occupant"] = "%s (owner)" % p.name
			b["occ_kind"] = "independent business"
			b["people"] = [p]
			b["story"] = _story("shop", ctx, 0.6)
		"mall":
			b["bname"] = _unique("%s %s" % [str(d.name).split(" ")[0], _pick(D.places.mall_words)])
			b["occupant"] = str(d.org) if str(d.get("org", "")) != "" else "Traders' cooperative"
			b["occ_kind"] = "%d storefronts" % rng.randi_range(40, 220)
			b["story"] = _story("mall", ctx, 0.5)
		"ap", "sc":
			if kind == "sc": b["bname"] = _unique("%s Hab Tower" % _pick(D.places.tower_words))
			else: b["bname"] = _unique("Hab Block %d%s" % [rng.randi_range(1, 99), "ABCDEFGH"[rng.randi() % 8]])
			var pop := floors * (rng.randi_range(18, 34) if kind == "sc" else rng.randi_range(8, 16))
			b["pop"] = pop
			b["occupant"] = "%d residents" % pop
			b["occ_kind"] = "landlord: %s" % ctx.landlord
			b["life"] = _life(floors)
			var ppl := []
			for i in 3: ppl.append(_person(ctx, 8, 88))
			b["people"] = ppl
			b["story"] = _story("housing", ctx, 0.65)
		"fh":
			var fam: String = _pick(D.people.surnames)
			b["bname"] = _unique("The %s House" % fam)
			var ppl := [_person(ctx, 28, 62, fam), _person(ctx, 28, 62, fam)]
			for i in rng.randi_range(0, 2): ppl.append(_person(ctx, 4, 17, fam))
			if rng.randf() < 0.3: ppl.append(_person(ctx, 70, 92, fam))
			b["people"] = ppl
			b["pop"] = ppl.size()
			b["occupant"] = "the %s family (%d)" % [fam, ppl.size()]
			b["occ_kind"] = "owner-occupied"
			b["life"] = _life(1)
			b["story"] = _story("home", ctx, 0.5)
		_:
			b["bname"] = _unique("Unlisted structure"); b["occupant"] = "unknown"; b["occ_kind"] = ""; b["story"] = "No public record."


func _life(floors: int) -> String:
	return "Rent ¥%s/mo · %d%% occupied · %d noise complaints this month" % [
		_thousands(rng.randi_range(6, 40) * 100), rng.randi_range(71, 100), rng.randi_range(0, 9 + floors * 2)]


static func _thousands(v: int) -> String:   # 3500 -> "3,500"
	var sv := str(v); var out := ""
	while sv.length() > 3:
		out = "," + sv.substr(sv.length() - 3) + out; sv = sv.substr(0, sv.length() - 3)
	return sv + out


# history + now (+ a rumour with probability p_rumour, if the category has any) from the content file
func _story(cat: String, ctx: Dictionary, p_rumour: float) -> String:
	var st: Dictionary = D.stories.get(cat, D.stories.values()[0])
	var parts := PackedStringArray()
	if not (st.get("history", []) as Array).is_empty(): parts.append(str(_pick(st.history)))
	if not (st.get("now", []) as Array).is_empty(): parts.append(str(_pick(st.now)))
	if not (st.get("rumour", []) as Array).is_empty() and rng.randf() < p_rumour:
		parts.append("Rumour: " + str(_pick(st.rumour)))
	return " ".join(parts).format(ctx)


func _unique(nm: String) -> String:   # a taken name becomes "<name> No. <n>" (an address, not a bare counter)
	if not _used.has(nm):
		_used[nm] = true; return nm
	for i in 40:
		var alt := "%s No. %d" % [nm, rng.randi_range(2, 99)]
		if not _used.has(alt):
			_used[alt] = true; return alt
	return nm


func _pick(arr):
	return arr[rng.randi() % arr.size()]
