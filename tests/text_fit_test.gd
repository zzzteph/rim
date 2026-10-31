extends SceneTree
## Every text must fit its space with a margin, never overlap another, and a card never cuts a sentence.
## Covers card faces, mini cards, building cards, the HUD, Help, the campaign banner, map names, and every
## Label/Button in the sidebar and the menu — at 1280x720 and 1366x768.
## godot --headless --path . --script tests/text_fit_test.gd
var game
var view: SubViewport
var font: Font
var checks := 0
var failures := []
const MARGIN := 4.0   # px every text keeps from the edge of its box


func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label); print("FAIL  " + label)


func settle() -> void:
	for k in 4: await process_frame


func w(text: String, fs: int) -> float: return game._text_w(font, text, fs)


func fitted(text: String, fs: int, room: float, floor := 8) -> int:   # what _fit_text / a shrink loop ends on
	var s := fs
	while s > floor and w(text, s) > room: s -= 1
	return s


func run() -> void:
	view = SubViewport.new(); view.size = Vector2i(1280, 720); root.add_child(view)
	game = load("res://scripts/botnet_proto.gd").new()
	game.theme = load("res://assets/ui_theme.tres")
	game._opt_size = Vector2i(10, 8); game._opt_enemies = 2; game._opt_seed = 7; game._opt_shape = "spiral"
	view.add_child(game); game.set_process(false)
	game.set_anchors_preset(Control.PRESET_TOP_LEFT)
	font = game.get_theme_default_font()
	for res in [Vector2i(1280, 720), Vector2i(1366, 768)]:
		view.size = res; game.size = Vector2(res); game._layout_ui()
		game._camp = false; game._open_menu(false); game.ai_enabled = false
		await settle()
		await cards(res)
		await chips(res)
		await research_tab(res)
		hud(res)
		build_cards()
		await map_names(res, "spiral match")
		await panel_controls(res)
		await menu_controls(res)
	help_pages()
	card_art()
	await campaign(Vector2i(1280, 720))
	print(JSON.stringify({"checks": checks, "failures": failures.size()}))
	quit(0 if failures.is_empty() else 1)


# ---- card faces: the lead in full, then whole rule sentences only; 4 lines; clear of the cost row ----
func cards(res: Vector2i) -> void:
	game._card_bank = "attack"; game._set_deck_open(true); game._refresh_hand()
	await settle()
	var tile: Control = game.hand_bar.get_child(0)
	var width: float = tile.size.x - 28.0
	var cost_top: float = tile.size.y - 66.0 - 7.5   # the price icons are 15 px, centred 66 px above the card's foot
	var report := []
	for recipe in game.CARD_ORDER:
		var card: Dictionary = game.CARDS[recipe]
		var lead := str(card.lead); var rules := str(card.rules)
		check(lead.ends_with("."), "%s: lead ends a sentence" % recipe)
		check(" ".join(PackedStringArray(game._sentences(rules))) == rules, "%s: rules split exactly into whole sentences" % recipe)
		var blurb: Array = game._card_blurb(recipe, font, width)
		var shown := str(blurb[1])
		var ll: int = game._text_lines(font, lead, width, game.CARD_TEXT_FS)
		check(ll == 1, "%s @%s: lead fits one line (%d)" % [recipe, res, ll])
		check(shown != "" and rules.begins_with(shown) and shown[-1] in [".", "!", "?"], "%s @%s: the face adds whole rule sentences ('%s')" % [recipe, res, shown])
		var lead_h: float = game._text_height(font, lead, width, game.CARD_TEXT_FS)
		var rules_h: float = game._text_height(font, shown, width, game.CARD_TEXT_FS)
		var bottom: float = game.CARD_TEXT_TOP + lead_h + (game.CARD_TEXT_GAP + rules_h if shown != "" else 0.0)
		check(game.CARD_TEXT_TOP >= 95.0 + MARGIN, "card text starts clear of the picture band")
		check(bottom + 6.0 <= cost_top, "%s @%s: text ends %.0f px above the cost row" % [recipe, res, cost_top - bottom])
		check(w(str(card.name), 16) <= width - MARGIN, "%s @%s: name fits the header" % [recipe, res])
		for status in ["Researching · 100%", "Making · 100%", "Paused · 100%", "Waiting · 100%"]:
			check(w(status, 13) <= tile.size.x - 110.0, "%s @%s: status '%s' fits" % [recipe, res, status])
		check(w("Click to resume · Drag to play", 10) <= width, "card hint fits")
		var cost_w: float = game._draw_cost_row(game, game._card_cost(recipe), game._card_time(recipe), Vector2.ZERO, 13, 15.0, false)
		check(cost_w <= width - MARGIN, "%s @%s: the price row (Bots included) fits the card (%.0f of %.0f px)" % [recipe, res, cost_w, width])
		report.append("%s %d/%d" % [recipe, game._sentences(shown).size(), game._sentences(rules).size()])
	print("cards @%s (rule sentences shown/total): %s" % [res, ", ".join(PackedStringArray(report))])
	game._set_deck_open(false)


