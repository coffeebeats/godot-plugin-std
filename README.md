# godot-plugin-std

A Godot 4.0+ plugin providing standard GDScript functions and components.

## Usage

### **`fsm`**

The [fsm](./fsm) directory contains an implementation of a hierarchical [StateMachine](./fsm/state_machine.gd) suited for most applications. State machines are constructed as a scene with the node hierarchy used to define the level of state nesting. Each state should utilize a custom script to implement its behavior, and users can input events into the state machine to trigger transitions or update states.

Additionally, the [StateMachine](./fsm/state_machine.gd) implementation provides a "compaction" process which is enabled by default. The state machine extracts the scripts of all child [State](./fsm/state.gd) nodes and stores those objects internally without adding children to the scene tree. This improves performance, especially for state machines which are instantiated often.

### **`iter`**

The [iter](./iter) directory contains helpful functions for interacting with sequences and collections of various types.

### **`scene`**

The [scene](./scene) directory contains an implementation of a [StateMachine](./fsm/state_machine.gd) specialized for declaratively managing scene transitions. See the [examples folder](./scene/example/) for a sample main scene.

## **Development**

### Setup

The following instructions outline how to get the project set up for local development:

1. Clone this repository using the `--recurse-submodules` flag, ensuring all submodules are initialized. Alternatively, run `git submodule sync` to update all submodules to latest.
2. [Follow the instructions](https://github.com/coffeebeats/gdenv/blob/main/docs/installation.md) to install `gdenv`. Then, install the [pinned version of Godot](./.godot-version) with `gdenv i`.
3. Install the tools [used below](#code-submission) by following each of their specific installation instructions.

### Code submission

When submitting code for review, ensure the following requirements are met:

1. The project adheres as closely as possible to the official [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).

2. The project is correctly formatted using [gdformat](https://github.com/Scony/godot-gdscript-toolkit/wiki/4.-Formatter):

    ```sh
    bin/gdformat -l 88 --check **/*.gd
    ```

3. All [gdlint](https://github.com/Scony/godot-gdscript-toolkit/wiki/3.-Linter) linter warnings are addressed:

    ```sh
    bin/gdlint **/*.gd
    ```

4. All [Gut](https://github.com/bitwes/Gut) unit tests pass:

    ```sh
    godot \
        --quit \
        --headless \
        -s addons/gut/gut_cmdln.gd \
        -gdir="res://" \
        -ginclude_subdirs \
        -gprefix="" \
        -gsuffix="_test.gd" \
        -gexit
    ```

## **Releasing**

[Semantic Versioning](http://semver.org/) is used for versioning and [Conventional Commits](https://www.conventionalcommits.org/) is used for commit messages. A [release-please](https://github.com/googleapis/release-please) integration via [GitHub Actions](https://github.com/googleapis/release-please-action) automates releases.

## **Version history**

See [CHANGELOG.md](https://github.com/coffeebeats/godot-plugin-template/blob/main/CHANGELOG.md).

## **License**

[MIT License](https://github.com/coffeebeats/godot-plugin-template/blob/main/LICENSE)
