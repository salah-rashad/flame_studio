# Flame Studio

A desktop editor for games made with the Flame engine: developers compose scenes visually while all
game logic stays in plain Dart in their own IDE.

## Language

### Tools and packages

**Studio**:
The Flame Studio desktop app.
_Avoid_: Editor (as a product name), IDE

**Runtime**:
The package shipped inside the user's game that loads scenes into Flame.

**Generator**:
The build-time tool that inspects the user's annotated classes and produces the Registry and the Manifest.

### Scenes

**Scene**:
A file holding a tree of Nodes that the Runtime loads into a running game.
_Avoid_: Level, map

**Node**:
One element of a Scene's tree, such as an Entity, a sprite, a hitbox or a Prefab instance.
_Avoid_: Object, game object, element

**Node kind**:
What sort of thing a Node is: a built-in sort (entity, sprite, hitbox, prefab instance) or a Custom component.
_Avoid_: Kind (unqualified), node type

**Entity**:
A Node that can hold Behaviors.

**Behavior**:
A user-written Dart class holding logic, attached to an Entity.
_Avoid_: Script

**Custom component**:
A Node whose class is a user-written Flame component rather than a built-in Node kind.

**Prefab**:
A Scene used inside other Scenes by reference.

**Prefab instance**:
A Node that places a Prefab inside another Scene.

**Node name**:
A human-chosen label on a Node, used to look it up from game code; not required to be unique.

### User types and their fields

**Type ID**:
The stable identifier a Scene uses to name a user's Behavior or Custom component class: the class name unless the developer gives an explicit one.
_Avoid_: Class path, fully qualified name

**Type role**:
Whether a user type is a Behavior or a Custom component.
_Avoid_: Kind (for types)

**Editable field**:
A field of a user type that the Studio lets the developer set per Node.

**Field type**:
The value type of an Editable field (number, text, enum, vector, colour, asset reference, entity reference).
_Avoid_: Kind (for fields)

**Override**:
A value the developer explicitly set for an Editable field on a Node; it is saved in the Scene. A field with no Override takes its default from code.
_Avoid_: Saved value, custom value

**Registry**:
Generated code shipped in the game that lets the Runtime create user types and set their Editable fields.
_Avoid_: Type registry

**Manifest**:
Generated data describing the user's annotated types and their Editable fields, read by the Studio.
_Avoid_: types.json

**Type catalog**:
The Studio's complete list of types it can offer: the user's types from the Manifest plus Flame's built-in Node kinds.
_Avoid_: Type registry, Registry (in the Studio)

**Missing behavior** / **Missing component**:
A Behavior or Custom component referenced by a Scene whose Type ID no longer exists in the code; its data is kept untouched.
_Avoid_: Missing script

### Editing and running

**Document**:
The Studio's in-memory, undoable model of one open Scene.

**Play**:
Running the developer's game from the Studio on a chosen device; the Studio owns that running game.
_Avoid_: Run game, launch

**Attach**:
Connecting the developer's IDE debugger to a game the Studio is already running.

**Hot-swap**:
Replacing a Scene inside a running game with its newly saved version, without restarting the game.
_Avoid_: Scene reload, live reload

**Live bridge**:
A future two-way connection between the Studio and a running game for selecting and tweaking Nodes live.
