import 'dart:convert';
import 'dart:io';

void writeDebugLog(Map<String, dynamic> logEntry) {
  final logFile = File(r'c:\Users\jl8696\OneDrive - Zebra Technologies\Documents\GitHub\first-robotics-RTLS\.cursor\debug.log');
  try {
    final existingContent = logFile.existsSync() ? logFile.readAsStringSync() : '';
    logFile.writeAsStringSync('$existingContent${jsonEncode(logEntry)}\n', mode: FileMode.append);
  } catch (_) {}
}

