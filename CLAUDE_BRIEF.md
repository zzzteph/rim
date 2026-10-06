# RIM — city and component exploration brief

Updated October 3, 2026. Read this file first when implementing the redesign. It consolidates the latest explanation with the earlier game decisions and reviewed notes.

**Status:** this is the requested design, not a report of implemented features. The inspected game declares `0.7.3`. Inspect current code and preserve unrelated working-tree changes. Later user instructions take precedence.

## Integrate the work already built

The user explicitly describes this as **a merge of the ideas and systems coded in earlier versions**. The implementation should combine those systems into one game and extend them with the two-map structure.

| Existing work | Its role in the combined game |
|---|---|
| Large procedural city, districts, streets, architecture, camera/minimap | The global city map |
| Scanning, access/persistence, captured hosts, multiple installations | Exploration and control at building and component scales |
| Earlier producers/processors, six resources, recipes, research | Programs installed in captured component slots and their progression |
| Actual packet delivery, input consumption, routing, and C2 banking | The operating economy and resource flow back to the hub |
| Capacity, upkeep, output controls, and overload feedback | Existing operational constraints, extended with component workload and access degradation |
| Readable left UI, accessibility, undo, saves, recovery, rendering optimizations | Shared foundation for both maps |

The new work is the local component graph, progressive discovery at both scales, component-specific ownership/slots/capacity, attack cards, and degradation/recapture. Earlier player-built facilities become installations on components; they keep their meaningful production and conversion roles.

Inspect and reuse or extract the relevant implemented code. Refactor where responsibilities need to move, and explain substantial replacements. Preserve functioning behavior and verification where it still matches the latest rules. A new small example that omits the old city, catalog, or economy is not the completed merge.

Keep distinct mechanics distinct: the earlier tunnel throughput/packet-loss model and the new component workload/access-loss model can coexist, but one is not a substitute for the other. Retain each only in the role defined by the combined design.

## The game the user now describes

RIM is a 2D cyberpunk hacking/automation game with an unseen operator and two connected map scales. **SimCity and Constructor describe the city presentation; Stellaris describes the hierarchy and exploration.**

- **Global map:** a continuous city. Each building is analogous to a star system, with connections to other buildings.
- **Local map:** a schematic network inside one building. Its components are analogous to the places where the player gains control and installs productive facilities.
- **Control:** hack individual components. One captured component establishes a building foothold and permits expansion to other connected buildings. Capturing every component grants full building control.
- **Economy:** install programs in captured components, benefit from their resource specialties, manage supported workload, and deliver actual resources to C2.
- **Risk:** excessive installed workload gradually degrades a component's access/control until it can be lost and must be hacked again.
- **Hacking:** invest resources and use technique cards with different powers and effects against component defenses.

Keep one New Game/Continue experience and no walking avatar.

The starting C2 has one known, captured entry component and an affordable resource reserve. It is the initial foothold, so exploration can begin without first hacking an unreachable building.

## 1. Global city map

Expose a seeded city size configuration from **10×10 to 100×100** before starting a run; save dimensions and seed. The precise grid unit is an implementation choice to document, rather than assuming every terrain tile is one building. Use a small initial map while supporting the larger configured sizes.

Restore adjoining neighborhoods, connected physical streets, readable building lots and varied architecture. Use an isometric or angled overhead 2D presentation with consistent scale and correct overlap ordering. Restore the earlier districts' architectural variety where useful. C2 starts near the Rim; starter resource classes remain reachable, with richer targets deeper in the city.

Every physical building is selectable and owns a generated component network. Keep pan/zoom, minimap navigation, and optional restrained city life. Respect reduced motion and the largest map's performance needs.

Buildings and their connections exist before the player arrives. **Scanning a building reveals its connections to other buildings.** Discovered links may be shown like connections in a Stellaris map; undiscovered links remain hidden. Preserve real streets as separate physical architecture.

Clicking a building opens its local schematic directly. Its summary and external-connection scan action can remain in the inspector/header. Returning to the city restores camera position, selection, and discovery state. The two maps are two views of the same run.

