import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:clawclip_opengl/clawclip_opengl.dart';
import 'package:clawclip_sdl/clawclip_sdl.dart';
import 'package:ffi/ffi.dart';

var running = true;
var fullscreen = false;
var bordered = true;

void main(List<String> args) {
  if (!sdlInit(sdlInitVideo | sdlInitEvents)) {
    stderr.writeln('failed to initialize SDL');
    return;
  }

  final window = sdlCreateWindow('an sdl window??'.toNativeUtf8().cast(), 400, 400, sdlWindowOpengl);
  sdlGlCreateContext(window);

  using((arena) {
    final countPtr = arena<Int>();
    final displays = sdlGetDisplays(countPtr);

    final fullscreenModes = sdlGetFullscreenDisplayModes(displays[countPtr.value - 1], countPtr);
    sdlSetWindowFullscreenMode(window, fullscreenModes[0]);
  }, malloc);

  sdlSetCursor(sdlCreateSystemCursor(SDLSystemCursor.systemCursorWait));

  final event = malloc<SDLEvent>();
  while (running) {
    frame(event, window);
  }

  sdlDestroyWindow(window);
  sdlQuit();
}

@pragma('vm:never-inline')
void frame(Pointer<SDLEvent> event, Pointer<SDLWindow> window) {
  while (sdlPollEvent(event)) {
    if (event.ref.type == SDLEventType.eventWindowCloseRequested) {
      running = false;
    }

    if (event.ref.type == SDLEventType.eventKeyDown) {
      print(
        'key down, scancode: ${sdlGetScancodeName(event.ref.key.scancode).cast<Utf8>().toDartString()}, key: ${sdlGetKeyName(event.ref.key.key).cast<Utf8>().toDartString()}',
      );

      switch (event.ref.key.key) {
        case sdlkF11:
          fullscreen = !fullscreen;
          sdlSetWindowFullscreen(window, fullscreen);
        case sdlkF2:
          bordered = !bordered;
          sdlSetWindowBordered(window, bordered);
      }
    }

    if (event.ref.type == SDLEventType.eventMouseButtonDown) {
      print('mouse button down: ${event.ref.button.button}');
    }

    if (event.ref.type == SDLEventType.eventMouseMotion) {
      print('motion: ${event.ref.motion.x}/${event.ref.motion.y}');
    }
  }

  final brightness = (sin(DateTime.now().millisecondsSinceEpoch / 1000) + 1) * .5;
  gl.clearColor(brightness, brightness, brightness, 1);
  gl.clear(glColorBufferBit);

  sdlGlSwapWindow(window);
}
