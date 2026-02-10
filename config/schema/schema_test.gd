##
## Tests pertaining to the `StdConfigSchema` class.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


class ConfigItemTest:
	extends StdConfigItem

	@export var key: int = 0

	var category: StringName = &""

	func _get_category() -> StringName:
		return category


class ConfigSchemaTest:
	extends StdConfigSchema

	@export var item: ConfigItemTest = null

	var ignored_field: bool


# -- TEST METHODS -------------------------------------------------------------------- #


func test_config_schema_copy_sets_properties_correctly():
	# Given: A populated config item.
	var item := ConfigItemTest.new()
	item.key = 1
	item.category = &"category"

	# Given: A destination schema instance with an empty item.
	var dst := ConfigSchemaTest.new()
	dst.item = ConfigItemTest.new()

	# Given: A source schema instance with one item set.
	var src := ConfigSchemaTest.new()
	src.item = item

	# When: The schema is copied from 'src' to 'dst'.
	dst.copy(src)

	# Then: All properties match expected values.
	assert_eq(dst.item.key, src.item.key)


func test_config_schema_store_serializes_items_to_config_correctly():
	# Given: A new, empty 'Config' instance.
	var config := Config.new()

	# Given: A populated config item.
	var item := ConfigItemTest.new()
	item.key = 1
	item.category = &"category"

	# Given: A new config schema with one item set.
	var schema := ConfigSchemaTest.new()
	schema.item = item

	# When: The schema is serialized into the config object.
	schema.store(config)

	# Then: The config contains the expected values.
	assert_eq(config.get_int(&"category", &"key", 0), 1)


func test_config_schema_load_deserializes_items_to_config_correctly():
	# Given: A populated 'Config' instance.
	var config := Config.new()
	config.set_int(&"category", &"key", 1)

	# Given: A new, empty config item.
	var item := ConfigItemTest.new()
	item.category = &"category"

	# Given: A new config schema with one item set.
	var schema := ConfigSchemaTest.new()
	schema.item = item

	# When: The schema is deserialized from the config object.
	schema.load(config)

	# Then: The config item contains the expected values.
	assert_eq(item.key, 1)


func test_config_schema_reset_restores_items_to_defaults():
	# Given: A populated config item.
	var item := ConfigItemTest.new()
	item.key = 1
	item.category = &"category"

	# Given: A new config schema with one item set.
	var schema := ConfigSchemaTest.new()
	schema.item = item
	schema.ignored_field = true

	# When: The schema is reset.
	schema.reset()

	# Then: The schema values match expectations.
	assert_eq(item.key, 0)
	assert_eq(item.category, &"category") # Ignored!
	assert_eq(schema.ignored_field, true) # Ignored!


func test_store_stamps_version():
	# Given: A schema at version 1.
	var item := ConfigItemTest.new()
	item.category = &"test"

	var schema := ConfigSchemaTest.new()
	schema.item = item
	schema.version = 1

	# Given: A new, empty Config.
	var config := Config.new()

	# When: The schema is stored.
	schema.store(config)

	# Then: The schema version is stamped in the config.
	assert_eq(
		schema.get_saved_version(config),
		1,
		"Store should stamp version in config",
	)


func test_load_applies_migrations():
	# Given: A migration from v0.
	var migration : StdConfigSchemaMigration = double(StdConfigSchemaMigration).new()
	migration.version_from = 0

	# Given: A schema at version 1 with the migration.
	var item := ConfigItemTest.new()
	item.category = &"test"

	var schema := ConfigSchemaTest.new()
	schema.item = item
	schema.version = 1
	schema.migrations = [migration]

	# Given: A Config with no __meta__ (simulating v0).
	var config := Config.new()
	config.set_int(&"test", &"key", 5)

	# When: The schema is loaded.
	var result := schema.load(config)

	# Then: Load succeeds.
	assert_true(result, "load should return true")

	# Then: The migration was called.
	assert_called(migration, "_migrate")

	# Then: The version is stamped.
	assert_eq(
		schema.get_saved_version(config),
		1,
		"Version should be stamped after migration",
	)


func test_load_rejects_forward_version():
	# Given: A schema at version 1.
	var item := ConfigItemTest.new()
	item.category = &"test"

	var schema := ConfigSchemaTest.new()
	schema.item = item
	schema.version = 1

	# Given: A Config stamped at version 2.
	var config := Config.new()
	var future := ConfigSchemaTest.new()
	future.version = 2
	future.store(config)

	# When: The schema is loaded.
	var result := schema.load(config)

	# Then: Load returns false (forward version).
	assert_false(result, "load should reject forward version")


