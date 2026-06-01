import 'package:vector_math/vector_math.dart';

class Color {
  final double r, g, b, a;

  static const Color black = Color.rgb(0x000000);
  static const Color white = Color.rgb(0xFFFFFF);
  static const Color red = Color.rgb(0xFF0000);
  static const Color green = Color.rgb(0x00FF00);
  static const Color blue = Color.rgb(0x0000FF);

  const Color(int argb)
      : this.values(((argb >> 16) & 0xFF) / 255, ((argb >> 8) & 0xFF) / 255, (argb & 0xFF) / 255, (argb >>> 24) / 255);

  const Color.rgb(int rgb) : this.values(((rgb >> 16) & 0xFF) / 255, ((rgb >> 8) & 0xFF) / 255, (rgb & 0xFF) / 255);

  const Color.values(this.r, this.g, this.b, [this.a = 1]);

  Color.ofVector(Vector4 color) : this.values(color.r, color.g, color.b, color.a);

  factory Color.ofHsv(double hue, double saturation, double value, [double alpha = 1]) {
    final rgbColor = Vector4(hue, saturation, value, alpha);
    Colors.hsvToRgb(rgbColor, rgbColor);
    return Color.ofVector(rgbColor);
  }

  int get rgb => (r * 255).toInt() << 16 | (g * 255).toInt() << 8 | (b * 255).toInt();

  int get argb => (a * 255).toInt() << 24 | (r * 255).toInt() << 16 | (g * 255).toInt() << 8 | (b * 255).toInt();

  Vector4 get hsv {
    final hsv = asVector();
    Colors.rgbToHsv(hsv, hsv);

    return hsv;
  }

  Color copyWith({double? r, double? g, double? b, double? a}) =>
      Color.values(r ?? this.r, g ?? this.g, b ?? this.b, a ?? this.a);

  Vector4 asVector() => Vector4(r, g, b, a);

  String toHexString(bool alpha) {
    return alpha ? argb.toRadixString(16).padLeft(8, '0') : rgb.toRadixString(16).padLeft(6, '0');
  }

  @override
  int get hashCode => Object.hash(r, g, b, a);

  @override
  bool operator ==(Object other) => other is Color && other.r == r && other.g == g && other.b == b && other.a == a;
}
