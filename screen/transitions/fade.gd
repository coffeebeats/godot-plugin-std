##
## screen/transitions/fade.gd
##
## StdScreenTransitionFade is a fade-to-color transition that uses a shared `ColorRect`
## overlay to fade the screen in or out. The overlay is stored as metadata on the
## manager node so multiple fade transitions in the same stack share a single overlay
## instance.
##

class_name StdScreenTransitionFade
extends StdScreenTransition

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../../event/signal.gd")

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

static var _logger := StdLogger.create(&"std/screen/transition-fade")  # gdlint:ignore=class-definitions-order,max-line-length

var _overlay: ColorRect = null
var _tween: Tween = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	reset_on_interrupt = false


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _start(manager: Node, scene: Node, is_entering: bool) -> void:
	_overlay = _get_or_create_overlay(manager)
	_overlay.color = color

	var target: float = 0.0 if is_entering else 1.0
	var adjusted := duration * absf(_overlay.modulate.a - target)

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = scene.get_tree().create_tween()

	(
		_tween
		. tween_property(_overlay, ^"modulate:a", target, adjusted)
		. set_ease(ease_type)
		. set_trans(transition_type)
	)

	_tween.tween_callback(_done)


func _stop() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = null


func _reset() -> void:
	_stop()

	if _overlay and is_instance_valid(_overlay):
		_overlay.modulate.a = 0.0

	_overlay = null


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _get_or_create_overlay returns the shared fade overlay for the given manager node.
## Creates one if it doesn't exist yet.
func _get_or_create_overlay(manager: Node) -> ColorRect:
	if manager.has_meta(_FADE_OVERLAY_KEY):
		var existing: ColorRect = manager.get_meta(_FADE_OVERLAY_KEY)
		if manager.get_child(-1) == existing:
			return existing

		_logger.warn("Overlay not last child of manager; recreating.")
		assert(false, "invalid state; overlay not last child of manager")

		if is_instance_valid(existing) and existing.is_inside_tree():
			existing.queue_free()

	var overlay := ColorRect.new()
	overlay.name = &"FadeOverlay"
	overlay.color = Color.BLACK
	overlay.modulate.a = 0.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	manager.add_child(overlay, Engine.is_editor_hint())
	manager.set_meta(_FADE_OVERLAY_KEY, overlay)

	# NOTE: Capture logger locally to avoid implicit self-capture in the lambda, which
	## would prevent this Resource from being freed.
	var logger := _logger
	var reorder_overlay := func():
		if not is_instance_valid(manager):
			logger.warn("Found invalid manager node during overlay reorder.")
			assert(false, "invalid state; manager node invalid")
			return
		if not is_instance_valid(overlay):
			logger.warn("Found invalid overlay node during overlay reorder.")
			assert(false, "invalid state; overlay node invalid")
			return
		if overlay.get_parent() != manager:
			logger.warn("Found incorrect overlay parent during overlay reorder.")
			assert(false, "invalid state; manager not overlay parent")
			return
		if manager.get_child(-1) != overlay:
			manager.move_child(overlay, -1)

	Signals.connect_safe(manager.child_order_changed, reorder_overlay)

	# NOTE: Disconnect the reorder callback before the manager exits the tree to
	# prevent spurious errors when children are freed during teardown.
	Signals.connect_safe(
		manager.tree_exiting,
		func(): Signals.disconnect_safe(manager.child_order_changed, reorder_overlay),
	)

	return overlay
