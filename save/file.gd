##
## std/save/file.gd
##
## StdSaveFile is a node which can read from and write to save files in a background
## thread. Only one save file can be interacted with at a time.
##

class_name StdSaveFile
extends StdBinaryConfigWriter

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _on_enter() -> void:
	_logger = _logger.named(&"std/save/file")
