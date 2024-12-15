# Changelog

## 1.8.6 (2024-12-15)

## What's Changed
* fix(input): revamp device type handling by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/124


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.8.5...v1.8.6

## 1.8.5 (2024-12-13)

## What's Changed
* fix(input): add assertions for correctly configuring analog actions by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/121
* fix(input): create a `StdInputSteamInGameActions` resource to declaratively write the manifest file by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/123


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.8.4...v1.8.5

## 1.8.4 (2024-12-12)

## What's Changed
* fix(condition): ensure `StdConditionParent` caches child nodes on enter by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/119


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.8.3...v1.8.4

## 1.8.3 (2024-12-12)

## What's Changed
* chore(addons): update `gut` to latest by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/115
* fix(file): use correct relative path instead of placeholder value by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/117
* fix(file): correctly form absolute path for exported projects by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/118


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.8.2...v1.8.3

## 1.8.2 (2024-12-12)

## What's Changed
* fix(condition): ensure initial block action is taken by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/112
* refactor(condition): extract expressions into `StdConditionExpression` resource, allowing for simpler `StdCondition` nodes by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/114


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.8.1...v1.8.2

## 1.8.1 (2024-12-12)

## What's Changed
* fix(input): correctly return typed array for all input slots by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/109
* fix(setting): correctly check for whether the property can be modified by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/111


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.8.0...v1.8.1

## 1.8.0 (2024-12-11)

## What's Changed
* fix(input): allow `StdInputSlot` components to be swappable at runtime by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/104
* feat(scene): allow loading actions for playable scenes by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/103
* feat(setting): add read-only settings properties for boolean logic and feature tracking by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/106
* feat(setting): allow `StdSettingsProperty` to propagate others' `value_changed` signals by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/107
* feat(feature,condition): refactor `feature` into `StdCondition` with two implementations by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/108


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.7.4...v1.8.0

## 1.7.4 (2024-12-10)

## What's Changed
* fix(input): update class name in test by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/99
* fix(input): handle keyboard activation on cursor motion; require user to supply nodes to `StdInputGlyph` by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/101
* fix(input): handle `activate_kbm_on_cursor_motion` set on layers by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/102


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.7.3...v1.7.4

## 1.7.3 (2024-12-09)

## What's Changed
* chore(input): remove leftover TODO by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/93
* fix(input): match axis values correctly by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/95
* refactor(input): streamline `InputDevice` components; update `InputSlot` and `InputGlyph` by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/96
* fix(input): allow `StdInputGlyph` to display plain text labels by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/97
* chore(input): prefix class names with `Std` by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/98


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.7.2...v1.7.3

## 1.7.2 (2024-12-07)

## What's Changed
* fix(input): encode axis values along with axis by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/90
* fix(input): encode `KeyLocation` values for `InputEventKey` by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/92


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.7.1...v1.7.2

## 1.7.1 (2024-12-07)

## What's Changed
* fix(input): swap glyph slot from "plus" to "equal"; add missing "space" glyph by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/87
* fix(input): initialize `InputGlyph` texture on ready by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/89


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.7.0...v1.7.1

## 1.7.0 (2024-12-07)

## What's Changed
* feat(input): create `InputGlyphSet` for loading input device icon collections by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/85


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.6.0...v1.7.0

## 1.6.0 (2024-12-06)

## What's Changed
* feat(input): create an `InputActionSetLoader` node for facilitating action set management by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/83


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.5.0...v1.6.0

## 1.5.0 (2024-12-06)

## What's Changed
* feat(input): write `encode`/`decode` functions for storing `InputEvent` types in an `int` by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/69
* feat(input): define `InputActionSet` and `InputActionSetLayer` resources by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/71
* feat(input): create a library for reading and writing input event bindings by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/72
* feat(input): create an `InputDevice` interface by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/73
* feat(input): create an `InputSlot` abstraction for managing per-player `InputDevice`s by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/74
* feat(input): add support for cursor management via `InputCursor` by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/75
* feat(input): implement `Bindings` components with native Godot support by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/76
* feat(input): implement haptics; move settings properties to `InputSlot` by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/77
* feat(input): create a class for writing a Steam action manifest from action sets by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/78
* feat(feature,input): create conditional subtree nodes; assign each `InputSlot` to a player by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/79
* fix(input): address various bugs in `InputActionSet`, `InputSlot`, and `InputCursor` by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/80
* feat(input): emit signals when action sets and layers change by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/81
* feat(input): create a `Glyph` node for displaying latest origin icons by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/82


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.4.0...v1.5.0

## 1.4.0 (2024-11-28)

## What's Changed
* feat(settings): add support for disabling input controls via a property by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/67


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.3.2...v1.4.0

## 1.3.2 (2024-11-28)

## What's Changed
* fix(settings): disable `OptionButton` with only one option by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/65


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.3.1...v1.3.2

## 1.3.1 (2024-11-24)

