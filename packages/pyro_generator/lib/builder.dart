/// build_runner entry point for Pyro: the factories `build.yaml` names.
///
/// Two builders write the Registry (`lib/pyro.g.dart`) and the Manifest
/// (`lib/pyro.manifest.json`) of a game's annotated Behaviors and Custom
/// components (project plan §7.3, §9.2). Both apply automatically to any
/// package that depends on `pyro_generator`, so a game needs no `build.yaml`.
library;

import 'package:build/build.dart';

import 'src/aggregate_builder.dart';
import 'src/scan_builder.dart';

/// Creates the per-library scan, which writes `<file>.pyro.json` to the
/// build cache.
Builder pyroScan(BuilderOptions options) => const PyroScanBuilder();

/// Creates the `$lib$` step, which writes the Registry and the Manifest.
Builder pyroAggregate(BuilderOptions options) => const PyroAggregateBuilder();
