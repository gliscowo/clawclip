import 'package:clawclip/clawclip.dart';
import 'package:clawclip_opengl/clawclip_opengl.dart';
import 'package:vector_math/vector_math.dart' as v32;

import 'clawclip_logging.dart';

enum VertexAttributePrimitive {
  u32(4, glUnsignedInt),
  i32(4, glInt),
  f32(4, glFloat),
  f64(8, glDouble);

  final int sizeInBytes;
  final int glType;
  const VertexAttributePrimitive(this.sizeInBytes, this.glType);
}

typedef Int32x1 = int;
typedef Int32x2 = ({int x, int y});
typedef Int32x3 = ({int x, int y, int z});
typedef Int32x4 = ({int x, int y, int z, int w});

class VertexAttribute<Vertex> {
  final String name;
  final VertexAttributePrimitive primitive;
  final int length;

  final void Function(BufferWriter buffer, Vertex vertex) serializer;

  VertexAttribute._(this.name, this.primitive, this.length, this.serializer);

  factory VertexAttribute.u32({required String name, required Int32x1 Function(Vertex vertex) getter}) =>
      VertexAttribute._(name, .u32, 1, (buffer, vertex) => buffer.u32(getter(vertex)));
  factory VertexAttribute.u32x2({required String name, required Int32x2 Function(Vertex vertex) getter}) =>
      VertexAttribute._(name, .u32, 2, (buffer, vertex) {
        final Int32x2(:x, :y) = getter(vertex);
        buffer.u32x2(x, y);
      });
  factory VertexAttribute.u32x3({required String name, required Int32x3 Function(Vertex vertex) getter}) =>
      VertexAttribute._(name, .u32, 3, (buffer, vertex) {
        final Int32x3(:x, :y, :z) = getter(vertex);
        buffer.u32x3(x, y, z);
      });
  factory VertexAttribute.u32x4({required String name, required Int32x4 Function(Vertex vertex) getter}) =>
      VertexAttribute._(name, .u32, 4, (buffer, vertex) {
        final Int32x4(:x, :y, :z, :w) = getter(vertex);
        buffer.u32x4(x, y, z, w);
      });

  factory VertexAttribute.i32({required String name, required Int32x1 Function(Vertex vertex) getter}) =>
      VertexAttribute._(name, .i32, 1, (buffer, vertex) => buffer.i32(getter(vertex)));
  factory VertexAttribute.i32x2({required String name, required Int32x2 Function(Vertex vertex) getter}) =>
      VertexAttribute._(name, .i32, 2, (buffer, vertex) {
        final Int32x2(:x, :y) = getter(vertex);
        buffer.i32x2(x, y);
      });
  factory VertexAttribute.i32x3({required String name, required Int32x3 Function(Vertex vertex) getter}) =>
      VertexAttribute._(name, .i32, 3, (buffer, vertex) {
        final Int32x3(:x, :y, :z) = getter(vertex);
        buffer.i32x3(x, y, z);
      });
  factory VertexAttribute.i32x4({required String name, required Int32x4 Function(Vertex vertex) getter}) =>
      VertexAttribute._(name, .i32, 4, (buffer, vertex) {
        final Int32x4(:x, :y, :z, :w) = getter(vertex);
        buffer.i32x4(x, y, z, w);
      });

  factory VertexAttribute.f32({required String name, required double Function(Vertex vertex) getter}) =>
      VertexAttribute._(name, .f32, 1, (buffer, vertex) => buffer.f32(getter(vertex)));
  factory VertexAttribute.f32x2({required String name, required v32.Vector2 Function(Vertex vertex) getter}) =>
      VertexAttribute._(name, .f32, 2, (buffer, vertex) {
        final v32.Vector2(:x, :y) = getter(vertex);
        buffer.f32x2(x, y);
      });
  factory VertexAttribute.f32x3({required String name, required v32.Vector3 Function(Vertex vertex) getter}) =>
      VertexAttribute._(name, .f32, 3, (buffer, vertex) {
        final v32.Vector3(:x, :y, :z) = getter(vertex);
        buffer.f32x3(x, y, z);
      });
  factory VertexAttribute.f32x4({required String name, required v32.Vector4 Function(Vertex vertex) getter}) =>
      VertexAttribute._(name, .f32, 4, (buffer, vertex) {
        final v32.Vector4(:x, :y, :z, :w) = getter(vertex);
        buffer.f32x4(x, y, z, w);
      });

