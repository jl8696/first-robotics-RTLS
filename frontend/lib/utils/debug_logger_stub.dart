import 'dart:convert';

void writeDebugLog(Map<String, dynamic> logEntry) {
  // Stub implementation - does nothing
  // This is used when neither dart:io nor dart:html are available
  print('DEBUG LOG: ${jsonEncode(logEntry)}');
}