# ---- mini cards in the pushed-down strip: the count is never cut ----
func chips(res: Vector2i) -> void:   # the strip: the four-place queue, ready cards at a fixed size (never shrunk), "+n", the cards button
	var was_known: Dictionary = (game.known[game.PLAYER] as Dictionary).duplicate()
	var was_cards: Dictionary = (game.cards[game.PLAYER] as Dictionary).duplicate()
	for r in game.CARD_ORDER:
		game.known[game.PLAYER][r] = true; game.cards[game.PLAYER][r] = 12   # the worst case: every card held, 2-digit counts
	game._layout_deck(); await settle()
	var handle: Rect2 = game.deck_handle.get_global_rect()
	var shown := 0
	for chip in game.ready_strip.get_children():
		if not (chip as Control).visible: continue
		var r: Rect2 = (chip as Control).get_global_rect()
		check(r.end.x <= handle.position.x - 4.0, "strip item ends before the cards button @%s" % res)
		if chip == game.ready_more: continue
		shown += 1
		check(absf(r.size.x - game.READY_CHIP_W) < 0.5, "ready chip keeps its size (%.0f px) @%s" % [r.size.x, res])
		var title := str(game.CARDS[game._card_of(chip.key)].get("short", ""))
		check(w(title, 12) <= r.size.x - 40.0, "ready chip name '%s' fits @%s" % [title, res])
		check(w("×12 · Crypto", 11) <= r.size.x - 40.0 or game._card_of(chip.key) != "siphon", "siphon chip line fits @%s" % res)
	check(shown >= 3 and game.ready_more.visible and game.ready_more.text == "+%d" % (game.CARD_ORDER.size() - shown), "%d ready chips fit, the rest behind '%s' @%s" % [shown, game.ready_more.text, res])
	for q in game.lane_strip.get_children():
		check((q as Control).get_global_rect().end.x <= game.ready_strip.get_global_rect().position.x, "queue stays left of the ready cards @%s" % res)
	for label in ["Making 100%", "Paused 100%", "Ready full", "Done: 1 ready", "4 · waiting"]:
		check(w(label, 11) <= game.QUEUE_CHIP_W - 30.0 - 22.0, "queue chip line '%s' fits @%s" % [label, res])
	var worst_short: float = game._draw_cost_row(game, {"intel": 120, "creds": 120}, -1.0, Vector2.ZERO, 11, 11.0, false)
	check(worst_short <= game.QUEUE_CHIP_W - 30.0 - 22.0, "a waiting head's shortage icons fit (%.0f px) @%s" % [worst_short, res])
	check(w("+ Queue a card", 12) <= game.QUEUE_CHIP_W - 16.0, "empty queue chip invitation fits @%s" % res)
	game.known[game.PLAYER] = was_known; game.cards[game.PLAYER] = was_cards
	game._layout_deck()


