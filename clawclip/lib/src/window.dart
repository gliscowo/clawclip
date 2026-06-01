import 'dart:async';
import 'dart:ffi';

import 'package:clawclip_sdl/clawclip_sdl.dart';
import 'package:ffi/ffi.dart';
import 'package:image/image.dart';
import 'package:vector_math/vector_math.dart';

import '../clawclip.dart';
import 'debug.dart';

class OpenGLVersion {
  final int major, minor;
  final bool coreProfile;

  const OpenGLVersion(this.major, this.minor, {this.coreProfile = false});
}

extension type const WindowFlag._(({String property, bool value}) _value) {
  static const startInvisible = WindowFlag._((property: sdlPropWindowCreateHiddenBoolean, value: true));
  static const notResizable = WindowFlag._((property: sdlPropWindowCreateResizableBoolean, value: false));
  static const alwaysOnTop = WindowFlag._((property: sdlPropWindowCreateAlwaysOnTopBoolean, value: true));
  static const maximized = WindowFlag._((property: sdlPropWindowCreateMaximizedBoolean, value: true));
  static const minimized = WindowFlag._((property: sdlPropWindowCreateMinimizedBoolean, value: true));
  static const fullscreen = WindowFlag._((property: sdlPropWindowCreateFullscreenBoolean, value: true));
  static const transparent = WindowFlag._((property: sdlPropWindowCreateTransparentBoolean, value: true));
  static const utility = WindowFlag._((property: sdlPropWindowCreateUtilityBoolean, value: true));
  static const undecorated = WindowFlag._((property: sdlPropWindowCreateBorderlessBoolean, value: true));
}

class Window {
  /// The default OpenGL version of contexts created through
  /// this class: 4.5 core profile
  static const defaultContextVersion = OpenGLVersion(4, 5, coreProfile: true);

  static final Map<int, Window> _knownWindows = {};

  late final Pointer<SDLWindow> _handle;
  late final Pointer<SDLGlcontextState> _glContext;
  final StreamController<WindowMoveEvent> _moveListeners = StreamController.broadcast(sync: true);
  final StreamController<WindowResizeEvent> _resizeListeners = StreamController.broadcast(sync: true);
  final StreamController<WindowCloseEvent> _closeListeners = StreamController.broadcast(sync: true);
  final StreamController<WindowRefreshEvent> _refreshListeners = StreamController.broadcast(sync: true);
  final StreamController<WindowFocusEvent> _focusListeners = StreamController.broadcast(sync: true);
  final StreamController<WindowMinimizeEvent> _minimizeListeners = StreamController.broadcast(sync: true);
  final StreamController<WindowMaximizeEvent> _maximizeListeners = StreamController.broadcast(sync: true);
  final StreamController<WindowRestoreEvent> _restoreListeners = StreamController.broadcast(sync: true);
  final StreamController<FramebufferResizeEvent> _framebufferResizeListeners = StreamController.broadcast(sync: true);
  final StreamController<ContentRescaleEvent> _rescaleListeners = StreamController.broadcast(sync: true);

  final StreamController<MouseInputEvent> _mouseInputListeners = StreamController.broadcast(sync: true);
  final StreamController<MouseMoveEvent> _mouseMoveListeners = StreamController.broadcast(sync: true);
  final StreamController<MouseEnterEvent> _mouseEnterListeners = StreamController.broadcast(sync: true);
  final StreamController<MouseLeaveEvent> _mouseLeaveListeners = StreamController.broadcast(sync: true);
  final StreamController<MouseScrollEvent> _mouseScrollListeners = StreamController.broadcast(sync: true);

  final StreamController<KeyInputEvent> _keyInputListeners = StreamController.broadcast(sync: true);
  final StreamController<TextInputEvent> _textInputListeners = StreamController.broadcast(sync: true);

  final StreamController<FilesDroppedEvent> _fileDropListeners = StreamController.broadcast(sync: true);
  final StreamController<TextDroppedEvent> _textDropListeners = StreamController.broadcast(sync: true);

  final Vector2 _cursorPos = Vector2.zero();
  late int _x;
  late int _y;
  late int _framebufferWidth;
  late int _framebufferHeight;
  int _width;
  int _height;
  bool _shouldClose = false;
  String _title;

  bool _fullscreen = false;
  int? fullscreenDisplayIdx;