This replaces the earlier mandatory radius-only frontier and blanket ban on displaying connections. Known exploration connections and actual resource flow are now part of the presentation. Do not reveal unexplored links or component information through overlays, packets, labels, colors, or the minimap.

## 2. Local building map and progressive discovery

A newly opened building initially exposes **one entry component**, not its entire network. It is an access/discovery starting point and can be any of the supported component types; do not add a sixth component type merely to represent entry.

Select and scan a visible component to reveal information about it and the components directly connected to it. Discover their local links progressively. Scanning does not capture anything and must not recursively expose the whole building.

Show the local schematic as readable nodes/links for actual devices and services. Unknown components disclose only the information needed to interact; scanned components show type, defenses, capacity, slots, suitable cards, and program options as appropriate. Global discovery and local discovery are independent.

Use stable generated IDs and preserve hidden components as well as discovered ones across save/load. All actual components count toward full control, including undiscovered ones; controlling every currently visible node must not falsely mark the building complete.

## 3. Component types and slots

Limit the initial component types to these five, with the user's stated installation slot counts:

| Component | Program slots | Resource specialty explicitly described |
|---|---:|---|
| IoT | 2 | Stronger CPU/Cycles generation |
| Web server | 4 | Define/tune in the component data |
| File server | 4 | Define/tune in the component data |
| Database | 6 | Stronger Intel generation |
| PC | 6 | Define/tune in the component data |

CPU refers to the existing **Cycles** resource (`compute`), not a new seventh currency. Components offer different resource potential and bonuses for installed programs. Do not equate slot count with output or supported workload, and do not invent settled specialty values for the three types the user has not specified.

Programs occupy slots **on a captured component**, rather than sharing one undifferentiated building-wide slot pool. Allow different program types when their target requirements are met. Preserve useful remove, disable, output-limit, and undo controls.

## 4. Foothold, partial control, and full control

Capture the first eligible component to establish a foothold inside a building. **Installing a program is not required for onward exploration.** The player may develop that foothold or immediately move toward another discovered connected building.

Capturing every actual component grants full building control. Display unknown/discovered, foothold/partial control, and full control truthfully. Do not invent an automatic full-control reward or force full capture before expansion; its extra mechanical benefits have not been specified.

If a component is lost, ownership of that component changes without erasing the building or past discovery. A fully controlled building becomes partial. Losing the last captured component removes the building's foothold and further expansion from it. Other captured components remain captured.

Keep building discovery, component discovery, component access, installed programs, operational resource connectivity, load, and integrity as separate states.

## 5. Program workload and degradation

Each component has supported capacity/power and each installed program has a workload/consumption contribution. **Available slots and supported capacity are different constraints.**

User example: a database has **six slots** and **Intel capacity 3**. Installations requiring **Intel load 4** fit the slot count but exceed its capacity. The component becomes overloaded and degrades over time until control can be lost. Hacking it again is required to restore access.

Treat the example's capacity/load as local workload values; exact units, production rates, degradation timing, and balancing remain to be tuned. Keep local capacity load separate from banked resources spent as installation cost or processor inputs.

Allow the player to exceed capacity with a clear warning rather than silently replacing this risk with a hard capacity rejection. Model sustained overload, not instant loss from one installation.

Before installation and while running, show slots used/free, supported capacities, projected active load, resource bonus, actual output, overload status, and access/control integrity or equivalent condition. Explain the consequence of overloading.

The concrete decline/grace/recovery rules are design parameters. A reasonable MVP default is that active programs contribute load, disabled programs do not, and reducing load stops further overload damage. Do not quietly claim that these defaults were agreed numeric rules.

Loss and recapture must have documented effects on installed programs, operational routes, and timers. For a recoverable MVP, a reasonable default is to keep installations dormant while access is lost and resume valid programs after recapture; program destruction/reinstallation costs are not specified by the user.

## 6. Resource-funded attack cards

Hacking is a game action using **technique cards**, not a uniform flat-cost Hack button with different artwork.

