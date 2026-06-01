import 'package:test/test.dart';

import '../lib/clawclip.dart';
import '../lib/sdl.dart';

void main() {
  test('GlCall with an without context', () {
    sdlInit(sdlInitVideo);
    final window = Window(1, 1, 'GlCall Test', flags: const [.startInvisible]);

    expect(() => GlCall(() {})(), throwsA(isA<AssertionError>()));
    window.activateContext();
    GlCall(() {})();

    window.dispose();
    sdlQuit();
  });
}
