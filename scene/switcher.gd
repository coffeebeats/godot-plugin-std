##
## std/scene/switcher.gd
##
## Switcher ...
##

extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

signal transition_started(prev: NodePath, next: String)
signal transition_stopped(prev: NodePath, next: String)

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- DEFINITIONS --------------------------------------------------------------------- #


## Transition is an interface for implementing a scene transition.
class Transition:
	extends Node

	signal done

	## replace is an absolute 'NodePath' to the 'Node' to remove from the 'SceneTree'.
	@export var replace: NodePath

	## next is the loaded scene with which to swap the to-be-replaced 'Node' with.
	@export var next: PackedScene

	## _start_transition is an abstract method called by the 'Switcher' node when this
	## transition should begin. When complete, emit the 'done' signal to run cleanup.
	func _start_transition() -> Error:
		assert(false, "unimplemented")
		return FAILED

	func _done() -> void:
		done.emit()


## TransitionInstant is an implementation of 'Transition' which instantly transitions
## to the new scene using GDScript built-in methods.
class TransitionInstant:
	extends Transition

	func _start_transition() -> Error:
		var err := get_tree().change_scene_to_packed(next)
		if err != OK:
			return err

		# NOTE: Must defer this call, otherwise the transition will be complete
		# before it's even registered as having started.
		call_deferred("_done")

		return OK


# -- CONFIGURATION ------------------------------------------------------------------- #

# -- INITIALIZATION ------------------------------------------------------------------ #

var _transition: Transition = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


func transition_to(
	target: NodePath, next: PackedScene, transition: Transition = null
) -> void:
	assert(get_tree().get_node_or_null(target) != null, "invalid replacement path")
	assert(next != null, "invalid argument; 'next' was null")
	assert(not _transition, "transition already in progress")

	if transition == null:
		transition = TransitionInstant.new()

	assert(not transition.is_inside_tree(), "invalid argument; 'transition' in tree")

	transition.next = next
	transition.replace = target

	var err := transition.done.connect(_on_transition_done)
	assert(err == OK, "failed to connect to signal")

	_transition = transition
	add_child(_transition, false, INTERNAL_MODE_BACK)

	err = _transition._start_transition()
	assert(err == OK, "failed to start transition")


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _process(_delta: float):
	pass


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

# -- PRIVATE METHODS ----------------------------------------------------------------- #

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_transition_done() -> void:
	assert(_transition is Transition, "invalid state; not in transition")

	_transition.done.disconnect(_on_transition_done)
	remove_child(_transition)
	_transition.queue_free()
	_transition = null

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
