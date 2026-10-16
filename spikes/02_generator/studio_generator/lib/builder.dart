import 'package:build/build.dart';

import 'src/aggregate_builder.dart';
import 'src/scan_builder.dart';

Builder studioScan(BuilderOptions options) => StudioScanBuilder();

Builder studioAggregate(BuilderOptions options) => StudioAggregateBuilder();
