##
## std/statistic/store.gd
##
## StdStatStore is a node which facilitate persisting statistic and achievement changes
## to the storefront's statistics server. Calls to store stats will be rate-limited via
## the configurable debounce properties.
##
## This node is a base class; storefronts should create their own subclass and implement
## the `_load_stats`/`_store_stats` methods to define how to persist statistics values.
##

@tool
class_name StdStatStore
extends Debouncer

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Debouncer := preload("../timer/debouncer.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## achievements is the set of user achievements defined for the game. Upon one of these
## unlocking, the statistics data will be stored (debounced via the properties below).
@export var achievements: Array[StdAchievement] = []

## leaderboards is the set of leaderboards defined for the game. Definitions for these
## will be fetched upon this store entering the scene.
@export var leaderboards: Array[StdLeaderboard] = []

## statistics is the set of user statistics defined for the game.
@export var statistics: Array[StdStat] = []

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## store_stats persists any pending statistic updates. If `force` is passed, this will
## bypass the debounce timer and directly update stats.
func store_stats(force: bool = false) -> void:
	if force:
		_store_stats()
		_cancel()
		return

	_start()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	super._ready()

	if Engine.is_editor_hint():
		return

	_load_stats()

	for achievement in achievements:
		if not achievement.is_unlocked():
			(
				Signals
				.connect_safe(
					achievement.unlocked,
					_on_achievement_unlocked.bind(achievement),
					CONNECT_ONE_SHOT,
				)
			)

	for leaderboard in leaderboards:
		leaderboard.load_definition()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _load_stats() -> void:
	pass


func _store_stats() -> bool:
	return false


func _timeout() -> void:
	store_stats()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_achievement_unlocked(_achievement: StdAchievement) -> void:
	store_stats(true)
