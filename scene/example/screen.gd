extends ColorRect

@export var target: NodePath


func _input(event) -> void:
	if event.is_action_pressed("ui_accept"):
		$SceneHandle.transition_to(target)
