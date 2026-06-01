import 'package:collection/collection.dart';
import 'package:ffigen/ffigen.dart';

enum Prefix { upper, lower, none }

class FfigenRenamer {
  final List<String> prefixes;
  final List<String> prefixesUpper;
  final List<String> prefixesLower;

  final RegExp namePattern;

  final Map<RegExp, String> replacements;

  FfigenRenamer(List<String> prefixes, {this.replacements = const {}})
    : prefixesUpper = prefixes.map((e) => e.toUpperCase()).sortedBy((element) => -element.length).toList(),
      prefixesLower = prefixes.map((e) => e.toLowerCase()).sortedBy((element) => -element.length).toList(),
      namePattern = RegExp('(?:${prefixes.join('|')})_(.*)'),
      prefixes = prefixes.sortedBy((element) => -element.length);

  bool isValidName(Declaration declaration) => namePattern.hasMatch(declaration.originalName);

  String Function(Declaration) fixDeclaration(Prefix prefix) {
    final fixer = fixName(prefix);
    return (declaration) => fixer(declaration.originalName);
  }

  String Function(String) fixName(Prefix prefix) => (name) {
    for (final MapEntry(key: pattern, value: replacement) in replacements.entries) {
      var match = pattern.matchAsPrefix(name);
      if (match == null) continue;

      name = replacement.replaceAllMapped(argPattern, (argMatch) => match[int.parse(argMatch[1]!)]!);
    }

    var prefixIdx = prefixes.indexed.firstWhereOrNull((prefix) => name.startsWith(prefix.$2))?.$1;

    final extractedName = namePattern.matchAsPrefix(name)?[1] ?? name;
    final nameParts = extractedName
        .replaceAllMapped(camelBoundaryPattern, (match) => '${match[1]!}_${match[2]!}')
        .split('_');

    final pascal = nameParts.map((e) {
      final lower = e.toLowerCase();
      return lower.length > 1 ? lower[0].toUpperCase() + lower.substring(1) : lower.toUpperCase();
    }).join();
    return switch (prefix) {
      .upper => '${prefixIdx != null ? prefixesUpper[prefixIdx] : ''}$pascal',
      .lower => '${prefixIdx != null ? prefixesLower[prefixIdx] : ''}$pascal',
      .none => pascal[0].toLowerCase() + pascal.substring(1),
    };
  };

  // ---

  static final camelBoundaryPattern = RegExp(r'([a-z\d])([A-Z\d])');
  static final underscorePattern = RegExp('_(.)');
  static final argPattern = RegExp(r'\$(\d+)');
}
