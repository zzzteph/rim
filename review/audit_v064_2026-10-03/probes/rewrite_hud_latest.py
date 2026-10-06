import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
file = root / 'findings' / 'hud_stats_alerts.json'
rows = json.loads(file.read_text(encoding='utf-8'))
line_map = {
    'scripts/ui.gd:891': 'scripts/ui.gd:920',
    'scripts/ui.gd:899': 'scripts/ui.gd:928',
    'scripts/ui.gd:761': 'scripts/ui.gd:780',
    'scripts/ui.gd:783': 'scripts/ui.gd:798',
    'scripts/ui.gd:832': 'scripts/ui.gd:860',
    'scripts/ui.gd:774': 'scripts/ui.gd:791',
    'scripts/ui.gd:928': 'scripts/ui.gd:957',
    'scripts/ui.gd:915': 'scripts/ui.gd:944',
}
for row in rows:
    row['source'] = line_map.get(row['source'], row['source'])
    row['evidence'] = row['evidence'].replace('probes/hud_results.json', 'probes/hud_v065_results.json').replace('Frozen UI', 'v0.6.5 UI').replace('frozen UI', 'v0.6.5 UI')

by_key = {row['key']: row for row in rows}
by_key['HUD01'].update(
    title='The compact header still clips at 200% and removes Feed from the HUD',
    evidence='Reverified on imported source_v065 at 1280×720: the 200% compact header needs 1005 px but has 956 px, clipping its final fields; the legend spans x=600–1399. Compact fallback is implemented, but omits Feed entirely and rounds upkeep to whole numbers. Baseline v0.6.4 geometry is retained separately. Evidence: probes/hud_v065_results.json scaled_hud.',
    source='scripts/ui.gd:824',
    reproduction='Set Text size to 200% at 1280×720; inspect the compact resource/health header and legend. Larger stockpile digit counts also force compact mode.',
    impact='Accessibility scaling still removes information, and compact mode hides network feed even when the network is starving.',
    recommendation='Use responsive resource chips or wrapped rows with reserved health space. Keep Feed and meaningful upkeep precision when compacting; make overflow information explicitly reachable.',
    acceptance='At 100–200% and 1280×720, all six resources and trace/feed/goal/upkeep remain readable or available through obvious overflow controls, without clipping or losing health fields.',
)
by_key['HUD15'].update(
    title='String-based message detection loses repeated and same-frame action results',
    evidence='Reverified v0.6.5: emit the same failed placement, wait 3.7 s, emit again; _msg_t stays 0 and status remains Hover hint. In a second controlled case, assign two results before one UI update; history contains only the second. The new queue stores observed strings but cannot recover undetected events. Evidence: probes/hud_v065_results.json repeated_same_message/same_frame_history.',
    source='scripts/ui.gd:957',
    reproduction='Repeat an identical invalid action after feedback expires, or produce two independent results within one render frame.',
    impact='Repeated input appears ignored, and earlier same-frame rewards/failures vanish before entering the new history.',
    recommendation='Emit action results as explicit events with unique IDs rather than watching a shared string; enqueue each event at its source.',
    acceptance='Every action result is captured, including identical consecutive failures and two events in one frame; history and visible feedback preserve both.',
)
by_key['HUD16'].update(
    title='The severity queue can delay urgent blackout warnings behind routine messages',
    kind='bug',
    evidence_level='verified_runtime',
    evidence='v0.6.5 classifies severity and varies color/duration, but uses FIFO pop_front. A controlled 10-routine-message fixture queues BLACKOUT last, giving a 22 s wait before its 3.6 s display. After 100 more messages, the pending queue grows to 110 while history is bounded at 12. Evidence: probes/hud_v065_results.json warning_fifo/queue_bound.',
    source='scripts/ui.gd:967',
    reproduction='Make several rapidly changing routine selections/results, then receive an ICE blackout or another critical error.',
    impact='Urgent information can arrive after the four-second blackout has already finished, while old routine feedback continues.',
    recommendation='Preempt or prioritize urgent operational events; coalesce routine repeats and bound the pending queue by count/age. Preserve readable acknowledgements without replaying obsolete actions.',
    acceptance='A newly received critical warning displays immediately; routine backlog remains bounded and does not delay time-critical information.',
)
rows.append(dict(
    key='HUD20',
    title='Loading a run preserves queued messages from the discarded timeline',
    kind='bug', area='Load feedback lifecycle', priority='P2', evidence_level='verified_runtime',
    evidence='A controlled v0.6.5 UI fixture queues old reward/expired messages, applies a valid saved state via the same _apply_save path used by Load, then reports Game loaded. The old reward still displays, with old expiry and Game loaded pending behind it. _apply_save clears Main transients but not UI message state. Evidence: probes/hud_v065_results.json load_message_timeline.',
    source='scripts/ui.gd:961',
    reproduction='Queue rapid action results, then successfully Load another saved run before the message queue drains. The fixture drives _apply_save directly to isolate message lifecycle.',
    impact='A restored run shows obsolete rewards/failures from a timeline that no longer exists, and Load success itself may be delayed.',
    recommendation='Reset pending/current UI messages and align history with the successful load boundary; immediately surface the load/recovery result. Preserve messages when Load is refused.',
    acceptance='After a successful Load, no discarded-timeline event is shown as current; success/recovery displays immediately, while failed Load leaves live-state feedback intact.',
    effort='S',
))
file.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'count': len(rows), 'bugs': sum(row['kind'] == 'bug' for row in rows)}))
