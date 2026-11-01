##
## std/transition/fade.gd
##
## StdTransitionFade fades the entering and exiting nodes through `modulate`, so one
## resource can fade a panel and a screen. A node that isn't a `CanvasItem` changes
## instantly; a screen rooted in 3D uses `StdScreenTransitionCurtain` instead.
##
## NOTE: A dialog that shouldn't take input the moment it shows holds before `done()` in
## its own transition, which is where a delay against a key in flight belongs.
##

class_name StdTransitionFade
extends StdTransition

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Curve")

## curve configures the timing and easing for the fade tween.
@export var curve: StdTweenCurve = null

@export_subgroup("Overrides")

## curve_enter overrides `curve` for the fade-in.
@export var curve_enter: StdTweenCurve = null

## curve_exit overrides `curve` for the fade-out.
@export var curve_exit: StdTweenCurve = null

# -- INITIALIZATION ------------------------------------------------------------------ #

## _alpha is the alpha that `_node` had before this transition touched it.
var _alpha: float = 1.0

## _node is the node currently fading, or null if there isn't one.
var _node: CanvasItem = null

var _tween: Tween = null

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _enter(_ctx: StdTransitionContext) -> void:
	_fade_in()


func _exit(ctx: StdTransitionContext) -> void:
	_fade_out(ctx.done)


func _stop() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = null

	_restore_alpha()


func _swap(_ctx: StdTransitionContext) -> void:
	_fade_out(_fade_in)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _fade_in mounts the entering node and fades it up to the alpha it was authored with.
func _fade_in() -> void:
	_context.mount()

	var node := _context.entering as CanvasItem
	if not node:
		_context.done()
		return

	_node = node
	_alpha = node.modulate.a
	node.modulate.a = 0.0

	_tween_alpha(curve_enter if curve_enter else curve, _alpha, _on_faded_in)


## _fade_out fades the exiting node, unmounts it and then calls `on_unmounted`.
func _fade_out(on_unmounted: Callable) -> void:
	var node := _context.exiting as CanvasItem
	if not node:
		_context.unmount()
		on_unmounted.call()
		return

	_node = node
	_alpha = node.modulate.a

	_tween_alpha(
		curve_exit if curve_exit else curve,
		0.0,
		_on_faded_out.bind(on_unmounted),
	)


## _restore_alpha returns the fading node to its authored alpha, so that a node shown
## again later, by another transition or none, isn't left transparent.
func _restore_alpha() -> void:
	if is_instance_valid(_node):
		_node.modulate.a = _alpha

	_node = null


## _tween_alpha fades `_node` to `target` along `curve_fade`, then calls `on_done`.
func _tween_alpha(curve_fade: StdTweenCurve, target: float, on_done: Callable) -> void:
	assert(curve_fade is StdTweenCurve, "invalid config; missing curve")

	_tween = _context.create_tween()
	curve_fade.tween_property(_tween, _node, ^"modulate:a", target)
	_tween.tween_callback(on_done)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


## _on_faded_in is called when the fade-in completes.
func _on_faded_in() -> void:
	_node = null
	_context.done()


## _on_faded_out is called when the fade-out completes.
func _on_faded_out(on_unmounted: Callable) -> void:
	_context.unmount()
	_restore_alpha()
	on_unmounted.call()