# ---- the deck tabs and the RESEARCH tab's tree: every label inside its box ----
func research_tab(res: Vector2i) -> void:
	for label in ["Ready ×99", "Attack recipes", "Defence recipes", "Research 100%", "Stalled 100%", "Paused 100%", "Research +10"]:
		check(w(label, 14) <= game.DECK_TAB_W - 20.0 - MARGIN, "drawer tab '%s' fits @%s" % [label, res])
	for label in ["Research 100%", "Stalled 100%", "Research +10"]:
		check(w(label, 16) <= game.research_button.size.x - 16.0, "Research button '%s' fits @%s" % [label, res])
	game._card_bank = "research"; game._set_deck_open(true); game._refresh_hand()
	await settle()
	var nodes: Array = game.research_tree.get_children()
	check(nodes.size() == game.CARD_ORDER.size(), "the tree has a node for every recipe @%s" % res)
	var rects := []
	for node in nodes:
		var sx: float = (node as Control).size.x
		var recipe := str(node.recipe)
		var card: Dictionary = game.CARDS[recipe]
		var title := str(card.name) if w(str(card.name), 13) <= sx - 40.0 else str(card.get("short", card.name))
		check(w(title, 13) <= sx - 40.0, "%s @%s: tree title '%s' fits" % [recipe, res, title])
		var lines := ["Researching 100%", "Paused 100%", "Stalled 100%", "Known", "Open · 55 s", "x12 ready"]
		if game.RESEARCH.has(recipe):
			lines.append("Research · %d s" % int(game._research_time(recipe)))
			lines.append("Needs %s" % str(game.CARDS[str(game.RESEARCH[recipe].prereq)].get("short", "")))
			var cw: float = game._draw_cost_row(game, game._research_cost(recipe), -1.0, Vector2.ZERO, 11, 12.0, false)
			check(cw <= sx - 20.0, "%s @%s: research price fits its node (%.0f of %.0f px)" % [recipe, res, cw, sx - 20.0])
		for line in lines:
			check(w(line, 11) <= sx - 20.0, "%s @%s: tree line '%s' fits" % [recipe, res, line])
		var r := Rect2((node as Control).position, (node as Control).size)
		for other in rects: check(not r.grow(2.0).intersects(other), "%s @%s: tree nodes keep apart" % [recipe, res])
		rects.append(r)
		check(r.end.y <= game.research_tree.size.y and r.position.x >= 0.0 and r.end.x <= game.research_tree.size.x, "%s @%s: node inside the deck" % [recipe, res])
	game._card_bank = "attack"; game._set_deck_open(false)


# ---- HUD: the workers' column and four banks inside the bar; even a 4-digit bank stays in its column ----
func hud(res: Vector2i) -> void:
	var items: Array = game._hud_items()
	var total := 0.0
	for it in items: total += float(it[3])
	check(total <= game.hud.size.x + 0.5, "HUD columns (%.0f px) fit the bar (%.0f px) @%s" % [total, game.hud.size.x, res])
	for it in items:   # a bank: "1250/1250" over "+1250/min"; the workers: "Workers 48" over "24 busy · 24 blocked"
		var room: float = float(it[3]) - 22.0 - float(game.HUD_GAP)
		var worst := "Workers 48" if str(it[4]) == "workers" else "1250/1250"
		var second := "24 busy · 24 blocked" if str(it[4]) == "workers" else "+1250/min"
		var fs: int = game._hud_fs(font, worst, float(it[3]) - 22.0)
		check(fs >= 12 and w(worst, fs) <= room, "HUD worst case '%s' fits at %d px @%s" % [worst, fs, res])
		check(w(second, 12) <= room, "HUD second line '%s' fits @%s" % [second, res])
	var obj_room: float = game.hud.size.x - total - 8.0 - 12.0 - MARGIN   # the objective lines after the five banks
	for line in ["MAJORITY 35 / 68 · you 35", "KRAKEN holds it: wins in 51 s", "Leader: KRAKEN with 34", "You lead; 35 more to hold"]:
		check(w(line, 12) <= obj_room, "HUD objective '%s' fits (%.0f of %.0f px) @%s" % [line, w(line, 12), obj_room, res])


