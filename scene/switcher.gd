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

const Transition := preload("transition.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


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
