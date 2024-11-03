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


# NOTE: serialization is done using 'var_to_bytes', so the opposite function should be
# used. However, 'ConfigWriter' expects a 'Dictionary', which can't be nil so this check
# is required to avoid exceptions.
func _deserialize_var(bytes: PackedByteArray) -> Variant:
	if bytes.is_empty():
		return {}

	var data: Variant = bytes_to_var(bytes)
	if not data is Dictionary:
		return {}

	return data


# NOTE: This method must be overridden.
func _get_filepath() -> String:
	return path
