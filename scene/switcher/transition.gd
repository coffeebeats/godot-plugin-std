##
## std/scene/switcher/transition.gd
##
## Transition ...
##

extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

signal done

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

## replace is an absolute 'NodePath' to the 'Node' to remove from the 'SceneTree'.
var replace: NodePath

## next is the loaded scene with which to swap the to-be-replaced 'Node' with.
var next: PackedScene

# -- INITIALIZATION ------------------------------------------------------------------ #

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _start_transition is an abstract method called by the 'Switcher' node when this
## transition should begin. When complete, emit the 'done' signal to run cleanup.
func _start_transition() -> Error:
	assert(false, "unimplemented")
	return FAILED


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _change_scene() -> void:
	print(
		"transition.gd ",
		"replacing node at path %s " % replace,
		"with packed scene: %s" % next
	)

	var previous := get_tree().root.get_node_or_null(replace)
	assert(previous is Node, "invalid input; missing node")

	var parent := previous.get_parent()
	assert(previous is Node, "invalid input; missing parent")

	parent.remove_child(previous)
	previous.queue_free()

	var node := next.instantiate()
	node.name = replace.get_name(replace.get_name_count() - 1)

	parent.add_child(node, true, INTERNAL_MODE_DISABLED)


func _done() -> void:
	done.emit()

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
