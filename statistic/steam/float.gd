##
## std/statistic/steam/float.gd
##
## StdStatFloatSteam is a `float` user statistic backed by Steam.
##

class_name StdStatFloatSteam
extends StdStatFloat

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value() -> float:
	return Steam.getStatFloat(id)


func _set_value(value: float) -> bool:
	return Steam.setStatFloat(id, value)
