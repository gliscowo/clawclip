import 'dart:ffi';
import 'dart:typed_data';

import 'package:clawclip/src/byte_array.dart';
import 'package:clawclip_opengl/clawclip_opengl.dart';
import 'package:ffi/ffi.dart';

import 'clawclip_logging.dart';
import 'shader.dart';
import 'vertex_descriptor.dart';

class MeshBuffer<Vertex> {
  final GlBufferObject _vbo = GlBufferObject.array();
  final GlVertexArray _vao = GlVertexArray();
  final VertexDescriptor<Vertex> _descriptor;
  final GlProgram program;

  BufferWriter buffer;

  MeshBuffer(VertexDescriptor<Vertex> descriptor, this.program, {ByteArray? array})
    : _descriptor = descriptor,
      buffer = BufferWriter(array ?? NativeByteArray(size: 1024)) {
    gl.vertexArrayVertexBuffer(_vao._id, 0, _vbo._id, 0, descriptor.vertexSize);
    descriptor.prepareAttributes(_vao._id, program);
  }

  int get vertexCount => buffer.cursor ~/ _descriptor.vertexSize;
  bool get isEmpty => buffer.cursor == 0;

  void writeVertices(List<Vertex> vertices) {
    _descriptor.serialize(buffer, vertices);
  }

  void upload({BufferUsage usage = BufferUsage.staticDraw}) {
    _vbo.upload(buffer, usage);
  }

  void clear() {
    buffer.rewind();
  }

  void draw({int mode = glTriangles}) {
    _vao.draw(vertexCount, mode: mode);
  }

  void drawInstanced(int instanceCount, {int mode = glTriangles}) {
    _vao.drawInstanced(vertexCount, instanceCount, mode: mode);
  }

  void delete() {
    _vbo.delete();
    _vao.delete();
  }
}

enum BufferUsage {
  streamDraw(glStreamDraw),
  streamRead(glStreamRead),
  streamCopy(glStreamCopy),
  staticDraw(glStaticDraw),
  staticRead(glStaticRead),
  staticCopy(glStaticCopy),
  dynamicDraw(glDynamicDraw),
  dynamicRead(glDynamicRead),
  dynamicCopy(glDynamicCopy);

  final int glType;
  const BufferUsage(this.glType);
}

class GlBufferObject {
  final int type;

  late final int _id;
  int _glObjectSize = 0;

  GlBufferObject.array() : this._(glArrayBufferBinding);
  GlBufferObject.shaderStorage() : this._(glShaderStorageBuffer);
  GlBufferObject.other(int type) : this._(type);

  GlBufferObject._(this.type) {
    final idPointer = malloc<UnsignedInt>();
    gl.createBuffers(1, idPointer);
    _id = idPointer.value;
    malloc.free(idPointer);
  }

  int get id => _id;

  void upload(BufferWriter data, BufferUsage usage) {
    final size = data.cursor;
    data.array.view(size, (pointer) {
      if (size > _glObjectSize) {
        gl.namedBufferData(_id, size, pointer.cast(), usage.glType);
        _glObjectSize = size;
      } else {
        gl.namedBufferSubData(_id, 0, size, pointer.cast());
      }
    });
  }

  @Deprecated('Use DSA over binding where possible')
  void bind() => gl.bindBuffer(type, _id);
  @Deprecated('Use DSA over binding where possible')
  void unbind() => gl.bindBuffer(type, 0);

  void delete() {
    final idPointer = malloc<UnsignedInt>();
    idPointer.value = _id;
    gl.deleteBuffers(1, idPointer);
    malloc.free(idPointer);
  }
}

class GlVertexArray {
  late final int _id;

  GlVertexArray() {
    final idPointer = calloc<UnsignedInt>();
    gl.createVertexArrays(1, idPointer);
    _id = idPointer.value;
  }

  void draw(int count, {int mode = glTriangles}) {
    bind();
    gl.drawArrays(mode, 0, count);
    unbind();
  }

  void drawInstanced(int count, int instanceCount, {int mode = glTriangles}) {
    bind();
    gl.drawArraysInstanced(mode, 0, count, instanceCount);
    unbind();
  }

  void bind() {
    gl.bindVertexArray(_id);
  }

  void unbind() {
    gl.bindVertexArray(0);
  }

  void delete() {
    final idPointer = malloc<UnsignedInt>();
    idPointer.value = _id;
    gl.deleteVertexArrays(1, idPointer);
    malloc.free(idPointer);
  }
}

final class BufferWriter {
  static final _logger = createLogger('buffer_writer');
  static const _int32Size = Int32List.bytesPerElement;
  static const _uint32Size = Uint32List.bytesPerElement;
  static const _float32Size = Float32List.bytesPerElement;
  static const _float64Size = Float64List.bytesPerElement;

  final ByteArray array;
  int _cursor = 0;

  BufferWriter(this.array);

  int get cursor => _cursor;

  void rewind() {
    _cursor = 0;
  }

  void u32(int a) {
    _ensureCapacity(_uint32Size);

    array.data.setUint32(_cursor, a, Endian.host);
    _cursor += _uint32Size;
  }

  void u32x2(int a, int b) {
    _ensureCapacity(_uint32Size * 2);

    array.data
      ..setUint32(_cursor + _uint32Size * 0, a, Endian.host)
      ..setUint32(_cursor + _uint32Size * 1, b, Endian.host);
    _cursor += _uint32Size * 2;
  }

