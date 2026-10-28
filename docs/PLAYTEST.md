# RIM — Milestone A usability tasks

Build: **0.5.0-a** (Milestone A: deterministic capture, open first-run menu, objective on the HUD, delivered-rate
accounting, host diagnoses and route inspection, target preview, event history).

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
| 2 | "Take one neutral host. Before you launch, tell me what could stop it." | Deterministic capture and its stop conditions (§8); target preview (§12.2) | A neutral host is captured, **and** they named at least two of: a Patch, losing the route, the host changing owner |
| 3 | "How many hosts do you need to win, and how close are you?" | Objective on the HUD (§16.2) | They read the majority needed, their count, and who leads or holds it |
| 4 | "Increase your Credential income, then show me that it is actually reaching your bank." | Delivered-rate accounting and the Economy view (§9.2) | A Credential harvester runs with an Intel supply, **and** they point to the Credentials rate or the Economy overview (E) rising, or to the host's "Delivered recently" line |
| 5 | "Build a Research lab on its own on one of your other hosts. Is it working? If not, why not?" | Host diagnosis of a starved remote Lab (§9.3) | They say it lacks Crypto (and Intel) on that host and that the bank can't feed a remote host, and name a fix (a Miner and Intel harvester there) |
| 6 | "One of your hosts may be cut off from your main node. Find out which, and what income you lose." *(Ask when a host has no route home. If it doesn't happen, ask them to check any remote host's route instead and record "staged: no".)* | Route inspection and the cut-off event (§12.1, §17.4) | They find the host (the red ring, its panel's "no route", or the critical event) and name what it was delivering |
| 7 | "Look at a rival's host. Pick an attack that hurts their economy, and before launching tell me what you expect and what you can't know." | Target preview, fog and dated Recon (§12.2) | They choose an economic card and state its effect and timing, and say what is unknown without Recon (e.g. its Firewall cards, its production) |
| 8 | "Set up a defence on one of your hosts so it protects itself, then later tell me what it did." | Firewall sockets and the event history (§13, §17.4) | A Firewall is loaded, **and** after an attack they find what fired (the event strip or H history) |
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
- Keep the sheets with the build version (0.5.0-a). Compare later builds with the same tasks.
