/// build_runner entry point for Pyro.
///
/// The `$lib$` aggregator that writes `lib/pyro.g.dart` and
/// `lib/pyro.manifest.json` (project plan §7.3, §9.2) lands with v0.1
/// work item 7, together with the `build.yaml` that registers it. Until then
/// the factory returns a builder with no outputs.
library;

import 'package:build/build.dart';

/// Creates the Pyro builder. Placeholder: produces no outputs.
Builder pyroBuilder(BuilderOptions options) => const _PlaceholderBuilder();

class _PlaceholderBuilder implements Builder {
  const _PlaceholderBuilder();

  @override
  Map<String, List<String>> get buildExtensions => const {};

  @override
  Future<void> build(BuildStep buildStep) async {}
}