Each card needs resource cost, technique family, power, target requirements, and effects against relevant component defenses. Organize cards around the user's three research areas: **vulnerabilities, credentials, and phishing**. Include password/brute-force techniques, distinct zero-day variants, and phishing techniques. The user specifically associates IoT targets with misconfiguration/weak-password attacks.

Make matchups meaningful: a password technique interacts with password-related defenses; zero-day variants apply to suitable vulnerable systems; phishing requires a suitable human-facing target. Express these concepts through game statistics and fictional technique descriptions. Avoid treating every technique as equally effective against every component.

Before committing, show cost, requirements, relevant target defenses, power/effects, and expected outcome or a clearly labeled success chance. Validate and pay costs consistently; failed/ineligible actions cannot charge twice or mint refunds.

No random draw deck, turn-based combat, or chance model was specified. For the first playable implementation, selectable available cards and transparent deterministic rules are a reasonable default. If using randomness, expose probabilities and define failure costs and persistence in saves. Exact power values and card effects require balancing.

### Research and stronger cards

The user proposed research to obtain more powerful cards. Connect this progression to the existing economy: **Intel + Cycles → Research Lab → Research → unlock a technique/card variant**. A researched card stays available in the current run and its save; cross-run progression is not implied. Research pays for the unlock, while each attack still pays its displayed operating cost in existing resources.

The latest discussion identifies **three research areas: vulnerability research, credentials, and phishing**. This replaces the earlier two-branch recommendation. The branch identities, card examples, costs, and target rules below are a proposed working design; the user has not settled their exact balance.

| Research area | Strategic role and eligible targets | Main attack resource emphasis | Illustrative card progression |
|---|---|---|---|
| Vulnerability research | Exploit a matching software weakness on a component; useful against compatible server/device targets with strong authentication | Tools, with supporting Cycles | Known Flaw → Service Exploit → Specialized Zero-Day |
| Credentials | Overcome weak authentication on a component with an exposed login; IoT is an early opportunity, but other types can qualify | Cycles; stronger attacks cost more | Weak Credentials → Brute Force → Optimized Brute Force |
| Phishing | Establish access through a human-operated endpoint; initially a PC with a human-facing trait | Intel, with supporting Cycles | Generic Phish → Targeted Phish → Tailored Campaign |

These resource emphases describe attack costs; **all three branches spend the existing Research resource to unlock cards**. They are independently researchable rather than mutually exclusive character classes. Let the player specialize early and combine approaches later. The higher-tier names illustrate direction, not a requirement to implement every card immediately.

For a small first slice, recommend one basic card and one researched improvement per branch. Basic password access is available at the start; gate stronger variants through research. Each improvement should have a clear benefit in power, applicability, or efficiency. A costly advanced card must leave the basic card useful against easy targets.

Eligibility depends on scanned target traits and relevant defenses, not component type alone. A PC may qualify for all three approaches; a machine without a human-facing trait cannot be phished. Show password defense for credential cards, software compatibility/resistance for vulnerability cards, and user awareness for phishing as abstract game attributes. An inapplicable card explains the missing requirement instead of merely showing low power.

Recommended phishing resolution for the first slice: a successful card captures the selected eligible PC, using the same ownership/slot rules as any other successful attack. This models the human interaction through a component trait; no sixth people/mailbox component or separate credential inventory is required. The new foothold permits normal scanning and onward attacks, but does not automatically capture its connected database or server. Every branch respects the same discovery and access frontier; advanced cards cannot reveal hidden nodes or jump across unexplored links.

Example combination: use a phishing card to capture an eligible entry PC, scan it to reveal a connected database, then use a suitable credential or vulnerability card on that database. This is a tactical option, not a mandatory sequence for every building.

Keep the existing **Phishing program** (installed production of Intel) distinct from **phishing cards** (paid capture actions). Cards do not also generate Intel, and the program does not automatically capture targets. Label the two roles clearly in their respective interfaces.

Show prerequisites, research cost, resulting card stats, attack cost, and suitable target defenses before purchase. A stronger card should open a useful new target or choice. Do not make one advanced card the best answer to every defense. Choose deterministic, clearly previewed behavior for this slice unless an alternative is explicitly documented.

