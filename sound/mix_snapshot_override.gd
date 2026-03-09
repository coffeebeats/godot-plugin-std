##
## std/sound/mix_snapshot_override.gd
##
## StdMixSnapshotOverride pairs an audio bus with a bus effect to apply as part of a mix
## snapshot.
##

class_name StdMixSnapshotOverride
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## bus is the target audio bus for the effect.
@export var bus: StdAudioBus = null

## bus_effect is the effect description to apply to the bus.
@export var bus_effect: StdSoundBusEffect = null
