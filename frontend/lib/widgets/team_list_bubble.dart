import 'package:flutter/material.dart';
import '../models/team_location.dart';

class TeamListBubble extends StatelessWidget {
  final String readerName;
  final List<TeamLocation> teamLocations;
  final Offset pinPosition;

  const TeamListBubble({
    super.key,
    required this.readerName,
    required this.teamLocations,
    required this.pinPosition,
  });

  /// Calculate bubble position to avoid screen edges
  Offset _calculateBubblePosition(BuildContext context, Size bubbleSize) {
    final screenSize = MediaQuery.of(context).size;
    const padding = 16.0;
    const pinHeight = 24.0;
    const spacing = 8.0;

    double x = pinPosition.dx - bubbleSize.width / 2;
    double y = pinPosition.dy - bubbleSize.height - pinHeight / 2 - spacing;

    // Adjust if too close to left edge
    if (x < padding) {
      x = padding;
    }
    // Adjust if too close to right edge
    if (x + bubbleSize.width > screenSize.width - padding) {
      x = screenSize.width - bubbleSize.width - padding;
    }
    // Adjust if too close to top edge (show below pin instead)
    if (y < padding) {
      y = pinPosition.dy + pinHeight / 2 + spacing;
    }
    // Adjust if too close to bottom edge
    if (y + bubbleSize.height > screenSize.height - padding) {
      y = screenSize.height - bubbleSize.height - padding;
    }

    return Offset(x, y);
  }

  /// Get color intensity based on recency
  Color _getTeamColor(TeamLocation location) {
    final now = DateTime.now();
    final difference = now.difference(location.timestamp);
    
    if (difference.inMinutes < 2) {
      return Colors.red.shade700; // Most recent - darkest red
    } else if (difference.inMinutes < 4) {
      return Colors.red.shade400; // Recent - medium red
    } else if (difference.inMinutes < 6) {
      return Colors.red.shade300; // Less recent - light red
    } else {
      return Colors.red.shade200; // Oldest - very light red
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort by timestamp (most recent first)
    final sortedLocations = List<TeamLocation>.from(teamLocations)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (sortedLocations.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bubbleSize = Size(250, 50 + (sortedLocations.length * 40.0));
        final position = _calculateBubblePosition(context, bubbleSize);

        return Positioned(
          left: position.dx,
          top: position.dy,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: bubbleSize.width,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            readerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Table
                  Flexible(
                    child: SingleChildScrollView(
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1),
                          1: FlexColumnWidth(1.5),
                        },
                        children: [
                          // Header row
                          TableRow(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                            ),
                            children: const [
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Teams',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Last Seen',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Data rows
                          ...sortedLocations.map((location) {
                            return TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    location.teamNumber,
                                    style: TextStyle(
                                      color: _getTeamColor(location),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    location.relativeTime,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

