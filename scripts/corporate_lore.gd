extends RefCounted
## Connected corporate case files. Authors supply entire stories and email threads in city_lore.json;
## this generator only assigns compatible cases and a consistent cast, location and chronology.

const PLACEHOLDERS := ["org", "building", "district", "rival", "lead", "witness", "manager", "outsider"]
const ROLES := ["lead", "witness", "manager", "outsider"]

var rng := RandomNumberGenerator.new()
var _archive: Dictionary
var _people: Dictionary
var _uses := {}


func _init(map_seed: int, content: Dictionary) -> void:
	rng.seed = map_seed * 32452843 + 71
	_archive = content.get("corporate_archive", {})
	_people = content.get("people", {})


func attach(lots: Dictionary, districts: Array, corporations: Dictionary) -> void:
	var library: Array = _archive.get("cases", [])
	if library.is_empty(): return
	var count := maxi(1, int(_archive.get("cases_per_building", 2)))
	for key in lots:
		var building: Dictionary = lots[key]
		if str(building.kind) not in ["corp", "off_m", "off_s"]: continue
		var owner := str(building.get("occupant", ""))
		var industry := str(corporations.get(owner, {}).get("industry", ""))
		var eligible := library.filter(func(record): return "any" in record.industries or industry in record.industries)
		var chosen := {}
		var records := []
		for slot in mini(count, eligible.size()):
			var source := _choose_case(eligible, chosen)
			chosen[str(source.id)] = true
			records.append(_render_case(source, building, districts[int(building.did)], corporations, key, slot))
		building["corporate_records"] = records


func _choose_case(eligible: Array, chosen: Dictionary) -> Dictionary:
	# Pick the least-used eligible plots across the whole city before repeating one, with seeded
	# random ties. A building cannot receive the same plot twice, even in a small custom library.
	var candidates := []
	var least := 2147483647
	for record in eligible:
		var id := str(record.id)
		if chosen.has(id): continue
		var uses := int(_uses.get(id, 0))
		if uses < least:
			least = uses; candidates.clear()
		if uses == least: candidates.append(record)
	var selected: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	_uses[str(selected.id)] = least + 1
	return selected


func _render_case(source: Dictionary, building: Dictionary, district: Dictionary,
		corporations: Dictionary, key: Vector2i, slot: int) -> Dictionary:
	var owner := str(building.occupant)
	var rivals := corporations.keys().filter(func(name): return str(name) != owner)
	var ctx := {"org": owner, "building": str(building.bname), "district": str(district.name),
		"rival": str(rivals[rng.randi_range(0, rivals.size() - 1)]) if not rivals.is_empty() else owner}
	var names := {}
	for role in ROLES:
		ctx[role] = _person_name(names)
		names[str(ctx[role])] = true
	var cast := []
	for role in ROLES:
		cast.append({"key": role, "name": str(ctx[role]), "job": str(source.roles[role]).format(ctx)})
	var year := int(_archive.get("year", 2080))
	var month := rng.randi_range(1, 12)
	var start_day := rng.randi_range(1, 12)
	var emails := []
	for message in source.emails:
		var sender := str(message.from)
		var recipients := PackedStringArray()
		for role in message.to: recipients.append(str(ctx[str(role)]))
		emails.append({"from_role": sender, "from": str(ctx[sender]),
			"from_job": str(source.roles[sender]).format(ctx), "to_roles": message.to.duplicate(),
			"to": ", ".join(recipients),
			"sent": "%04d-%02d-%02d %s" % [year, month, start_day + int(message.day) - 1, str(message.time)],
			"subject": str(message.subject).format(ctx), "body": str(message.body).format(ctx)})
	return {"id": "%d,%d:%s:%d" % [key.x, key.y, str(source.id), slot], "template_id": str(source.id),
		"title": str(source.title).format(ctx), "summary": str(source.summary).format(ctx),
		"story": str(source.story).format(ctx), "cast": cast, "emails": emails}


func _person_name(used: Dictionary) -> String:
	var first: Array = _people.get("first_names", [])
	var last: Array = _people.get("surnames", [])
	for attempt in 32:
		var name := "%s %s" % [first[rng.randi_range(0, first.size() - 1)], last[rng.randi_range(0, last.size() - 1)]]
		if not used.has(name): return name
	# Finite recovery for small user-authored name lists, without inventing names in code.
	for given in first:
		for surname in last:
			var name := "%s %s" % [given, surname]
			if not used.has(name): return name
	return "%s %s" % [first[0], last[0]]
