# The Studio runs the game; the IDE attaches to it

As in Unity, Play lives in the Studio: it launches the game with `flutter run --machine` on the chosen device, owns that process, and hot-swaps Scenes into it on save. Developers who want breakpoints or code hot reload attach their IDE's debugger to the running process instead of launching the game from the IDE. We chose this so the Studio controls the whole loop (Play, Stop, device choice, Console, Hot-swap) and does not depend on which IDE the developer uses or how they start the game. The cost is that "Attach" is an extra step developers aren't used to in Flutter, so the Studio has to make it easy.

## Considered Options

- **IDE owns the run, Studio only edits files**: hot-swap through the IDE's hot reload. Rejected: the Studio can't offer Play/Stop, a device picker or a Console, and the loop depends on each developer's IDE setup.
- **Studio runs the game, IDE attaches** (chosen).
