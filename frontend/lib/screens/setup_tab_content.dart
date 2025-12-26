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
import '../widgets/pin_list_sidebar.dart';

class SetupTabContent extends StatefulWidget {
  const SetupTabContent({super.key});

  @override
  State<SetupTabContent> createState() => _SetupTabContentState();
}

class _SetupTabContentState extends State<SetupTabContent> {
  String? _selectedPinId;
  final Random _random = Random();
  bool _isAddingPin = false;
  Rect? _imageBounds;
  bool _isDragging = false;
  String? _draggingPinId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final venueService = Provider.of<VenueService>(context, listen: false);
      final configService = Provider.of<ConfigService>(context, listen: false);
      
      venueService.loadVenues();
      configService.loadConfigs();
    });
  }

  String _generateId() {
    return 'reader_${_random.nextInt(10000)}';
  }

  Future<void> _handleMapTap(Offset position) async {
    if (!mounted || !_isAddingPin) return;
    
    final venueService = Provider.of<VenueService>(context, listen: false);
    final configService = Provider.of<ConfigService>(context, listen: false);
    
    if (venueService.selectedVenue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a venue map first')),
      );
      setState(() {
        _isAddingPin = false;
      });
      return;
    }

    // Show dialog to enter reader name
    final readerName = await showDialog<String>(
      context: context,
      builder: (context) => const ReaderNameDialog(),
    );

    if (!mounted) return;
    
    setState(() {
      _isAddingPin = false;
    });
    
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
      final configService = Provider.of<ConfigService>(context, listen: false);
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
      final configService = Provider.of<ConfigService>(context, listen: false);
      await configService.deleteReaderConfig(config.venueMapId, config.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reader "${config.readerName}" deleted')),
        );
      }
    }
  }

  void _onPinSelected(ReaderConfig config) {
    setState(() {
      _selectedPinId = config.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<VenueService, ConfigService>(
      builder: (context, venueService, configService, child) {
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
          } catch (e) {
            dropdownValue = venues.isNotEmpty ? venues.first : null;
          }
        }
        final readerConfigs = selectedVenue != null
            ? configService.getConfigsForVenue(selectedVenue.id)
            : <ReaderConfig>[];

        return Column(
          children: [
            // Toolbar with venue dropdown and add pin button
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
                            _selectedPinId = null;
                            _isAddingPin = false;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: selectedVenue == null
                        ? null
                        : () {
                            setState(() {
                              _isAddingPin = !_isAddingPin;
                            });
                            if (_isAddingPin) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Click on the map to add a pin'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                    icon: Icon(_isAddingPin ? Icons.close : Icons.add_location),
                    label: Text(_isAddingPin ? 'Cancel' : 'Add Pin'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAddingPin
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Map and Sidebar
            Expanded(
              child: selectedVenue == null
                  ? const Center(
                      child: Text('Please select a venue map'),
                    )
                  : Row(
                      children: [
                        // Map - takes remaining space
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Stack(
                                children: [
                                  VenueMapWidget(
                                    key: ValueKey(selectedVenue.id), // Use venue ID as key to preserve image
                                    imagePath: selectedVenue.imagePath,
                                    onTap: _isAddingPin ? _handleMapTap : null,
                                    onImageBoundsChanged: (bounds) {
                                      setState(() {
                                        _imageBounds = bounds;
                                      });
                                    },
                                    overlays: readerConfigs.map((config) {
                                      return Positioned(
                                        left: config.x - 12,
                                        top: config.y - 12,
                                        child: GestureDetector(
                                          onTap: () {
                                            if (!_isDragging) {
                                              setState(() {
                                                _selectedPinId = config.id;
                                              });
                                              _editReader(config);
                                            }
                                          },
                                          onLongPress: () {
                                            if (!_isDragging) {
                                              _deleteReader(config);
                                            }
                                          },
                                          onPanStart: (details) {
                                            setState(() {
                                              _isDragging = true;
                                              _selectedPinId = config.id;
                                              _draggingPinId = config.id;
                                            });
                                          },
                                          onPanUpdate: (details) {
                                            if (_draggingPinId == config.id) {
                                              // Update pin position during drag
                                              final newX = config.x + details.delta.dx;
                                              final newY = config.y + details.delta.dy;
                                              
                                              // Update the config (no clamping - allow pins anywhere)
                                              final updatedConfig = config.copyWith(
                                                x: newX,
                                                y: newY,
                                              );
                                              
                                              // Update in config service (async, but we don't await)
                                              final configService = Provider.of<ConfigService>(context, listen: false);
                                              configService.updateReaderConfig(updatedConfig);
                                              
                                              // Trigger rebuild to show new position
                                              setState(() {});
                                            }
                                          },
                                          onPanEnd: (details) {
                                            setState(() {
                                              _isDragging = false;
                                              _draggingPinId = null;
                                            });
                                          },
                                          child: ReaderPinWidget(
                                            readerName: config.readerName,
                                            isSelected: _selectedPinId == config.id,
                                            onTap: () {
                                              if (!_isDragging) {
                                                setState(() {
                                                  _selectedPinId = config.id;
                                                });
                                                _editReader(config);
                                              }
                                            },
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  // Visual indicator when adding pin
                                  if (_isAddingPin)
                                    Stack(
                                      children: [
                                        // Semi-transparent overlay - ignore pointer events
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            ignoring: true,
                                            child: Container(
                                              color: Colors.black.withValues(alpha: 0.1),
                                            ),
                                          ),
                                        ),
                                        // Label positioned above the image on Y axis - NOT ignored
                                        if (_imageBounds != null)
                                          Positioned(
                                            top: _imageBounds!.top - 80,
                                            left: _imageBounds!.left,
                                            right: constraints.maxWidth - _imageBounds!.right,
                                            child: const IgnorePointer(
                                              ignoring: true, // Label itself doesn't need pointer events
                                              child: Center(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.add_location,
                                                      size: 48,
                                                      color: Colors.blue,
                                                    ),
                                                    SizedBox(height: 8),
                                                    Text(
                                                      'Click on the map to place a pin',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          // Fallback if bounds not calculated yet
                                          Positioned(
                                            top: constraints.maxHeight * 0.15,
                                            left: 0,
                                            right: 0,
                                            child: const IgnorePointer(
                                              ignoring: true,
                                              child: Center(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.add_location,
                                                      size: 48,
                                                      color: Colors.blue,
                                                    ),
                                                    SizedBox(height: 8),
                                                    Text(
                                                      'Click on the map to place a pin',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                        // Sidebar
                        PinListSidebar(
                          pins: readerConfigs,
                          selectedPinId: _selectedPinId,
                          onPinSelected: _onPinSelected,
                          onPinEdit: _editReader,
                          onPinDelete: _deleteReader,
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

