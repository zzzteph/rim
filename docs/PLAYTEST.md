# RIM — Milestone A usability tasks

Build: **0.6.18** (every building makes 1 unit every 6 s instead of 12, and prices, storages and caps doubled with it, so your workers are rarely free; a worker freed at a host carries that host's output home before it walks anywhere empty; a worker leaving a host for the main node to fetch supplies takes a unit of that host's output along; a host whose Firewall lives on Intel brought in keeps room for it, so a full storage never switches it off; the forecast follows the workers as they now work, host by host; under each bank the net change per minute — income less research, the card queue, construction and Firewall upkeep — with the breakdown on hover; the host panel shows the host's facts and one row per slot with what each building makes, uses and has in stock as icons, and a click on a slot opens the list of buildings to build there; workers are free where they deliver and go on from there: building and Firewall upkeep strictly first, their materials carried straight from the nearest stock — your bank, a host's spare, your salvage — to the site, never through the main node; a host's surplus waits for the worker already on its way there; a Firewall host that makes no Intel is topped up by its neighbours' surplus; workers sent together never take the Intel a host keeps for its Firewalls, phished or not; a Vault raid leaves no stale claims; a Firewall note never tells you to build a harvester that is only stopped, nor that Intel is coming while Sabotage holds your workers; a remote Firewall eats its host's own Intel harvest first, so a full storage never switches it off; research leaves alone what your buildings still need; the research bar says what the bank lacks and what it keeps, and for whom; an eliminated thief's siphons and Phishing end at once; one stolen or salvaged unit draws one worker; your own salvage is collected before exports; the attack preview and the map show a host where no Patch can be played; a Patch that stops an intrusion leaves its host open to another for 30 s; no card can be played while your main node is under DDoS; whoever takes a main node inherits that network with its buildings; Phishing lasts 180 s, Packet siphon 60 s, Sabotage also stops the hit hosts' station workers, and stolen goods are your workers' last job; the Worm is a Known exploit that moves on; every Miner, Credential harvester and Lab makes a unit each cycle with no input; the card at the head of the manufacturing queue collects its price before research and supplies take any; buildings and blueprints priced mostly in Crypto; workers that build first — a project's materials before any supply, and the bank stock it needs kept for it, Bot stations first, while Firewalls stay powered and every host is still served; a build menu that never scrolls and never sits under the card drawer, and says what each building does; hover notes that stay on screen; buildings that cannot be paused; rival AIs that keep developing, even when cut off or boxed in, and build their Research host where it feeds itself; a map view that only you move, whatever the sim takes, gives or hides; an income forecast that is right for each material even when workers are short or a host's storage is nearly full, and says why; Recon gets through half the time; attacks work 50% on a scouted host and 25% otherwise; one pool of
workers working from the main node, two per Bot station, building first and the hosts served in turn; 1 unit per
producer every 6 s; construction supplied before work; one four-place manufacturing
queue; your host's panel is a build menu with no prose; a Logs button instead of messages over the map; a research
bar only while research runs; unscouted hosts that show only their name).