# ---- building cards: the palette width the sidebar allows, slots 112 px; titles and effects at >= 10 px with side margins ----
func build_cards() -> void:
	for card_w in [game._palette_card_w(), 112.0]:
		var room: float = card_w - 12.0
		for kind in game.BUILD_KINDS:
			var title := str(game.BUILD_KINDS[kind].card)
			check(fitted(title, 12, room) >= 11, "build card title '%s' >= 11 px at %d" % [title, card_w])
			for line in game.BUILD_EFFECT.get(kind, []):
				check(fitted(str(line), 11, room) >= 10, "build card line '%s' >= 10 px at %d" % [line, card_w])
			var cost_w: float = game._draw_cost_row(game, game._build_cost(kind), -1.0, Vector2.ZERO, 11, 12.0, false)
			check(cost_w <= card_w - 2.0 * MARGIN, "build card '%s' price row fits at %d (%.0f px)" % [kind, card_w, cost_w])


# ---- map names: none overlaps another or a building; yours, rigs and the focused one are always named ----
func map_names(res: Vector2i, what: String) -> void:
	game._ctx = {}
	var cx: Dictionary = game._map_ctx()
	var placed: Array = game._place_names(font, cx.vis, cx.seen, int(cx.aim))
	var named := {}
	for k in placed.size():
		var a: Rect2 = placed[k][1]; named[int(placed[k][0])] = true
		for m in range(k + 1, placed.size()):
			check(not a.grow(1.0).intersects(placed[m][1]), "%s @%s: names of %s and %s overlap" % [what, res, game.hosts[int(placed[k][0])].name, game.hosts[int(placed[m][0])].name])
		for i in game.hosts.size():
			if i == int(placed[k][0]) or not (cx.vis.has(i) or cx.seen.has(i)): continue
			var p: Vector2 = game._w2s(game.hosts[i].pos); var rr := maxf(16.0, game._r(i) * game._zoom)
			check(not a.intersects(Rect2(p - Vector2.ONE * rr * 0.95, Vector2.ONE * rr * 1.9)), "%s @%s: name of %s covers %s" % [what, res, game.hosts[int(placed[k][0])].name, game.hosts[i].name])
		check(game._map_rect().encloses(a), "%s @%s: name of %s stays on the map" % [what, res, game.hosts[int(placed[k][0])].name])
	for i in game.hosts.size():
		if not cx.vis.has(i) or not game._map_rect().has_point(game._w2s(game.hosts[i].pos)): continue
		if game._mine(i) or (bool(game.hosts[i].rig) and int(game.hosts[i].owner) != game.NEUTRAL):
			check(named.has(i), "%s @%s: %s keeps its name" % [what, res, game.hosts[i].name])
	print("%s @%s: %d names placed, %d visible hosts" % [what, res, placed.size(), cx.vis.size()])


