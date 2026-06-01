import 'dart:math';

import 'package:benchmark_harness/benchmark_harness.dart';

final _random = Random();

final a = _random.nextInt(256);
final b = _random.nextInt(256);
final c = _random.nextInt(256);
final d = _random.nextInt(256);
final e = _random.nextInt(256);

class RecordBenchmark extends BenchmarkBase {
  RecordBenchmark() : super('records');

  @override
  void run() {
    final result = a + b + c + d + e;
    if (result != calculate((a: a, b: b, c: c, d: d, e: e))) {
      throw AssertionError('bruh');
    }
  }

  @pragma('vm:never-inline')
  int calculate(({int a, int b, int c, int d, int e}) args) {
    return args.a + args.b + args.c + args.d + args.e;
  }
}

class FuncBenchmark extends BenchmarkBase {
  FuncBenchmark() : super('funcs');

  @override
  void run() {
    final result = a + b + c + d + e;
    if (result != calculate(a, b, c, d, e)) {
      throw AssertionError('bruh');
    }
  }

  @pragma('vm:never-inline')
  int calculate(int a, int b, int c, int d, int e) {
    return a + b + c + d + e;
  }
}

void main(List<String> args) {
  FuncBenchmark().report();
  RecordBenchmark().report();
}
