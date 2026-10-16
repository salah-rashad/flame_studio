# flame_studio_generator

The `build_runner` generator for Flame Studio. It reads your
annotated components and behaviors and writes two committed files into `lib/`:

- `flame_studio.g.dart`: the Registry your game uses to create them from scenes.
- `flame_studio.manifest.json`: the types Manifest the Studio reads.

Add it as a dev dependency next to `build_runner` (≥ 2.14).

> **Status:** skeleton. The generator arrives in v0.1 (see
> [`docs/project-plan.md`](../../docs/project-plan.md) §7.3, §9.2).
