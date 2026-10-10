# RIM game-design review

Reviewed 10 October 2026. Scope: every Markdown document in `design/` — **15 documents, 3,249 lines** — including historical design, implementation briefs, city research, economy/lore guides, and the botnet assault proposal. Uses the Game Design Review and Game Balance Analysis skills. Recommendations are review findings, not newly agreed rules or implemented changes.

## Verdict and decision at stake

**RIM has a strong potential identity: conquer a believable cyberpunk city by turning fixed hosts into productive, expendable offensive infrastructure. Its most valuable unresolved question is whether spending that infrastructure creates meaningful choices between expansion, specialization, and safety.**

The strongest candidate loop is: identify a useful frontier host → commit bots and an operation resource → break through a small internal network → gain a productive foothold/host → choose what it should produce and what must remain defended → approach the CENTRAL HUB. This joins the territory fantasy to the automation economy. The attractive city and lore give those decisions a recognizable place.

The documents currently describe several playable slices and proposals with different capture, resource, risk, and victory rules. Those differences are not automatically defects: the project has evolved. However, merging them without selecting one governing contract would make the player's reward, objective, and preparation unclear. **Choose and validate that contract before investing in more attack families, city families, progression tiers, or campaign content.**

My recommendation is to test the locked botnet direction in a small, representative city: fixed contributing hosts, consumable bots, resource-powered operations, CORE conquest, a focused HUB finale, and one announced defensive event. Retain program production as the economic reason to care about conquered hosts. Whether partial component capture permits onward city expansion needs an explicit choice; the existing documents offer different answers.

## Evidence baseline and limits

**Confirmed by document reading:** all 15 documents were read in full across three review batches. Historical rules, proposed rules, and reported measurements were classified separately. The botnet's locked constraints remain constraints: stationary hosts, one-way consumable bots, no forward staging, adjacent frontier reach, one attack/defence pool, and global preparation followed by internal combat.

