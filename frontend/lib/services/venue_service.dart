import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/venue_map.dart';
import '../utils/debug_logger.dart';

class VenueService extends ChangeNotifier {
  final List<VenueMap> _venues = [];
  VenueMap? _selectedVenue;

  List<VenueMap> get venues => List.unmodifiable(_venues);
  VenueMap? get selectedVenue => _selectedVenue;
  
  // #region agent log
  void _log(String message, Map<String, dynamic> data) {
    debugLog('venue_service.dart', message, data);
  }
  // #endregion

  /// Load available venue maps from assets by scanning the venues directory
  Future<void> loadVenues() async {
    // #region agent log
    _log('loadVenues START', {'selectedVenueId': _selectedVenue?.id, 'selectedVenueName': _selectedVenue?.name, 'venuesCount': _venues.length});
    // #endregion
    try {
      final oldSelectedId = _selectedVenue?.id;
      _venues.clear();
      // #region agent log
      _log('loadVenues CLEARED', {'oldSelectedId': oldSelectedId, 'venuesCount': _venues.length});
      // #endregion
      
      // Try to load AssetManifest.json which Flutter generates during build
      // This file contains a list of all assets in the app
      String manifestContent;
      try {
        // Try loading from root (for web builds)
        manifestContent = await rootBundle.loadString('AssetManifest.json');
      } catch (e) {
        // If that fails, try alternative paths or fall back to venues.json
        print('Could not load AssetManifest.json, trying fallback: $e');
        await _loadVenuesFromManifest();
        return;
      }
      
      final Map<String, dynamic> manifestMap = jsonDecode(manifestContent);
      
      // Filter for assets in the venues directory
      final venueAssets = manifestMap.keys
          .where((String key) => key.startsWith('assets/images/venues/'))
          .where((String key) {
            // Only include image files (png, jpg, jpeg, webp)
            final lowerKey = key.toLowerCase();
            return lowerKey.endsWith('.png') ||
                   lowerKey.endsWith('.jpg') ||
                   lowerKey.endsWith('.jpeg') ||
                   lowerKey.endsWith('.webp');
          })
          .toList()
        ..sort(); // Sort alphabetically
      
      // Create VenueMap objects from discovered assets
      for (final assetPath in venueAssets) {
        final fileName = assetPath.split('/').last;
        final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
        
        // Convert filename to a readable name (e.g., "venue_map_1" -> "Venue Map 1")
        final displayName = _formatVenueName(nameWithoutExt);
        
        final venue = VenueMap(
          id: assetPath, // Use full path as ID for uniqueness
          name: displayName,
          imagePath: assetPath,
        );
        
        // Check for duplicates before adding
        if (!_venues.any((v) => v.id == venue.id)) {
          _venues.add(venue);
        } else {
          // #region agent log
          _log('loadVenues DUPLICATE_SKIPPED', {'venueId': venue.id, 'venueName': venue.name});
          // #endregion
        }
      }
      // #region agent log
      _log('loadVenues LOADED', {'venuesCount': _venues.length, 'venueIds': _venues.map((v) => v.id).toList(), 'oldSelectedId': oldSelectedId});
      // #endregion
      
      // If no venue is selected, select the first one
      if (_selectedVenue == null && _venues.isNotEmpty) {
        _selectedVenue = _venues.first;
        // #region agent log
        _log('loadVenues AUTO_SELECTED', {'selectedId': _selectedVenue?.id});
        // #endregion
      } else if (_selectedVenue != null && oldSelectedId != null) {
        // Check if old selected venue still exists in new list and get the matching instance
        final matchingVenue = _venues.where((v) => v.id == oldSelectedId).firstOrNull;
        // #region agent log
        _log('loadVenues CHECK_EXISTS', {'oldSelectedId': oldSelectedId, 'found': matchingVenue != null});
        // #endregion
        if (matchingVenue != null) {
          // Use the new instance from the list to ensure reference equality
          _selectedVenue = matchingVenue;
        } else {
          // Old selected venue no longer exists, select first or clear
          _selectedVenue = _venues.isNotEmpty ? _venues.first : null;
          // #region agent log
          _log('loadVenues RESET_SELECTION', {'newSelectedId': _selectedVenue?.id});
          // #endregion
        }
      }
      
      notifyListeners();
      // #region agent log
      _log('loadVenues COMPLETE', {'selectedVenueId': _selectedVenue?.id, 'venuesCount': _venues.length});
      // #endregion
    } catch (e) {
      print('Error loading venues: $e');
      // If AssetManifest.json doesn't exist or can't be loaded,
      // try loading a fallback venues.json manifest file
      await _loadVenuesFromManifest();
    }
  }

  /// Fallback: Load venues from a custom venues.json manifest file
  Future<void> _loadVenuesFromManifest() async {
    try {
      final manifestContent = await rootBundle.loadString('assets/configs/venues.json');
      final List<dynamic> venuesList = jsonDecode(manifestContent);
      
      _venues.clear();
      for (final venueJson in venuesList) {
        _venues.add(VenueMap.fromJson(venueJson));
      }
      
      if (_selectedVenue == null && _venues.isNotEmpty) {
        _selectedVenue = _venues.first;
      }
      
      notifyListeners();
    } catch (e) {
      print('Error loading venues from manifest: $e');
      // If all else fails, ensure we have at least an empty list
      _venues.clear();
      notifyListeners();
    }
  }

  /// Format venue filename into a readable display name
  /// Examples:
  /// "venue1" -> "Venue 1"
  /// "venue_map_1" -> "Venue Map 1"
  /// "stadium_main" -> "Stadium Main"
  String _formatVenueName(String name) {
    // Replace underscores and hyphens with spaces
    String formatted = name.replaceAll('_', ' ').replaceAll('-', ' ');
    
    // Split into words and capitalize each word
    final words = formatted.split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) {
          // Capitalize first letter, lowercase the rest
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .toList();
    
    return words.join(' ');
  }

  /// Add a new venue
  void addVenue(VenueMap venue) {
    _venues.add(venue);
    notifyListeners();
  }

  /// Select a venue
  void selectVenue(VenueMap venue) {
    // #region agent log
    _log('selectVenue', {'venueId': venue.id, 'venueName': venue.name, 'venuesCount': _venues.length, 'venueInList': _venues.any((v) => v.id == venue.id)});
    // #endregion
    _selectedVenue = venue;
    notifyListeners();
  }

  /// Select venue by ID
  void selectVenueById(String venueId) {
    final venue = _venues.firstWhere(
      (v) => v.id == venueId,
      orElse: () => _venues.first,
    );
    selectVenue(venue);
  }
}

