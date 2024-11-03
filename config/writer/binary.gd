##
## std/config/writer/binary.gd
##
## BinaryConfigWriter synchronizes the provided 'Config' instance with the specified
## file. File contents will be written using binary serialization.
##

class_name BinaryConfigWriter
extends ConfigWriter

# -- CONFIGURATION ------------------------------------------------------------------- #

## path is the filepath at which the 'Config' file contents will be synced to.
@export var path: String = ""

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

# NOTE: This method must be overridden.
func _get_filepath() -> String:
	return path
