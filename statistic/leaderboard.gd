##
## std/statistic/leaderboard.gd
##
## StdLeaderboard is a class defining a leaderboard. This allows the game to interact
## with a specific leaderboard, regardless of the storefront.
##
## NOTE: This resource should be added to a `StdStatisticStore` node so that its
## implementation and definition can automatically be loaded.
##

class_name StdLeaderboard
extends StdStatistic

# -- SIGNALS ------------------------------------------------------------------------- #

## scores_downloaded is emitted when leaderboard results have successfully been fetched
## from a download query.
signal scores_downloaded(entries: Array[Entry])

## score_uploaded is emitted after attempting to upload a new score to the leaderboard.
signal score_uploaded(success: bool, updated: bool, score: int)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


## Entry is a data class representing one entry within a leaderboard.
class Entry:
	var details: Variant = null
	var player: int = 0
	var rank: int = 0
	var score: int = 0

# -- PUBLIC METHODS ------------------------------------------------------------------ #

## download_scores fetches a range of global leaderboard entries.
##
## NOTE: The fetch operation is asynchronous; if successful, the `scores_downloaded`
## will be emitted. There is currently no way to relay an error to the caller.
func download_scores(start: int, end: int) -> void:
	assert(_store is StdStatisticStore, "invalid state; missing store")
	Signals.ensure_connected(_store.leaderboard_scores_downloaded, _on_downloaded_scores)

	_store.download_leaderboard_scores(id, start, end)


## download_scores_around_user fetches a range of global leaderboard entries centered
## around the local user.
##
## NOTE: The fetch operation is asynchronous; if successful, the `scores_downloaded`
## will be emitted. There is currently no way to relay an error to the caller.
func download_scores_around_user(before: int, after: int) -> void:
	assert(_store is StdStatisticStore, "invalid state; missing store")
	Signals.ensure_connected(
		_store.leaderboard_scores_downloaded,
		_on_downloaded_scores,
	)

	_store.download_leaderboard_scores_around_user(id, before, after)


## download_scores_for_friends fetches all leaderboard entries belonging to the local
## user's friend list.
##
## NOTE: The fetch operation is asynchronous; if successful, the `scores_downloaded`
## will be emitted. There is currently no way to relay an error to the caller.
func download_scores_for_friends() -> void:
	assert(_store is StdStatisticStore, "invalid state; missing store")
	Signals.ensure_connected(_store.leaderboard_scores_downloaded, _on_downloaded_scores)

	_store.download_leaderboard_scores_for_friends(id)


## download_scores_for_users fetches all leaderboard entries belonging to the specified
## list of users.
##
## NOTE: The fetch operation is asynchronous; if successful, the `scores_downloaded`
## will be emitted. There is currently no way to relay an error to the caller.
func download_scores_for_users(users: PackedInt64Array) -> void:
	assert(_store is StdStatisticStore, "invalid state; missing store")
	Signals.ensure_connected(_store.leaderboard_scores_downloaded, _on_downloaded_scores)

	_store.download_leaderboard_scores_for_users(id, users)


## upload_score asynchronosuly uploads the provided score (and optional details) to the
## leaderboard. If `keep_best` is passed, then only the user's best score will be kept.
## A small amount of run-specific details can be provided via `details` (must not be an
## `Object`).
##
## NOTE: This method is *not* asynchronous; the `score_uploaded` signal will be emitted
## once the call has completed (regardless of outcome), so `await` that if needed.
func upload_score(score: int, details: Variant = null, keep_best: bool = true) -> void:
	assert(_store is StdStatisticStore, "invalid state; missing store")
	Signals.ensure_connected(_store.leaderboard_score_uploaded, _on_uploaded_score)

	_store.upload_leaderboard_score(id, score, details, keep_best)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

func _on_downloaded_scores(leaderboard: StringName, entries: Array[Entry] = []) -> void:
	if leaderboard != id:
		return

	scores_downloaded.emit(entries)


func _on_uploaded_score(
	leaderboard: StringName,
	success: bool,
	updated: bool,
	score: int = 0,
) -> void:
	if leaderboard != id:
		return

	score_uploaded.emit(success, updated, score)
