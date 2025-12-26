import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reader_config.dart';
import '../models/venue_map.dart';
import '../services/config_service.dart';
import '../services/mqtt_service.dart';
import '../services/venue_service.dart';
import '../widgets/venue_map_widget.dart';
import '../widgets/reader_pin_widget.dart';
import '../widgets/team_list_bubble.dart';

class ViewerModeScreen extends StatefulWidget {
  const ViewerModeScreen({super.key});

  @override
  State<ViewerModeScreen> createState() => _ViewerModeScreenState();
}

class _ViewerModeScreenState extends State<ViewerModeScreen> {
  String? _selectedReaderName;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final venueService = Provider.of<VenueService>(context, listen: false);
      final configService = Provider.of<ConfigService>(context, listen: false);
      final mqttService = Provider.of<MQTTService>(context, listen: false);
      
      venueService.loadVenues();
      configService.loadConfigs();
      
      // Connect to MQTT
      mqttService.connect().then((connected) {
        if (connected && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connected to MQTT broker'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to connect to MQTT broker'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });

      // Set up periodic updates for relative time display
      _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            // Trigger rebuild to update relative times
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Viewer Mode'),
        actions: [
          Consumer<MQTTService>(
            builder: (context, mqttService, child) {
              return Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 16),
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
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () {
                      _showMQTTSettings(context, mqttService);
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer3<VenueService, ConfigService, MQTTService>(
        builder: (context, venueService, configService, mqttService, child) {
          final selectedVenue = venueService.selectedVenue;
          final readerConfigs = selectedVenue != null
              ? configService.getConfigsForVenue(selectedVenue.id)
              : <ReaderConfig>[];

          if (selectedVenue == null) {
            return const Center(
              child: Text('Please select a venue map'),
            );
          }

          return Stack(
            children: [
              // Map with pins
              VenueMapWidget(
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
              // Venue selector
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Venue:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButton<VenueMap>(
                          value: selectedVenue,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: venueService.venues.map((VenueMap venue) {
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
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMQTTSettings(BuildContext context, MQTTService mqttService) {
    final brokerController = TextEditingController(text: 'localhost');
    final portController = TextEditingController(text: '1883');
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
              // Capture Navigator and ScaffoldMessenger before async operations
              // to avoid using context across async gaps
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              
              mqttService.configure(
                broker: brokerController.text,
                port: int.tryParse(portController.text) ?? 1883,
                clientId: clientIdController.text,
                topic: topicController.text,
              );
              
              await mqttService.disconnect();
              final connected = await mqttService.connect();
              
              if (!mounted) return;
              
              navigator.pop();
              messenger.showSnackBar(
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
}

