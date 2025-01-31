##
## std/statistic/stat.gd
##
## StdStat is a base class for a user statistic.
##

class_name StdStat
extends Resource

# -- SIGNALS ------------------------------------------------------------------------- #

## value_changed is emitted when the value of this statistic has changed.
signal value_changed(value: Variant)

# -- CONFIGURATION ------------------------------------------------------------------- #

## id is the "API name", or unique identifier, for this statistic.
@export var id: StringName = &""

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_value reads the current value of the statistic.
func get_value():
	assert(id, "invalid state; missing id")
	return _get_value()


## set_value updates the current value of the statistic.
func set_value(value) -> bool:
	assert(id, "invalid state; missing id")

	var previous: Variant = _get_value()
	var result: bool = _set_value(value)

	var has_changed: bool = previous != value

	# NOTE: It's unclear what the return value of `_set_value` should be. Set this
	# assertion here to catch a mistaken assumption, which is that it returns whether it
	# was updated.
	assert(result == has_changed, "conflicting return value for statistic")

	if has_changed:
		value_changed.emit(value)

	return result

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value():
	assert(false, "unimplemented")


func _set_value(_value) -> bool:
	assert(false, "unimplemented")
	return false
