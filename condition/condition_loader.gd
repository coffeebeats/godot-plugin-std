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

# -- INITIALIZATION ------------------------------------------------------------------ #

var _node: Node = null
var _packed_scene: PackedScene = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

func _exit_tree() -> void:
	super._exit_tree()

	if _node:
		_node.free()
		_node = null

	_packed_scene = null

func _enter_tree() -> void:
	assert(scene, "invalid config; missing scene")
	_packed_scene = load(scene)

	super._enter_tree()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _on_allow() -> void:
	assert(_packed_scene is PackedScene, "invalid state; missing packed scene")
	assert(not _node or not _node.is_inside_tree(), "invalid state; found dangling node")

	if not _node:
		_node = _packed_scene.instantiate()

	add_child(_node, false)

func _on_block() -> void:
	if not _node:
		return

	assert(_node.is_inside_tree(), "invalid state; node not in scene")
	assert(is_ancestor_of(_node), "invalid state; node not a descendent")

	remove_child(_node)

func _should_trigger_allow_action_on_enter() -> bool:
	return true
