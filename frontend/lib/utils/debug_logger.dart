// Conditional imports for platform-specific logging
import 'debug_logger_stub.dart' if (dart.library.io) 'debug_logger_io.dart' if (dart.library.html) 'debug_logger_web.dart';

void debugLog(String location, String message, Map<String, dynamic> data, {String? hypothesisId}) {
  final logEntry = {
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'location': location,
    'message': message,
    'data': data,
    'sessionId': 'debug-session',
    'runId': 'run1',
    if (hypothesisId != null) 'hypothesisId': hypothesisId,
  };
  
  writeDebugLog(logEntry);
}
