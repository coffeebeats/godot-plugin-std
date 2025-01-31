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
func unlock():
	assert(id, "invalid state; missing id")

	var was_unlocked := is_unlocked()

	_unlock()

	if not was_unlocked:
		unlocked.emit()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _is_unlocked() -> bool:
	assert(false, "unimplemented")
	return false


func _unlock() -> void:
	assert(false, "unimplemented")