Keep the opening and recapture affordable; lack of a specific randomly drawn card must not permanently strand the run. The starting economy and basic cards must support reaching and operating a Research Lab without needing the very advanced card that lab unlocks. Ensure the Forge/Tools chain is accessible before it becomes essential to progress. Research unlocks survive component loss; losing a lab can stop new research production without erasing learned techniques.

Generation must provide an affordable Cycles-funded route to initial Cycles/Intel income before Intel-heavy or Tools-heavy attacks become necessary. Provide reachable, discoverable targets for each branch, including human-facing PCs, so a research investment has usable opportunities in the generated city.

Optional later proposals, not required additions to the first slice:

- **Technique efficiency:** reduce an attack's resource cost as an alternative to increasing power.
- **Reconnaissance:** improve defense/vulnerability information from scanning while preserving progressive component discovery.
- **Program efficiency or access stability:** reduce installed workload or slow overload degradation, with a meaningful investment/tradeoff. These must not erase capacity management or make overload harmless.

Start with the three attack branches and test the full economy-to-research-to-capture loop before expanding the tree. Treat efficiency/reconnaissance/stability proposals as supporting upgrades, not additional attack families. Use the existing Research resource; no additional currency, random card packs, or deck-draw system is required.

## 7. Programs, specialties, and the earlier economy

Reuse the earlier productive facilities as programs installed on captured components. Preserve the locked resource roles:

| Resource | Role |
|---|---|
| Cycles/CPU (`compute`) | Processing power, operations, and running costs |
| Intel (`data`) | Information and inputs to higher-value chains |
| Tools | Exploit resources for access/cards where required |
| Crypto | Stolen value requiring laundering |
| Cash (`credits`) | Clean money for investment |
| Research | Permanent facility/technique unlocks |

Preserve the useful catalog and real input/output chains: Mirai/Poisoned Package/Cloud Cryptojacker → Cycles; Phishing/Scraper → Intel; Magecart → Crypto; Market converts Intel → Cash; Mixer converts Crypto → Cash; Forge uses Intel + Cycles → Tools; Lab uses Intel + Cycles → Research. Proxy/router utility remains optional where useful.

Component type and its resource potential provide bonuses to suitable installations. Distinguish **mandatory target capability**, **specialty bonus**, **slot usage**, **capacity load**, **installation cost**, **research requirement**, and **ongoing recipe inputs**. Unsupported targets are unavailable with a reason; temporary input starvation is an operational state.

The earlier user request specified 100% performance for matching affinity/color, 50% for another compatible affinity, and unavailable when mandatory requirements are missing. Keep that prior rule in view: this explanation adds component specialties without supplying a different numeric bonus scale. A reasonable MVP mapping is to use those percentages as the component's base resource-affinity factor. The relationship between earlier building color and new component specialty still needs an explicit choice; do not silently discard the earlier rule or stack arbitrary extra multipliers.

Keep shared resource colors/glyphs without making captured ownership overwrite resource identity. Research needs a readable fitting view/tree.

## 8. Actual flow to the hub

The player should see resources **start flowing to C2 after installing productive programs**. Transported resource state, banked amounts, converter consumption, and displayed feedback must agree. The user previously rejected decorative flow unrelated to actual delivery.

Show useful flow on discovered, operational connections without exposing the hidden city/local graph. Captured access and installed production are separate; a foothold can expand while having no production, and an installed program can be idle or disconnected.

Reuse reliable routing/packet simulation where practical. Handle broken routes and lost components coherently. Avoid the earlier long-path freeze, especially at maximum map size. Full local transport detail is optional for the first slice; do not require a second manual tunnel-construction system before the core loop works.

## 9. Preserved usability and recovery requirements

Keep a fixed-width **left** inspector/sidebar, stable minimap, large default text, supported 100–200% scaling, high contrast, alternate palette, reduced motion, keyboard controls, and truthful text/symbol status cues.

Both city and local views need readable selection, consistent hit geometry, click-versus-drag panning, and preserved camera state. Panels/modals must not leak input into either map. Preserve pause-to-plan, focus trapping/restoration, and immediate repaint after paused state changes.

