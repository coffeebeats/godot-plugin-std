##
## std/feature/condition_loader.gd
##
## StdConditionLoader is a node which conditionally instantiates and adds the configured
## packed scene based on whether the underlying condition evaluates to `true`.
##

class_name StdConditionalLoader
extends StdCondition

# -- CONFIGURATION ------------------------------------------------------------------- #

## scene is a filepath to a packed scene which should be instantiated and added to the
## scene tree (below this node) if the condition evaluates to `true`.
@export_file("*.tscn") var scene: String

# -- INITIALIZATION ------------------------------------------------------------------ #

var _node: Node = null
var _packed_scene: PackedScene = null

func _enter_tree() -> void:
	assert(scene, "invalid config; missing scene")
	_packed_scene = load(scene)

	super._enter_tree()

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

func _on_allow() -> void:
	assert(not _node, "invalid state; found dangling node")
	assert(_packed_scene is PackedScene, "invalid state; missing packed scene")

	_node = _packed_scene.instantiate()
	add_child(_node, false)

func _on_block() -> void:
	if not _node:
		return

	assert(is_ancestor_of(_node), "invalid state; node not in scene")

	remove_child(_node)
	_node.free()
	_node = null
