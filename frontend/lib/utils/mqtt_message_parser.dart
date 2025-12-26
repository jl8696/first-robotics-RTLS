import 'dart:convert';
import '../models/team_location.dart';

class MQTTMessageParser {
  /// Parse MQTT message JSON and convert to map of reader names to team locations
  static Map<String, List<TeamLocation>> parseMessage(String jsonString) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      
      final Map<String, List<TeamLocation>> result = {};

      data.forEach((readerName, teams) {
        if (teams is Map) {
          final List<TeamLocation> locations = [];
          
          teams.forEach((teamNumber, timestampStr) {
            try {
              final timestamp = _parseTimestamp(timestampStr.toString());
              locations.add(TeamLocation(
                teamNumber: teamNumber.toString(),
                readerName: readerName,
                timestamp: timestamp,
              ));
            } catch (e) {
              // Skip invalid timestamps
              print('Error parsing timestamp for team $teamNumber: $e');
            }
          });
          
          result[readerName] = locations;
        }
      });

      return result;
    } catch (e) {
      print('Error parsing MQTT message: $e');
      return {};
    }
  }

  /// Parse timestamp string in format "MM-dd-yyyy HH:mm:ss:SSS" or "MM-dd-yyyy HH:mm:ss.SSS"
  static DateTime _parseTimestamp(String timestampStr) {
    // Handle both colon and dot separators for milliseconds
    String normalized = timestampStr.replaceAll('.', ':');
    
    // Format: "MM-dd-yyyy HH:mm:ss:SSS"
    final parts = normalized.split(' ');
    if (parts.length != 2) {
      throw FormatException('Invalid timestamp format: $timestampStr');
    }

    final datePart = parts[0].split('-');
    final timePart = parts[1].split(':');

    if (datePart.length != 3 || timePart.length < 3) {
      throw FormatException('Invalid timestamp format: $timestampStr');
    }

    final month = int.parse(datePart[0]);
    final day = int.parse(datePart[1]);
    final year = int.parse(datePart[2]);
    final hour = int.parse(timePart[0]);
    final minute = int.parse(timePart[1]);
    final second = int.parse(timePart[2]);
    final millisecond = timePart.length > 3 ? int.parse(timePart[3]) : 0;

    return DateTime(year, month, day, hour, minute, second, millisecond);
  }
}

