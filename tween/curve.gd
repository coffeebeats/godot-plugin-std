##
## std/tween/curve.gd
##
## StdTweenCurve is a reusable timing/easing resource for configuring tween animations.
## It captures delay, duration, ease type, and transition type, and creates a fully
## configured `PropertyTweener` via `tween_property()`.
##

class_name StdTweenCurve
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## delay is the duration of time prior to starting the animation.
@export var delay: float = 0.0

## duration is the duration (in seconds) over which the animation plays.
@export var duration: float = 0.0

## ease_type is the ease type for the animation.
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

## transition_type is the transition type for the animation.
@export var transition_type: Tween.TransitionType = Tween.TRANS_EXPO

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## tween_property creates a `PropertyTweener` on the given tween and configures it with
## this curve's settings. If `duration_override` is non-negative, it replaces the
## curve's duration (useful for proportional animations).
func tween_property(
	tween: Tween,
	target: Object,
	property: NodePath,
	value: Variant,
	duration_override: float = -1.0,
) -> PropertyTweener:
	var d := duration if duration_override < 0.0 else duration_override
	return (
		tween
		. tween_property(target, property, value, d)
		. set_delay(delay)
		. set_ease(ease_type)
		. set_trans(transition_type)
	)
