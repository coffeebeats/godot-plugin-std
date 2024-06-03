##
## std/scene/example/main.gd
##
## Main is the root of the scene example.
##

extends Node

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _process(_delta: float) -> void:
	$Label.text = $Scene.state._path
