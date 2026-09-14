##
## std/statistic/statistic.gd
##
## StdStatistic is a base class for a user statistic.
##

class_name StdStatistic
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## id is the "API name" (i.e. unique identifier) for this statistic.
@export var id: StringName = &""

# -- INITIALIZATION ------------------------------------------------------------------ #

var _store: StdStatisticStore = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## set_store updates the underlying statistics store which is used to implement the
## supported operations for this type.
func set_store(store: StdStatisticStore) -> void:
	assert(store is StdStatisticStore, "invalid argument; missing store")
	assert(not _store, "invalid state; already have a store implementation")