This is the exit-gate session from the implementation brief (§22, §23.1): **5–8 first-time players** attempt the
tasks below without being taught the interface. It is a small qualitative sample. Report counts ("4 of 6 completed
unaided"), never a population percentage, and fix any confusion that recurs or blocks play before adding mechanics.

## Before each session

1. Use the exported build or the editor at 1366×768 or 1280×720, 100% UI scale.
2. Start from a **fresh profile**. Delete the game's user folder, or at least `campaign.json` in it:
   - Windows: `%APPDATA%\Godot\app_userdata\Rim\`
   - macOS: `~/Library/Application Support/Godot/app_userdata/Rim/`
   - Linux: `~/.local/share/godot/app_userdata/Rim/`
3. Give each participant a code (P1, P2, …). No names or personal data go on the sheet.
4. Have a printed or open copy of the recording sheet (below) and a timer.

## How to run it

- Say once: "Please think aloud. I can't help with the game, but there are no wrong answers. We're testing the game, not you."
- Read each task exactly as written. Do not point at the screen, name a control, or explain a rule.
- Start the timer when you finish reading the task. Stop it when the participant does the task or explains it correctly.
- If they are stuck for **3 minutes**, ask "What would you try next?" If that doesn't unblock them, give the
  smallest hint that does, and record it as assistance. **A task completed after coaching is not an unaided success.**
- Note wrong assumptions in the participant's own words; they are the most useful data.

## Tasks

Run them in this order. Tasks 1–3 are at the start of a Skirmish (Medium map, 1 enemy). Tasks 4–8 continue the
same match.

| # | Task (read aloud) | What it checks | Done when |
|---|-------------------|----------------|-----------|
| 1 | "Start a match against the computer. You don't have to do the tutorial." | Learn is skippable; Skirmish opens at once (brief §17.1) | A Skirmish is running, without finishing Learn |
| 2 | "Take one neutral host. Before you launch, tell me what could stop it." | Capture, its stop conditions and the Recon odds; target preview | A neutral host is captured, **and** they named at least two of: a Patch, losing the route, the host changing owner, the dice (50% scouted, 25% without fresh Recon) |
| 3 | "How many hosts do you need to win, and how close are you?" | Objective on the HUD (§16.2) | They read the majority needed, their count, and who leads or holds it |
| 4 | "Increase your Credential income, then show me that it is actually reaching your bank." | The income forecast and the Economy view | A Credential harvester runs with Intel on its host (made there or brought by workers), **and** they point to the Credentials forecast on the HUD or in the Economy overview (E) rising |
| 5 | "Build a Research lab on its own on one of your other hosts. Is it working? If not, why not?" | Host diagnosis of a starved remote Lab; supply | They hover its Lab slot (or open the Logs) and say whether workers are bringing Intel and Crypto, or what blocks them (no workers, no stock at the main node, no route) |
| 6 | "One of your hosts may be cut off from your main node. Find out which, and what income you lose." *(Ask when a host has no route home. If it doesn't happen, ask them to check any remote host's route instead and record "staged: no".)* | Route inspection and the cut-off event (§12.1, §17.4) | They find the host (the red ring, "no route" in a slot's tooltip, or the critical entry in the Logs) and name what it was delivering |
| 7 | "Look at a rival's host. Pick an attack that hurts their economy, and before launching tell me what you expect and what you can't know." | Target preview, fog and dated Recon (§12.2) | They choose an economic card and state its effect and timing, and say what is unknown without Recon (e.g. its Firewall cards, its production) |
| 8 | "Set up a defence on one of your hosts so it protects itself, then later tell me what it did." | Firewall sockets, travelling defence cards, the event history | A defence card reaches a Firewall socket (they can point to it under the Firewall), **and** after an attack they find what fired (the Logs button, or H) |
| 9 | At the end of the match, or after 25 minutes: "Why did you win or lose, and what would you try next time?" | End-of-match understanding (a debrief is planned, not in this build) | Record their explanation; no pass/fail |

Not in this build, so not asked: funding two Exploits under a research budget (orders and research policy are
planned for a later milestone), and saving, closing and continuing a match (no save yet).

## Recording sheet (one row per task per participant)

| Participant | Task | Completed (yes / partial / no) | Assistance (none / question / hint / shown) | Time to understand (s) | Wrong assumptions (their words) | Notes |
|---|---|---|---|---|---|---|
| P1 | 1 | | | | | |

At the end, ask: **"Would you like to play another match?"** (yes / maybe / no, and why), and record it.

## After all sessions

- For each task: how many completed it unaided, with assistance, or not at all, plus the median time.
- Group the wrong assumptions. Rate each group **severe** (blocked the task, or a wrong mental model that led to bad
  decisions), **moderate** (slowed them down, then self-corrected) or **minor**.
- Exit gate (brief §22): a dependable first capture (task 2), no recurring severe confusion, and all automated
  checks passing (see BUILD.md). A severe confusion that recurs in two or more participants is fixed before new
  mechanics are added.
- Keep the sheets with the build version (0.6.0). Compare later builds with the same tasks.
