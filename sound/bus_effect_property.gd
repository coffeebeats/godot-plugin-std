##
## std/sound/bus_effect_property.gd
##
## StdSoundBusEffectProperty describes a single animatable property on an audio effect,
## including its on/off values and optional in/out transition curves.
##

class_name StdSoundBusEffectProperty
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## property is the effect property to blend (e.g. &"cutoff_hz").
@export var property: StringName = &""

## value_on is the target property value when the effect is fully active.
@export var value_on: float = 0.0

## value_off is the property value when the effect is inactive.
@export var value_off: float = 0.0

@export_group("Transitions")

## transition_in is an optional tween curve for blending in.
@export var transition_in: StdTweenCurve = null

## transition_out is an optional tween curve for blending out.
@export var transition_out: StdTweenCurve = null
