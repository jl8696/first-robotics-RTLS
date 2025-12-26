import 'package:flutter/material.dart';
import '../models/team_location.dart';

class ReaderPinWidget extends StatelessWidget {
  final String readerName;
  final List<TeamLocation>? teamLocations;
  final VoidCallback onTap;
  final bool isSelected;

  const ReaderPinWidget({
    super.key,
    required this.readerName,
    this.teamLocations,
    required this.onTap,
    this.isSelected = false,
  });

  bool get hasRecentActivity {
    if (teamLocations == null || teamLocations!.isEmpty) {
      return false;
    }
    return teamLocations!.any((location) => location.isRecent);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pin shadow
          Positioned(
            bottom: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Main pin
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: hasRecentActivity ? Colors.red : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.white,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                readerName.length > 2 
                    ? readerName.substring(0, 2).toUpperCase()
                    : readerName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Activity indicator
          if (hasRecentActivity)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green,
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

