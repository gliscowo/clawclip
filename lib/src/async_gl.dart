import 'dart:ffi';

import 'package:clawclip_sdl/clawclip_sdl.dart';

/// A function which requires an active OpenGL context
/// in order to run. In debug builds, this precondition
/// is asserted through an explicit check - in production
/// it falls through directly to the representation type
///
/// Note: This type should be used by asynchronous functions
/// which must perform some type of OpenGL setup after they
/// have crossed their async gap(s). Only the minimal amount
/// of code (ie. only the actual calls to OpenGL functions)
/// should be in the returned closure
extension type const GlCall<T>(T Function() _fn) {
  @pragma('vm:prefer-inline')
  T call() {
    assert(sdlGlGetCurrentContext() != nullptr, 'an OpenGL context must be active to invoke a GlCall');
    return _fn();
  }

  /// Create a new GlCall which returns the
  /// result of calling [fn] on the result of [this]
  GlCall<S> then<S>(S Function(T) fn) => GlCall(() => fn(_fn()));

  /// Create a new GlCall which returns a list
  /// of all results from invoking every call in [calls]
  static GlCall<List<T>> allOf<T>(Iterable<GlCall<T>> calls) => GlCall(() => calls.map((call) => call()).toList());
}
