##
## std/sound/mix_snapshot.gd
##
## StdMixSnapshot describes a set of audio bus effect overrides that can be applied as a
## group. Call `apply()` to activate all overrides and receive an instance handle.
##

class_name StdMixSnapshot
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## overrides is the list of bus/effect pairs to apply.
@export var overrides: Array[StdMixSnapshotOverride] = []

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## apply activates all overrides and returns an instance handle for removal. The `owner`
## node is used for creating tweens and determines their lifetime.
func apply(owner: Node) -> StdMixSnapshotInstance:
	var instances: Array[StdSoundBusEffectInstance] = []

	for override in overrides:
		assert(override is StdMixSnapshotOverride, "invalid config; wrong type")
		assert(override.bus is StdAudioBus, "invalid config; missing bus")
		assert(
			override.bus_effect is StdSoundBusEffect,
			"invalid config; missing bus_effect",
		)

		var bus_index := override.bus.get_bus_index()
		assert(bus_index > -1, "invalid state; missing audio bus")

		instances.append(override.bus_effect.apply(bus_index, owner))

	return StdMixSnapshotInstance.new(instances)
