class TeamLocation {
  final String teamNumber;
  final String readerName;
  final DateTime timestamp;

  TeamLocation({
    required this.teamNumber,
    required this.readerName,
    required this.timestamp,
  });

  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ${difference.inSeconds % 60}s ago';
    } else {
      return '${difference.inSeconds}s ago';
    }
  }

  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inMinutes < 5;
  }
}

