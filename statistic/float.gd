##
## std/statistic/float.gd
##
## StdStatFloat is a float user statistic.
##

class_name StdStatFloat
extends StdStat

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value() -> float:
	assert(false, "unimplemented")
	return 0.0


func _set_value(_value: float) -> bool:
	assert(false, "unimplemented")
	return false
