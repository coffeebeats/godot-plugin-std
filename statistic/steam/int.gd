##
## std/statistic/steam/int.gd
##
## StdStatValueIntSteam is an `int` user statistic backed by Steam.
##

class_name StdStatValueIntSteam
extends StdStatValueInt

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value() -> int:
	return Steam.getStatInt(id)


func _set_value(value: int) -> void:
	if not Steam.setStatInt(id, value):
		assert(false, "unexpected result; failed to update value")
