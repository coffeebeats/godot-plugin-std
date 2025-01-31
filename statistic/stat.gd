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
func set_value(value):
	assert(id, "invalid state; missing id")
	if value != _get_value():
		_set_value(value)
		value_changed.emit(value)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value():
	assert(false, "unimplemented")


func _set_value(_value) -> void:
	assert(false, "unimplemented")