## What's Changed
* fix(settings): cache options for `StdSettingsOptionButtonController`s by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/63


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.3.0...v1.3.1

## 1.3.0 (2024-11-21)

## What's Changed
* feat(setting): simplify property notifications by binding each to a scope by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/61


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.2.5...v1.3.0

## 1.2.5 (2024-11-09)

## What's Changed
* fix(setting): update controlled `OptionButton` when properties change by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/59


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.2.4...v1.2.5

## 1.2.4 (2024-11-09)

## What's Changed
* fix(setting): pass `Config` to `StdSettingsObserver` when handling a property change by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/57


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.2.3...v1.2.4

## 1.2.3 (2024-11-08)

## What's Changed
* fix(setting): change slider value after changing its configuration by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/55


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.2.2...v1.2.3

## 1.2.2 (2024-11-08)

## What's Changed
* fix(setting): don't store default values by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/52
* refactor(setting): strictly type `property` and `options_property` variables on `StdSettingsController` classes by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/54


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.2.1...v1.2.2

## 1.2.1 (2024-11-06)

## What's Changed
* refactor(setting): make settings implementation more flexible and type-safe by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/49


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.2.0...v1.2.1

## 1.2.0 (2024-11-03)

## What's Changed
* feat(setting): implement components for updating settings within a scope by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/43
* feat(timer): add `Debounce` and `Throttle` timer nodes by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/46
* feat(config,file): create standalone `FileSyncer` and `ConfigWriter` nodes by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/47
* feat(group): implement a more flexible value group by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/48


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.1.1...v1.2.0

## 1.1.1 (2024-10-28)

## What's Changed
* chore(addons): update to latest `gut` by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/40


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.1.0...v1.1.1

## 1.1.0 (2024-10-28)

## What's Changed
* feat(config): implement secure `Config` and `ConfigWithFileSync` classes by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/38


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.0.1...v1.1.0

## 1.0.1 (2024-10-24)

## What's Changed
* fix(ci): upgrade `godot-infra` release actions to `v1` by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/36


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v1.0.0...v1.0.1

## 1.0.0 (2024-10-23)

## What's Changed
* feat!: upgrade `Godot` version to `4.3-stable` by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/33
* chore(docs): provide instructions on which version to use by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/35


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v0.2.5...v1.0.0

## 0.2.5 (2024-10-23)

## What's Changed
* chore(deps): bump tj-actions/changed-files from 44 to 45 by @dependabot in https://github.com/coffeebeats/godot-plugin-std/pull/30
* chore(ci): pin to `godot-infra` actions at `v0` by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/32

## New Contributors
* @dependabot made their first contribution in https://github.com/coffeebeats/godot-plugin-std/pull/30

**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v0.2.4...v0.2.5

## 0.2.4 (2024-06-14)

## What's Changed
* feat(scene): implement a `Splash` scene state for splash screens by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/28


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v0.2.3...v0.2.4

## 0.2.3 (2024-06-14)

## What's Changed
* fix(ci): update leftover hard-coded reference to addon subfolder by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/26


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v0.2.2...v0.2.3

## 0.2.2 (2024-06-14)

## What's Changed
* fix(ci): generate correct paths in `.import` files by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/24


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v0.2.1...v0.2.2

## 0.2.1 (2024-06-14)

## What's Changed
* fix(scene): correctly initialize `ColorRect` in `Fade` states; add initial state type by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/20
* feat(scene): allow tracking additional `State` nodes by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/22
* chore: keep `*.import` files when exporting the plugin by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/23


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v0.2.0...v0.2.1

## 0.2.0 (2024-06-03)

## What's Changed
* fix(fsm): allow setting compact behavior and process callback by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/12
* feat(scene): create a `Scene` state machine for declaratively managing scene transitions by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/14
* chore: bump minor version after `scene` package addition by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/15
* chore!: document new `scene` folder; bump minor version by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/16


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v0.1.2...v0.2.0

## 0.1.2 (2024-05-21)

## What's Changed
* fix(ci): use correct directory when ignoring files for packaging by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/9


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v0.1.1...v0.1.2

## 0.1.1 (2024-05-21)

## What's Changed
* chore: ignore `import` files for editor assets by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/7


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/compare/v0.1.0...v0.1.1

## 0.1.0 (2024-05-21)

## What's Changed
* chore: initial setup by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/1
* fix(ci): bootstrap release of entire repository by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/2
* chore: restructure plugin into standard GDScript library plugin by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/4
* chore: release 0.1.0 by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/5
* Release-As: 0.1.0 by @coffeebeats in https://github.com/coffeebeats/godot-plugin-std/pull/6

## New Contributors
* @coffeebeats made their first contribution in https://github.com/coffeebeats/godot-plugin-std/pull/1

**Full Changelog**: https://github.com/coffeebeats/godot-plugin-std/commits/v0.1.0

## Changelog
