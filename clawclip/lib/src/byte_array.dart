import 'dart:ffi';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

/// A resizable byte array. The allocation strategy is dicated by subclasses
/// like [ManagedByteArray] and [NativeByteArray]. All subclasses must provide
/// normal garbage collection semantics on a best-effort basis and document
/// when this is not the case.
///
/// Crucially, this class can provide a temporary FFI native pointer through
/// [view] for, e.g. exporting the memory to OpenGL and other native APIs.
///
/// In most situations [NativeByteArray] is preferable since it is backed by
/// a native allocation and thus does not require copying its contents when
/// making them available through [view]. [ManagedByteArray] should generally
/// only be used when the array must be sent across isolates.
abstract class ByteArray {
  ByteArray({required int size});

  /// A writable view over the data managed by this array. The value this
  /// returns is cached internally but may change (especially upon [resize])
  /// and must thus not be cached externally
  ByteData get data;

  /// Create a pointer which is valid for accessing up to [size] bytes of
  /// this array, at the optional [offset], and invoke [withView] with it.
  ///
  /// The pointer is only valid for the duration of the call to [withView].
  @mustBeOverridden
  @mustCallSuper
  void view(int size, void Function(Pointer<Uint8> pointer) withView, {int offset = 0}) {
    assert(offset + size <= data.lengthInBytes);
  }

  void resize(int newSize);
}

/// A byte array which maintains
final class ManagedByteArray extends ByteArray {
  ByteData _array;

  ManagedByteArray({required super.size}) : _array = ByteData(size);

  @override
  ByteData get data => _array;

  @override
  void view(int size, void Function(Pointer<Uint8> pointer) withView, {int offset = 0}) {
    super.view(size, withView, offset: offset);

    final pointer = malloc<Uint8>(size);
    pointer.asTypedList(size).setRange(0, size, _array.buffer.asUint8List(offset));

    try {
      withView(pointer);
    } finally {
      malloc.free(pointer);
    }
  }

  @override
  void resize(int newSize) {
    final newArray = ByteData(newSize);
    newArray.buffer.asUint8List().setRange(0, min(newSize, _array.lengthInBytes), _array.buffer.asUint8List());
    _array = newArray;
  }
}

final class NativeByteArray extends ByteArray implements Finalizable {
  Pointer<Uint8> _pointer;
  ByteData _view;

  NativeByteArray._(this._pointer, this._view) : super(size: _view.lengthInBytes) {
    _finalizer.attach(this, _pointer.cast(), detach: this, externalSize: _view.lengthInBytes);
  }

  factory NativeByteArray({required int size}) {
    final pointer = malloc<Uint8>(size);
    final view = pointer.asTypedList(size).buffer.asByteData();

    return NativeByteArray._(pointer, view);
  }

  @override
  ByteData get data => _view;

  @override
  void view(int size, void Function(Pointer<Uint8> pointer) withView, {int offset = 0}) {
    super.view(size, withView, offset: offset);
    withView(offset == 0 ? _pointer : _pointer + offset);
  }

  @override
  void resize(int newSize) {
    final newPointer = malloc<Uint8>(newSize);
    newPointer.asTypedList(newSize).setRange(0, min(newSize, _view.lengthInBytes), _view.buffer.asUint8List());

    _finalizer.detach(this);
    malloc.free(_pointer);

    _pointer = newPointer;
    _finalizer.attach(this, _pointer.cast(), detach: this, externalSize: newSize);

    _view = _pointer.asTypedList(newSize).buffer.asByteData();
  }

  // ---

  static final _finalizer = NativeFinalizer(malloc.nativeFree);
}
