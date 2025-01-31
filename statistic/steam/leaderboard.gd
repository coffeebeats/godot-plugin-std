##
## std/statistic/steam/leaderboard.gd
##
## StdLeaderboardSteam is a leaderboard implementation backed by Steam.
##

class_name StdLeaderboardSteam
extends StdLeaderboard

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../../event/signal.gd")

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _download_scores(start: int, end: int) -> void:
	assert(_handle is int, "invalid state; missing leaderboard handle")

	if not Steam.leaderboard_scores_downloaded.is_connected(_on_scores_downloaded):
		Signals.connect_safe(Steam.leaderboard_scores_downloaded, _on_scores_downloaded)

	(
		Steam
		. downloadLeaderboardEntries(
			start,
			end,
			Steam.LEADERBOARD_DATA_REQUEST_GLOBAL,
			_handle,
		)
	)


func _download_scores_around_user(before: int, after: int) -> void:
	assert(_handle is int, "invalid state; missing leaderboard handle")

	if not Steam.leaderboard_scores_downloaded.is_connected(_on_scores_downloaded):
		Signals.connect_safe(Steam.leaderboard_scores_downloaded, _on_scores_downloaded)

	(
		Steam
		. downloadLeaderboardEntries(
			before,
			after,
			Steam.LEADERBOARD_DATA_REQUEST_GLOBAL_AROUND_USER,
			_handle,
		)
	)


func _download_scores_for_friends() -> void:
	assert(_handle is int, "invalid state; missing leaderboard handle")

	if not Steam.leaderboard_scores_downloaded.is_connected(_on_scores_downloaded):
		Signals.connect_safe(Steam.leaderboard_scores_downloaded, _on_scores_downloaded)

	(
		Steam
		. downloadLeaderboardEntries(
			0,
			0,
			Steam.LEADERBOARD_DATA_REQUEST_FRIENDS,
			_handle,
		)
	)


func _download_scores_for_users(users: PackedInt64Array) -> void:
	assert(_handle is int, "invalid state; missing leaderboard handle")

	if not Steam.leaderboard_scores_downloaded.is_connected(_on_scores_downloaded):
		Signals.connect_safe(Steam.leaderboard_scores_downloaded, _on_scores_downloaded)

	Steam.downloadLeaderboardEntriesForUsers(Array(users), _handle)


func _get_details_max_bytes() -> int:
	# See https://partner.steamgames.com/doc/features/leaderboards#1.
	return 64 * 4


func _get_score_max_value() -> int:
	# See https://partner.steamgames.com/doc/api/ISteamUserStats#UploadLeaderboardScore.
	return (1 << 31) - 1


func _load_definition() -> void:
	assert(not _handle, "invalid state; already found leaderboard")

	if not Steam.leaderboard_find_result.is_connected(_on_leaderboard_found):
		Signals.connect_safe(Steam.leaderboard_find_result, _on_leaderboard_found)

	Steam.findLeaderboard(id)


func _upload_score(score: int, details: PackedByteArray, keep_best: bool) -> void:
	assert(_handle is int, "invalid state; missing leaderboard handle")

	if not Steam.leaderboard_score_uploaded.is_connected(_on_score_uploaded):
		Signals.connect_safe(Steam.leaderboard_score_uploaded, _on_score_uploaded)

	Steam.uploadLeaderboardScore(score, keep_best, details.to_int32_array())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _on_leaderboard_found(handle: int, found: int = 0) -> void:
	if not _handle or handle != _handle:
		return

	if not found:
		_logger.error("Failed to find leaderboard.", {&"name": id})
		return

	_notify_load_definition(handle)


func _on_scores_downloaded(handle: int, results: Array) -> void:
	if not _handle or handle != _handle:
		return

	var entries: Array[Entry] = []

	for data in results:
		var details: PackedInt32Array = data.get("details", PackedInt32Array())

		(
			entries
			. append(
				_create_entry(
					data["steam_id"],
					data["score"],
					data["global_rank"],
					details.to_byte_array(),
				)
			)
		)

	_notify_download_scores(entries)


func _on_score_uploaded(success: bool, handle: int, data: Dictionary) -> void:
	if not _handle or handle != _handle:
		return

	_notify_upload_score(
		success,
		data.get("score_changed", 0) > 0,
		data.get("score", 0),
	)
