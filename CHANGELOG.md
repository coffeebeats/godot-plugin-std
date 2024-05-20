# Changelog

## 0.2.7 (2024-05-14)

## What's Changed
* chore(ci): migrate `release-please` action by @coffeebeats in https://github.com/coffeebeats/godot-plugin-template/pull/40
* chore: update link in README to point to new `release-please` repository by @coffeebeats in https://github.com/coffeebeats/godot-plugin-template/pull/41
* chore(ci): switch to `github` changelog type by @coffeebeats in https://github.com/coffeebeats/godot-plugin-template/pull/42


**Full Changelog**: https://github.com/coffeebeats/godot-plugin-template/compare/v0.2.6...v0.2.7

## [0.2.6](https://github.com/coffeebeats/godot-plugin-template/compare/v0.2.5...v0.2.6) (2024-05-14)


### Bug Fixes

* **ci:** publish addon to branch prefixed with `godot-` ([#37](https://github.com/coffeebeats/godot-plugin-template/issues/37)) ([a5ed535](https://github.com/coffeebeats/godot-plugin-template/commit/a5ed53563dc5cf3e2ddd86f29e190f2de08a4bc8))

## [0.2.5](https://github.com/coffeebeats/godot-plugin-template/compare/v0.2.4...v0.2.5) (2024-05-13)


### Bug Fixes

* **ci:** add missing `-r` flag when deleting directory ([#35](https://github.com/coffeebeats/godot-plugin-template/issues/35)) ([3d26c99](https://github.com/coffeebeats/godot-plugin-template/commit/3d26c99463e5f3c26e2684827f610584103012c9))

## [0.2.4](https://github.com/coffeebeats/godot-plugin-template/compare/v0.2.3...v0.2.4) (2024-05-13)


### Bug Fixes

* **ci:** don't publish addons, submodules during release ([#33](https://github.com/coffeebeats/godot-plugin-template/issues/33)) ([d4ddef7](https://github.com/coffeebeats/godot-plugin-template/commit/d4ddef79473a7521fc1d5aa6f9461235aa5b3937))

## [0.2.3](https://github.com/coffeebeats/godot-plugin-template/compare/v0.2.2...v0.2.3) (2024-05-13)


### Bug Fixes

* **ci:** keep `.git` folder when deleting old files ([#31](https://github.com/coffeebeats/godot-plugin-template/issues/31)) ([eebd05e](https://github.com/coffeebeats/godot-plugin-template/commit/eebd05e512aecd283a3fbd6360273b198ab7d9cc))

## [0.2.2](https://github.com/coffeebeats/godot-plugin-template/compare/v0.2.1...v0.2.2) (2024-05-13)


### Bug Fixes

* **ci:** enable `extglob` prior to using extended glob patterns ([#29](https://github.com/coffeebeats/godot-plugin-template/issues/29)) ([4263c6b](https://github.com/coffeebeats/godot-plugin-template/commit/4263c6b267e44cedf98fd6772e382b93ddc83871))

## [0.2.1](https://github.com/coffeebeats/godot-plugin-template/compare/v0.2.0...v0.2.1) (2024-05-13)


### Bug Fixes

* **ci:** don't delete `.` or `..` when creating addon ([#27](https://github.com/coffeebeats/godot-plugin-template/issues/27)) ([4e735f0](https://github.com/coffeebeats/godot-plugin-template/commit/4e735f01a4a7dd9893ff83de31ad4e43baedd200))

## [0.2.0](https://github.com/coffeebeats/godot-plugin-template/compare/v0.1.1...v0.2.0) (2024-05-13)


### ⚠ BREAKING CHANGES

* update plugin template to use latest `godot-infra` infrastructure ([#25](https://github.com/coffeebeats/godot-plugin-template/issues/25))

### Features

* add support for `gdpack` ([#19](https://github.com/coffeebeats/godot-plugin-template/issues/19)) ([68f016b](https://github.com/coffeebeats/godot-plugin-template/commit/68f016b38885792b1a5ca777d38a2946dad53a95))
* **addon:** add `gut` as an addon dependency ([#26](https://github.com/coffeebeats/godot-plugin-template/issues/26)) ([4e2ee08](https://github.com/coffeebeats/godot-plugin-template/commit/4e2ee0851bad6018af5240eee54130327d95ed0a))
* **ci:** refactor CI workflows; add new `check-commit.yml` workflow ([#15](https://github.com/coffeebeats/godot-plugin-template/issues/15)) ([e10b9ca](https://github.com/coffeebeats/godot-plugin-template/commit/e10b9ca585f0b7c8dc090d21dee9b1b6a7c02111))
* update plugin template to use latest `godot-infra` infrastructure ([#25](https://github.com/coffeebeats/godot-plugin-template/issues/25)) ([cb0fcae](https://github.com/coffeebeats/godot-plugin-template/commit/cb0fcae4ce7f84018a0c8a2d18360228318ea251))

## [0.1.1](https://github.com/coffeebeats/godot-plugin-template/compare/v0.1.0...v0.1.1) (2023-03-27)


### Bug Fixes

* **ci:** ensure 'addons' is properly exported ([#12](https://github.com/coffeebeats/godot-plugin-template/issues/12)) ([5585153](https://github.com/coffeebeats/godot-plugin-template/commit/55851535885340f88233ce447ff9613bca820f55))

## 0.1.0 (2023-03-27)


### Features

* **ci:** create action `setup-godot`; create `bootstrap.sh` script  ([#6](https://github.com/coffeebeats/godot-plugin-template/issues/6)) ([71d75a2](https://github.com/coffeebeats/godot-plugin-template/commit/71d75a206ea166525c28e858e40c48ef84ec6f31))
* **ci:** set up project folders and release workflow using `release-please` ([#1](https://github.com/coffeebeats/godot-plugin-template/issues/1)) ([e8029cb](https://github.com/coffeebeats/godot-plugin-template/commit/e8029cbb8a0e0bd573c01f4a6eb1929a2d37bf6a))


### Bug Fixes

* **ci:** add requisite 'release-please' workflow permissions ([#3](https://github.com/coffeebeats/godot-plugin-template/issues/3)) ([7bd903c](https://github.com/coffeebeats/godot-plugin-template/commit/7bd903c32b046a4f8ed41269c0a9239d6db69a57))
* **ci:** change initial plugin version to '0.0.0' ([#10](https://github.com/coffeebeats/godot-plugin-template/issues/10)) ([66a4e2b](https://github.com/coffeebeats/godot-plugin-template/commit/66a4e2b5aaa267a12c06948a4adfa106d191413a))
* **ci:** fix 'release-please' workflow; create example plugin 'example-plugin' ([#2](https://github.com/coffeebeats/godot-plugin-template/issues/2)) ([12d7fdc](https://github.com/coffeebeats/godot-plugin-template/commit/12d7fdce9a3f490ae543fb392f80cd9b6b5eea9a))
* **ci:** only export 'addons' dir when releasing ([#11](https://github.com/coffeebeats/godot-plugin-template/issues/11)) ([bb51f0d](https://github.com/coffeebeats/godot-plugin-template/commit/bb51f0dd4c606a36a4f65edf562595d8fd014f6e))
