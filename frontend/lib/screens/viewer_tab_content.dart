import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reader_config.dart';
import '../models/venue_map.dart';
import '../services/config_service.dart';
import '../services/mqtt_service.dart';
import '../services/venue_service.dart';
import '../utils/debug_logger.dart';
import '../widgets/venue_map_widget.dart';
import '../widgets/reader_pin_widget.dart';
import '../widgets/team_list_bubble.dart';

class ViewerTabContent extends StatefulWidget {
  const ViewerTabContent({super.key});

  @override
  State<ViewerTabContent> createState() => _ViewerTabContentState();
}

class _ViewerTabContentState extends State<ViewerTabContent> {
  String? _selectedReaderName;
  Timer? _updateTimer;
  bool _isDisposed = false;

  // #region agent log
  void _log(String message, Map<String, dynamic> data) {
    debugLog('viewer_tab_content.dart', message, data, hypothesisId: 'C');
  }
  // #endregion

  @override
  void initState() {
    super.initState();
    // #region agent log
    _log('initState START', {'mounted': mounted, 'isDisposed': _isDisposed});
    // #endregion
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // #region agent log
      _log('addPostFrameCallback EXECUTED', {'mounted': mounted, 'isDisposed': _isDisposed});
      // #endregion
      if (_isDisposed || !mounted) {
        // #region agent log
        _log('addPostFrameCallback SKIPPED', {'mounted': mounted, 'isDisposed': _isDisposed});
        // #endregion
        return;
      }
      final venueService = Provider.of<VenueService>(context, listen: false);
      final configService = Provider.of<ConfigService>(context, listen: false);
      final mqttService = Provider.of<MQTTService>(context, listen: false);
      
      venueService.loadVenues();
      configService.loadConfigs();
      
      // Connect to MQTT (works on both mobile and web)
      mqttService.connect().then((connected) {
        // #region agent log
        _log('mqttService.connect COMPLETED', {'mounted': mounted, 'isDisposed': _isDisposed, 'connected': connected});
        // #endregion
        if (connected && mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connected to MQTT broker'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to connect to MQTT broker${kIsWeb ? ' (check WebSocket URL)' : ''}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });

      // Set up periodic updates for relative time display
      _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        // #region agent log
        _log('Timer FIRED', {'mounted': mounted, 'isDisposed': _isDisposed});
        // #endregion
        if (mounted && !_isDisposed) {
          setState(() {
            // Trigger rebuild to update relative times
          });
        } else {
          // #region agent log
          _log('Timer SKIPPED setState', {'mounted': mounted, 'isDisposed': _isDisposed});
          // #endregion
        }
      });
    });
  }

  @override
  void dispose() {
    // #region agent log
    _log('dispose START', {'mounted': mounted, 'isDisposed': _isDisposed, 'timerActive': _updateTimer != null});
    // #endregion
    _isDisposed = true;
    _updateTimer?.cancel();
    // #region agent log
    _log('dispose Timer CANCELLED', {'mounted': mounted});
    // #endregion
    super.dispose();
    // #region agent log
    _log('dispose COMPLETE', {});
    // #endregion
  }

  void _showMQTTSettings(BuildContext context, MQTTService mqttService) {
    final brokerController = TextEditingController(text: 'localhost');
    final portController = TextEditingController(text: '8083');
    final clientIdController = TextEditingController(text: 'rtls_flutter_client');
    final topicController = TextEditingController(text: 'Robot Locations');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('MQTT Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: brokerController,
                decoration: const InputDecoration(
                  labelText: 'Broker',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: clientIdController,
                decoration: const InputDecoration(
                  labelText: 'Client ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: topicController,
                decoration: const InputDecoration(
                  labelText: 'Topic',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Capture the State's context before async operations
              final scaffoldContext = this.context;
              
              mqttService.configure(
                broker: brokerController.text,
                port: int.tryParse(portController.text) ?? 8083,
                clientId: clientIdController.text,
                topic: topicController.text,
              );
              
              await mqttService.disconnect();
              final connected = await mqttService.connect();
              
              // Check if the dialog context is still valid before using it
              if (!context.mounted) return;
              
              Navigator.of(context).pop();
              
              // Check if the State is still mounted before using its context
              if (!mounted) return;
              
              ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                SnackBar(
                  content: Text(
                    connected
                        ? 'MQTT settings updated and connected'
                        : 'Failed to connect with new settings',
                  ),
                  backgroundColor: connected ? Colors.green : Colors.red,
                ),
              );
            },
            child: const Text('Save & Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<VenueService, ConfigService, MQTTService>(
      builder: (context, venueService, configService, mqttService, child) {
        final selectedVenue = venueService.selectedVenue;
        final venues = venueService.venues;
        
        // Find matching venue instance from current list
        VenueMap? dropdownValue;
        if (selectedVenue != null && venues.isNotEmpty) {
          try {
            dropdownValue = venues.firstWhere(
              (v) => v.id == selectedVenue.id,
              orElse: () => venues.first,
            );
            // #region agent log
            debugLog('viewer_tab_content.dart:build', 'Dropdown value selection', {
              'selectedVenueId': selectedVenue.id,
              'selectedVenueName': selectedVenue.name,
              'venuesCount': venues.length,
              'venueIds': venues.map((v) => v.id).toList(),
              'foundMatch': dropdownValue.id == selectedVenue.id,
              'dropdownValueId': dropdownValue.id,
              'usingFirst': dropdownValue.id != selectedVenue.id,
            });
            // #endregion
          } catch (e) {
            // #region agent log
            debugLog('viewer_tab_content.dart:build', 'Dropdown value selection ERROR', {
              'error': e.toString(),
              'selectedVenueId': selectedVenue.id,
              'venuesCount': venues.length,
            });
            // #endregion
            dropdownValue = venues.isNotEmpty ? venues.first : null;
          }
        }
        final readerConfigs = selectedVenue != null
            ? configService.getConfigsForVenue(selectedVenue.id)
            : <ReaderConfig>[];

        return Column(
          children: [
            // Toolbar with venue dropdown and MQTT status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Venue Map:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButton<VenueMap>(
                      value: dropdownValue,
                      isExpanded: true,
                      hint: const Text('Select a venue map'),
                      items: venues.map((VenueMap venue) {
                        return DropdownMenuItem<VenueMap>(
                          value: venue,
                          child: Text(venue.name),
                        );
                      }).toList(),
                      onChanged: (VenueMap? venue) {
                        if (venue != null) {
                          venueService.selectVenue(venue);
                          setState(() {
                            _selectedReaderName = null;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // MQTT Status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: mqttService.isConnected
                          ? Colors.green
                          : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          mqttService.connectionStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () => _showMQTTSettings(context, mqttService),
                    tooltip: 'MQTT Settings',
                  ),
                ],
              ),
            ),
            // Full-screen map
            Expanded(
              child: selectedVenue == null
                  ? const Center(
                      child: Text('Please select a venue map'),
                    )
                  : Stack(
                      children: [
                        // Map with pins
                        VenueMapWidget(
                          key: ValueKey(selectedVenue.id), // Use venue ID as key to preserve image
                          imagePath: selectedVenue.imagePath,
                          interactive: false,
                          overlays: readerConfigs.map((config) {
                            final teamLocations = mqttService.getLocationsForReader(
                              config.readerName,
                            );
                            
                            return Positioned(
                              left: config.x - 12,
                              top: config.y - 12,
                              child: ReaderPinWidget(
                                readerName: config.readerName,
                                teamLocations: teamLocations,
                                isSelected: _selectedReaderName == config.readerName,
                                onTap: () {
                                  setState(() {
                                    if (_selectedReaderName == config.readerName) {
                                      _selectedReaderName = null;
                                    } else {
                                      _selectedReaderName = config.readerName;
                                    }
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                        // Team list bubbles
                        if (_selectedReaderName != null)
                          ...readerConfigs
                              .where((config) => config.readerName == _selectedReaderName)
                              .map((config) {
                            final teamLocations = mqttService.getLocationsForReader(
                              config.readerName,
                            );
                            
                            if (teamLocations.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            
                            return TeamListBubble(
                              readerName: config.readerName,
                              teamLocations: teamLocations,
                              pinPosition: Offset(config.x, config.y),
                            );
                          }),
                        // Tap to dismiss overlay
                        if (_selectedReaderName != null)
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedReaderName = null;
                                });
                              },
                              child: Container(
                                color: Colors.transparent,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

