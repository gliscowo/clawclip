import 'package:logging/logging.dart';

import 'debug.dart';

class GlLoggingConfig {
  final bool Function(GlMessageType type, GlSeverity severity) messageFilter;
  final bool printStacktraces;

  const GlLoggingConfig({this.messageFilter = _severityLowAllTypes, this.printStacktraces = false});

  static bool _severityLowAllTypes(GlMessageType type, GlSeverity severity) => severity >= .low;
  static const severityLowAllTypesNoStacktraces = GlLoggingConfig();
}

typedef ClawclipLoggingConfig = ({Logger? baseLogger, GlLoggingConfig? glConfig});

// ---

ClawclipLoggingConfig? _loggingConfig;
ClawclipLoggingConfig? get clawlipLoggingConfig => _loggingConfig;

void clawclipSetupLoggingInIsolate({Logger? baseLogger, GlLoggingConfig? glConfig}) {
  assert(_loggingConfig == null, 'attempted to configure clawclip logging twice');
  _loggingConfig = (baseLogger: baseLogger, glConfig: glConfig);
}

// ---

Logger? createLogger(String system) {
  if (clawlipLoggingConfig?.baseLogger == null) return null;
  return Logger('${clawlipLoggingConfig!.baseLogger!.name}.$system');
}
