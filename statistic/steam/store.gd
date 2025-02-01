##
## std/statistic/store.gd
##
## StdStatStoreSteam is a Steam-backed stats store implementation.
##

@tool
class_name StdStatStoreSteam
extends StdStatisticStore

# -- INITIALIZATION ------------------------------------------------------------------ #

var _pending: Dictionary = {}

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _download_leaderboard_scores(id: StringName, begin: int, end: int) -> void:
	var handle: Variant = _leaderboards.get(id)
	assert(handle is int, "invalid state; missing leaderboard handle")

	_pending[handle] = id

	Signals.ensure_connected(Steam.leaderboard_scores_downloaded, _on_scores_downloaded)

	(
		Steam
		. downloadLeaderboardEntries(
			begin,
			end,
			Steam.LEADERBOARD_DATA_REQUEST_GLOBAL,
			handle,
		)
	)


func _download_leaderboard_scores_around_user(
	id: StringName,
	before: int,
	after: int,
) -> void:
	var handle: Variant = _leaderboards.get(id)
	assert(handle is int, "invalid state; missing leaderboard handle")

	_pending[handle] = id

	Signals.ensure_connected(Steam.leaderboard_scores_downloaded, _on_scores_downloaded)

	(
		Steam
		. downloadLeaderboardEntries(
			before,
			after,
			Steam.LEADERBOARD_DATA_REQUEST_GLOBAL_AROUND_USER,
			handle,
		)
	)


func _download_leaderboard_scores_for_friends(_id: StringName) -> void:
	var handle: Variant = _leaderboards.get(id)
	assert(handle is int, "invalid state; missing leaderboard handle")

	_pending[handle] = id

	Signals.ensure_connected(Steam.leaderboard_scores_downloaded, _on_scores_downloaded)

	(
		Steam
		. downloadLeaderboardEntries(
			0,
			0,
			Steam.LEADERBOARD_DATA_REQUEST_FRIENDS,
			handle,
		)
	)


func _download_leaderboard_scores_for_users(
	_id: StringName,
	_users: PackedInt64Array,
) -> void:
	var handle: Variant = _leaderboards.get(id)
	assert(handle is int, "invalid state; missing leaderboard handle")

	_pending[handle] = id

	Signals.ensure_connected(Steam.leaderboard_scores_downloaded, _on_scores_downloaded)

	Steam.downloadLeaderboardEntriesForUsers(Array(users), handle)


func _get_leaderboard_details_max_bytes() -> int:
	# See https://partner.steamgames.com/doc/features/leaderboards#1.
	return 64 * 4


func _get_leaderboard_score_max_value() -> int:
	# See https://partner.steamgames.com/doc/api/ISteamUserStats#UploadLeaderboardScore.
	return (1 << 31) - 1


func _get_stat_value_float(id: StringName) -> float:
	return Steam.getStatFloat(id)


func _get_stat_value_int(id: StringName) -> int:
	return Steam.getStatInt(id)


func _is_achievement_unlocked(id: StringName) -> bool:
	var data := Steam.getAchievement(id)
	assert(data.get("ret", false), "failed to check achievement status")
	return data.get("achieved", false)


func _load_leaderboard(id: StringName) -> void:
	var handle: Variant = _leaderboards.get(id)
	assert(handle is int, "invalid state; missing leaderboard handle")

	_pending[handle] = id

	Signals.ensure_connected(Steam.leaderboard_find_result, _on_leaderboard_found)

	Steam.findLeaderboard(id)


func _set_stat_value_float(id: StringName, value: float) -> bool:
	return Steam.setStatFloat(id, value)


func _set_stat_value_int(id: StringName, value: int) -> bool:
	return Steam.setStatInt(id, value)


func _store_stats() -> bool:
	return Steam.storeStats()


func _timeout() -> void:
	store_stats()


func _unlock_achievement(_id: StringName) -> bool:
	return Steam.setAchievement(id)


func _upload_leaderboard_score(
	id: StringName,
	score: int,
	details: PackedByteArray,
	keep_best: bool,
) -> void:
	var handle: Variant = _leaderboards.get(id)
	assert(handle is int, "invalid state; missing leaderboard handle")

	_pending[handle] = id

	Signals.ensure_connected(Steam.leaderboard_score_uploaded, _on_leaderboard_found)

	Steam.uploadLeaderboardScore(score, keep_best, details.to_int32_array(), handle)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_leaderboard_found(handle: int, found: int = 0) -> void:
	var id: StringName = _pending.get(handle, &"")
	if not id:
		assert(false, "invalid state; missing id mapping")
		return

	_pending.erase(handle)

	if not found:
		_logger.error("Failed to find leaderboard.", {&"name": id})
		return

	_notify_leaderboard_loaded(id, handle)


func _on_scores_downloaded(handle: int, results: Array) -> void:
	var entries: Array[StdLeaderboard.Entry] = []

	for data in results:
		var details: PackedInt32Array = data.get("details", PackedInt32Array())

		var entry := StdLeaderboard.Entry.new()
		entry.player = data["steam_id"]
		entry.score = data["score"]
		entry.rank = data["global_rank"]
		entry.details = details.to_byte_array()

		entries.append(entry)

	var id: StringName = _pending.get(handle, &"")
	if not id:
		assert(false, "invalid state; missing id mapping")
		return

	_pending.erase(handle)
	_notify_downloaded_leaderboard_scores(id, entries)


func _on_score_uploaded(success: bool, handle: int, data: Dictionary) -> void:
	var id: StringName = _pending.get(handle, &"")
	if not id:
		assert(false, "invalid state; missing id mapping")
		return

	_pending.erase(handle)

	_notify_uploaded_leaderboard_score(
		id,
		success,
		data.get("score_changed", 0) > 0,
		data.get("score", 0),
	)
