##
## std/config/writer/binary.gd
##
## StdConfigWriterBinary synchronizes the provided `Config` instance with the specified
## file. File contents will be written using binary serialization and include a 16-byte
## MD5 checksum as a prefix.
##

class_name StdConfigWriterBinary
extends StdConfigWriter

# -- DEFINITIONS --------------------------------------------------------------------- #

const CHECKSUM_BYTE_LENGTH := 16


class StdConfigWriterBinaryResult:
	extends StdThreadWorkerResult

	var _checksum: String = ""

	func get_checksum() -> String:
		_mutex.lock()
		var checksum := _checksum
		_mutex.unlock()

		return checksum

	func set_checksum(value: String) -> void:
		_mutex.lock()
		_checksum = value
		_mutex.unlock()


# -- CONFIGURATION ------------------------------------------------------------------- #

## path is the filepath at which the 'Config' file contents will be synced to.
@export var path: String = ""

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	_logger = _logger.named(&"std/config/writer/binary")


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _create_worker_result can be overridden to custom the type of result object used by
## the worker.
func _create_worker_result() -> StdThreadWorkerResult:
	return StdConfigWriterBinaryResult.new()


func _config_read_bytes(config_path: String) -> ReadResult:
	var tmp_config_path := FilePath.make_project_path_absolute(_get_tmp_filepath())
	if not FileAccess.file_exists(tmp_config_path):
		return super._config_read_bytes(config_path)

	# '.tmp' file exists; check whether it was completely written.

	var result := ReadResult.new()
	var err := _file_open(tmp_config_path, FileAccess.READ, false)
	if err != OK:
		result.error = err
		return result

	var bytes := _file_read()

	err = _file_close()
	if err != OK:
		assert(false, "invalid state; failed to close file")
		result.error = err
		return result

	var checksum := bytes.slice(0, CHECKSUM_BYTE_LENGTH)
	var data := bytes.slice(CHECKSUM_BYTE_LENGTH)

	# Checksum doesn't match file contents; don't use that file.
	if checksum.hex_encode() != _compute_checksum(data).hex_encode():
		return super._config_read_bytes(config_path)

	# File contents validated; promote file.
	_file_move(tmp_config_path, config_path)

	# Now read file at target path.
	return super._config_read_bytes(config_path)


func _deserialize_var(bytes: PackedByteArray) -> Variant:
	if bytes.size() < (CHECKSUM_BYTE_LENGTH + VARIANT_ENCODING_LENGTH_MIN):
		assert(false, "invalid argument; missing data")
		return null

	var checksum := bytes.slice(0, CHECKSUM_BYTE_LENGTH)
	var data := bytes.slice(CHECKSUM_BYTE_LENGTH)

	if checksum.hex_encode() != _compute_checksum(data).hex_encode():
		return null

	var value: Variant = bytes_to_var(data)
	if not value is Dictionary:
		return null

	_worker_mutex.lock()
	var result: StdConfigWriterBinaryResult = _worker_result
	_worker_mutex.unlock()

	if not result:
		assert(false, "invalid state; missing result")
		return null

	result.set_checksum(checksum.hex_encode())

	return value


# NOTE: This method must be overridden.
func _get_filepath() -> String:
	return path


func _serialize_var(variant: Variant) -> PackedByteArray:
	var out := PackedByteArray()

	var bytes := var_to_bytes(variant)
	var checksum := _compute_checksum(bytes)

	out.append_array(checksum)
	out.append_array(bytes)

	_worker_mutex.lock()
	var result: StdConfigWriterBinaryResult = _worker_result
	_worker_mutex.unlock()

	assert(result, "invalid state; missing result")
	if result:
		result.set_checksum(checksum.hex_encode())

	return out


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _compute_checksum(bytes: PackedByteArray) -> PackedByteArray:
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(bytes)

	var checksum := ctx.finish()
	assert(
		checksum.size() == CHECKSUM_BYTE_LENGTH,
		"invalid output; unexpected checksum length",
	)

	return checksum
