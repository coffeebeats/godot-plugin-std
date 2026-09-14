##
## screen/transitions/fade.gd
##
## StdScreenTransitionFade is a fade-to-color transition that uses a ColorRect overlay
## to fade the screen in or out. Each duplicated transition instance manages its own
## overlay.
##

class_name StdScreenTransitionFade
extends StdScreenTransition

# -- CONFIGURATION ------------------------------------------------------------------- #

## color is the color to fade to/from (typically black).
@export var color: Color = Color.BLACK

@export_group("Curve")

## curve configures the timing and easing for the fade tween.
@export var curve: StdTweenCurve = null

@export_subgroup("Overrides")

## curve_cover overrides `curve` for the fade-to-opaque phase.
@export var curve_cover: StdTweenCurve = null

## curve_reveal overrides `curve` for the fade-to-transparent phase.
@export var curve_reveal: StdTweenCurve = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _change_fn: Callable = Callable()
var _context: StdScreenTransitionContext = null
var _overlay: ColorRect = null
var _tween: Tween = null

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _push(ctx: StdScreenTransitionContext) -> void:
	_start_curtain(ctx, ctx.mount)


func _pop(ctx: StdScreenTransitionContext) -> void:
	_start_curtain(ctx, ctx.unmount)


func _replace(ctx: StdScreenTransitionContext) -> void:
	_start_curtain(ctx, ctx.swap)


func _stop() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = null

	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()

	_overlay = null
	_context = null
	_change_fn = Callable()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _start_curtain begins the fade-to-opaque, change, then fade-to-transparent sequence.
func _start_curtain(ctx: StdScreenTransitionContext, change_fn: Callable) -> void:
	_context = ctx
	_change_fn = change_fn
	_overlay = _create_overlay(ctx)
	_overlay.color = color

	if ctx.current_scene:
		# Fade to opaque over the current scene, then callback.
		var c := curve_cover if curve_cover else curve
		assert(c is StdTweenCurve, "invalid config; missing curve")
		_fade_to(c, 1.0, _on_covered)
	else:
		# Initial push: start fully opaque, skip fade-out.
		_overlay.modulate.a = 1.0
		_on_covered()


## _fade_to tweens the overlay alpha to the target value and calls the callback on
## completion. Uses proportional duration based on remaining distance.
func _fade_to(curve_fade: StdTweenCurve, target: float, on_complete: Callable) -> void:
	assert(curve_fade is StdTweenCurve, "invalid argument; missing curve")

	var duration := curve_fade.duration * absf(_overlay.modulate.a - target)

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = _context.create_tween()
	(
		curve_fade
		. tween_property(
			_tween,
			_overlay,
			^"modulate:a",
			target,
			duration,
		)
	)
	_tween.tween_callback(on_complete)


## _create_overlay creates a new full-rect ColorRect for the fade.
func _create_overlay(ctx: StdScreenTransitionContext) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = &"FadeOverlay"
	overlay.color = Color.BLACK
	overlay.modulate.a = 0.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	ctx.manager.add_child(overlay, false, Node.INTERNAL_MODE_BACK)

	return overlay


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


## _on_covered is called when the fade-to-opaque phase completes.
func _on_covered() -> void:
	if not _context:
		return

	# Perform the scene change behind the opaque overlay.
	_change_fn.call()

	# Fade from opaque to transparent to reveal the new scene.
	var c := curve_reveal if curve_reveal else curve
	assert(c is StdTweenCurve, "invalid config; missing curve")
	_fade_to(c, 0.0, _on_revealed)


## _on_revealed is called when the fade-to-transparent phase completes.
func _on_revealed() -> void:
	if not _context:
		return

	if _overlay.is_inside_tree():
		_overlay.get_parent().remove_child(_overlay)
	_overlay.queue_free()
	_overlay = null

	var ctx := _context
	_context = null
	_change_fn = Callable()

	ctx.done()