  Window(
    int width,
    int height,
    String title, {
    OpenGLVersion contextVersion = defaultContextVersion,
    bool debug = false,
    List<WindowFlag> flags = const [],
  }) : _title = title,
       _width = width,
       _height = height {
    using((arena) {
      final properties = sdlCreateProperties();
      sdlSetStringProperty(
        properties,
        sdlPropWindowCreateTitleString.toNativeUtf8(allocator: arena).cast(),
        title.toNativeUtf8(allocator: arena).cast(),
      );
      sdlSetNumberProperty(properties, sdlPropWindowCreateWidthNumber.toNativeUtf8(allocator: arena).cast(), width);
      sdlSetNumberProperty(properties, sdlPropWindowCreateHeightNumber.toNativeUtf8(allocator: arena).cast(), height);
      sdlSetBooleanProperty(properties, sdlPropWindowCreateOpenglBoolean.toNativeUtf8(allocator: arena).cast(), true);
      sdlSetBooleanProperty(
        properties,
        sdlPropWindowCreateResizableBoolean.toNativeUtf8(allocator: arena).cast(),
        true,
      );

      for (final flag in flags) {
        sdlSetBooleanProperty(
          properties,
          flag._value.property.toNativeUtf8(allocator: arena).cast(),
          flag._value.value,
        );
      }

      _handle = sdlCreateWindowWithProperties(properties);

      if (_handle.address == 0) {
        throw WindowInitializationException(sdlGetError().cast<Utf8>().toDartString());
      }

      sdlGlSetAttribute(.glContextFlags, debug ? sdlGlContextDebugFlag : 0);
      sdlGlSetAttribute(.glContextMajorVersion, contextVersion.major);
      sdlGlSetAttribute(.glContextMinorVersion, contextVersion.minor);
      sdlGlSetAttribute(
        .glContextProfileMask,
        contextVersion.coreProfile ? sdlGlContextProfileCore : sdlGlContextProfileCompatibility,
      );

      _glContext = sdlGlCreateContext(_handle);
      if (_glContext == nullptr) {
        throw WindowInitializationException(sdlGetError().cast<Utf8>().toDartString());
      }

      final x = arena<Int>();
      final y = arena<Int>();

      if (!_isWayland) {
        sdlGetWindowPosition(_handle, x, y);
        _x = x.value;
        _y = y.value;
      } else {
        _x = 0;
        _y = 0;
      }

      sdlGetWindowSizeInPixels(_handle, x, y);
      _framebufferWidth = x.value;
      _framebufferHeight = y.value;
    });

    _knownWindows[sdlGetWindowId(_handle)] = this;

    if (clawlipLoggingConfig?.glConfig != null) {
      attachGlErrorCallbackToContext();
    }

    dropContext();
  }

  static void _onMove(SDLWindowEvent event) {
    if (!_knownWindows.containsKey(event.windowID)) return;
    final window = _knownWindows[event.windowID]!;

    final deltaX = event.data1 - window._x, deltaY = event.data2 - window._y;
    if (deltaX != 0 || deltaY != 0) {
      window._moveListeners.add((x: event.data1, y: event.data2, deltaX: deltaX, deltaY: deltaY));
    }

    window._x = event.data1;
    window._y = event.data2;
  }

  static void _onResize(SDLWindowEvent event) {
    if (!_knownWindows.containsKey(event.windowID)) return;
    final window = _knownWindows[event.windowID]!;

    window._width = event.data1;
    window._height = event.data2;

    window._resizeListeners.add((newWidth: event.data1, newHeight: event.data2));
  }

  static void _onClose(SDLWindowEvent event) {
    if (!_knownWindows.containsKey(event.windowID)) return;
    final window = _knownWindows[event.windowID]!;

    window._shouldClose = true;
    window._closeListeners.add(const ());
  }

  static void _onRefresh(SDLWindowEvent event) {
    if (!_knownWindows.containsKey(event.windowID)) return;
    final window = _knownWindows[event.windowID]!;

    window._refreshListeners.add(const ());
  }

  static void _onFocus(SDLWindowEvent event, bool nowFocused) {
    if (!_knownWindows.containsKey(event.windowID)) return;
    final window = _knownWindows[event.windowID]!;

    window._focusListeners.add((nowFocused: nowFocused));
  }

  static void _onMinimize(SDLWindowEvent event) {
    if (!_knownWindows.containsKey(event.windowID)) return;
    final window = _knownWindows[event.windowID]!;

    window._minimizeListeners.add(const ());
  }

  static void _onMaximize(SDLWindowEvent event) {
    if (!_knownWindows.containsKey(event.windowID)) return;
    final window = _knownWindows[event.windowID]!;

    window._maximizeListeners.add(const ());
  }

