import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart';

void writeDebugLog(Map<String, dynamic> logEntry) {
  try {
    final headers = Headers();
    headers.set('Content-Type', 'application/json');
    
    final url = 'http://127.0.0.1:7243/ingest/5fd47289-8f29-4f7e-95a0-476d147a98d2';
    final body = jsonEncode(logEntry);
    
    window.fetch(
      url.toJS,
      RequestInit(
        method: 'POST',
        headers: headers,
        body: body.toJS,
      ),
    ).toDart.catchError((_) {
      // Ignore errors - logging should not break the app
      return Future<Response>.value(Response());
    });
  } catch (_) {
    // Ignore errors - logging should not break the app
  }
}

