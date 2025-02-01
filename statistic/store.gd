##
## std/statistic/store.gd
##
## StdStatisticStore is a node which facilitate persisting statistic and achievement
## changes to the storefront's statistics server. Calls to store stats will be rate-
## limited via the configurable debounce properties.
##
## This node is a base class; storefronts should create their own subclass and implement
## the `_load_stats`/`_store_stats` methods to define how to persist statistics values.
##

class_name StdStatisticStore
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## achievement_unlocked is emitted when an achievement is first unlocked.
signal achievement_unlocked(id: StringName)

## leaderboard_loaded is emitted once a leaderboard definition has been fetched and is
## ready for other operations.
signal leaderboard_loaded(id: StringName)

## leaderboard_score_uploaded is emitted after attempting to upload a new score to the
## leaderboard. This will be broadcast regardless of the outcome.
signal leaderboard_score_uploaded(
	id: StringName,
	success: bool,
	updated: bool,
	score: int,
)

## leaderboard_scores_downloaded is emitted when leaderboard results have successfully
## been fetched from a download query.
signal leaderboard_scores_downloaded(
	id: StringName,
	entries: Array[StdLeaderboard.Entry],
)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")
const Debounce := preload("../timer/debounce.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## achievements is the set of user achievements defined for the game. Upon one of these
## unlocking, the statistics data will be stored (debounced via the properties below).
@export var achievements: Array[StdAchievement] = []

## leaderboards is the set of leaderboards defined for the game. Definitions for these
## will be fetched upon this store entering the scene.
@export var leaderboards: Array[StdLeaderboard] = []

## statistics is the set of user statistics defined for the game.
@export var statistics: Array[StdStat] = []

@export_subgroup("Debounce")

## debounce_duration is the minimum duration (in seconds) between calls to store stats.
@export var debounce_duration: float = 5.0

## debounce_duration_max sets the maximum duration (in seconds) a call can be delayed.
@export var debounce_duration_max: float = 30.0

# -- INITIALIZATION ------------------------------------------------------------------ #

# gdlint:ignore=class-definitions-order
static var _logger := StdLogger.create(&"std/statistic/store")

var _debounce: Debounce = null
var _leaderboards: Dictionary = {}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## store_stats persists any pending statistic updates. If `force` is passed, this will
## bypass the debounce timer and directly update stats.
func store_stats(force: bool = false) -> void:
	assert(is_inside_tree(), "invalid state; must be inside scene tree")
	assert(_debounce is Debounce, "invalid state; missing debounce timer")

	if force:
		_debounce.reset()
		_store_stats()
		return

	_debounce.start()


# Achievements


## is_achievement_unlocked returns whether the specified achievement has been unlocked
## by the local user.
func is_achievement_unlocked(id: StringName) -> bool:
	assert(id, "invalid argument; missing id")
	return _is_achievement_unlocked(id)


## unlock_achievement "sets" the achievement, unlocking it for the user. Safe to call
## even if the achievement has previously been unlocked. This method returns whether the
## call was successful, *not* whether the achievement was newly unlocked.
func unlock_achievement(id: StringName) -> bool:
	assert(id, "invalid argument; missing id")

	var was_unlocked := is_achievement_unlocked(id)
	var result := _unlock_achievement(id)

	if not was_unlocked:
		achievement_unlocked.emit(id)
		store_stats()

	return result


# Leaderboards


## load_leaderboard asynchronously fetches information about the leaderboard from the
## storefront. This should be called once before attempting other operations on the
## leaderboard.
##
## NOTE: This method is *not* asynchronous and the `loaded` signal will *only* be
## emitted if the leaderboard definition was successfully loaded. There is currently no
## way to relay an error to the caller.
func load_leaderboard(id: StringName) -> void:
	if _leaderboards.get(id):
		return

	_logger.info("Loading leaderboard definition.", {&"name": id})

	_load_leaderboard(id)


## download_leaderboard_scores fetches a range of global leaderboard entries.
##
## NOTE: The fetch operation is asynchronous; if successful, the `scores_downloaded`
## will be emitted. There is currently no way to relay an error to the caller.
func download_leaderboard_scores(id: StringName, start: int, end: int) -> void:
	if not _leaderboards.get(id):
		assert(false, "invalid state; missing leaderboard handle")
		return

	if start < 0 or end < 0:
		assert(false, "invalid argument(s); must be >= 0")
		return

	(
		_logger
		. info(
			"Downloading leaderboard scores in range.",
			{&"name": id, &"start": start, &"end": end},
		)
	)

	_download_leaderboard_scores(id, start, end)


## download_leaderboard_scores_around_user fetches a range of global leaderboard
## entries centered around the local user.
##
## NOTE: The fetch operation is asynchronous; if successful, the `scores_downloaded`
## will be emitted. There is currently no way to relay an error to the caller.
func download_leaderboard_scores_around_user(
	id: StringName,
	before: int,
	after: int,
) -> void:
	if not _leaderboards.get(id):
		assert(false, "invalid state; missing leaderboard handle")
		return

	if before < 0 or after < 0:
		assert(false, "invalid argument(s); must be >= 0")
		return

	(
		_logger
		. info(
			"Downloading leaderboard scores around local user.",
			{&"name": id, &"before": before, &"after": after},
		)
	)

	_download_leaderboard_scores_around_user(id, before, after)


## download_leaderboard_scores_for_friends fetches all leaderboard entries belonging to
## the local user's friend list.
##
## NOTE: The fetch operation is asynchronous; if successful, the `scores_downloaded`
## will be emitted. There is currently no way to relay an error to the caller.
func download_leaderboard_scores_for_friends(id: StringName) -> void:
	if not _leaderboards.get(id):
		assert(false, "invalid state; missing leaderboard handle")
		return

	(
		_logger
		. info(
			"Downloading leaderboard scores for friends.",
			{&"name": id},
		)
	)

	_download_leaderboard_scores_for_friends(id)


## download_leaderboard_scores_for_users fetches all leaderboard entries belonging to
## the specified list of users.
##
## NOTE: The fetch operation is asynchronous; if successful, the `scores_downloaded`
## will be emitted. There is currently no way to relay an error to the caller.
func download_leaderboard_scores_for_users(
	id: StringName,
	users: PackedInt64Array,
) -> void:
	if not _leaderboards.get(id):
		assert(false, "invalid state; missing leaderboard handle")
		return

	if not users:
		assert(false, "invalid argument; missing users")
		return

	(
		_logger
		. info(
			"Downloading leaderboard scores for users.",
			{&"name": id, &"users": users},
		)
	)

	_download_leaderboard_scores_for_users(id, users)


## upload_leaderboard_score asynchronosuly uploads the provided score (and optional
## details) to the leaderboard. If `keep_best` is passed, then only the user's best
## score will be kept. A small amount of run-specific details can be provided via
## `details` (must not be an `Object`).
##
## NOTE: This method is *not* asynchronous; the `score_uploaded` signal will be emitted
## once the call has completed (regardless of outcome), so `await` that if needed.
func upload_leaderboard_score(
	id: StringName,
	score: int,
	details: Variant = null,
	keep_best: bool = true,
) -> void:
	if not _leaderboards.get(id):
		leaderboard_score_uploaded.emit(id, false, false, 0)
		return

	if score > _get_leaderboard_score_max_value():
		assert(false, "invalid input; score exceed maximum value")
		leaderboard_score_uploaded.emit(id, false, false, 0)
		return

	var bytes: PackedByteArray
	if details != null:
		assert(not details is Object, "invalid argument; wrong type")

		bytes = var_to_bytes(details)
		if bytes.size() > _get_leaderboard_details_max_bytes():
			assert(false, "invalid input; score exceed maximum value")
			leaderboard_score_uploaded.emit(id, false, false, 0)
			return

	(
		_logger
		. info(
			"Uploading leaderboard score.",
			{
				&"name": id,
				&"score": score,
				&"keep_best": keep_best,
				&"has_details": not bytes.is_empty(),
			},
		)
	)

	_upload_leaderboard_score(id, score, bytes, keep_best)


# Stats


## get_stat_value_int reads the current `int` value of a statistic.
func get_stat_value_int(id: StringName) -> int:
	assert(id, "invalid argument; missing id")
	return _get_stat_value_int(id)


## get_stat_value_float reads the current `float` value of a statistic.
func get_stat_value_float(id: StringName) -> float:
	assert(id, "invalid argument; missing id")
	return _get_stat_value_float(id)


## set_stat_value_float updates the current value of the `float` statistic.
func set_stat_value_float(id: StringName, value: float) -> bool:
	assert(id, "invalid argument; missing id")
	return _set_stat_value_float(id, value)


## set_stat_value_int updates the current value of the `int` statistic.
func set_stat_value_int(id: StringName, value: int) -> bool:
	assert(id, "invalid argument; missing id")
	return _set_stat_value_int(id, value)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	_debounce = null


func _ready() -> void:
	assert(_debounce == null, "invalid state: found dangling Debounce timer")

	# Configure the 'Debounce' timer used to rate-limit calls to store stats. Use a
	# "leading" execution mode so first call is immediate (allows achievements to be
	# displayed as soon as they unlock).
	_debounce = (
		Debounce
		. create(
			debounce_duration,
			debounce_duration_max,
			true,
			Debounce.EXECUTION_MODE_LEADING,
		)
	)
	add_child(_debounce, false, INTERNAL_MODE_BACK)
	Signals.connect_safe(_debounce.timeout, _on_debounce_timeout)

	_load_stats()

	for leaderboard in leaderboards:
		leaderboard.set_store(self)
		load_leaderboard(leaderboard.id)

	for achievement in achievements:
		achievement.set_store(self)

	for stat in statistics:
		stat.set_store(self)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _download_leaderboard_scores(_id: StringName, _begin: int, _end: int) -> void:
	assert(false, "unimplemented")


func _download_leaderboard_scores_around_user(
	_id: StringName,
	_before: int,
	_after: int,
) -> void:
	assert(false, "unimplemented")


func _download_leaderboard_scores_for_friends(_id: StringName) -> void:
	assert(false, "unimplemented")


func _download_leaderboard_scores_for_users(
	_id: StringName,
	_users: PackedInt64Array,
) -> void:
	assert(false, "unimplemented")


func _get_leaderboard_details_max_bytes() -> int:
	assert(false, "unimplemented")
	return 0


func _get_leaderboard_score_max_value() -> int:
	assert(false, "unimplemented")
	return 0


func _get_stat_value_float(_id: StringName) -> float:
	assert(false, "unimplemented")
	return 0


func _get_stat_value_int(_id: StringName) -> int:
	assert(false, "unimplemented")
	return 0


func _is_achievement_unlocked(_id: StringName) -> bool:
	assert(false, "unimplemented")
	return false


func _load_leaderboard(_id: StringName) -> void:
	assert(false, "unimplemented")


func _load_stats() -> void:
	pass


func _set_stat_value_float(_id: StringName, _value: float) -> bool:
	assert(false, "unimplemented")
	return false


func _set_stat_value_int(_id: StringName, _value: int) -> bool:
	assert(false, "unimplemented")
	return false


func _store_stats() -> bool:
	return false


func _unlock_achievement(_id: StringName) -> bool:
	assert(false, "unimplemented")
	return false


func _upload_leaderboard_score(
	_id: StringName,
	_score: int,
	_details: PackedByteArray,
	_keep_best: bool,
) -> void:
	assert(false, "unimplemented")


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _notify_downloaded_leaderboard_scores(
	id: StringName,
	entries: Array[StdLeaderboard.Entry] = [],
) -> void:
	(
		_logger
		. info(
			"Successfully downloaded leaderboard scores.",
			{&"name": id, &"count": entries.size()},
		)
	)

	leaderboard_scores_downloaded.emit(id, entries)


func _notify_leaderboard_loaded(
	id: StringName,
	handle: Variant = null,
) -> void:
	assert(handle, "invalid state; missing leaderboard handle")

	(
		_logger
		. info(
			"Successfully loaded leaderboard definition.",
			{&"name": id, &"handle": handle},
		)
	)

	leaderboard_loaded.emit(id)
	_leaderboards[id] = handle


func _notify_uploaded_leaderboard_score(
	id: StringName,
	success: bool,
	updated: bool,
	score: int = 0,
) -> void:
	if success:
		(
			_logger
			. info(
				"Successfully uploaded leaderboard score.",
				{&"name": id, &"updated": updated, &"score": score},
			)
		)
	else:
		_logger.error("Failed to upload leaderboard score.", {&"name": id})

	leaderboard_score_uploaded.emit(id, success, updated, score)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_achievement_unlocked(_achievement: StdAchievement) -> void:
	store_stats(true)


func _on_debounce_timeout() -> void:
	store_stats()
