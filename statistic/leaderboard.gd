##
## std/statistic/leaderboard.gd
##
## StdLeaderboard is a base class for a leaderboard. This allows the game to interact
## with a specific leaderboard.
##

class_name StdLeaderboard
extends Resource

# -- SIGNALS ------------------------------------------------------------------------- #

## loaded is emitted once the leaderboard definition has been fetched and is ready for
## other operations.
signal loaded

## score_uploaded is emitted after attempting to upload a new score to the leaderboard.
signal score_uploaded(success: bool, updated: bool, score: int)

## scores_downloaded is emitted when leaderboard results have successfully been fetched
## from a download query.
signal scores_downloaded(entries: Array[Entry])

# -- DEFINITIONS --------------------------------------------------------------------- #


## Entry is a data class representing one entry within a leaderboard.
class Entry:
	var details: Variant = null
	var player: int = 0
	var rank: int = 0
	var score: int = 0


# -- CONFIGURATION ------------------------------------------------------------------- #

## id is the "API name", or unique identifier, for this leaderboard.
@export var id: StringName = &""

# -- INITIALIZE ---------------------------------------------------------------------- #

# gdlint:ignore=class-definitions-order
static var _logger := StdLogger.create(&"std/stat/leaderboard")

var _handle: Variant = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## load_definition asynchronously fetches information about the leaderboard from the
## storefront. This should be called once before attempting other operations on the
## leaderboard.
##
## NOTE: This method is *not* asynchronous and the `loaded` signal will *only* be
## emitted if the leaderboard definition was successfully loaded. There is currently no
## way to relay an error to the caller.
func load_definition() -> void:
	if _handle != null:
		return

	_logger.debug("Loading leaderboard definition.", {&"name": id})

	_load_definition()


## download_scores fetches a range of global leaderboard entries.
##
## NOTE: The fetch operation is asynchronous; if successful, the `scores_downloaded`
## will be emitted. There is currently no way to relay an error to the caller.
func download_scores(start: int, end: int) -> void:
	if _handle == null:
		assert(false, "invalid state; missing leaderboard handle")
		return

	if start < 0 or end < 0:
		assert(false, "invalid argument(s); must be >= 0")
		return

	(
		_logger
		. debug(
			"Downloading leaderboard scores in range.",
			{&"name": id, &"start": start, &"end": end},
		)
	)

	_download_scores(start, end)


## download_scores_around_user fetches a range of global leaderboard entries centered
## around the local user.
##
## NOTE: The fetch operation is asynchronous; if successful, the `scores_downloaded`
## will be emitted. There is currently no way to relay an error to the caller.
func download_scores_around_user(before: int, after: int) -> void:
	if _handle == null:
		assert(false, "invalid state; missing leaderboard handle")
		return

	if before < 0 or after < 0:
		assert(false, "invalid argument(s); must be >= 0")
		return

	(
		_logger
		. debug(
			"Downloading leaderboard scores around local user.",
			{&"name": id, &"before": before, &"after": after},
		)
	)

	_download_scores_around_user(before, after)


## download_scores_for_friends fetches all leaderboard entries belonging to the local
## user's friend list.
##
## NOTE: The fetch operation is asynchronous; if successful, the `scores_downloaded`
## will be emitted. There is currently no way to relay an error to the caller.
func download_scores_for_friends() -> void:
	if _handle == null:
		assert(false, "invalid state; missing leaderboard handle")
		return

	(
		_logger
		. debug(
			"Downloading leaderboard scores for friends.",
			{&"name": id},
		)
	)

	_download_scores_for_friends()


## download_scores_for_users fetches all leaderboard entries belonging to the specified
## list of users.
##
## NOTE: The fetch operation is asynchronous; if successful, the `scores_downloaded`
## will be emitted. There is currently no way to relay an error to the caller.
func download_scores_for_users(users: PackedInt64Array) -> void:
	if _handle == null:
		assert(false, "invalid state; missing leaderboard handle")
		return

	if not users:
		assert(false, "invalid argument; missing users")
		return

	(
		_logger
		. debug(
			"Downloading leaderboard scores for users.",
			{&"name": id, &"users": users},
		)
	)

	_download_scores_for_users(users)


## upload_score asynchronosuly uploads the provided score (and optional details) to the
## leaderboard. If `keep_best` is passed, then only the user's best score will be kept.
## A small amount of run-specific details can be provided via `details` (must not be an
## `Object`).
##
## NOTE: This method is *not* asynchronous; the `score_uploaded` signal will be emitted
## once the call has completed (regardless of outcome), so `await` that if needed.
func upload_score(score: int, details: Variant = null, keep_best: bool = true) -> void:
	if _handle == null:
		score_uploaded.emit(false, false, 0)
		return

	if score > _get_score_max_value():
		assert(false, "invalid input; score exceed maximum value")
		score_uploaded.emit(false, false, 0)
		return

	var bytes: PackedByteArray
	if details != null:
		assert(not details is Object, "invalid argument; wrong type")

		bytes = var_to_bytes(details)
		if bytes.size() > _get_details_max_bytes():
			assert(false, "invalid input; score exceed maximum value")
			score_uploaded.emit(false, false, 0)
			return

	(
		_logger
		. debug(
			"Uploading leaderboard score.",
			{
				&"name": id,
				&"score": score,
				&"keep_best": keep_best,
				&"has_details": not bytes.is_empty(),
			},
		)
	)

	_upload_score(score, bytes, keep_best)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _download_scores(_start: int, _end: int) -> void:
	assert(false, "unimplemented")


func _download_scores_around_user(_before: int, _after: int) -> void:
	assert(false, "unimplemented")


func _download_scores_for_friends() -> void:
	assert(false, "unimplemented")


func _download_scores_for_users(_users: PackedInt64Array) -> void:
	assert(false, "unimplemented")


func _get_details_max_bytes() -> int:
	assert(false, "unimplemented")
	return 0


func _get_score_max_value() -> int:
	assert(false, "unimplemented")
	return 0


func _load_definition() -> void:
	assert(false, "unimplemented")


func _upload_score(_score: int, _details: PackedByteArray, _keep_best: bool) -> void:
	assert(false, "unimplemented")


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_entry(
	player: int,
	score: int,
	rank: int,
	details: PackedByteArray,
) -> Entry:
	var entry := Entry.new()

	entry.player = player
	entry.score = score
	entry.rank = rank
	entry.details = bytes_to_var(details)

	return entry


func _notify_download_scores(entries: Array[Entry] = []) -> void:
	(
		_logger
		. debug(
			"Successfully downloaded leaderboard scores.",
			{&"name": id, &"count": entries.size()},
		)
	)

	scores_downloaded.emit(entries)


func _notify_load_definition(handle: Variant = null) -> void:
	(
		_logger
		. debug(
			"Successfully loaded leaderboard definition.",
			{&"name": id, &"handle": handle},
		)
	)

	loaded.emit()
	_handle = handle


func _notify_upload_score(success: bool, updated: bool, score: int = 0) -> void:
	if success:
		(
			_logger
			. debug(
				"Successfully uploaded leaderboard score.",
				{&"name": id, &"updated": updated, &"score": score},
			)
		)
	else:
		_logger.error("Failed to upload leaderboard score.", {&"name": id})

	score_uploaded.emit(success, updated, score)
