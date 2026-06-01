import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:clawclip/src/async_gl.dart';
import 'package:clawclip_opengl/clawclip_opengl.dart';
import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:vector_math/vector_math.dart';

import 'clawclip_logging.dart';

final _logger = createLogger('shader_compiler');

enum GlShaderType {
  vertex(glVertexShader),
  tesselationControl(glTessControlShader),
  tesselationEvalution(glTessEvaluationShader),
  geometry(glGeometryShader),
  fragment(glFragmentShader),
  compute(glComputeShader);

  final int glType;
  const GlShaderType(this.glType);
}

class GlShader {
  final int _id;

  @factory
  static Future<GlCall<GlShader>> fromFile(File file, GlShaderType type) async {
    final source = await file.readAsString();
    return GlCall(() => GlShader(basename(file.path), source, type));
  }

  // TODO: consider turning this into a fallible factory
  //  function and returning null on compilation failure
  GlShader(String sourceName, String source, GlShaderType type) : _id = gl.createShader(type.glType) {
    _loadAndCompile(sourceName, source);
  }

  int get id => _id;

  void _loadAndCompile(String sourceName, String source) {
    using((arena) {
      final sourceBuffer = source.toNativeUtf8(allocator: arena);

      final sourceArray = arena<Pointer<Utf8>>();
      sourceArray[0] = sourceBuffer;

      gl.shaderSource(_id, 1, sourceArray.cast(), nullptr);
      gl.compileShader(_id);

      final success = arena<Int>();
      gl.getShaderiv(_id, glCompileStatus, success);
      _logger?.fine('Shader "$sourceName" compile success: ${success.value}');

      if (success.value != glTrue) {
        final logLength = arena<Int>();
        gl.getShaderiv(_id, glInfoLogLength, logLength);

        final log = arena<Char>(logLength.value);
        gl.getShaderInfoLog(_id, logLength.value, nullptr, log);
        _logger?.severe('Failed to compile shader "$sourceName": ${log.cast<Utf8>().toDartString()}');
      }
    });
  }
}

class GlProgram {
  static const _floatBufferLength = 16;
  static final _floatBuffer = malloc<Float>(_floatBufferLength);
  static final _floatBufferView = _floatBuffer.asTypedList(_floatBufferLength);

  final int _id;
  final String name;
  final Map<String, int> _uniformCache = {};

  GlProgram(this.name, List<GlShader> shaders) : _id = gl.createProgram() {
    for (final shader in shaders) {
      gl.attachShader(_id, shader.id);
    }

    gl.linkProgram(_id);

    for (final shader in shaders) {
      gl.deleteShader(shader.id);
    }

    final success = malloc<Int>();
    gl.getProgramiv(_id, glLinkStatus, success);
    _logger?.fine('Program "$name link success: ${success.value}');

    if (success.value != glTrue) {
      final logLength = malloc<Int>();
      gl.getProgramiv(_id, glInfoLogLength, logLength);

      final log = malloc<Char>(logLength.value);
      gl.getProgramInfoLog(_id, logLength.value, nullptr, log);
      _logger?.severe('Failed to link program "$name": ${log.cast<Utf8>().toDartString()}');

      malloc.free(logLength);
      malloc.free(log);
    }

    malloc.free(success);
  }

  int get id => _id;
  void use() => gl.useProgram(_id);

  void uniformMat4(String uniform, Matrix4 value) {
    _floatBufferView.setRange(0, _floatBufferLength, value.storage);
    gl.programUniformMatrix4fv(_id, _uniformLocation(uniform), 1, glFalse, _floatBuffer);
  }

  void uniform1f(String uniform, double value) {
    gl.programUniform1f(_id, _uniformLocation(uniform), value);
  }

  void uniform2vf(String uniform, Vector2 vec) => uniform2f(uniform, vec.x, vec.y);
  void uniform2f(String uniform, double x, double y) {
    gl.programUniform2f(_id, _uniformLocation(uniform), x, y);
  }

  void uniform3vf(String uniform, Vector3 vec) => uniform3f(uniform, vec.x, vec.y, vec.z);
  void uniform3f(String uniform, double x, double y, double z) {
    gl.programUniform3f(_id, _uniformLocation(uniform), x, y, z);
  }

  void uniform4vf(String uniform, Vector4 vec) => uniform4f(uniform, vec.x, vec.y, vec.z, vec.w);
  void uniform4f(String uniform, double x, double y, double z, double w) {
    gl.programUniform4f(_id, _uniformLocation(uniform), x, y, z, w);
  }

  void uniform1i(String uniform, int value) {
    gl.programUniform1i(_id, _uniformLocation(uniform), value);
  }

  void uniform2i(String uniform, int x, int y) {
    gl.programUniform2i(_id, _uniformLocation(uniform), x, y);
  }

  void uniform3i(String uniform, int x, int y, int z) {
    gl.programUniform3i(_id, _uniformLocation(uniform), x, y, z);
  }

  void uniform4i(String uniform, int x, int y, int z, int w) {
    gl.programUniform4i(_id, _uniformLocation(uniform), x, y, z, w);
  }

  void uniformSampler(String uniform, int texture, int index) {
    gl.programUniform1i(_id, _uniformLocation(uniform), index);
    gl.bindTextureUnit(index, texture);
  }

  void ssbo(int binding, int ssboId) {
    gl.bindBufferBase(glShaderStorageBuffer, binding, ssboId);
  }

  int _uniformLocation(String uniform) => _uniformCache.putIfAbsent(
    uniform,
    () => using((arena) => gl.getUniformLocation(_id, uniform.toNativeUtf8(allocator: arena).cast())),
  );

  int getAttributeLocation(String attibute) =>
      using((arena) => gl.getAttribLocation(_id, attibute.toNativeUtf8(allocator: arena).cast()));
}