Preserve safe undo and validated atomic save/load/backups. Save dimensions/seed, both graph levels, hidden/discovered identities, component access, installed programs, settings/load/integrity, attack/card progression, resources, operational state, and cameras. Rejected loading keeps the live run intact. Test with isolated saves/settings.

Keep a viable bootstrap and bounded emergency recovery after spending out, access loss, and Continue. Recovery must afford an applicable attack/recapture and a basic income path, not merely the old producer/link cost. Mistakes can cause setbacks and rehacking without permanently freezing the run.

## Implementation choices and scope

Document these unsettled details as choices rather than historical agreements:

- Whether city dimensions measure terrain tiles or building lots.
- Global scan frontier: a reasonable default is discovered links from a building with a captured component.
- Local frontier: entry is initially available; scan visible components to discover direct neighbors. A reasonable hacking default is entry first, then scanned components connected to captured access.
- Per-resource versus shared capacity, active/disabled load, grace/decline/recovery rates, integrity threshold, and recapture state.
- Dormant versus removed programs on loss; deterministic versus probabilistic cards.
- Research costs, prerequisites, card statistics, and the exact first set of unlocks within vulnerabilities/credentials/phishing. Phishing eligibility, direct PC capture, and resource emphases above are recommended defaults; supporting research upgrades remain optional proposals.
- Exact specialty bonuses and any retained color modifiers.
- Additional benefits for full building control and eventual victory conditions.

Do not transplant the whole old audit/genre wishlist. Bigger campaigns, rival operators, new resource types, audio, Ascension, storage systems, and a promised two-hour session remain separate work. The current win check must be adapted carefully to true component ownership; discovering/capturing only the visible subset cannot trigger full-control victory.

## Code and evidence

Active game: `scripts/netrun.gd`, `scenes/netrun.tscn`, `scripts/menu.gd`, `scripts/session.gd`. Earlier city/economy: `scripts/main.gd` (`_generate_city()`, `_paint_city()`, `DEFS`, `COST`, `CONV`, `TECH`). Reuse suitable `city_layer.gd`, `minimap.gd`, `ui.gd`, `glyphs.gd`, and `settings.gd`.

Reviewed notes and history: [review/CITY_REDESIGN_DECISIONS.md](review/CITY_REDESIGN_DECISIONS.md). Read old `DESIGN.md` and audit briefs against this current request. Older radius-only scans, installed-content-required expansion, blanket hidden-connection rules, and whole-building Hack actions are superseded. Old test/FPS reports do not verify this redesign.

## Playable slice and delivery

First demonstrate the entire loop on a small configured city: scan a reachable building, discover its external links, enter its one-component local view, scan and reveal a neighbor, use a resource-funded card to capture a component, install a producer, deliver real output to C2, expand to another building after only one capture, and demonstrate full control plus overload/loss/recapture separately.

Also demonstrate producing Research in a reachable lab, buying a card unlock, and using that card against a suitable component. Cover meaningful matchups across all three attack families, including an eligible phishing capture and a target that cannot be phished. Verify exact slot counts, progressive discovery at both levels, partial/full control, load versus slots, card costs/effects, research prerequisites and saved unlocks, real economy, loss of the last foothold, recapture/recovery, save/load, and supported rendered UI settings. Update `DESIGN.md` and tests that encode older rules; adapt `review/netrun_assertions.gd` to both graphs rather than retaining whole-building capture assumptions.

Measure comparable small, populated, and maximum-size maps, including local-view navigation, scan expansion, pan/zoom, and running/paused play. Report rendered FPS/frame times separately from synthetic/headless timings.

For the implemented game change, finish with clean Godot checks, rendered verification, a version bump using the project's single-digit carry rule, actual Windows export into **`build/rim.exe`**, and a fresh launch. Verify the existing `Windows Desktop` preset and recorded engine path `C:/Users/steph/Downloads/godot/Godot_v4.7.2-stable_win64_console.exe`.

Report the implemented behavior, chosen tuning defaults, checks actually run, measured performance, exported build, and remaining limitations.
