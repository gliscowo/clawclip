import 'package:test/test.dart';

import '../lib/src/byte_array.dart';

void main() {
  test('native byte array alloc and resize', () {
    final array = NativeByteArray(size: 64);
    array.data.buffer.asUint8List()[16] = 123;
    array.resize(32);
    expect(array.data.buffer.asUint8List()[16], 123);
    array.resize(128);
    expect(array.data.buffer.asUint8List()[16], 123);
  });

  test('managed byte array alloc and resize', () {
    final array = ManagedByteArray(size: 64);
    array.data.buffer.asUint8List()[16] = 123;
    array.resize(32);
    expect(array.data.buffer.asUint8List()[16], 123);
    array.resize(128);
    expect(array.data.buffer.asUint8List()[16], 123);
  });

  test('view bounds checks', () {
    final managed = ManagedByteArray(size: 64);
    final native = NativeByteArray(size: 64);

    managed.view(64, (_) {});
    native.view(64, (_) {});

    expect(() => managed.view(65, (_) {}), throwsA(isA<AssertionError>()));
    expect(() => native.view(65, (_) {}), throwsA(isA<AssertionError>()));

    managed.view(32, (_) {}, offset: 32);
    native.view(32, (_) {}, offset: 32);

    expect(() => managed.view(32, (_) {}, offset: 34), throwsA(isA<AssertionError>()));
    expect(() => native.view(32, (_) {}, offset: 34), throwsA(isA<AssertionError>()));
  });
}