  static void _onRestore(SDLWindowEvent event) {
    if (!_knownWindows.containsKey(event.windowID)) return;
    final window = _knownWindows[event.windowID]!;

    window._restoreListeners.add(const ());
  }

  static void _onFramebufferResize(SDLWindowEvent event) {
    if (!_knownWindows.containsKey(event.windowID)) return;
    final window = _knownWindows[event.windowID]!;

    window._framebufferWidth = event.data1;
    window._framebufferHeight = event.data2;

    window._framebufferResizeListeners.add((newWidth: event.data1, newHeight: event.data2));
  }

  static void _onContentRescale(SDLWindowEvent event) {
    if (!_knownWindows.containsKey(event.windowID)) return;
    final window = _knownWindows[event.windowID]!;

    final scale = sdlGetWindowDisplayScale(window._handle);
    window._rescaleListeners.add((xScale: scale, yScale: scale));
  }

  static void _onMouseButton(SDLMouseButtonEvent event) {
    if (!_knownWindows.containsKey(event.windowID)) return;
    final window = _knownWindows[event.windowID]!;

    window._mouseInputListeners.add((button: event.button, down: event.down, mods: KeyModifiers(sdlGetModState())));
  }

  static void _onMousePos(SDLMouseMotionEvent event) {
    if (!_knownWindows.containsKey(event.windowID)) return;
    final window = _knownWindows[event.windowID]!;

    final deltaX = event.x - window._cursorPos.x, deltaY = event.y - window._cursorPos.y;
    if (deltaX != 0 || deltaY != 0) {
      window._mouseMoveListeners.add((x: event.x, y: event.y, dx: deltaX, dy: deltaY));
    }

    window._cursorPos.x = event.x;
    window._cursorPos.y = event.y;
  }

  static void _onMouseEnter(SDLWindowEvent event, bool enter) {
    if (!_knownWindows.containsKey(event.windowID)) return;
    final window = _knownWindows[event.windowID]!;

    (enter ? window._mouseEnterListeners : window._mouseLeaveListeners).add(const ());
  }

  static void _onScroll(SDLMouseWheelEvent event) {
    if (!_knownWindows.containsKey(event.windowID)) return;
    final window = _knownWindows[event.windowID]!;

    window._mouseScrollListeners.add((xOffset: event.x, yOffset: event.y));
  }

  static void _onKey(SDLKeyboardEvent event) {
    if (!_knownWindows.containsKey(event.windowID)) return;
    final window = _knownWindows[event.windowID]!;

    window._keyInputListeners.add((
      key: event.key,
      scancode: event.scancode,
      action: event.down
          ? event.repeat
                ? .repeat
                : .press
          : .release,
      mods: KeyModifiers(event.mod),
    ));
  }

  static void _onTextInput(SDLTextInputEvent event) {
    if (!_knownWindows.containsKey(event.windowID)) return;
    final window = _knownWindows[event.windowID]!;

    window._textInputListeners.add((text: event.text.cast<Utf8>().toDartString()));
  }

  static List<String>? _dropPathBuffer = [];
  static void _onFileDrop(SDLDropEvent event) {
    if (!_knownWindows.containsKey(event.windowID)) return;
    final window = _knownWindows[event.windowID]!;

    switch (event.type) {
      case SDLEventType.eventDropBegin:
        _dropPathBuffer = [];
      case SDLEventType.eventDropFile:
        _dropPathBuffer!.add(event.data.cast<Utf8>().toDartString());
      case SDLEventType.eventDropComplete:
        window._fileDropListeners.add((paths: _dropPathBuffer!));
        _dropPathBuffer = null;
    }
  }

  static void _onTextDrop(SDLDropEvent event) {
    if (!_knownWindows.containsKey(event.windowID)) return;
    final window = _knownWindows[event.windowID]!;

    window._textDropListeners.add((text: event.data.cast<Utf8>().toDartString()));
  }

