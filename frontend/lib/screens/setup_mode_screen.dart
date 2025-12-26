import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../models/reader_config.dart';
import '../models/venue_map.dart';
import '../services/config_service.dart';
import '../services/venue_service.dart';
import '../widgets/venue_map_widget.dart';
import '../widgets/reader_pin_widget.dart';
import '../widgets/reader_name_dialog.dart';

class SetupModeScreen extends StatefulWidget {
  const SetupModeScreen({super.key});

  @override
  State<SetupModeScreen> createState() => _SetupModeScreenState();
}

class _SetupModeScreenState extends State<SetupModeScreen> {
  String? _selectedPinId;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final venueService = context.read<VenueService>();
      final configService = context.read<ConfigService>();
      
      venueService.loadVenues();
      configService.loadConfigs();
    });
  }

  String _generateId() {
    return 'reader_${_random.nextInt(10000)}';
  }

  Future<void> _handleMapTap(Offset position) async {
    if (!mounted) return;
    
    final venueService = context.read<VenueService>();
    final configService = context.read<ConfigService>();
    
    if (venueService.selectedVenue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a venue map first')),
      );
      return;
    }

    // Show dialog to enter reader name
    final readerName = await showDialog<String>(
      context: context,
      builder: (context) => const ReaderNameDialog(),
    );

    if (!mounted) return;
    
    if (readerName != null && readerName.isNotEmpty) {
      final config = ReaderConfig(
        id: _generateId(),
        readerName: readerName,
        x: position.dx,
        y: position.dy,
        venueMapId: venueService.selectedVenue!.id,
      );

      await configService.addReaderConfig(config);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reader "$readerName" added')),
        );
      }
    }
  }

  Future<void> _editReader(ReaderConfig config) async {
    if (!mounted) return;
    
    final readerName = await showDialog<String>(
      context: context,
      builder: (context) => ReaderNameDialog(initialName: config.readerName),
    );

    if (!mounted) return;
    
    if (readerName != null && readerName.isNotEmpty) {
      final configService = context.read<ConfigService>();
      final updatedConfig = config.copyWith(readerName: readerName);
      await configService.updateReaderConfig(updatedConfig);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reader updated to "$readerName"')),
        );
      }
    }
  }

  Future<void> _deleteReader(ReaderConfig config) async {
    if (!mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reader'),
        content: Text('Are you sure you want to delete "${config.readerName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    
    if (confirmed == true) {
      final configService = context.read<ConfigService>();
      await configService.deleteReaderConfig(config.venueMapId, config.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reader "${config.readerName}" deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Mode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Setup Mode Help'),
                  content: const Text(
                    'Tap anywhere on the map to place a reader pin. '
                    'Enter a name for each reader when prompted. '
                    'Long press a pin to edit or delete it.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer2<VenueService, ConfigService>(
        builder: (context, venueService, configService, child) {
          final selectedVenue = venueService.selectedVenue;
          final readerConfigs = selectedVenue != null
              ? configService.getConfigsForVenue(selectedVenue.id)
              : <ReaderConfig>[];

          return Column(
            children: [
              // Venue selector
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade200,
                child: Row(
                  children: [
                    const Text(
                      'Venue Map:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButton<VenueMap>(
                        value: selectedVenue,
                        isExpanded: true,
                        hint: const Text('Select a venue map'),
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
                              _selectedPinId = null;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Map display
              Expanded(
                child: selectedVenue == null
                    ? const Center(
                        child: Text('Please select a venue map'),
                      )
                    : VenueMapWidget(
                        imagePath: selectedVenue.imagePath,
                        onTap: _handleMapTap,
                        overlays: readerConfigs.map((config) {
                          return Positioned(
                            left: config.x - 12,
                            top: config.y - 12,
                            child: GestureDetector(
                              onLongPress: () {
                                _deleteReader(config);
                              },
                              child: ReaderPinWidget(
                                readerName: config.readerName,
                                isSelected: _selectedPinId == config.id,
                                onTap: () {
                                  setState(() {
                                    _selectedPinId = config.id;
                                  });
                                  _editReader(config);
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              // Info bar
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Readers placed: ${readerConfigs.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: readerConfigs.isEmpty
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Clear All Readers'),
                                  content: const Text(
                                    'Are you sure you want to remove all readers for this venue?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text('Clear All'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true && selectedVenue != null && mounted) {
                                final venueId = selectedVenue.id;
                                await configService.clearConfigsForVenue(venueId);
                              }
                            },
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear All'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

