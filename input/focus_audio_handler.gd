##
## std/input/focus_audio_handler.gd
##
## StdFocusAudioHandler is a node that listens to a `StdInputCursorFocusHandler` and
## plays sound effects when focus or hover state changes. This decouples audio feedback
## from focus management, allowing for more flexible UI sound design.
##

class_name StdFocusAudioHandler
extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## focus_handler is a path to the `StdInputCursorFocusHandler` node to listen to.
## Defaults to the parent node.
@export var focus_handler: NodePath = NodePath("..")

@export_subgroup("Sounds")

## sound_effect_focus is a sound event to play when the target `Control` node is first
## focused. This will not play if the node was already hovered.
@export var sound_effect_focus: StdSoundEvent = null

## sound_effect_hover is a sound event to play when the target `Control` node is first
## hovered. This will not play if the node was already focused.
@export var sound_effect_hover: StdSoundEvent = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _handler: StdInputCursorFocusHandler = null
var _player: StdSoundEventPlayer = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	_handler = get_node_or_null(focus_handler)
	assert(
		_handler is StdInputCursorFocusHandler, "invalid state; missing focus handler"
	)

	if not StdGroup.is_empty(StdSoundEventPlayer.GROUP_SOUND_PLAYER):
		_player = StdGroup.get_sole_member(StdSoundEventPlayer.GROUP_SOUND_PLAYER)

	Signals.connect_safe(_handler.focused, _on_focused)
	Signals.connect_safe(_handler.hovered, _on_hovered)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_focused() -> void:
	if sound_effect_focus and _player and not _handler.is_hovered():
		_player.play(sound_effect_focus)


func _on_hovered() -> void:
	if sound_effect_hover and _player and not _handler.is_focused():
		_player.play(sound_effect_hover)
