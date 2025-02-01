##
## std/statistic/stat.gd
##
## StdStat is a class defining a custom user statistic. This allows the game to
## persistently track a specific value across playsessions, regardless of the storefront
## the build targets.
##
## NOTE: This resource should be added to a `StdStatisticStore` node so that its
## implementation can automatically be loaded.
##

class_name StdStat
extends StdStatistic

# -- PUBLIC METHODS (OVERRIDES) ------------------------------------------------------ #


## get_value reads the current value of the statistic.
func get_value():
	assert(false, "unimplemented")


## set_value updates the current value of the statistic.
func set_value(_value) -> bool:
	assert(false, "unimplemented")
	return false