  static void pollEvents() => using((arena) {
    final event = arena<SDLEvent>();
    while (sdlPollEvent(event)) {
      final eventRef = event.ref;

      switch (eventRef.type) {
        case SDLEventType.eventWindowMoved:
          _onMove(eventRef.window);
        case SDLEventType.eventWindowResized:
          _onResize(eventRef.window);
        case SDLEventType.eventWindowCloseRequested:
          _onClose(eventRef.window);
        case SDLEventType.eventWindowExposed:
          _onRefresh(eventRef.window);
        case SDLEventType.eventWindowFocusGained:
          _onFocus(eventRef.window, true);
        case SDLEventType.eventWindowFocusLost:
          _onFocus(eventRef.window, false);
        case SDLEventType.eventWindowMinimized:
          _onMinimize(eventRef.window);
        case SDLEventType.eventWindowMaximized:
          _onMaximize(eventRef.window);
        case SDLEventType.eventWindowRestored:
          _onRestore(eventRef.window);
        case SDLEventType.eventWindowPixelSizeChanged:
          _onFramebufferResize(eventRef.window);
        case SDLEventType.eventWindowDisplayScaleChanged:
          _onContentRescale(eventRef.window);
        case SDLEventType.eventMouseButtonDown || SDLEventType.eventMouseButtonUp:
          _onMouseButton(eventRef.button);
        case SDLEventType.eventMouseMotion:
          _onMousePos(eventRef.motion);
        case SDLEventType.eventWindowMouseEnter:
          _onMouseEnter(eventRef.window, true);
        case SDLEventType.eventWindowMouseLeave:
          _onMouseEnter(eventRef.window, false);
        case SDLEventType.eventMouseWheel:
          _onScroll(eventRef.wheel);
        case SDLEventType.eventKeyDown || SDLEventType.eventKeyUp:
          _onKey(eventRef.key);
        case SDLEventType.eventTextInput:
          _onTextInput(eventRef.text);
        case SDLEventType.eventDropBegin || SDLEventType.eventDropFile || SDLEventType.eventDropComplete:
          _onFileDrop(eventRef.drop);
        case SDLEventType.eventDropText:
          _onTextDrop(eventRef.drop);
      }
    }
  }, malloc);

  void startTextInput() => sdlStartTextInput(_handle);
  void stopTextInput() => sdlStopTextInput(_handle);

  void activateContext() => sdlGlMakeCurrent(_handle, _glContext);
  void dropContext() => sdlGlMakeCurrent(_handle, nullptr);

  void _enterFullscreen() {
    if (fullscreenDisplayIdx != null) {
      final monitorCount = malloc<Int>();

      final displays = sdlGetDisplays(monitorCount);
      final display = displays[fullscreenDisplayIdx!.clamp(0, monitorCount.value - 1)];

      sdlSetWindowFullscreenMode(_handle, sdlGetFullscreenDisplayModes(display, nullptr)[0]);
    }

    sdlSetWindowFullscreen(_handle, true);
  }

  void _exitFullscreen() => sdlSetWindowFullscreen(_handle, false);

  bool get fullscreen => _fullscreen;
  set fullscreen(bool value) {
    if (value == _fullscreen) return;

    _fullscreen = value;
    _fullscreen ? _enterFullscreen() : _exitFullscreen();
  }

  String get title => _title;
  set title(String value) {
    if (value == _title) return;

    _title = value;
    using((arena) {
      sdlSetWindowTitle(_handle, title.toNativeUtf8(allocator: arena).cast());
    });
  }

  void setIcon(Image icon) {
    final convertedIcon = icon.convert(format: Format.uint8, numChannels: 4, alpha: 255);

    final bufferSize = convertedIcon.width * convertedIcon.height * convertedIcon.numChannels;
    final pixelBuffer = malloc<Uint8>(bufferSize);

    pixelBuffer.asTypedList(bufferSize).setRange(0, bufferSize, convertedIcon.data!.buffer.asUint8List());
    final surface = sdlCreateSurfaceFrom(
      icon.width,
      icon.height,
      .pixelformatRgba32,
      pixelBuffer.cast(),
      convertedIcon.rowStride,
    );

    sdlSetWindowIcon(_handle, surface);
    sdlDestroySurface(surface);
  }

  void swapBuffers() => sdlGlSwapWindow(_handle);

  static void enableVsyncInContext() => sdlGlSetSwapInterval(1);
  static void disableVsyncInContext() => sdlGlSetSwapInterval(0);

  void dispose() {
    sdlGlDestroyContext(_glContext);
    sdlDestroyWindow(_handle);
    _knownWindows.remove(_handle.address);
  }

  double get cursorX => _cursorPos.x;
  set cursorX(double value) {
    if (value == _cursorPos.x) return;

    _cursorPos.x = value;
    sdlWarpMouseInWindow(_handle, _cursorPos.x, _cursorPos.y);
  }

  double get cursorY => _cursorPos.y;
  set cursorY(double value) {
    if (value == _cursorPos.y) return;

    _cursorPos.y = value;
    sdlWarpMouseInWindow(_handle, _cursorPos.x, _cursorPos.y);
  }

  Vector2 get cursorPos => _cursorPos.xy;

