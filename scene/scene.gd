##
## std/scene/scene.gd
##
## Scene manages all possible scene states for the game and the transitions between
## them. Add a hierarchy of 'State' nodes to define scenes and transitions for the game.
## State nodes should be organized such that transitions form an alternating sequence of
## instantiable/playable states and transition states.
##

extends "../fsm/state_machine.gd"

# -- DEFINITIONS --------------------------------------------------------------------- #

## Mode is an enumeration of child positions at which a node can be added.
enum Mode {
	SCENE_MODE_REPLACE = 0,
	SCENE_MODE_BEFORE = 1,
	SCENE_MODE_AFTER = 2,
}

## State is the base class for all state scripts supported by this state machine.
class State:
	extends "../fsm/state.gd"

	func _get_loader() -> Loader:
		return _root._loader

	func _get_scene_state(path: NodePath) -> State:
		return _root.get_node(str(_path) + "/" + str(path)) as Object

	func _on_input(_event: Event) -> State:
		return _parent

const _GROUP_SCENE_FSM := "std/scene:scene"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Event := preload ("event.gd")
const Loader := preload ("loader.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## game_root is a node path to the root of the user-defined game scene (which will be
## modified by states).
##
## NOTE: Take care that this node is not included under this path, otherwise the entire
## scene state machine may be unloaded.
@export var game_root: NodePath = NodePath("Root")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _loader: Loader = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #

## Dispatches 'StateMachine' events to the current 'State' node.
func input(event: Event) -> void:
	super(event)

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

func _enter_tree() -> void:
	add_to_group(_GROUP_SCENE_FSM)

	# Add a new 'Loader' node.
	_loader = Loader.new()
	_loader.process_callback = Loader.SceneProcessCallback.SCENE_PROCESS_IDLE
	add_child(_loader, false, INTERNAL_MODE_FRONT)

	super()

func _ready() -> void:
	# Remove any property paths or subnames.
	game_root = NodePath(game_root.get_concatenated_names())

	# Make the game root path absolute.
	if not game_root.is_absolute():
		game_root = NodePath(str(get_path()) + "/" + str(game_root))

	super()

# -- PRIVATE METHODS ----------------------------------------------------------------- #

func _add_node_to_scene(
	path: NodePath, node: Node, mode: Mode=Mode.SCENE_MODE_REPLACE
) -> void:
	assert(not path.is_empty(), "missing scene path")
	assert(node != null, "missing scene node to add")

	# Make the scene path absolute.
	if not path.is_absolute():
		path = NodePath(str(get_path()) + "/" + str(path))

	assert(str(path).begins_with(game_root), "invalid path; must be under scene root")
	assert(not node.is_inside_tree(), "node should not be in scene")

	node.name = path.get_name(path.get_name_count() - 1)

	# Trim '/root' prefix because the root node is the starting target.
	path = NodePath(str(path).trim_prefix("/root").trim_prefix("/"))

	var target: Node = get_tree().root
	var parent: Node = target.get_parent()

	for index in path.get_name_count():
		parent = target
		target = target.get_node_or_null(NodePath(path.get_name(index)))
		assert(
			(
				target
				or (
					index == path.get_name_count() - 1
					and mode == Mode.SCENE_MODE_REPLACE
				)
			),
			"missing node; cannot correctly construct game scene",
		)

	match mode:
		Mode.SCENE_MODE_REPLACE:
			if not target:
				parent.add_child(node)
			else:
				var index := target.get_index()

				parent.remove_child(target)
				parent.add_child(node)
				parent.move_child(node, index)

				target.queue_free()
		Mode.SCENE_MODE_BEFORE:
			assert(target, "missing target node; cannot add sibling")

			var index := target.get_index()

			var placeholder := Node.new()
			target.add_sibling(placeholder)

			parent.move_child(placeholder, index)
			placeholder.replace_by(node)
			placeholder.queue_free()
		Mode.SCENE_MODE_AFTER:
			assert(target, "missing target node; cannot add sibling")

			target.add_sibling(node)
