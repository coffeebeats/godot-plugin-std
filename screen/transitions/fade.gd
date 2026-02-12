##
## screen/transitions/fade.gd
##
## StdScreenTransitionFade is a fade-to-color transition that uses a shared `ColorRect`
## overlay to fade the screen in or out. The overlay is stored as metadata on the
## manager node (via the transition context) so multiple fade transitions in the same
## stack share a single overlay instance.
##

class_name StdScreenTransitionFade
extends StdScreenTransition

# -- DEFINITIONS --------------------------------------------------------------------- #

const _FADE_OVERLAY_KEY := &"_std_fade_overlay"

# -- CONFIGURATION ------------------------------------------------------------------- #

## color is the color to fade to/from (typically black).
@export var color: Color = Color.BLACK

## duration is the base time in seconds for a full fade.
@export_range(0.0, 4.0) var duration: float = 0.6

## ease_type controls the easing applied to the fade tween.
@export var ease_type: Tween.EaseType = Tween.EASE_IN

## transition_type controls the transition curve for the fade tween.
@export var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC

# -- INITIALIZATION ------------------------------------------------------------------ #

var _context: StdScreenTransitionContext = null
var _is_entering: bool = false
var _overlay: ColorRect = null
var _tween: Tween = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	reset_on_interrupt = false


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _start(
	context: StdScreenTransitionContext,
	_scene: Node,
	is_entering: bool,
) -> void:
	_context = context
	_is_entering = is_entering
	_overlay = _get_or_create_overlay(context)
	_overlay.color = color

	context.block_input()

	var target: float = 0.0 if is_entering else 1.0
	var adjusted := duration * absf(_overlay.modulate.a - target)

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = context.create_tween()

	(
		_tween
		. tween_property(_overlay, ^"modulate:a", target, adjusted)
		. set_ease(ease_type)
		. set_trans(transition_type)
	)

	_tween.tween_callback(_on_tween_completed)


func _stop() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = null


func _reset() -> void:
	_stop()

	if _context:
		_context.allow_input()

	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()

		if _context:
			_context.remove_manager_meta(_FADE_OVERLAY_KEY)

	_overlay = null
	_context = null


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _get_or_create_overlay returns the shared fade overlay for the transition context, or
## creates one if it doesn't exist yet.
func _get_or_create_overlay(context: StdScreenTransitionContext) -> ColorRect:
	if context.has_manager_meta(_FADE_OVERLAY_KEY):
		var existing: ColorRect = context.get_manager_meta(_FADE_OVERLAY_KEY)
		if is_instance_valid(existing):
			if not existing.is_inside_tree():
				context.push_node(existing)

			return existing

	var overlay := ColorRect.new()
	overlay.name = &"FadeOverlay"
	overlay.color = Color.BLACK
	overlay.modulate.a = 0.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	context.push_node(overlay)
	context.set_manager_meta(_FADE_OVERLAY_KEY, overlay)

	return overlay


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


## _on_tween_completed is called when the fade tween finishes.
func _on_tween_completed() -> void:
	if not _context:
		return

	_context.allow_input()

	if _is_entering and _overlay and is_instance_valid(_overlay):
		_context.pop_node(_overlay)

	_context.done()
	_context = null
