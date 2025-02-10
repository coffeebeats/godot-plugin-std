##
## std/sound/bus.gd
##
## StdAudioBusStatic describes a predefined audio bus.
##

class_name StdAudioBusStatic
extends StdAudioBus

# -- CONFIGURATION ------------------------------------------------------------------- #

## name is the name of the audio bus. It must already exist.
@export var name: StringName = &""

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_bus_name() -> StringName:
	return name