  factory VertexAttribute.f64({required String name, required double Function(Vertex vertex) getter}) =>
      VertexAttribute._(name, .f64, 1, (buffer, vertex) => buffer.f64(getter(vertex)));
  factory VertexAttribute.f64x2({required String name, required v32.Vector2 Function(Vertex vertex) getter}) =>
      VertexAttribute._(name, .f64, 2, (buffer, vertex) {
        final v32.Vector2(:x, :y) = getter(vertex);
        buffer.f64x2(x, y);
      });
  factory VertexAttribute.f64x3({required String name, required v32.Vector3 Function(Vertex vertex) getter}) =>
      VertexAttribute._(name, .f64, 3, (buffer, vertex) {
        final v32.Vector3(:x, :y, :z) = getter(vertex);
        buffer.f64x3(x, y, z);
      });
  factory VertexAttribute.f64x4({required String name, required v32.Vector4 Function(Vertex vertex) getter}) =>
      VertexAttribute._(name, .f64, 4, (buffer, vertex) {
        final v32.Vector4(:x, :y, :z, :w) = getter(vertex);
        buffer.f64x4(x, y, z, w);
      });

  factory VertexAttribute.color({required String name, required Color Function(Vertex vertex) getter}) =>
      VertexAttribute._(name, .f32, 4, (buffer, vertex) {
        final Color(:r, :g, :b, :a) = getter(vertex);
        buffer.f32x4(r, g, b, a);
      });

  VertexAttribute.direct({
    required String name,
    required VertexAttributePrimitive primitive,
    required int length,
    required void Function(BufferWriter buffer, Vertex vertex) serializer,
  }) : this._(name, primitive, length, serializer);
}

class VertexDescriptor<Vertex> {
  static final _logger = createLogger('vertex_descriptor');
  static final _missingAttrs = Expando<Set<String>>();

  final List<VertexAttribute<Vertex>> _attributes;
  final List<int> _attributeOffsets;
  final int vertexSize;

  VertexDescriptor._(this._attributeOffsets, this._attributes, this.vertexSize);

  factory VertexDescriptor(List<VertexAttribute<Vertex>> attributes) {
    assert(attributes.isNotEmpty, 'A vertex descriptor must declare at least one attribute');

    final attributeOffsets = <int>[];
    var vertexSize = 0;

    for (final VertexAttribute(:primitive, :length) in attributes) {
      attributeOffsets.add(vertexSize);
      vertexSize += primitive.sizeInBytes * length;
    }

    return VertexDescriptor._(attributeOffsets, attributes, vertexSize);
  }

  void serialize(BufferWriter buffer, List<Vertex> vertices) {
    for (final vertex in vertices) {
      for (final attribute in _attributes) {
        attribute.serializer(buffer, vertex);
      }
    }
  }

  void prepareAttributes(int vao, GlProgram program) {
    for (final (idx, attr) in _attributes.indexed) {
      final location = program.getAttributeLocation(attr.name);
      if (location == -1 && _isKnownToMissAttr(program, attr.name)) {
        _logger?.warning('Did not find attribute "${attr.name}" in program "${program.name}"');
        _markMissingAttr(program, attr.name);

        continue;
      }

      gl.enableVertexArrayAttrib(vao, location);
      gl.vertexArrayAttribBinding(vao, location, 0);
      gl.vertexArrayAttribFormat(vao, location, attr.length, attr.primitive.glType, glFalse, _attributeOffsets[idx]);
    }
  }

  static bool _isKnownToMissAttr(GlProgram program, String attr) => !(_missingAttrs[program]?.contains(attr) ?? false);
  static void _markMissingAttr(GlProgram program, String attr) => (_missingAttrs[program] ??= <String>{}).add(attr);
}
