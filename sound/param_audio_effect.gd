##
## std/sound/param_audio_effect.gd
##
## StdSoundParamAudioEffect is an implementation of a sound parameter which
## conditionally adds an audio effect to the audio bus through which the associated
## sound event is playing.
##
## TODO: The instant on/off of this implementation is jarring. Consider tweening the
## audio effect application (though that requires either a more specific implementation
## or some thought as to how to make it generalizable).
##

class_name StdSoundParamAudioEffect
extends StdSoundParam

# -- CONFIGURATION ------------------------------------------------------------------- #

## enabled defines whether the specified audio effect should be set on the audio bus.
@export var enabled: bool = false:
	set(value):
		var is_change := enabled != value
		enabled = value
		if is_change:
			emit_changed()

## effect defines the audio effect to set on the audio bus.
@export var effect: AudioEffect = null:
	set(value):
		var is_change := effect != value
		effect = value
		if is_change:
			emit_changed()

# -- INITIALIZATION ------------------------------------------------------------------ #

var _effect: AudioEffectInstance = null
var _index: int = -1

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _apply_to_event_instance(instance: StdSoundInstance) -> void:
	var bus_index := instance.bus.get_bus_index()
	assert(bus_index > -1, "invalid state; missing audio bus")

	match enabled:
		true:
			if _effect:
				return

			_index = AudioServer.get_bus_effect_count(bus_index)

			AudioServer.add_bus_effect(bus_index, effect, _index)
			_effect = AudioServer.get_bus_effect_instance(bus_index, _index)
			assert(_effect is AudioEffectInstance, "invalid state; missing instance")

		false:
			if not _effect:
				return

			assert(_index > -1, "invalid state; missing effect")
			AudioServer.remove_bus_effect(bus_index, _index)

			_effect = null
			_index = -1
