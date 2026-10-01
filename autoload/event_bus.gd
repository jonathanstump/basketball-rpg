extends Node
## Typed signals for cross-system events (spec §15.3). Systems never hold
## references to each other for notifications; they emit/listen here.

# --- Combat / ball ---
signal shot_released(actor_id: int, grade: String)
signal bucket_scored(grade: String, zone: String, damage: float)
signal ankle_broken(attacker_id: int, target_id: int)
signal strip_landed(attacker_id: int, target_id: int)
signal deflect_landed(attacker_id: int, target_id: int)
signal rejection_landed(attacker_id: int, target_id: int)
signal actor_damaged(target_id: int, amount: float, source_id: int)
signal actor_died(actor_id: int, kind: String)
signal composure_broken(actor_id: int, kind: String)
signal hype_changed(value: float)
signal takeover_started()
signal takeover_ended()
signal bag_move_used(move_id: String)
signal taunt_completed(actor_id: int)
signal bucket_blast_fired(hoop_id: String, position: Vector3)
signal ball_lost(reason: String)

# --- Bosses / duel ---
signal duel_state_changed(state: String)
signal boss_engaged(boss_id: String)
signal boss_phase_changed(boss_id: String, phase: int)
signal boss_defeated(boss_id: String)
signal game_point_reached(boss_id: String)
signal crown_awarded(borough: String)

# --- Player lifecycle ---
signal player_cooked()
signal chain_dropped(position: Vector3, rep: int)
signal chain_recovered(rep: int)
signal player_respawned(bodega_id: String)
signal rested(bodega_id: String)
signal leveled_up(stat: String, new_level: int)

# --- Exploration / economy ---
signal station_discovered(station_id: String)
signal item_acquired(item_id: String, count: int)
signal tokens_changed(value: int)
signal rep_changed(value: int)
signal box_opened(box_id: String, item_ids: PackedStringArray)
signal shortcut_opened(shortcut_id: String)
signal quest_flag_set(flag: String)
signal district_loaded(district_id: String)

# --- Presentation hooks ---
signal popup_text(text: String, world_pos: Vector3, style: String)
signal hitstop_requested(frames: int)
signal screen_shake_requested(strength: float)
signal slowmo_requested(time_scale: float, duration_s: float)
signal flash_requested(kind: String)
signal dialogue_requested(speaker: String, lines: PackedStringArray)
signal achievement_unlocked(api_name: String)
signal settings_changed()
