import 'dart:async';

/// Runs [work] off the UI isolate and returns its result.
///
/// The app passes `Isolate.run` (the default everywhere); tests that use
/// `fake_async` pass a runner that does the work in place, because an isolate's
/// reply arrives on the real event loop, which `fake_async` never runs
/// (spec 002, research R9).
typedef Offload = Future<R> Function<R>(FutureOr<R> Function() work);
