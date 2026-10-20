import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:uuid/uuid.dart';

/// Makes a new Node ID, unique in its Scene. Tests pass a counter.
typedef NodeIdSource = NodeId Function();

const _uuid = Uuid();

/// A random (version 4) UUID, the Node ID form of *Q14*.
NodeId uuidNodeIds() => NodeId(_uuid.v4());