**Confirmed by selective source inspection:** `project.godot` declares **1.3.5**. [New Game opens `city.tscn` and resets Econ](../../scripts/menu.gd#L73); [Continue opens `netrun.tscn`](../../scripts/menu.gd#L81). The New Game city/building path uses the five-resource `Econ` system. `netrun.gd` is a different six-resource deterministic-card slice. `botnet_proto.gd` is a standalone assault sandbox. This review does not call the v0.7.4 document snapshot the complete current game.

**Calculated:** the retained [balance checker](balance_checks.py) reads source constants and economy JSON, executes an isolated combat model, enumerates permitted card-defense combinations, and computes economy breakpoints and retry expectations. [Results and hashes](balance_results.json) identify the inspected source and all design documents. Known-case checks passed. These are numerical consequences of the inspected rules, not engine or human-playtest results.

**Unknown:** intended primary player audience and target session length for the combined game; representative human decision quality, comprehension, frustration and replay interest; actual frequency of unwinnable generated netrun seeds; rendered readability/performance of the present build; final Net Watch behavior; integrated assault economy and research progression.

The older report of tedious node-by-node hacking is a **documented anecdote** in [BOTNET_ATTACK_DESIGN](../../design/BOTNET_ATTACK_DESIGN.md#L70), without sample or observation details here. Old multi-agent agreement in GAP_ANALYSIS is a design hypothesis, not player evidence. The historical city audits and external research sources were not rerun or independently reverified for this review. No gameplay files, tuning data, design documents, saves, or exports were changed.

## Complete document coverage

| Document | Status and contribution | Assessment and implication |
|---|---|---|
| [BOTNET_ATTACK_DESIGN.md](../../design/BOTNET_ATTACK_DESIGN.md) | Early standalone prototype; locked foundations, numeric defaults, seven open questions | Strongest statement of the proposed territory/force loop. CORE assault and shared attack/defence are promising; role separation, starting affordability and counterpressure require validation. Answers appear below. |
| [DESIGN.md](../../design/DESIGN.md) | v0.7.4 two-map snapshot at lines 13–75; explicitly legacy placement/history below line 77 | Useful record of component capture, production, workload and accessibility. Its “now” heading and New Game description no longer establish current menu routing. Keep its preserved principles, label its scope accurately. |
| [GAME_DESIGN.md](../../design/GAME_DESIGN.md) | Explicit v0.5.2 placement GDD | Clear automation promise: delivered packets, converters, coverage, upkeep, routing and 1000-Cash goal. Source of design intent and historical questions; its numbers should not be applied to the five-resource or assault systems. |
| [ECONOMY_GUIDE.md](../../design/ECONOMY_GUIDE.md) | Five-resource, data-driven tuning guide matching the inspected New Game economy | Excellent source/sink and rule explanation. Intel throttles actions; credentials/exploits improve capture odds; Cash buys the Credential Dumper in current data. Escalating capture prices, retry tails and heat/cooling need experience targets rather than isolated dial changes. |
| [GAP_ANALYSIS.md](../../design/GAP_ANALYSIS.md) | Historical genre comparison and ranked proposal backlog | Antagonist, objectives and legibility remain useful questions. Its wishlist is not a required combined-game feature list. Some old recommendations were subsequently addressed in legacy code/history. Validate the core loop before importing contracts, Ascension, new intermediates or a longer campaign. |
| [CLAUDE_BRIEF.md](../../design/CLAUDE_BRIEF.md) |3 October requested integration, explicitly not an implementation report | Strong specification of discovery, target eligibility, control states, program capacity, recovery and transparent previews. Its first-component expansion and all-component full control conflict with the newer CORE-conquest rule if treated as simultaneous requirements. Its developer demonstration sequence still needs a player learning sequence. |
| [CLAUDE_CITY.md](../../design/CLAUDE_CITY.md) |4 October city presentation/implementation brief with dated audit references | Strong composition, complete-site, selection, dry/water comparison and rendered acceptance expectations. Preserve those goals, but richer generation does not validate the attack/defence decision. Use one representative family for the next gameplay experiment. |
| [CITY.md](../../design/CITY.md) | Description of city generator/presentation and reported checks | Useful explanation of actual sites, roads, selection, settlement composition and LOD. Explicitly a presentation foundation. Road connectivity is valuable; a separate integrated host-graph test must establish strategic choices. Water-order descriptions conflict at lines 35–37 and 89–91. |
| [CITY_ARCHITECTURE.md](../../design/CITY_ARCHITECTURE.md) | Regional/era research, proposed building library and coherent ensembles | Strong silhouettes, frontage, roofs, grounds and constrained variation. The unresolved one-ensemble-versus-several-hosts choice at line 136 is a gameplay dependency. Set entity boundaries before expanding archetypes. |
| [DUTCH_CITY_ANALYSIS.md](../../design/DUTCH_CITY_ANALYSIS.md) | Qualitative research and proposed generator rules | Purposeful centres, neighborhood coherence, access and optional water give places identity. It correctly avoids claiming measured zoning weights. Apply relationships as inspiration; do not treat historical audit failures or proposed counts as verified current defects. |
| [FRANCE_CITY_ANALYSIS.md](../../design/FRANCE_CITY_ANALYSIS.md) | Qualitative research and country-specific proposals | Mixed frontages, inherited layouts, courtyards and employment anchors provide contrast without mandatory towers everywhere. Keep regular/formal areas valid. Strategic target value still needs mechanics; a varied facade alone does not make a different decision. |
| [UK_CITY_ANALYSIS.md](../../design/UK_CITY_ANALYSIS.md) | Qualitative research and country-specific proposals | Terraces, high streets, industrial grids, local materials and independent pedestrian links support readable neighborhood identity. Avoid translating every route into meanders or assuming a road graph must be the hacking graph. |
| [SMALL_TOWN_ANALYSIS.md](../../design/SMALL_TOWN_ANALYSIS.md) | Extension to 24 town cases and proposed town generation; no new code audit | Good separation of settlement family from grid size, population geography caveats and dry-town-first priorities. A low-rise town can still be a long tactical scenario: define strategic host count and goal distance independently of appearance. |
| [EUROPEAN_CITY_GENERATION.md](../../design/EUROPEAN_CITY_GENERATION.md) | Synthesis of country studies and bounded implementation proposals | Good separation of sites, buildings, neighborhood identity and usable capacity. Supports a small coherent first implementation. Host representation is expressly unsettled, and newer source behavior is not verified by older benchmark references. |
| [LORE_GUIDE.md](../../design/LORE_GUIDE.md) | Seeded content-authoring, placeholders, uniqueness and writing contract | Strong inexpensive human-scale atmosphere, sentence limits and consistency. Content quantity does not establish engagement. Its “flavour” security description needs updating: inspected building logic now uses that label to set actual success probabilities. |

All ten applicable review domains were covered: audience/experience; concept/theme; actions/agency; challenge/progression/economy; puzzles/problem representation; level/space/pacing; attention/guidance; interface/accessibility; narrative/world; production/validation. Human multiplayer/community design was excluded because the described game is single-player; Net Watch is an in-game opponent, not a social system. Puzzle review covered internal-route decisions and information, not a claim that RIM must become a puzzle game.

## Prioritized findings

### F 01 — Major: choose one capture, progression and recovery contract

**Observation.** [CLAUDE_BRIEF lines 83–87](../../design/CLAUDE_BRIEF.md#L83) allows onward expansion after the first captured component and requires every component for full control. [The botnet process](../../design/BOTNET_ATTACK_DESIGN.md#L62) conquers the host at the CORE and builds forward war capacity after conquest. New Game's `Econ.host_conquered` already uses CORE control, or all nodes for hosts without a CORE ([econ.gd:238](../../scripts/econ.gd#L238)). The old GDD ends at 1000 Cash; netrun requires every component; the assault proposal targets the HUB. The old GDD promises no unrecoverable states, while the proposal plans defeat after losing one's footing.

**Mechanism and impact.** These rules give different value to partial progress, side nodes, money production, expansion and retreat. If combined implicitly, the player cannot predict what a successful intrusion rewards or what still needs clearing. It also makes balance comparisons across documents invalid. This is a confirmed design/version divergence, not evidence that an intentional change is wrong.

**Recommendation.** Record one governing next-slice rule: what grants host ownership; what permits outward expansion; what optional internal capture buys; what ends a run; what recovery is guaranteed before defeat. My preferred test uses CORE conquest plus optional useful side nodes and a focused HUB objective. Label other models as historical or alternatives. Preserve the locked one-way bot rules.

**Tradeoff.** First-component expansion offers faster infiltration and partial control; CORE conquest offers a clearer assault objective and territory reward. Recoverable setbacks can coexist with a clearly announced final defeat, but an invulnerable home anchor creates a different pressure model. Choose deliberately.

**Validation.** Show a small host with one captured side node and an untouched CORE. Without coaching, ask what is owned, what can produce, which external hosts are reachable and what retreat loses. A practical small-test gate is 4 of 5 participants predicting all four correctly after the opening encounter. This is a proposed usability gate, not measured evidence.

### F 02 — Critical for the netrun/Continue slice: some required targets are permanently unreachable

**Observation.** [netrun's win check](../../scripts/netrun.gd#L587) requires every actual component. [Database defenses and traits](../../scripts/netrun.gd#L32) start at password 6/software 5, with no human trait. [Generation adds organization index and 0/1](../../scripts/netrun.gd#L255), while [all available cards top out at power 6](../../scripts/netrun.gd#L64). Organization 2 databases therefore have password 8–9 and software 7–8: no card can capture them. Organization 1 databases are also impossible when software rolls 7. Other Organization 2 targets have unreachable combinations.

**Mechanism and impact.** A run containing a mandatory unreachable target cannot satisfy full-city victory regardless of skill or preparation. The enumerator proves the rule conflict; it does not measure real seed incidence. This applies specifically to netrun, currently the Continue path, not to the five-resource probabilistic building game or separate botnet sandbox.

**Recommendation.** Require every mandatory target to have at least one attainable, trait-compatible capture method and an attainable access route. Constrain defense generation before adding more tiers just to repair the mismatch. If the objective changes, designate which targets are genuinely mandatory.

**Tradeoff.** Capping numeric defenses removes one escalation dial, but preserves difficulty through resource commitments, topology, counterpressure and matchups.

**Validation.** Enumerated compatibility must have zero permanently inaccessible mandatory targets. Then verify complete reachable paths on generated maps, including bootstrap and research access. Passing the isolated enumerator alone would not prove whole-run solvability.

The same enumeration shows basic Known Flaw and Generic Phish have no viable normally generated targets: power 3 is below every eligible baseline. The guaranteed opening repair creates an easy IoT for credentials, not an eligible software/human target. This is a separate teaching/progression consequence within that slice; restore actual early opportunities if these branches remain presented as opening options.

### F 03 — Major for the assault prototype: bots and operation resources do not have their promised distinct roles

**Observation.** The [locked two-knob rule](../../design/BOTNET_ATTACK_DESIGN.md#L41) says bots supply force/speed and matching resources supply power. [Current resolution](../../scripts/botnet_proto.gd#L179) independently drains both pools and deals `bots_spent ×1 + Intel_spent ×2.5`; either pool keeps attacking without the other. Source-host selection needs some resident bots, but the attack itself does not require sustained bot supply.

**Calculated consequence.** A committed **one bot** with enough Intel can take the HUB in the isolated model. A per-host Intel source produces 1.5 damage-equivalent units/s; one war building produces 0.2 through bots, a **7.5×** difference. Doubling or halving the Intel damage coefficient changes affordability, but all three tested coefficients still permit a one-bot HUB assault when sufficient Intel is provided. This is a structural role issue, not something fixed merely by adjusting the ratio.

**Mechanism and impact.** The economy can reward waiting for operation currency instead of assembling a meaningful botnet. That undermines the reason to choose contributing hosts and later reserve defensive strength. Bots do contribute speed under the current model; the problem is that they are optional after commitment rather than the necessary executor of the operation.

**Recommendation.** Test a rule where bots are required to execute the operation, their allocated throughput governs speed, and the operation resource modifies effectiveness or pays for a particular action. Preview both requirements. Avoid adding attack variants before one variant gives both knobs distinct value.

**Tradeoff.** Required resources clarify preparation but can create frustrating stalls. Show a usable minimum budget and an explicit stop/retreat consequence. No particular final damage formula is selected by this review.

**Validation.** Use the same target with low/high bots and low/high Intel. Players should correctly predict which change affects execution speed and which changes capability/effectiveness. A resource-rich, effectively bot-free assault should not deliver the intended full-strength operation unless that is deliberately chosen as a different rule.

### F 04 — Major for the assault prototype: the opening promise and target preview disagree with the actual budgets

**Observation.** [The prototype document](../../design/BOTNET_ATTACK_DESIGN.md#L94) says a fresh rig with 10 bots and about 15 Intel can crack a soft host. Its table lists 5–8 internal nodes and CORE 72. The inspected source instead generates 3/4/6 total nodes with the entry already controlled, CORE 70, and residual path defenses 92/120/194. Global display defense is 20/40/240 and is not the operative total damage requirement.

**Calculated consequence.** The starting budget can deal at most 47.5 damage against the weakest 92-damage path. The isolated 60Hz model takes one node and then runs out of force. With one starting host and no spending, the no-waste affordability lower bound is about 26.18s of replenishment before committing enough total damage; actual input time, per-node frame waste and allocation may add time.

**Recommendation.** Before changing pace, show the real operation budget and reconcile document defaults with source. For the present additive model only, two test fixtures are 10 bots+34 Intel, clearing the weak host in about 10.95s, and 42 bots+21 Intel, clearing it in about 6.83s. These are affordable-operation fixtures, not recommended final starting balance: giving more Intel alone worsens F 03's role imbalance. Recalculate after selecting the role rule.

**Tradeoff.** A clearly affordable opening teaches successful preparation; an initial waiting period can teach production if it contains an intentional choice. An unpreviewed guaranteed failure teaches unreliable rules.

**Validation.** The first encounter must match its shown minimum requirements. Ask a novice to choose a sufficient budget and explain a failed example without trial-and-error expenditure. Use actual node costs rather than the decorative global defense number.

### F 05 — Major validation dependency: shared attack/defence needs one defensive event

**Observation.** [Shared bots and overreach](../../design/BOTNET_ATTACK_DESIGN.md#L38) are locked, while [Net Watch and defeat are deliberately absent](../../design/BOTNET_ATTACK_DESIGN.md#L105).

**Mechanism and impact.** Without counterpressure, preserving resident bots has no defensive opportunity value. Testing all-bots commitment now cannot establish whether it becomes an interesting choice later. This is an acknowledged prototype limitation, not a demand to finish the antagonist faction before doing anything else.

**Recommendation.** Test one announced attack against one owned host while an offensive opportunity is available. Resident bots auto-defend and are spent; a small visible base delay can make an empty host respondable without adding a second defense currency. Show the threatened host and reserve consequence while preparing an assault.

**Tradeoff.** Pressure creates commitment decisions but can overload attention during an internal view. Resolve whether the world clock continues, how pause works, whether an ongoing operation may be interrupted and what happens to production/access when a host falls.

**Validation.** Give two contributing war-hosts and repeat the same frontier choice with different warned attack timing. Look for an explained change in contributors or reserves. If plans never change, the shared-pool tradeoff is not yet doing its intended work.

### F 06 — Major hypothesis: internal progress may still be purchasing the next node, rather than tactics

**Observation.** [The earlier tedium report and rationale](../../design/BOTNET_ATTACK_DESIGN.md#L70) motivates finite resourced assaults. Yet [the current internal generator](../../scripts/botnet_proto.gd#L134) is a fixed chain with one legal next node. Auto-draining a defense number introduces a budget, but it does not create a new target-choice problem. Increasing clicks or node HP would extend this solved sequence.

**Mechanism and impact.** Players can make a meaningful preparation decision globally and then perform repetitive confirmation work internally. Because every city host demands another interior, even a short weak interaction may dominate the session.

**Recommendation.** Keep automatic assault and compare the existing chain with one small branch that changes the next decision: an optional node giving useful intelligence or a different route/cost to the CORE. The same operation can remain deterministic and legible. Do not add pulse clicking simply to make hands busy.

**Tradeoff.** A genuine branch adds explanation and authoring work. Full preplanned resolution reduces repeated clicks but can reduce adaptation. Preserve the smallest difference that players use and understand.

**Validation.** Ask why the player picked each of the first three targets and what alternative they rejected. If answers remain “it was the next clickable thing,” do not increase interior count/length. Compare time spent deciding with time executing an already decided sequence.

### F 07 — Major hypothesis for the five-resource economy: escalation and repeated rolls can turn expansion into waiting

**Observation.** [Capture scaling](../../design/ECONOMY_GUIDE.md#L186) increases cost with every controlled local node, including optional holdings. At the current 0.5 scale and 8-Intel base price, an unburned capture costs `4×controlled_nodes +4`. A 100-Intel base cap prevents the next capture when 25 nodes are already controlled unless storage capacity is added. [Every network scan/profile/capture is paid and probabilistic](../../scripts/building.gd#L389), with failed actions interrupting 25–90% through their timer.

**Calculated consequence.** A Lethal-black-ICE CORE has 15.6% base success for a takeover; an exploit raises it to 45.6%. With sufficient stock, no alarms, no canceled actions and independent stationary attempts, takeover alone averages 6.41 attempts/41.11s without a boost, or 2.19 attempts/16.86s with one. Five consecutive failures occur with 42.83% versus 4.76% probability. These exclude profiling, scan, travel, earning enough Intel and player input; they are not session measurements. At higher node counts, the expected Intel cost scales further.

**Mechanism and impact.** Credentials/exploits clearly have numerical value, which is good. However, failed retries and a global holdings surcharge can punish optional capture and recovery even when the player is not gaining enough productive power to justify the increase. Long tails can feel like time penalties after the meaningful choice has already been made. Storage gating may be intentional; it must be anticipatable.

**Recommendation.** Test the current system before copying its surcharge into botnet combat. Show the next-capture cost and the storage breakpoint early enough to plan. Compare a prepared boosted approach with an unboosted one on the same late host. If repeated non-decisions dominate, first change the failure/presentation loop or price basis; do not simultaneously increase rates and lower every cost.

**Tradeoff.** Randomness can make preparation and specialist resources valuable. Deterministic preview reduces retry frustration but changes the fiction of intrusion risk. A global surcharge restrains growth but also taxes strategically unimportant nodes. Neither property is inherently wrong without the intended pacing target.

**Validation.** Track attempts and time to successful meaningful actions, long failure streaks, voluntary optional-node captures, and recovery following one alarm. Ask whether the player knows an action is storage-blocked or merely thinks the game is stalled. Set an intended completion band and acceptable retry tail before selecting final numbers.

### F 08 — Major integration risk: define the visible unit that counts as a host

**Observation.** [CITY_ARCHITECTURE line 136](../../design/CITY_ARCHITECTURE.md#L136) and [EUROPEAN synthesis line 86](../../design/EUROPEAN_CITY_GENERATION.md#L86) explicitly leave one terrace ensemble versus several independently selectable buildings undecided. The game brief and assault proposal describe every building as a host. Bots, passive Intel, component counts and frontier positions are priced per gameplay entity.

**Mechanism and impact.** An art improvement that combines houses into an ensemble can silently change income, target count, offensive positions and repeated interior workload. Decorative doors can also promise targets that selection does not provide.

**Recommendation.** Define host boundaries for a terrace, courtyard block and campus before expanding the architecture library. Keep selection, naming, ownership, interior graph and rewards consistent with that boundary. Physical streets and hacking wires may remain separate: independent graphs are an intentional design choice, not a defect.

**Tradeoff.** Aggregate hosts reduce repetition and clutter; finer hosts allow more territorial granularity and need clearer identity cues.

**Validation.** On three static examples, ask players how many hosts exist, which one is selected, what is owned after capture and what becomes reachable. Then reveal the actual selection/frontier behavior and record prediction errors.

### F 09 — Major validation gap: beautiful connected cities do not yet prove varied strategic routes

**Observation.** [City acceptance](../../design/CITY.md#L206) checks determinism, physical connections, sites and composition. [The research synthesis](../../design/EUROPEAN_CITY_GENERATION.md#L112) checks frontage, access and street continuity. These are valid presentation goals, but they do not establish the value of different wire-frontier targets. Settlement family, rendered grid size and strategic scenario size are also different quantities.

**Mechanism and impact.** A procedurally varied city can hide a forced or interchangeable host graph. Conversely, a sound tactical graph can be hard to use when silhouettes overlap, selection treats ensembles inconsistently, or essential cues disappear at overview/large-map LOD.

**Recommendation.** Add one integrated acceptance question: which two frontier targets offer different understandable reasons to attack? Check essential host identity, ownership and frontier cues at both overview and detail. Record host count, objective distance and branching alongside existing city-size presets. Preserve the real-city composition work without assuming it supplies tactics by itself.

**Tradeoff.** Tactical fixtures constrain procedural freedom; clear ownership cues can compete with an atmospheric city view. Use normal-play-scale evidence to decide how much detail and guidance are useful.

**Validation.** First put the same wire graph on two city layouts; then put two wire graphs on the same layout. Ask why the next target changes. Repeat selection tasks in small/large rendering. This separates orientation problems from strategic topology problems.

### F 10 — Major validation gap: define the opening decision sequence and representative accessibility

**Observation.** [The integration's first slice](../../design/CLAUDE_BRIEF.md#L219) is a developer demonstration list. It asks the player to distinguish global/local discovery, target requirements, affinity, slots, workload, operating costs and research. The botnet adds source selection, commitment, internal force and reserves. [Accessibility/pause standards](../../design/CLAUDE_BRIEF.md#L186) are strong, but [the assault prototype's controls](../../design/BOTNET_ATTACK_DESIGN.md#L140) only demonstrate mouse clicks and glowing targets.

**Mechanism and impact.** A novice may understand each button while not knowing the reason for the next action. A mouse-only sandbox cannot establish low-vision legibility, keyboard operability or pause-safe planning of the intended combined game. These are prototype evidence limits, not proof the final accessibility direction has been abandoned.

**Recommendation.** Define the first three consequential decisions and show the needed information at that point: choose a useful reachable target, commit an affordable force, use and defend what was gained. Introduce specialized production/research after the first successful operation. Include existing accessibility settings and pause behavior in the representative test, rather than validating them only after the new interaction is settled.

**Tradeoff.** Guided early information reduces overload but may slow experts; keep deeper information available without making it mandatory before the first decision.

**Validation.** Use an uncoached first-ten-minutes test with the intended audience, including low-vision requirements. Ask what was spent, what was gained, what can threaten it and why the next target differs. Test keyboard-only planning, text scaling, non-color status and returning between maps with the same scenario.

### F 11 — Scoped economy/fiction issues: retain each resource and description for an explicit reason

**Observation.** The six-resource netrun catalog produces Cash through Intel/Crypto conversion, but [its costs](../../scripts/netrun.gd#L48) do not spend Cash and its objective is component ownership. That terminal chain is currently strategically inert **in that slice**. The current New Game economy does spend Cash on the Credential Dumper: the conclusion must not be transferred between versions. Separately, [LORE_GUIDE calls security flavour](../../design/LORE_GUIDE.md#L87), while [building.gd derives success chance from `info.sec`](../../scripts/building.gd#L337). City lore generates that label from `security` data.

**Mechanism and impact.** Following the wrong economy document can make a player produce a currency with no current purpose. Editing what appears to be flavor security can change actual difficulty; unrecognized text falls back to 0.7. Fictional descriptions need a clear reliability boundary so the world can support planning.

**Recommendation.** Give every retained chain a concrete decision it finances, or leave that chain outside the next core-loop test. For current New Game, evaluate whether Cash's one present purchase creates enough meaningful differentiation before multiplying currencies. Document that security strings now affect gameplay and use stable game attributes when prose changes are intended to be harmless. State what broad target clues are reliable and what requires scanning.

**Tradeoff.** Fewer chains simplify planning but reduce laundering flavor. Broad reliable fictional clues improve planning but reduce surprise. Do not add quests or a cast solely to make generated lore “mechanical.”

**Validation.** Trace each output to an actual spend/goal in the selected rule set. Change only a security description in a fixture and verify whether its odds should change. Ask players what a residential, retail and corporate target's description lets them predict before scanning.

## Numerical evidence and candidate comparisons

### Assault sandbox: actual paths, not the stale document table

| Target | Generated nodes, including owned entry | Actual defense to remove | Displayed global defense | Ideal full-rate duration* | Intel-only damage budget |
|---|---:|---:|---:|---:|---:|
| Outer host |3|92|20|6.815s|36.8|
| Inner host |4|120|40|8.889s|48.0|
| HUB |6|194|240|14.370s|77.6|

*Continuous lower bound with enough of both pools, instantaneous target selection and no opponent. The 60Hz isolated model is slightly slower because resources are consumed before a node's remaining defense is clamped. Only 2/3/5 nodes actually need assaulting: entry is already controlled.

| Weak-host scenario | Isolated result | Meaning |
|---|---|---|
| Current 10 bots+15 Intel |Fails after about 5.00s; first hostile node taken, CORE survives|Starting maximum damage 47.5 is insufficient for 92.|
| Test fixture 10 bots+34 Intel |Succeeds in about 10.95s|Shows affordability, but reinforces the current Intel-heavy bypass.|
| Test fixture 42 bots+21 Intel |Succeeds in about 6.83s|Supports both damage streams through the encounter; still does not prove distinct roles.|
| One capped war-host 80 bots, no Intel |Fails|A full single-host bot reserve is below even the weakest path's 92.|
|1 bot plus 78.6 Intel against HUB |Succeeds in about 25.73s|Connected territorial access is still required, but an assembled offensive bot stack is not.|

At current coefficients, a war building costing 25 Intel gives 10 starting bot-damage plus 0.2 per second thereafter. The 25 Intel could instead provide 62.5 damage. The **damage-budget-only** break-even is 262.5s, ignoring attack speed, reserves, placement, caps and defensive value. That calculation cannot decide whether war buildings are good once defence exists; it explains why the present offensive-only additive model underrepresents their intended value.

The ammo coefficient sweep 1.25/2.5/5.0 preserved the one-bot HUB bypass with sufficient Intel in all three cases. Select a role rule before choosing final coefficients. No accepted final tuning set is claimed.

### Netrun cards: permitted defense combinations

All currently available tiers are treated as unlocked, which makes this a generous compatibility check. Each row enumerates 8 possible 0/1 rolls over password/software/awareness; inactive awareness offsets duplicate states for nonhuman components. Counts describe combinations, not generated-map probabilities.

| Organization | IoT | Web | File | Database | PC |
|---|---:|---:|---:|---:|---:|
|0|8/8|8/8|8/8|8/8|8/8|
|1|8/8|8/8|8/8|4/8|8/8|
|2|8/8|4/8|4/8|0/8|7/8|

Even a compatible attack is not enough to prove progression: research must be affordable and its target must be reachable. The zero-compatible Organization 2 database proves a necessary victory constraint already fails for that target class.

### Five-resource New Game: capture and retry pressure

| Controlled local nodes before the next capture | Unburned takeover cost | Fits 100 base Intel cap? |
|---:|---:|---|
|1|8|Yes|
|5|24|Yes|
|11|48|Yes|
|24|100|Yes, exactly|
|25|104|No: needs additional storage|
|50|204|No: needs additional storage|

Burn history adds its own surcharge. Node count, not number of fully conquered hosts or productive installations, drives this price. That is a meaningful scope choice for both optional exploration and recovery.

| Takeover example, no burn penalty | Success | Expected attempts | Expected takeover execution time* | Expected Intel at 1 controlled node |
|---|---:|---:|---:|---:|
| Corporate-ICE CORE, unboosted |41.6%|2.40|18.07s|19.23|
| Corporate-ICE CORE, exploit boost |71.6%|1.40|12.28s|11.17 + expected 1.40 Exploits|
| Lethal-black-ICE CORE, unboosted |15.6%|6.41|41.11s|51.28|
| Lethal-black-ICE CORE, exploit boost |45.6%|2.19|16.86s|17.54 + expected 2.19 Exploits|

*Sufficient stock, independent stationary retries, success takes 10s, failure interrupts uniformly at 25–90% of 10s. `E[T]=10×(1+0.575×(1−p)/p)`. Excludes scans, profiling, stock-generation waits, alarm risk and input delay. These model predictions establish boost value and failure-tail exposure; they do not establish how long a real player takes.

The retained netrun workload numbers additionally imply loss after 14.29s at 1 unit over capacity,7.14s at 2, or 4.76s at 3, from 100 integrity. The capture path restores full integrity; programs are disabled on loss, so recapture does not automatically resume the previous overloaded load. Treat these as that slice's test points, not the five-resource heat system. An interface that shows slots without supported load can invite an unexpectedly fast penalty.

## Answers to the seven botnet design questions

| Open question | Recommended first test | Tradeoff and decision rule |
|---|---|---|
|1. Internal combat feel |Keep click-to-start automatic assault, with cancel/retarget. Compare one meaningful branch to the fixed chain.|Pulse clicks add hand work; preplanned resolution may remove adaptation. Keep the version where players can explain consequential choices; add clicks only if they change decisions.|
|2. Force granularity |Keep contributing-host selection. Once defence is represented, test a simple reserve amount/preset per participating host.|All-bots is readable but makes “participate” mean “empty this host.” Partial commitment earns a control only if it changes an understandable decision. Sent bots remain consumed; they never return or stage.|
|3. Defence |Resident war-host bots automatically defend and are consumed; test a small visible host-level delay/base resistance plus an announced attack.|The buffer makes response possible without a second resource. Too much free resistance makes reserves irrelevant. Test two threatened hosts with insufficient bots to protect both fully.|
|4. Transit |Use instant breach for the initial role/defence test, then compare a short previewed hop delay if forward placement needs a distinct payoff.|1–2s/hop is a suggestion, not validated balance. Delays must change placement/commitment, not merely make waiting longer; preserve no movement/no staging.|
|5. Attack types/economy |Honor scan→Intel, credential action→Credentials, exploit action→Exploits. Test one operation and one specialist alternative before the whole catalog.|Resources need distinct target/supply consequences. Retain Cash/Crypto when investment/upgrades give laundering a real use. Do not merge the five- and six-resource names/numbers by accident.|
|6. Escalation |Start with structured harder targets and the HUB, then one Net Watch event. Compare global per-conquest inflation only after those work.|Inflation restrains growth but also taxes optional expansion and recovery. Test rushing, conservative and defensive plans under the same scenario.|
|7. Failure stakes |Keep committed bots fully consumed. Test retained discovered intelligence and, separately, limited temporary partial damage.|Refunding bots conflicts with the lock. Permanent damage can reward repeated tiny attacks; total reset can erase useful learning. Prefer informative bounded setbacks and test the cheap-chip strategy explicitly.|

These are recommendations for experiments, not declarations that the open questions are already settled. CORE capture, partial damage persistence, reserve controls, structural delay and transit timing all need a chosen contract.

## Historical questions and work worth deferring

The old GDD's seven questions remain useful **within the off-menu placement design**:

1. **Coverage:** test whether scanning dense blocks creates interesting placement choices or repeated hunting. Do not carry its multiplicative output rates into per-host assault production without a deliberate reason.
2. **Dominant placement strategy:** saturation and Cash sinks must be evaluated against actual legal build paths; an old “Scraper+Market” result does not describe the current five-resource economy.
3. **Node overload:** preserve readable bottleneck information wherever actual throughput is retained. Distinguish tunnel loss from component integrity and stochastic alarms.
4. **Threat:** the useful surviving question is what decision a telegraphed opponent creates. Legacy Sweep progress recorded later in DESIGN is not proof of the assault proposal's Net Watch.
5. **Multiple out-links:** defer richer load balancing until players need and can explain redundant routes. A more complicated graph alone is not strategic depth.
6. **Cash onboarding:** necessary when money production is a goal/sink; teach the selected economy's actual use rather than a historical conversion chain.
7. **Session/endgame:** a focused HUB endpoint is the cleaner first test for the new conquest promise. Preserve all-component completion as an alternative/optional goal only if voluntary cleanup is enjoyable.

The city research supports preserving coherent centers, contrasting neighborhoods, complete sites, constrained materials, optional water and normal-zoom readability. It does not require implementing all countries, all 24 town cases, every architecture archetype, pedestrians, railways or measured population simulation to validate gameplay.

Generated lore has a valid atmospheric role. Its stated 4,083 entries and millions of combinations are content capacity, not evidence of memorable stories. Define what CITY OVERLOAD means to the inhabited city and why the operator seeks it in one clear sentence; a branching campaign is not needed to answer that fiction question.

## Document maintenance findings

- **Scope/version labels:** DESIGN's “now v0.7.4” and New Game entry path describe an older snapshot; GAME_DESIGN explicitly records v0.5.2; CLAUDE_BRIEF records an inspectedv0.7.3 request. Add current applicability/authority labels rather than overwriting history.
- **Menu continuity:** New Game and Continue currently enter different rule sets. This review confirms static routing, not actual save/runtime behavior. Decide which run Continue is meant to resume before treating old save/load evidence as validation of the newer game.
- **Stale botnet table:** update internal counts, CORE defense and the first-rig affordability statement against the selected source/model.
- **Internal city inconsistency:** CITY describes water first at 35–37 and last at 89–91. Resolve current pipeline documentation against source; keep proposed capacity-first rules separately labeled.
- **Lore-security contract:** the guide's flavor-only claim no longer describes building success calculations. Treat that link as gameplay content when editing security labels.
- **Moved links:** the checker found **24 relative Markdown link occurrences** pointing to `review/...` from within `design/`. All target artifacts exist relative to the repository root, but the links resolve to nonexistent `design/review/...`. They need `../review/...` when rendered relative to their documents. Exact locations are in the result JSON. No link edits were made during review.

## Smallest next validation and order of work

**A bounded encounter:** two owned war-hosts; one frontier target with one consequential internal branch; bots and one operation resource; one predictable warned counterattack; a short path to a HUB goal. Use one existing representative city appearance rather than a new city-generation family. A paper facilitator or a small scenario can test the allocation decision before a complete antagonist is built.

| Order | Decision to resolve | Evidence to collect | Proposed pass/stop rule |
|---:|---|---|---|
|1|Governing capture/ownership/recovery rule and primary audience|One-page rules, small host diagram, player predictions|All rewards/frontiers/retreat effects follow one contract; avoid implementation from contradictory documents.|
|2|Mechanical attainability and trustworthy previews|Source-derived budget checks and reachable target paths|Zero mandatory targets outside obtainable capability; opening budget agrees with preview.|
|3|Distinct bot/resource roles and offensive reserve value|Low/high allocation cases with/without warned counterattack|Both knobs change their intended dimension; players sometimes preserve reserves for an explained reason.|
|4|Internal decision quality|Linear versus one-branch encounter; reasons for chosen/rejected actions|At least one consequential choice changes because of information/cost/pressure. Stop adding node count if the layer is only confirmation work.|
|5|Opening understanding, accessibility and information reliability|5–8 representative players as an initial qualitative sample, including intended low-vision needs|Most can explain cost/reward/threat after one conquest; keyboard/pause/non-color/scale requirements work in the tested interaction. Sample does not estimate market demand.|
|6|Economic pace and recovery|Attempts, failure tails, earning waits, next-capture storage needs, response to one loss|Set the intended time band first; select rate/price changes only if they improve it without removing choices or stranding recovery.|
|7|City entity/readability and replay variation|Terrace/courtyard/campus predictions; same graph/different city and same city/different graph|Clear host identity at normal/overview scales and at least two frontier choices with understandable differing value.|

Record meaningful decisions, time executing an already-known plan, forced waits, repeated low-value captures, misunderstanding of failure, and why the next target was chosen. A proposed short-test target is 10–15 minutes, solely to bound the experiment; this review does not impose that as the final game's session length.

After the core decision survives this test, evaluate the full five-resource supply chains, specialist attacks and city-scale procedural variation. Introduce research, broader content, transit complexity or replay progression when they solve an observed decision problem. This order preserves the project's identity while reducing the risk of polishing a large setting around an unproven central interaction.

## Reproduce the numerical audit

From the repository root:

```powershell
python review/game_design_2026-10-10/balance_checks.py --output review/game_design_2026-10-10/balance_results.json
```

The tool reads current source/data without changing it and includes source hashes in the output. It checks a hand-known damage tick, insufficient starting force, per-node excess-damage loss, nonnegative force, bounded simulation termination, permitted card-defense combinations, capture-cap breakpoints and retry expectations. Its targeted assertions stop if key inspected formulas change. It is a small reproducible audit tool, not a complete engine simulator.

Optional `--ammo-damage` and `--bot-damage` arguments support inspecting proposed coefficients without editing gameplay. Results are accepted as arithmetic verification; **no final numerical balance has been accepted**, because the bot/resource role and defensive-pressure rules are not yet settled. No rendered game test, export, save migration or whole-project regression suite was run for this document-analysis task.
