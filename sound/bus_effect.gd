##
## std/sound/bus_effect.gd
##
## StdSoundBusEffect describes an audio effect that can be applied to an audio bus with
## optional animated properties. Call `apply()` to add the effect and receive an
## instance handle for later removal.
##

class_name StdSoundBusEffect
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## effect is the audio effect to apply. It will be duplicated on each `apply()` call.
@export var effect: AudioEffect = null

## properties is a list of animatable properties on the effect, each with its own on/off
## values and optional transition curves.
@export var properties: Array[StdSoundBusEffectProperty] = []

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## apply duplicates the effect, adds it to the given bus, tweens any properties with a
## `transition_in` curve, and returns an instance handle. The `owner` node is used for
## creating tweens and determines their lifetime.
func apply(bus_index: int, owner: Node) -> StdSoundBusEffectInstance:
	assert(effect is AudioEffect, "invalid config; missing effect")
	assert(bus_index > -1, "invalid argument; bad bus index")
	assert(is_instance_valid(owner), "invalid argument; missing owner")

	var duplicated := effect.duplicate()

	for prop in properties:
		if prop.property != &"":
			duplicated.set(prop.property, prop.value_off)

	AudioServer.add_bus_effect(bus_index, duplicated)

	var instance := (
		StdSoundBusEffectInstance
		. new(
			owner,
			self,
			duplicated,
			bus_index,
		)
	)

	var tween: Tween = null
	for p in properties:
		if not p.transition_in or p.property == &"":
			continue
		if not tween:
			tween = owner.create_tween().set_parallel(true)
		var path := NodePath(String(p.property))
		p.transition_in.tween_property(tween, duplicated, path, p.value_on)

	instance._tween = tween

	return instance
