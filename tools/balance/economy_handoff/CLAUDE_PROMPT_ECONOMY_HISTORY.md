# Prompt to give Claude

**Follow-up:** candidate A is now present in the working tree. For the latest report that a few producers still support full-farm expansion, use [MILITARY_ECONOMY_ADDENDUM.md](MILITARY_ECONOMY_ADDENDUM.md). Preserve the existing implementation and test the new regeneration-cost and local-regeneration-cap candidates separately. The original request below is retained as historical context, not an instruction to redo the completed patch.

Please implement and validate the first economy candidate described in `tools/balance/economy_handoff/HANDOFF.md` for RIM's active Botnet prototype.

Read the whole handoff and inspect the current working tree before editing. Preserve existing user changes. The authoritative economy is in `scripts/botnet_cfg/*.gd` and `scripts/botnet_proto.gd`; do not change the legacy `data/economy.json` economy.

The vision is an investment and logistics economy: Intel funds operations and conversion; Crypto funds expansion and competes with tactical research; new captures require a development decision. Cards should be useful situational alternatives, not mandatory taxes.

Implement **candidate A only**:

- Bot farm construction changes from **30 Intel to 30 Crypto**, using the existing `cash` resource key.
- Intel harvesters add **15 capacity instead of 50**; base capacity stays 100.
- Preserve starting forces/resources, all production rates, free bot regeneration, construction timing/payment semantics, card rules, and other prices.
- Fix both AI brains' Crypto assumptions and zero-stock miner bootstrap. Keep the unfinished Insane difficulty disabled in the UI.
- Update costs/help and show resource-specific funding shortages for construction jobs.
- Run the specified mechanics, zero-Crypto AI, UI/help, and multiplayer checks. Follow the project's version convention when producing a changed gameplay build.

The previous conversational **10-Crypto price is superseded**: it lowers the source Intel cost per farm and makes cards expensive relative to farms. The handoff recommends 30 to preserve material cost; 20 is a conditional pacing fallback to test, not the default.

Run the accompanying prediction tool using its README. Its rates are not full-match predictions. Validate the candidate against baseline on the same maps, including an adapted strategy that builds efficient miners and then spams farms. Do not claim the snowball is solved if the stockpile simply moves from Intel to Crypto.

Use the handoff's acceptance criteria and report exact tested behavior separately from hypotheses. Do not implement escalating prices, upkeep, settling delays, diminishing farm output, or paid bot regeneration in this first patch. These are gated follow-ups, not additional requirements.

Return the changes, verification evidence, before/after observations, remaining limits, and a clear verdict. If a tool or playtest cannot be run, say so; do not invent results.
