##
## std/statistic/int.gd
##
## StdStat is a class defining a custom user `int` statistic.
##
## NOTE: This resource should be added to a `StdStatisticStore` node so that its
## implementation can automatically be loaded.
##

class_name StdStatInt
extends StdStat

# -- PUBLIC METHODS (OVERRIDES) ------------------------------------------------------ #


## get_value reads the current value of the `int` statistic.
func get_value() -> int:
	assert(_store is StdStatisticStore, "invalid state; missing store")
	return _store.get_stat_value_int(id)


## set_value updates the current value of the `int` statistic.
func set_value(value: int) -> bool:
	assert(_store is StdStatisticStore, "invalid state; missing store")
	return _store.set_stat_value(id, value)
