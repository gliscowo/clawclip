import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

const supportedOperatingSystems = {OS.linux};
const supportedArchitectures = {Architecture.x64};

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    output.assets.code.add(
      CodeAsset(package: input.packageName, name: 'sdl3', linkMode: DynamicLoadingSystem(.file('libSDL3.so.0'))),
    );
  });
}
