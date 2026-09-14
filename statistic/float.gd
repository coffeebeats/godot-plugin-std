##
## std/statistic/float.gd
##
## StdStat is a class defining a custom user `float` statistic.
##
## NOTE: This resource should be added to a `StdStatisticStore` node so that its
## implementation can automatically be loaded.
##

class_name StdStatFloat
extends StdStat

# -- PUBLIC METHODS (OVERRIDES) ------------------------------------------------------ #


## get_value reads the current value of the `float` statistic.
func get_value() -> float:
	assert(_store is StdStatisticStore, "invalid state; missing store")
	return _store.get_stat_value_float(id)


## set_value updates the current value of the `float` statistic.
func set_value(value: float) -> bool:
	assert(_store is StdStatisticStore, "invalid state; missing store")
	return _store.set_stat_value(id, value)
