##
## std/sound/mix_snapshot_instance.gd
##
## StdMixSnapshotInstance is a handle to an active set of bus effect overrides. Use it
## to modulate intensity, remove with transition, or reset immediately.
##

class_name StdMixSnapshotInstance
extends RefCounted

# -- INITIALIZATION ------------------------------------------------------------------ #

var _instances: Array[StdSoundBusEffectInstance] = []

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## is_valid returns true if any effect instance is still active.
func is_valid() -> bool:
	for instance in _instances:
		if instance.is_valid():
			return true

	return false


## remove transitions all effects back to their off values, then removes them.
func remove() -> void:
	for instance in _instances:
		instance.remove()


## reset immediately removes all effects with no transition.
func reset() -> void:
	for instance in _instances:
		instance.reset()


## set_intensity blends all effect instances (0.0 = off, 1.0 = active).
func set_intensity(t: float) -> void:
	for instance in _instances:
		if instance.is_valid():
			instance.set_blend(t)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init(instances: Array[StdSoundBusEffectInstance]) -> void:
	_instances = instances
