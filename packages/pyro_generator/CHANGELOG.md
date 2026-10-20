## Unreleased

- Every Behavior in the Registry gets `acceptsParent`, from its `Behavior<T>`; a parent type
  the Registry can't name is the new `unreachableParentType` error (24 errors in all).
- The generator: a per-library scan and a `$lib$` aggregator write the Registry
  (`lib/pyro.g.dart`) and the Manifest (`lib/pyro.manifest.json`, `manifestVersion` 1) for
  every v1 Field type, with inherited and mixin fields, supertypes and parent types.
- 23 build errors and 2 warnings, each naming file, line, class and field, in the build log
  and the Manifest; classes sharing a Type ID are all left out.
- Both builders auto-apply to dependents, so games need no `build.yaml`.

## 0.0.1

- Initial workspace skeleton; not published.
