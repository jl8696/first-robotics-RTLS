# RTLS Frontend - Real-Time Location Tracking System

A Flutter application for tracking FIRST Robotics teams on venue maps using RFID reader data received via MQTT.

## Features

- **Setup Mode**: Configure RFID reader pin locations on venue maps
- **Viewer Mode**: Real-time display of team locations as they pass under readers
- **MQTT Integration**: Subscribe to "Robot Locations" topic for live updates
- **Life360-style UI**: Team list bubbles showing teams and last seen times
- **Persistent Configuration**: Reader positions saved between sessions

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/                      # Data models
│   ├── reader_config.dart       # Reader pin configuration
│   ├── team_location.dart       # Team location data
│   └── venue_map.dart           # Venue map metadata
├── services/                     # Business logic services
│   ├── mqtt_service.dart        # MQTT client and message handling
│   ├── config_service.dart      # Reader configuration storage
│   └── venue_service.dart       # Venue map management
├── screens/                      # App screens
│   ├── mode_selector_screen.dart # Main mode selection
│   ├── setup_mode_screen.dart    # Reader pin placement
│   └── viewer_mode_screen.dart   # Real-time team tracking
├── widgets/                      # Reusable UI components
│   ├── venue_map_widget.dart     # Map display with overlays
│   ├── reader_pin_widget.dart    # Pin marker for readers
│   ├── team_list_bubble.dart     # Life360-style team list
│   └── reader_name_dialog.dart   # Reader name input dialog
└── utils/                        # Utility functions
    └── mqtt_message_parser.dart  # MQTT JSON message parsing
```

## Setup

1. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

2. Add venue map images to `assets/images/venues/` directory (PNG format)

3. Configure MQTT broker settings in Viewer Mode (default: localhost:1883)

## MQTT Message Format

The app subscribes to the "Robot Locations" topic and expects JSON messages in this format:

```json
{
    "Reader 1": {
        "2211": "12-11-2025 1:50:10:231",
        "1723": "12-11-2025 1:58:23.235"
    },
    "Reader 2": {
        "4995": "12-11-2025 2:01:15:123"
    }
}
```

Where:
- Keys are reader names (must match configured reader names)
- Values are maps of team numbers to timestamps
- Timestamp format: `"MM-dd-yyyy HH:mm:ss:SSS"` or `"MM-dd-yyyy HH:mm:ss.SSS"`

## Usage

### Setup Mode

1. Select a venue map from the dropdown
2. Tap anywhere on the map to place a reader pin
3. Enter a reader name when prompted
4. Long press a pin to edit or delete it
5. Reader configurations are automatically saved

### Viewer Mode

1. Select a venue map (must have configured readers from Setup Mode)
2. The app connects to the MQTT broker automatically
3. Tap on reader pins to see teams that passed under them
4. Team list bubbles show teams with color-coded recency (darker = more recent)
5. "Last Seen" times update in real-time

## Configuration

- MQTT broker settings can be configured via the settings icon in Viewer Mode
- Reader configurations are stored locally using SharedPreferences
- Venue maps are loaded from the `assets/images/venues/` directory

## Dependencies

- `mqtt_client`: MQTT protocol client
- `provider`: State management
- `shared_preferences`: Local configuration storage
- `image`: Image handling utilities

