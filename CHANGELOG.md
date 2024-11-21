# Changelog

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
