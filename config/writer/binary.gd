##
## std/config/writer/binary.gd
##
## StdConfigWriterBinary synchronizes the provided `Config` instance with the specified
## file. File contents will be written using binary serialization and include a 1-byte
## compression mode, 8-byte uncompressed size, and 16-byte MD5 checksum as a prefix.
##

class_name StdConfigWriterBinary
extends StdConfigWriter

# -- DEFINITIONS --------------------------------------------------------------------- #

const CHECKSUM_BYTE_LENGTH := 16
const COMPRESSION_MODE_BYTE_LENGTH := 1
const UNCOMPRESSED_SIZE_BYTE_LENGTH := 8
const HEADER_BYTE_LENGTH := (
	COMPRESSION_MODE_BYTE_LENGTH + UNCOMPRESSED_SIZE_BYTE_LENGTH + CHECKSUM_BYTE_LENGTH
)

enum CompressionMode {  # gdlint:ignore=class-definitions-order
	NONE = 0,
	FASTLZ = 1,
	DEFLATE = 2,
	ZSTD = 3,
	GZIP = 4,
}


class Result:
	extends StdThreadWorkerResult

	var _checksum: String = ""
	var _config = null

	func get_checksum() -> String:
		_mutex.lock()
		var checksum := _checksum
		_mutex.unlock()

		return checksum

	func get_config():
		_mutex.lock()
		var config = _config
		_mutex.unlock()

		return config

	func set_checksum(value: String) -> void:
		_mutex.lock()
		_checksum = value
		_mutex.unlock()

	func set_config(value) -> void:
		_mutex.lock()
		_config = value
		_mutex.unlock()


# -- CONFIGURATION ------------------------------------------------------------------- #

## compression_mode controls the compression algorithm used for serialized data.
@export var compression_mode: CompressionMode = CompressionMode.ZSTD

## path is the filepath at which the 'Config' file contents will be synced to.
@export var path: String = ""

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	_logger = _logger.named(&"std/config/writer/binary")


# -- PUBLIC METHODS ------------------------------------------------------------------ #


## from_bytes deserializes a `Config` from the provided binary buffer; returns `null` if
## the data is invalid.
func from_bytes(bytes: PackedByteArray) -> Config:
	if bytes.size() < _get_minimum_size():
		return null

	var mode_byte := bytes[0]
	if mode_byte > CompressionMode.GZIP:
		return null

	var payload := bytes.slice(HEADER_BYTE_LENGTH)
	var checksum := (
		bytes
		. slice(
			COMPRESSION_MODE_BYTE_LENGTH + UNCOMPRESSED_SIZE_BYTE_LENGTH,
			HEADER_BYTE_LENGTH,
		)
	)

	if _compute_checksum(payload) != checksum:
		return null

	var size := bytes.decode_s64(COMPRESSION_MODE_BYTE_LENGTH)

	if mode_byte > CompressionMode.NONE:
		payload = payload.decompress(size, mode_byte - 1)
		if payload.is_empty():
			return null
	elif payload.size() != size:
		return null

	var value: Variant = bytes_to_var(payload)
	if not value is Dictionary:
		return null

	var config := Config.new()
	config._data = value
	return config  # gdlint:ignore=max-returns


## to_bytes serializes a `Config` to binary format with optional compression.
func to_bytes(
	config: Config,
	mode: CompressionMode = CompressionMode.NONE,
) -> PackedByteArray:
	if mode < 0 or mode > CompressionMode.GZIP:
		assert(false, "invalid argument; expected valid compression mode")
		mode = CompressionMode.NONE

	var data := config._data.duplicate(true)
	_sort_config_data(data)  # Ensure deterministic ordering.

	var payload := var_to_bytes(data)
	var size := payload.size()

	if mode > CompressionMode.NONE:
		var compressed := payload.compress(mode - 1)
		if compressed.is_empty():
			(
				_logger
				. warn(
					"Compression failed; falling back to uncompressed.",
					{&"mode": mode},
				)
			)

			mode = CompressionMode.NONE
		else:
			payload = compressed

	var checksum := _compute_checksum(payload)

	var out := PackedByteArray()
	out.append(mode)
	out.append_array(_encode_uncompressed_size(size))
	out.append_array(checksum)
	out.append_array(payload)

	return out


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _create_worker_result can be overridden to custom the type of result object used by
## the worker.
func _create_worker_result() -> StdThreadWorkerResult:
	return Result.new()


func _config_read_bytes(config_path: String) -> ReadResult:
	var tmp_config_path := _get_tmp_filepath()
	if not FileAccess.file_exists(tmp_config_path):
		return _read_file_bytes(config_path)

	# '.tmp' file exists; check whether it was completely written.
	var tmp_result := _read_file_bytes(tmp_config_path)
	if tmp_result.error != OK:
		return _read_file_bytes(config_path)

	var config := from_bytes(tmp_result.bytes)
	if not config:
		return _read_file_bytes(config_path)

	# Cache parsed `Config` so `_deserialize_var` skips re-parsing.
	_worker_mutex.lock()
	var result: Result = _worker_result
	_worker_mutex.unlock()

	if result:
		result.set_config(config)

	# File contents validated; promote and then return bytes.
	_file_move(tmp_config_path, config_path)
	return tmp_result


func _deserialize_var(bytes: PackedByteArray) -> Variant:
	_worker_mutex.lock()
	var result: Result = _worker_result
	_worker_mutex.unlock()

	if not result:
		assert(false, "invalid state; missing result")
		return null

	var config = result.get_config()
	if config:
		result.set_config(null)
	else:
		config = from_bytes(bytes)

	if not config:
		return null

	var checksum := (
		bytes
		. slice(
			COMPRESSION_MODE_BYTE_LENGTH + UNCOMPRESSED_SIZE_BYTE_LENGTH,
			HEADER_BYTE_LENGTH,
		)
	)

	result.set_checksum(checksum.hex_encode())

	return config._data


# NOTE: This method must be overridden.
func _get_filepath() -> String:
	return path


func _get_minimum_size() -> int:
	return HEADER_BYTE_LENGTH + VARIANT_ENCODING_LENGTH_MIN


func _serialize_var(variant: Variant) -> PackedByteArray:
	var config := Config.new()
	config._data = variant

	var out := to_bytes(config, compression_mode)

	var checksum := (
		out
		. slice(
			COMPRESSION_MODE_BYTE_LENGTH + UNCOMPRESSED_SIZE_BYTE_LENGTH,
			HEADER_BYTE_LENGTH,
		)
	)

	_worker_mutex.lock()
	var result: Result = _worker_result
	_worker_mutex.unlock()

	assert(result, "invalid state; missing result")
	if result:
		result.set_checksum(checksum.hex_encode())

	return out


# -- PRIVATE METHODS ----------------------------------------------------------------- #


static func _encode_uncompressed_size(value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(UNCOMPRESSED_SIZE_BYTE_LENGTH)
	bytes.encode_s64(0, value)
	return bytes


## _sort_config_data sorts dictionary keys in-place for deterministic serialization. Two
## levels only - `StdConfigItem` properties are never dictionaries.
static func _sort_config_data(data: Dictionary) -> void:
	data.sort()

	for key: StringName in data:
		var inner: Variant = data[key]
		if inner is Dictionary:
			inner.sort()


func _compute_checksum(bytes: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(bytes)

	var checksum := ctx.finish()
	assert(
		checksum.size() == CHECKSUM_BYTE_LENGTH,
		"invalid output; unexpected checksum length",
	)

	return checksum
