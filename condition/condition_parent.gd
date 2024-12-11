##
## std/feature/condition_parent.gd
##
## StdConditionParent is a node which conditionally allows its children to enter the scene
## tree based on whether the underlying condition evaluates to `true`.
##

class_name StdConditionalParent
extends StdCondition

# -- CONFIGURATION ------------------------------------------------------------------- #

## include_internal determines whether to remove internal nodes from the scene tree when
## conditions are not met.
@export var include_internal: bool = true

# -- INITIALIZATION ------------------------------------------------------------------ #

var _children: Array[Node] = []

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	# Store a reference to all children nodes defined at build time.
	_children = get_children(include_internal)

	super._enter_tree()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _on_allow() -> void:
	for child in _children:
		if not is_ancestor_of(child):
			add_child(child, false)


func _on_block() -> void:
	for child in get_children(include_internal):
		assert(child in _children, "invalid state; found unknown child node")

		if is_ancestor_of(child):
			remove_child(child)
