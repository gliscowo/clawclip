import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:vector_math/vector_math.dart';

class SimdVectorAddition extends BenchmarkBase {
  SimdVectorAddition() : super('simd addition');

  var a = Float32x4(1, 2, 3, 4);
  final b = Float32x4(5, 6, 7, 8);

  @override
  void run() {
    for (var i = 0; i < 100; i++) {
      a = a + b;
    }
  }
}

class NormalVectorAddition extends BenchmarkBase {
  NormalVectorAddition() : super('normal addition');

  var a = Vector4(1, 2, 3, 4);
  final b = Vector4(5, 6, 7, 8);

  @override
  void run() {
    for (var i = 0; i < 100; i++) {
      a = a + b;
    }
  }
}

void main(List<String> args) {
  SimdVectorAddition().report();
  NormalVectorAddition().report();
}
