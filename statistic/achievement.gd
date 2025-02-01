##
## std/statistic/achievement.gd
##
## StdAchievement is a base class for an achievement statistic.
##
## NOTE: The API defined here is intentionally minimal, as it's possible/likely a game
## won't display the achievements within the game itself.
##

class_name StdAchievement
extends StdStatistic

# -- SIGNALS ------------------------------------------------------------------------- #

## unlocked is emitted when this achievement is first unlocked.
signal unlocked

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## is_unlocked returns whether the achievement has already been unlocked by the user.
func is_unlocked() -> bool:
	assert(_store is StdStatisticStore, "invalid state; missing store")
	return _store.is_achievement_unlocked(id)


## unlock "sets" the achievement, unlocking it for the user. Safe to call repeatedly.
func unlock() -> bool:
	assert(_store is StdStatisticStore, "invalid state; missing store")
	Signals.ensure_connected(_store.achievement_unlocked, _on_achievement_unlocked)

	return _store.unlock_achievement(id)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_achievement_unlocked(achievement: StringName) -> void:
	if achievement != id:
		return

	unlocked.emit()

	# NOTE: This signal is no longer needed - the achievement won't be unlocked twice.
	Signals.disconnect_safe(_store.achievement_unlocked, _on_achievement_unlocked)
