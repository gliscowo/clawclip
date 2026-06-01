import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'gl_functions.dart';

final GL gl = () {
  String libraryPath;
  if (Platform.isWindows) {
    libraryPath = 'Opengl32.dll';
  } else if (Platform.isLinux) {
    libraryPath = 'libGL.so.1';
  } else if (Platform.isMacOS) {
    libraryPath = '/System/Library/Frameworks/OpenGL.framework/Versions/Current/OpenGL';
  } else {
    throw GlInitError('Unsupported operating system: ${Platform.operatingSystem}');
  }

  DynamicLibrary openGlLibrary;
  try {
    openGlLibrary = DynamicLibrary.open(libraryPath);
  } catch (e) {
    throw GlInitError('Failed to load OpenGL binary', e);
  }

  String? getProcAddressFunction;
  if (Platform.isLinux) {
    getProcAddressFunction = 'glXGetProcAddress';
  } else if (Platform.isWindows) {
    getProcAddressFunction = 'wglGetProcAddress';
  }

  Pointer<Void> Function(Pointer<Utf8>)? getProcAddress;
  if (getProcAddressFunction != null) {
    try {
      getProcAddress = openGlLibrary
          .lookupFunction<Pointer<Void> Function(Pointer<Utf8>), Pointer<Void> Function(Pointer<Utf8>)>(
            getProcAddressFunction,
            isLeaf: true,
          );
    } catch (e) {
      throw GlInitError('Failed to link platform-specific OpenGL API retrieval function', e);
    }
  }

  Pointer<T> lookupSymbol<T extends NativeType>(String symbol) {
    if (openGlLibrary.providesSymbol(symbol)) {
      return openGlLibrary.lookup(symbol);
    } else if (getProcAddress != null) {
      return using((arena) {
        return getProcAddress!(symbol.toNativeUtf8(allocator: arena)).cast();
      });
    } else {
      return nullptr;
    }
  }

  return GL.fromLookup(lookupSymbol);
}();

class GlInitError extends Error {
  final String message;
  final Object? cause;

  GlInitError(this.message, [this.cause]);

  @override
  String toString() => cause != null ? "$message\nCaused by: $cause" : message;
}
