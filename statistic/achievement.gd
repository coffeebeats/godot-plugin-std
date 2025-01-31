##
## std/statistic/achievement.gd
##
## StdAchievement is a base class for an achievement statistic.
##
## NOTE: The API defined here is intentionally minimal, as it's possible/likely a game
## won't display the achievements within the game itself.
##

class_name StdAchievement
extends Resource

# -- SIGNALS ------------------------------------------------------------------------- #

## unlocked is emitted when this achievement is first unlocked.
signal unlocked

# -- CONFIGURATION ------------------------------------------------------------------- #

## id is the "API name", or unique identifier, for this achievement.
@export var id: StringName = &""

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## is_unlocked returns whether the achievement is currently unlocked by the user.
func is_unlocked() -> bool:
	assert(id, "invalid state; missing id")
	return _is_unlocked()


## unlock "sets" the achievement, unlocking it for the user. Safe to call repeatedly.
func unlock() -> bool:
	assert(id, "invalid state; missing id")

	var was_unlocked := is_unlocked()
	var result := _unlock()

	# NOTE: It's unclear what the return value of `_unlock` should be. Set this
	# assertion here to catch a mistaken assumption, which is that it returns whether it
	# was newly unlocked.
	assert(result != was_unlocked, "conflicting return value for achievement")

	if not was_unlocked:
		unlocked.emit()

	return result


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _is_unlocked() -> bool:
	assert(false, "unimplemented")
	return false


func _unlock() -> bool:
	assert(false, "unimplemented")
	return false
