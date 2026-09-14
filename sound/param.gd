##
## std/sound/param.gd
##
## StdSoundParam is a base class for a type which can modulate a sound instance as its
## playing. Subclasses can override the `_apply_to_event_instance` method to customize
## any aspect of the instance.
##
## NOTE: The `changed` signal must be emitted any time the parameter has meaningfully
## changed. Ensure changed script properties have custom setters which manage this.
##

class_name StdSoundParam
extends Resource

# -- PUBLIC METHODS ------------------------------------------------------------------ #


func apply_to_event_instance(instance: StdSoundInstance) -> void:
	_apply_to_event_instance(instance)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _apply_to_event_instance(_instance: StdSoundInstance) -> void:
	pass