  void u32x3(int a, int b, int c) {
    _ensureCapacity(_uint32Size * 3);

    array.data
      ..setUint32(_cursor + _uint32Size * 0, a, Endian.host)
      ..setUint32(_cursor + _uint32Size * 1, b, Endian.host)
      ..setUint32(_cursor + _uint32Size * 2, c, Endian.host);
    _cursor += _uint32Size * 3;
  }

  void u32x4(int a, int b, int c, int d) {
    _ensureCapacity(_uint32Size * 4);

    array.data
      ..setUint32(_cursor + _uint32Size * 0, a, Endian.host)
      ..setUint32(_cursor + _uint32Size * 1, b, Endian.host)
      ..setUint32(_cursor + _uint32Size * 2, c, Endian.host)
      ..setUint32(_cursor + _uint32Size * 3, d, Endian.host);
    _cursor += _uint32Size * 4;
  }

  void i32(int a) {
    _ensureCapacity(_int32Size);

    array.data.setInt32(_cursor, a, Endian.host);
    _cursor += _int32Size;
  }

  void i32x2(int a, int b) {
    _ensureCapacity(_int32Size * 2);

    array.data
      ..setInt32(_cursor + _int32Size * 0, a, Endian.host)
      ..setInt32(_cursor + _int32Size * 1, b, Endian.host);
    _cursor += _int32Size * 2;
  }

  void i32x3(int a, int b, int c) {
    _ensureCapacity(_int32Size * 3);

    array.data
      ..setInt32(_cursor + _int32Size * 0, a, Endian.host)
      ..setInt32(_cursor + _int32Size * 1, b, Endian.host)
      ..setInt32(_cursor + _int32Size * 2, c, Endian.host);
    _cursor += _int32Size * 3;
  }

  void i32x4(int a, int b, int c, int d) {
    _ensureCapacity(_int32Size * 4);

    array.data
      ..setInt32(_cursor + _int32Size * 0, a, Endian.host)
      ..setInt32(_cursor + _int32Size * 1, b, Endian.host)
      ..setInt32(_cursor + _int32Size * 2, c, Endian.host)
      ..setInt32(_cursor + _int32Size * 3, d, Endian.host);
    _cursor += _int32Size * 4;
  }

  void f32(double a) {
    _ensureCapacity(_float32Size);

    array.data.setFloat32(_cursor, a, Endian.host);
    _cursor += _float32Size;
  }

  void f32x2(double a, double b) {
    _ensureCapacity(_float32Size * 2);

    array.data
      ..setFloat32(_cursor + _float32Size * 0, a, Endian.host)
      ..setFloat32(_cursor + _float32Size * 1, b, Endian.host);
    _cursor += _float32Size * 2;
  }

  void f32x3(double a, double b, double c) {
    _ensureCapacity(_float32Size * 3);

    array.data
      ..setFloat32(_cursor + _float32Size * 0, a, Endian.host)
      ..setFloat32(_cursor + _float32Size * 1, b, Endian.host)
      ..setFloat32(_cursor + _float32Size * 2, c, Endian.host);
    _cursor += _float32Size * 3;
  }

  void f32x4(double a, double b, double c, double d) {
    _ensureCapacity(_float32Size * 4);

    array.data
      ..setFloat32(_cursor + _float32Size * 0, a, Endian.host)
      ..setFloat32(_cursor + _float32Size * 1, b, Endian.host)
      ..setFloat32(_cursor + _float32Size * 2, c, Endian.host)
      ..setFloat32(_cursor + _float32Size * 3, d, Endian.host);
    _cursor += _float32Size * 4;
  }

  void f64(double f) {
    _ensureCapacity(_float64Size);

    array.data.setFloat64(_cursor, f, Endian.host);
    _cursor += _float64Size;
  }

  void f64x2(double a, double b) {
    _ensureCapacity(_float64Size * 2);

    array.data
      ..setFloat64(_cursor + _float64Size * 0, a, Endian.host)
      ..setFloat64(_cursor + _float64Size * 1, b, Endian.host);
    _cursor += _float64Size * 2;
  }

  void f64x3(double a, double b, double c) {
    _ensureCapacity(_float64Size * 3);

    array.data
      ..setFloat64(_cursor + _float64Size * 0, a, Endian.host)
      ..setFloat64(_cursor + _float64Size * 1, b, Endian.host)
      ..setFloat64(_cursor + _float64Size * 2, c, Endian.host);
    _cursor += _float64Size * 3;
  }

  void f64x4(double a, double b, double c, double d) {
    _ensureCapacity(_float64Size * 4);

    array.data
      ..setFloat64(_cursor + _float64Size * 0, a, Endian.host)
      ..setFloat64(_cursor + _float64Size * 1, b, Endian.host)
      ..setFloat64(_cursor + _float64Size * 2, c, Endian.host)
      ..setFloat64(_cursor + _float64Size * 3, d, Endian.host);
    _cursor += _float64Size * 4;
  }

  void _ensureCapacity(int bytes) {
    if (_cursor + bytes <= array.data.lengthInBytes) return;

    _logger?.fine(
      'Growing BufferWriter $hashCode from ${array.data.lengthInBytes} to ${array.data.lengthInBytes * 2} bytes to fit ${_cursor + bytes}',
    );

    array.resize(array.data.lengthInBytes * 2);
  }
}
