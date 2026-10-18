# pyro_generator

The `build_runner` generator for Pyro. It reads your
annotated components and behaviors and writes two committed files into `lib/`:

- `pyro.g.dart`: the Registry your game uses to create them from scenes.
- `pyro.manifest.json`: the types Manifest Pyro reads.

Add it as a dev dependency next to `build_runner` (≥ 2.14).

> **Status:** skeleton. The generator arrives in v0.1 (see
> [`docs/project-plan.md`](../../docs/project-plan.md) §7.3, §9.2).