  /// In an effort to stay general-purpose, window coordinates are tracked by this class
  /// even though Wayland does not have such a concept. Thus, use with care
  int get x => _x;

  /// In an effort to stay general-purpose, window coordinates are tracked by this class
  /// even though Wayland does not have such a concept. Thus, use with care
  int get y => _y;

  int get width => _width;
  int get height => _height;
  int get framebufferWidth => _framebufferWidth;
  int get framebufferHeight => _framebufferHeight;

  bool get shouldClose => _shouldClose;

  Pointer<SDLWindow> get handle => _handle;
  Pointer<SDLGlcontextState> get glContext => _glContext;

  Stream<WindowMoveEvent> get onMove => _moveListeners.stream;
  Stream<WindowResizeEvent> get onResize => _resizeListeners.stream;
  Stream<WindowCloseEvent> get onClose => _closeListeners.stream;
  Stream<WindowRefreshEvent> get onRefresh => _refreshListeners.stream;
  Stream<WindowFocusEvent> get onFocus => _focusListeners.stream;
  Stream<WindowMinimizeEvent> get onIconify => _minimizeListeners.stream;
  Stream<WindowMaximizeEvent> get onMaximize => _maximizeListeners.stream;
  Stream<WindowRestoreEvent> get onRestore => _restoreListeners.stream;
  Stream<FramebufferResizeEvent> get onFramebufferResize => _framebufferResizeListeners.stream;
  Stream<ContentRescaleEvent> get onContentRescale => _rescaleListeners.stream;

  Stream<MouseInputEvent> get onMouseButton => _mouseInputListeners.stream;
  Stream<MouseMoveEvent> get onMouseMove => _mouseMoveListeners.stream;
  Stream<MouseEnterEvent> get onMouseEnter => _mouseEnterListeners.stream;
  Stream<MouseLeaveEvent> get onMouseLeave => _mouseLeaveListeners.stream;
  Stream<MouseScrollEvent> get onMouseScroll => _mouseScrollListeners.stream;

  Stream<KeyInputEvent> get onKey => _keyInputListeners.stream;
  Stream<TextInputEvent> get onTextInput => _textInputListeners.stream;

  Stream<FilesDroppedEvent> get onFilesDropped => _fileDropListeners.stream;
  Stream<TextDroppedEvent> get onTextDropped => _textDropListeners.stream;

  static final _isWayland = sdlGetCurrentVideoDriver().cast<Utf8>().toDartString() == 'wayland';
}

extension type const KeyModifiers(int bitMask) {
  bool get shift => (bitMask & sdlKmodShift) != 0;
  bool get ctrl => (bitMask & sdlKmodCtrl) != 0;
  bool get alt => (bitMask & sdlKmodAlt) != 0;
  bool get meta => (bitMask & sdlKmodGui) != 0;
  bool get capsLock => (bitMask & sdlKmodCaps) != 0;
  bool get numLock => (bitMask & sdlKmodNum) != 0;

  static const KeyModifiers none = KeyModifiers(0);

  static bool isModifier(int keyCode) => _modifierKeys.contains(keyCode);
  static const _modifierKeys = {sdlkLshift, sdlkRshift, sdlkLalt, sdlkRalt, sdlkLgui, sdlkRgui};
}

typedef WindowMoveEvent = ({int x, int y, int deltaX, int deltaY});
typedef WindowResizeEvent = ({int newWidth, int newHeight});
typedef WindowCloseEvent = ();
typedef WindowRefreshEvent = ();
typedef WindowFocusEvent = ({bool nowFocused});
typedef WindowMinimizeEvent = ();
typedef WindowMaximizeEvent = ();
typedef WindowRestoreEvent = ();
typedef FramebufferResizeEvent = ({int newWidth, int newHeight});
typedef ContentRescaleEvent = ({double xScale, double yScale});

typedef MouseInputEvent = ({int button, bool down, KeyModifiers mods});
typedef MouseMoveEvent = ({double x, double y, double dx, double dy});
typedef MouseEnterEvent = ();
typedef MouseLeaveEvent = ();
typedef MouseScrollEvent = ({double xOffset, double yOffset});

enum KeyAction { press, release, repeat }

typedef KeyInputEvent = ({int key, SDLScancode scancode, KeyAction action, KeyModifiers mods});
typedef TextInputEvent = ({String text});

typedef FilesDroppedEvent = ({List<String> paths});
typedef TextDroppedEvent = ({String text});

class WindowInitializationException {
  final String error;

  WindowInitializationException(this.error);

  @override
  String toString() => 'could not create window: $error';
}