func test_load_handles_legacy_saves():
	# Given: A migration from v0.
	var migration : StdConfigSchemaMigration = double(StdConfigSchemaMigration).new()
	migration.version_from = 0

	# Given: A schema at version 1 with the migration.
	var item := ConfigItemTest.new()
	item.category = &"test"

	var schema := ConfigSchemaTest.new()
	schema.item = item
	schema.version = 1
	schema.migrations = [migration]

	# Given: A Config with data but no __meta__ (legacy save).
	var config := Config.new()
	config.set_int(&"test", &"key", 10)

	# When: The schema is loaded.
	var result := schema.load(config)

	# Then: Load succeeds.
	assert_true(result, "load should succeed for legacy saves")

	# Then: The migration ran.
	assert_called(migration, "_migrate")

	# Then: Item data is hydrated.
	assert_eq(item.key, 10, "Item data should be hydrated")


func test_load_skips_gaps_in_migration_chain():
	# Given: Migrations for v0 and v2 (gap at v1).
	var migration_0 : StdConfigSchemaMigration = double(StdConfigSchemaMigration).new()
	migration_0.version_from = 0

	var migration_2 : StdConfigSchemaMigration = double(StdConfigSchemaMigration).new()
	migration_2.version_from = 2

	# Given: A schema at version 3 with both migrations (unsorted intentionally).
	var item := ConfigItemTest.new()
	item.category = &"test"

	var schema := ConfigSchemaTest.new()
	schema.item = item
	schema.version = 3
	schema.migrations = [migration_2, migration_0]

	# Given: A Config with data but no __meta__ (starts at v0).
	var config := Config.new()
	config.set_int(&"test", &"key", 1)

	# When: The schema is loaded.
	var result := schema.load(config)

	# Then: Load succeeds.
	assert_true(result, "load should succeed with gaps in migration chain")

	# Then: Both migrations ran.
	assert_called(migration_0, "_migrate")
	assert_called(migration_2, "_migrate")


func test_check_migrations_returns_ok_for_valid_config():
	# Given: Valid migrations from v0 and v2.
	var migration_0 : StdConfigSchemaMigration = double(StdConfigSchemaMigration).new()
	migration_0.version_from = 0

	var migration_2 : StdConfigSchemaMigration = double(StdConfigSchemaMigration).new()
	migration_2.version_from = 2

	# Given: A schema at version 3 with the migrations.
	var item := ConfigItemTest.new()
	item.category = &"test"

	var schema := ConfigSchemaTest.new()
	schema.item = item
	schema.version = 3
	schema.migrations = [migration_0, migration_2]

	# When: Migrations are validated.
	var result := schema.check_migrations()

	# Then: Validation passes.
	assert_eq(result, OK, "Valid migrations should return OK")


func test_check_migrations_rejects_duplicate_version_from():
	# Given: Two migrations both from v0 (duplicate).
	var migration_a : StdConfigSchemaMigration = double(StdConfigSchemaMigration).new()
	migration_a.version_from = 0

	var migration_b : StdConfigSchemaMigration = double(StdConfigSchemaMigration).new()
	migration_b.version_from = 0

	# Given: A schema at version 2 with the duplicate migrations.
	var item := ConfigItemTest.new()
	item.category = &"test"

	var schema := ConfigSchemaTest.new()
	schema.item = item
	schema.version = 2
	schema.migrations = [migration_a, migration_b]

	# When: Migrations are validated.
	var result := schema.check_migrations()

	# Then: Validation fails with ERR_INVALID_PARAMETER.
	assert_eq(
		result,
		ERR_INVALID_PARAMETER,
		"Duplicate version_from should be rejected",
	)

	# Then: An error was logged about the duplicate.
	assert_push_error("Duplicate migration version_from")


func test_check_migrations_rejects_version_from_gte_schema_version():
	# Given: A migration from v1 (>= schema version).
	var migration : StdConfigSchemaMigration = double(StdConfigSchemaMigration).new()
	migration.version_from = 1

	# Given: A schema at version 1 with that migration.
	var item := ConfigItemTest.new()
	item.category = &"test"

	var schema := ConfigSchemaTest.new()
	schema.item = item
	schema.version = 1
	schema.migrations = [migration]

	# When: Migrations are validated.
	var result := schema.check_migrations()

	# Then: Validation fails with ERR_INVALID_PARAMETER.
	assert_eq(
		result,
		ERR_INVALID_PARAMETER,
		"version_from >= schema version should be rejected",
	)

	# Then: An error was logged about the invalid version.
	assert_push_error("version_from >= schema version")


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all():
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)
