import 'package:clawclip/clawclip.dart';
import 'package:clawclip/sdl.dart';
import 'package:test/test.dart';

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
