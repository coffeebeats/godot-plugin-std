##
## std/feature/condition_loader.gd
##
## StdConditionLoader is an implementation of `StdCondition` which conditionally
## instantiates and adds the configured scene as a child node based on the configured
## expressions.
##

class_name StdConditionLoader
extends StdCondition

# -- CONFIGURATION ------------------------------------------------------------------- #

## scene is a filepath to a packed scene which should be instantiated and added to the
## scene tree (below this node) if the condition evaluates to `true`.
@export_file("*.tscn") var scene: String

## force_readable_name controls whether the instantiated scene uses a readable name.
@export var force_readable_name: bool = false

# -- INITIALIZATION ------------------------------------------------------------------ #

var _node: Node = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	super._exit_tree()

	if _node:
		_node.free()
		_node = null


func _ready() -> void:
	assert(scene, "invalid config; missing scene")


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _on_allow() -> void:
	assert(
		not _node or not _node.is_inside_tree(), "invalid state; found dangling node"
	)

	if not _node:
		var packed_scene := load(scene)
		assert(packed_scene is PackedScene, "invalid state; missing packed scene")

		_node = packed_scene.instantiate()

	(
		_logger
		. debug(
			"Adding node to scene.",
			{&"parent": get_parent().get_path(), &"scene": scene},
		)
	)

	add_child(_node, force_readable_name)


func _on_block() -> void:
	if not _node:
		return

	assert(_node.is_inside_tree(), "invalid state; node not in scene")
	assert(is_ancestor_of(_node), "invalid state; node not a descendent")

	(
		_logger
		. debug(
			"Removing node from scene.",
			{&"parent": get_parent().get_path(), &"scene": scene},
		)
	)

	remove_child(_node)


func _should_trigger_allow_action_on_enter() -> bool:
	return true


func _should_trigger_block_action_on_enter() -> bool:
	return true