# ---- every Label / Button / RichTextLabel inside the sidebar and the menu stays inside its box ----
func controls_inside(root_node: Node, clip: Rect2, what: String) -> void:
	var stack := [root_node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children(): stack.append(c)
		if not (n is Control) or not (n as Control).is_visible_in_tree() or n == root_node: continue
		if not (n is Container) and not (n is ScrollBar):   # every leaf widget (cards, slots, badges, text) stays inside, clear of the scrollbar
			var gr: Rect2 = (n as Control).get_global_rect()
			check(gr.position.x >= clip.position.x - 0.5 and gr.end.x <= clip.end.x + 0.5, "%s: %s '%s' crosses the edge (%.0f..%.0f in %.0f..%.0f)" % [what, n.get_class(), _txt(n), gr.position.x, gr.end.x, clip.position.x, clip.end.x])
		if n is Label or n is Button or n is RichTextLabel:
			var r: Rect2 = (n as Control).get_global_rect()
			check(r.position.x >= clip.position.x - 0.5 and r.end.x <= clip.end.x + 0.5, "%s: '%s' runs out of its box (%s in %s)" % [what, _txt(n), r, clip])
			if n is Label and (n as Label).autowrap_mode == TextServer.AUTOWRAP_OFF and not (n as Label).clip_text:
				check((n as Label).get_minimum_size().x <= r.size.x + 0.5, "%s: label '%s' is cut" % [what, _txt(n)])
			if n is Button and (n as Button).clip_text and (n as Button).text != "":
				var need := w((n as Button).text, (n as Button).get_theme_font_size("font_size")) + 12.0
				check(need <= r.size.x + 0.5, "%s: button '%s' is cut" % [what, _txt(n)])


func _txt(n: Node) -> String:
	var t := ""
	if n is Label: t = (n as Label).text
	elif n is Button: t = (n as Button).text
	elif n is RichTextLabel: t = (n as RichTextLabel).get_parsed_text()
	return t.substr(0, 40)


func visible_area(sc: ScrollContainer) -> Rect2:   # the scroll view less its reserved vertical scrollbar
	var r := sc.get_global_rect()
	var bar := sc.get_v_scroll_bar()
	if bar != null and (bar.visible or sc.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_RESERVE): r.size.x -= bar.size.x + 4.0   # and keep 4 px off it
	return r


func panel_controls(res: Vector2i) -> void:
	var P: int = game.PLAYER
	game.sel = {int(game.rig[P]): true}; game._inspect = -1; game._refresh_panel(); await settle()
	controls_inside(game.panel_box, visible_area(game.panel_scroll), "main node panel @%s" % res)
	var remote := -1   # a remote host with every kind of problem line: starved converters, full storage, a Firewall with no Intel
	for i in game.hosts.size():
		if int(game.hosts[i].owner) == P and i != int(game.rig[P]): remote = i; break
	if remote >= 0:
		var keep_builds: Array = (game.hosts[remote].builds as Array).duplicate(); var keep_slots: int = int(game.hosts[remote].slots)
		var keep_store: Dictionary = (game.hosts[remote].store as Dictionary).duplicate(true)
		game._set_builds(remote, ["lab", "wall", "cred"])
		game.hosts[remote].store = {P: {"creds": 10.0}}
		game.sel = {remote: true}; game._inspect = -1; game._refresh_panel(); await settle()
		check(game._panel_text().contains("starved"), "diagnosed host panel shows its status @%s" % res)
		controls_inside(game.panel_box, visible_area(game.panel_scroll), "diagnosed host panel @%s" % res)
		game.hosts[remote].builds = keep_builds; game.hosts[remote].slots = keep_slots; game.hosts[remote].store = keep_store
	var foreign := -1
	for i in game.hosts.size():
		if int(game.hosts[i].owner) != P and int(game.hosts[i].owner) != game.NEUTRAL: foreign = i; break
	game.cards[P] = {"breach": 2, "exploit": 1, "phish": 1, "ddos": 1, "siphon": 1}
	game.sel = {}; game._inspect = foreign; game._refresh_panel(); await settle()
	controls_inside(game.panel_box, visible_area(game.panel_scroll), "target panel @%s" % res)
	game._chosen_attack = "siphon"; game._refresh_panel(); await settle()
	controls_inside(game.panel_box, visible_area(game.panel_scroll), "siphon launch panel @%s" % res)
	game.sel = {}; game._inspect = -1; game._refresh_panel(); await settle()
	controls_inside(game.panel_box, visible_area(game.panel_scroll), "standings @%s" % res)
	for k in 300: game._sim_step(game.SIM_DT)   # ten seconds of play, so the overview has flows to show
	game._tab = "economy"; game._refresh_panel(); await settle()
	controls_inside(game.panel_box, visible_area(game.panel_scroll), "economy overview @%s" % res)
	game._event("fit:long", game.EV_CRIT, "NYX's Credential breach on Neighborhood Relay: 14 s left. A Patch on it stops it.", int(game.rig[P]), true)
	game._event("fit:news", game.EV_INFO, "Firewall on Neighborhood Relay fired Patch against Credential breach; 2 cards left in it.", int(game.rig[P]))
	game._tab = "events"; game._refresh_panel(); await settle()
	controls_inside(game.panel_box, visible_area(game.panel_scroll), "event history @%s" % res)
	game._refresh_event_strip(); await settle()
	var strip_clip: Rect2 = game._map_rect()
	for b in game.event_strip.get_children():
		var r: Rect2 = (b as Control).get_global_rect()
		check(strip_clip.encloses(r), "event strip row '%s' stays inside the map @%s" % [(b as Button).text.substr(0, 30), res])
	game._tab = ""; game._refresh_panel(); await settle()


func menu_controls(res: Vector2i) -> void:
	for v in ["main", "help"]:
		game._open_menu(true); game._menu_view = v; game._help_page = 0; game._refresh_menu(); await settle()
		controls_inside(game.menu_box, visible_area(game.menu_sc), "menu '%s' @%s" % [v, res])
	game._open_menu(false); await settle()


# ---- card pictures: every recipe has its own, coloured like its family ----
func card_art() -> void:
	var seen := {}
	for recipe in game.CARD_ORDER:
		var fam := str(game.CARDS[recipe].fam)
		var tex: Texture2D = game.FAMILY_ART.get(fam)
		check(tex != null and game.FAMILY_COL.has(fam), "%s: has a picture and a family colour" % recipe)
		if tex == null: continue
		check(not seen.has(tex.resource_path), "%s: its picture %s is not shared (also %s)" % [recipe, tex.resource_path.get_file(), seen.get(tex.resource_path, "")])
		seen[tex.resource_path] = recipe


# ---- Help: each lead line on one line with room to spare; each caption within its two lines ----
func help_pages() -> void:
	var page = load("res://scripts/botnet_help.gd").new(); page.game = game
	var lw: float = page.LEAD_WIDTH
	for p in game.HELP_PAGES:
		for line in page.lead_lines(str(p)):
			check(w(str(line), page.LEAD_FS) <= lw - 24.0, "help '%s': lead '%s' fits with 24 px spare (%.0f / %.0f)" % [p, line, w(str(line), page.LEAD_FS), lw])
		var cap := str(page.CAPTIONS[p])
		check(game._text_lines(font, cap, page.CAPTION.size.x, page.CAPTION_FS) <= 2, "help '%s': caption fits two lines" % p)
	page.free()


# ---- the campaign: banner lines fit one line each; the board's names never overlap ----
func campaign(res: Vector2i) -> void:
	view.size = res; game.size = Vector2(res); game._layout_ui()
	var body_w: float = maxf(200.0, float(res.x) - 80.0) - 40.0   # the banner body, less room for inline icons
	for ch in game.CAMP_CHAPTERS:
		for st in game._camp_steps(ch):
			check(w(str(st.a), 19) <= body_w, "campaign ch%d '%s': instruction fits one line" % [ch + 1, st.t])
			check(not st.has("w"), "campaign ch%d '%s': no WHY block" % [ch + 1, st.t])
			check(w("Done: " + str(st.r), 16) <= body_w, "campaign ch%d '%s': result line fits one line" % [ch + 1, st.t])
			check(w(str(st.r), 19) <= body_w, "campaign ch%d '%s': result fits one line" % [ch + 1, st.t])
	if FileAccess.file_exists(game._camp_save_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game._camp_save_path()))
	game._start_campaign(0); game._fit_view(); await settle()
	await map_names(res, "campaign board")
