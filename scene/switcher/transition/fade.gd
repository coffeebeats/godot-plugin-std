##
## std/scene/switcher/transition/fade.gd
##
## Fade ...
##

extends "../transition.gd"

# -- SIGNALS ------------------------------------------------------------------------- #

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

## duration is the length of the fade in/out animation.
@export_range(0.0, 3.0) var duration: float = 1.0

## color_rect is a node path to the 'ColorRect' used to fade the screen.
@export_node_path("ColorRect") var color_rect: NodePath = NodePath("ColorRect")

## fade_in determines whether a fade in animation is played.
@export var fade_in: bool = true

# -- INITIALIZATION ------------------------------------------------------------------ #

var _tween: Tween = null

@onready var _color_rect: ColorRect = get_node_or_null(color_rect)

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(_color_rect is ColorRect, "invalid config; missing ColorRect node")

	# Reset the alpha in case its default value is incorrect.
	_color_rect.modulate.a = 0


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _start_transition() -> Error:
	var tween := create_tween()

	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)

	_color_rect.modulate.a = 0
	tween.tween_property(_color_rect, NodePath(":modulate:a"), 255, duration)
	tween.tween_callback(_change_scene)
	tween.tween_property(_color_rect, NodePath(":modulate:a"), 0, duration)
	tween.tween_callback(_done)

	return OK

# -- PRIVATE METHODS ----------------------------------------------------------------- #

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
