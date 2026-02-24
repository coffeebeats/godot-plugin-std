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

const _FADE_OVERLAY_KEY := &"_addons_std_fade_overlay"

# -- CONFIGURATION ------------------------------------------------------------------- #

## color is the color to fade to/from (typically black).
@export var color: Color = Color.BLACK

## curve configures the timing and easing for the fade tween.
@export var curve: StdTweenCurve = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _context: StdScreenTransitionContext = null
var _overlay: ColorRect = null
var _tween: Tween = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	reset_on_interrupt = false


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _enter(context: StdScreenTransitionContext) -> void:
	assert(curve is StdTweenCurve, "invalid config; missing curve")

	_context = context
	_overlay = _get_or_create_overlay(context)
	_overlay.color = color

	if context.current_scene:
		# Phase 1: fade to black over current scene.
		_fade_to(1.0, _on_enter_covered)
	else:
		# Initial push — start fully opaque, skip fade-out.
		_overlay.modulate.a = 1.0
		_on_enter_covered()


func _exit(context: StdScreenTransitionContext) -> void:
	assert(curve is StdTweenCurve, "invalid config; missing curve")

	_context = context
	_overlay = _get_or_create_overlay(context)
	_overlay.color = color

	# Phase 1: fade to black over popped scene.
	_fade_to(1.0, _on_exit_covered)


func _stop() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = null


func _reset() -> void:
	_stop()

	if _context:
		var retained := _context.pop_retained_node(_FADE_OVERLAY_KEY)
		if retained and is_instance_valid(retained):
			retained.queue_free()

	_overlay = null
	_context = null


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _fade_to tweens the overlay's alpha to the target value and calls the callback on
## completion. Uses proportional duration based on remaining distance.
func _fade_to(target: float, on_complete: Callable) -> void:
	var adjusted := curve.duration * absf(_overlay.modulate.a - target)

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = _context.create_tween()
	curve.tween_property(_tween, _overlay, ^"modulate:a", target, adjusted)
	_tween.tween_callback(on_complete)


## _get_or_create_overlay returns the shared fade overlay for the transition context, or
## creates one if it doesn't exist yet.
func _get_or_create_overlay(context: StdScreenTransitionContext) -> ColorRect:
	if context.has_retained_node(_FADE_OVERLAY_KEY):
		var existing: ColorRect = context.get_retained_node(_FADE_OVERLAY_KEY)
		if is_instance_valid(existing):
			if not existing.is_inside_tree():
				context.push_node(existing)

			return existing

		# Stale entry — pop and free it.
		var stale := context.pop_retained_node(_FADE_OVERLAY_KEY)
		if stale and is_instance_valid(stale):
			stale.queue_free()

	var overlay := ColorRect.new()
	overlay.name = &"FadeOverlay"
	overlay.color = Color.BLACK
	overlay.modulate.a = 0.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	context.push_node(overlay)
	context.retain_node(_FADE_OVERLAY_KEY, overlay)

	return overlay


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


## _on_enter_covered is called when the fade-to-black phase completes during enter.
func _on_enter_covered() -> void:
	if not _context:
		return

	_context.swap()

	# Phase 2: fade from black to reveal new scene.
	_fade_to(0.0, _on_enter_revealed)


## _on_enter_revealed is called when the fade-from-black phase completes during enter.
func _on_enter_revealed() -> void:
	if not _context:
		return

	_context.pop_node(_overlay)
	_context.done()
	_context = null


## _on_exit_covered is called when the fade-to-black phase completes during exit.
func _on_exit_covered() -> void:
	if not _context:
		return

	_context.unmount()

	if _context.is_replace:
		# Two-phase replace: skip the reveal and leave the overlay opaque. The
		# entering screen's enter transition will handle fading it out. Connect a
		# one-shot to clean up the overlay after the enter phase completes.
		var overlay := _overlay
		var manager := _context._manager
		manager.screen_entered.connect(
			func(_s: StdScreen, _sc: Node) -> void:
				if is_instance_valid(overlay) and overlay.is_inside_tree():
					overlay.get_parent().remove_child(overlay),
			CONNECT_ONE_SHOT,
		)

		_context.done()
		_context = null
		return

	# Phase 2: fade from black to reveal uncovered scene.
	_fade_to(0.0, _on_exit_revealed)


## _on_exit_revealed is called when the fade-from-black phase completes during exit.
func _on_exit_revealed() -> void:
	if not _context:
		return

	_context.pop_node(_overlay)
	_context.done()
	_context = null
