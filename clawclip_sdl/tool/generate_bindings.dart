import 'dart:io';

import 'package:ffigen/ffigen.dart';
import 'package:path/path.dart';

import 'ffigen_utils.dart';

void main(List<String> args) {
  var [sdlIncludePath, ...] = args;
  sdlIncludePath = absolute(sdlIncludePath);

  final packageRoot = Platform.script.resolve('../');
  final renamer = FfigenRenamer(const ['SDL', 'SDLK']);

  FfiGenerator(
    headers: Headers(
      entryPoints: [Uri.file(sdlIncludePath).resolve('SDL3/SDL.h')],
      include: (header) => !header.path.endsWith('SDL_oldnames.h'),
      compilerOptions: ['-I$sdlIncludePath'],
    ),
    macros: Macros(include: renamer.isValidName, rename: renamer.fixDeclaration(.lower)),
    functions: Functions(include: renamer.isValidName, rename: renamer.fixDeclaration(.lower)),
    structs: Structs(include: renamer.isValidName, rename: renamer.fixDeclaration(.upper)),
    unions: Unions(include: renamer.isValidName, rename: renamer.fixDeclaration(.upper)),
    enums: Enums(
      include: renamer.isValidName,
      rename: renamer.fixDeclaration(.upper),
      renameMember: (_, member) => renamer.fixName(.none)(member),
      style: (declaration, suggestedStyle) => declaration.originalName == 'SDL_EventType' ? .intConstants : .dartEnum,
    ),
    output: Output(
      dartFile: packageRoot.resolve('lib/src/sdl.g.dart'),
      style: const NativeExternalBindings(assetId: 'package:clawclip_sdl/sdl3'),
      commentType: const CommentType(.doxygen, .brief),
    ),
  ).generate();
}
