##
## std/config/schema/schema.gd
##
## StdConfigSchema is a collection of `StdConfigItem` instances that can be serialized
## to or deserialized from a `Config` object. Schemas support versioning and migrations.
##

class_name StdConfigSchema
extends Resource

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config.gd")
const Metadata := preload("meta.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const PROPERTY_KEY_NAME := &"name"
const PROPERTY_KEY_USAGE := &"usage"

const PROPERTY_USAGE_SERDE := PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_STORAGE

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Versioning")

## version is the current schema version; stored in the `__meta__` category.
@export var version: int = 0

## migrations is an ordered list of schema migrations to apply when loading old data.
@export var migrations: Array[StdConfigSchemaMigration] = []

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"std/config/schema")  # gdlint:ignore=class-definitions-order,max-line-length

var _meta := Metadata.new()

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## check_migrations validates the specified schema migrations. Returns `OK` if valid, or
## an error code if misconfigured.
func check_migrations() -> Error:
	var seen := PackedInt32Array()

	for migration in migrations:
		if migration.version_from in seen:
			(
				_logger
				. error(
					"Duplicate migration version_from.",
					{&"version_from": migration.version_from},
				)
			)
			return ERR_INVALID_PARAMETER

		if migration.version_from >= version:
			(
				_logger
				. error(
					"Migration version_from >= schema version.",
					{
						&"version_from": migration.version_from,
						&"schema_version": version,
					},
				)
			)
			return ERR_INVALID_PARAMETER

		seen.append(migration.version_from)

	return OK


## copy sets this config schema object to be equivalent to the provided instance. All
## values will be overwritten with those sourced from the `other` object.
func copy(other: StdConfigSchema) -> void:
	if not other is StdConfigSchema:
		assert(false, "invalid argument; missing other schema object")
		return

	for property in get_property_list():
		if property[PROPERTY_KEY_USAGE] & PROPERTY_USAGE_SERDE != PROPERTY_USAGE_SERDE:
			continue

		var name: StringName = property[PROPERTY_KEY_NAME]
		var value: Variant = get(name)
		var value_other: Variant = other.get(name)

		if not value is StdConfigItem or not value_other is StdConfigItem:
			continue

		value.copy(value_other)


## get_saved_version returns the schema version stored in the config, or `0` if none.
func get_saved_version(config: Config) -> int:
	_meta.load(config)
	return _meta.version


## load populates this schema object from the provided `Config` instance. Returns false
## if the saved version is newer than the current schema version (forward version).
##
## NOTE: Only exported, non-null `StdConfigItem` properties will be updated.
func load(config: Config) -> bool:
	assert(check_migrations() == OK, "invalid config; check migration setup")

	_meta.load(config)
	var saved_version := _meta.version

	# Reject forward versions (downgrade).
	if saved_version > version:
		return false

	# Apply migrations if needed.
	if saved_version < version:
		_apply_migrations(config, saved_version)
		_meta.version = version
		_meta.store(config)

	# Existing item hydration.
	var categories := PackedStringArray()

	for property in get_property_list():
		if property[PROPERTY_KEY_USAGE] & PROPERTY_USAGE_SERDE != PROPERTY_USAGE_SERDE:
			continue

		var name: StringName = property[PROPERTY_KEY_NAME]
		var value: Variant = get(name)

		if not value is StdConfigItem:
			continue

		var category := (value as StdConfigItem).get_category()
		assert(category not in categories, "invalid config; duplicate category")
		categories.append(category)

		value.load(config)

	return true


## reset sets all `StdConfigItem` properties back to their default values.
func reset() -> void:
	for property in get_property_list():
		if property[PROPERTY_KEY_USAGE] & PROPERTY_USAGE_SERDE != PROPERTY_USAGE_SERDE:
			continue

		var name: StringName = property[PROPERTY_KEY_NAME]
		var value: Variant = get(name)

		if not value is StdConfigItem:
			continue

		value.reset()


## store populates the provided `Config` instance with this schema's items.
##
## NOTE: Only exported, non-null `StdConfigItem` properties will be set on the `Config`.
func store(config: Config) -> void:
	assert(check_migrations() == OK, "invalid config; check migration setup")

	_meta.version = version
	_meta.store(config)

	var categories := PackedStringArray()

	for property in get_property_list():
		if property[PROPERTY_KEY_USAGE] & PROPERTY_USAGE_SERDE != PROPERTY_USAGE_SERDE:
			continue

		var name: StringName = property[PROPERTY_KEY_NAME]
		var value: Variant = get(name)

		if not value is StdConfigItem:
			continue

		var category := (value as StdConfigItem).get_category()
		assert(category not in categories, "invalid config; duplicate category")
		categories.append(category)

		value.store(config)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _apply_migrations(config: Config, from: int) -> void:
	migrations.sort_custom(
		func(a: StdConfigSchemaMigration, b: StdConfigSchemaMigration) -> bool:
			return a.version_from < b.version_from
	)

	for migration in migrations:
		if migration.version_from >= from and migration.version_from < version:
			migration._migrate(config)
