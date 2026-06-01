import 'dart:math';

import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

import '../lib/clawclip.dart';
import '../lib/opengl.dart';
import '../lib/sdl.dart';

typedef Vertex = ({Vector3 pos, double yOffset, Color color});
final vertexDescriptor = VertexDescriptor<Vertex>([
  .f32x3(name: 'aPos', getter: (vertex) => vertex.pos),
  .f32(name: 'aYOffset', getter: (vertex) => vertex.yOffset),
  .color(name: 'aColor', getter: (vertex) => vertex.color),
]);

const vertexShaderSource = '''
#version 330 core

in vec3 aPos;
in vec4 aColor;
in float aYOffset;

out vec4 vColor;

void main() {
  gl_Position = vec4(aPos.x, aPos.y + aYOffset, aPos.z, 1.0);
  vColor = aColor;
}
''';

const fragmentShaderSource = '''
#version 330 core

in vec4 vColor;
out vec4 fragColor;

void main() {
  fragColor = vColor;
}
''';

void main() {
  test('simple triangle', () {
    Logger.root.onRecord.listen((event) {
      print('[${event.loggerName}] (${event.level}) ${event.message}');
    });

    clawclipSetupLoggingInIsolate(baseLogger: Logger('simple_triangle'), glConfig: .severityLowAllTypesNoStacktraces);

    sdlInit(sdlInitVideo);
    final window = Window(800, 600, 'clawclip triangle test', flags: [.transparent, .undecorated]);

    window.activateContext();
    window.onFramebufferResize.listen((event) {
      gl.viewport(0, 0, event.newWidth, event.newHeight);
    });

    Window.disableVsyncInContext();

    final vertexShader = GlShader('vertexShaderSource', vertexShaderSource, .vertex);
    final fragmentShader = GlShader('fragmentShaderSource', fragmentShaderSource, .fragment);

    final program = GlProgram('theProgram', [vertexShader, fragmentShader]);
    program.use();

    final mesh = MeshBuffer(vertexDescriptor, program);

    while (!window.shouldClose) {
      gl.clearColor(1, 1, 1, 0);
      gl.clear(glColorBufferBit);

      final time = DateTime.now().millisecondsSinceEpoch / 1000;

      final color1 = Color.ofHsv((time / 15) % 1, .75, 1);
      final color2 = Color.ofHsv((time / 10) % 1, .75, 1);
      final color3 = Color.ofHsv((time / 5) % 1, .75, 1);

      mesh
        ..clear()
        ..writeVertices([
          (pos: Vector3(0, .5, 0), yOffset: sin(time) * .2, color: color1),
          (pos: Vector3(-.5, -.5, 0), yOffset: sin(time * 4) * .05, color: color2),
          (pos: Vector3(.5, -.5, 0), yOffset: sin(time * 8) * .05, color: color3),
        ])
        ..upload(usage: .dynamicDraw)
        ..draw();

      window.swapBuffers();
      Window.pollEvents();
    }
  });
}
