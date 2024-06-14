##
## std/scene/state/fade.gd
##
## Fade is a transition state which fades the root viewport to black using the specified
## tweener properties. While the fade is in effect, the transition target's scene will
## be instantiated and added to the scene.
##

extends "transition.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Playable := preload("playable.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Fade In ")
@export var fade_in: bool = true
@export_range(0.0, 4.0) var fade_in_duration: float = 1.2
@export var fade_in_ease: Tween.EaseType = Tween.EASE_OUT
@export var fade_in_transition: Tween.TransitionType = Tween.TRANS_CUBIC

@export_group("Fade Out ")
@export var fade_out: bool = true
@export_range(0.0, 4.0) var fade_out_duration: float = 0.8
@export var fade_out_ease: Tween.EaseType = Tween.EASE_IN
@export var fade_out_transition: Tween.TransitionType = Tween.TRANS_CUBIC

# -- INITIALIZATION ------------------------------------------------------------------ #

var _color_rect: ColorRect = ColorRect.new()
var _tween_in: Tween = null
var _tween_out: Tween = null

var _is_node_added_to_scene: bool = false

# -- PRIVATE METHODS (OVERRIDES)------------------------------------------------------ #


## A virtual method called when this state is entered (after exiting previous state).
func _on_enter(previous: State) -> void:
	super(previous)

	assert(not _tween_in and not _tween_out, "found leftover tween")
	assert(not _color_rect.is_inside_tree(), "node should not be in tree")

	_is_node_added_to_scene = false

	_color_rect.color = Color.BLACK
	_color_rect.modulate.a = 0.0
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	assert(fade_in or fade_out, "expected fade to be used")

	if fade_in:
		_tween_in = (self as Object as Node).create_tween()
		_tween_in.pause()

		(
			_tween_in
			. tween_property(_color_rect, ":modulate:a", 1.0, fade_in_duration)
			. set_trans(fade_in_transition)
			. set_ease(fade_in_ease)
		)
	else:
		_color_rect.modulate.a = 1.0

	if fade_out:
		_tween_out = (self as Object as Node).create_tween()
		_tween_out.pause()

		(
			_tween_out
			. tween_property(_color_rect, ":modulate:a", 0.0, fade_out_duration)
			. set_trans(fade_out_transition)
			. set_ease(fade_out_ease)
		)

	# gdlint:ignore=private-method-call
	_root._add_node_to_scene(_root.game_root, _color_rect, Mode.SCENE_MODE_AFTER)


## A virtual method called when leaving this state (prior to entering next state).
func _on_exit(next: State) -> void:
	super(next)

	_tween_in = null
	_tween_out = null


## A virtual method called to process a frame/tick, given the frame time 'delta'.
func _on_update(delta: float) -> State:
	super(delta)

	var target := _get_target()
	assert(target, "missing transition target state")

	if fade_in and _tween_in.custom_step(delta):  # Still has remaining time on the tween.
		return _parent

	if not _is_node_added_to_scene:
		assert(_to_load_result.get_error() == OK, "failed to load resource")
		if _to_load_result.status != ResourceLoader.THREAD_LOAD_LOADED:
			return _parent

		assert(_to_load_result.scene is PackedScene, "missing packed scene")
		var node := _to_load_result.scene.instantiate()

		# TODO: Determine if the default fallback needs to be centrally handled.
		var path: NodePath = _root.game_root
		if (target as Object) is Instantiable and not target.path.is_empty():
			path = target.path

		_root._add_node_to_scene(path, node, Mode.SCENE_MODE_REPLACE)  # gdlint:ignore=private-method-call
		_is_node_added_to_scene = true

		if target as Object as State is Playable:
			target.set_node(node)

	if fade_out and _tween_out.custom_step(delta):  # Still has remaining time on the tween.
		return _parent

	assert(_color_rect.is_inside_tree(), "expected '_color_rect' to be in scene")

	var parent := _color_rect.get_parent()
	assert(parent, "missing '_color_rect' parent node")

	parent.remove_child(_color_rect)

	return _transition_to(
		str(target.get_path()).trim_prefix(str(_root.get_path()) + "/")
	)
