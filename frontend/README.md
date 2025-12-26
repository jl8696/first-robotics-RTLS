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
frontend/
├── lib/                          # Main application code
│   ├── main.dart                # Application entry point
│   ├── models/                  # Data models
│   │   ├── reader_config.dart
│   │   ├── team_location.dart
│   │   └── venue_map.dart
│   ├── services/                # Business logic services
│   │   ├── config_service.dart
│   │   ├── mqtt_service.dart
│   │   ├── mqtt_service_impl.dart
│   │   ├── mqtt_service_web_stub.dart
│   │   └── venue_service.dart
│   ├── screens/                 # UI screens
│   │   ├── main_tab_screen.dart
│   │   ├── setup_mode_screen.dart
│   │   ├── setup_tab_content.dart
│   │   ├── viewer_mode_screen.dart
│   │   └── viewer_tab_content.dart
│   ├── widgets/                 # Reusable UI components
│   │   ├── pin_list_sidebar.dart
│   │   ├── reader_name_dialog.dart
│   │   ├── reader_pin_widget.dart
│   │   ├── team_list_bubble.dart
│   │   └── venue_map_widget.dart
│   └── utils/                   # Utility functions
│       ├── debug_logger.dart
│       ├── debug_logger_io.dart
│       ├── debug_logger_stub.dart
│       ├── debug_logger_web.dart
│       └── mqtt_message_parser.dart
├── assets/                      # Static assets
│   ├── configs/                 # Configuration files
│   │   ├── mqtt_config.json
│   │   └── venues.json
│   └── images/                  # Image assets
│       └── venues/              # Venue map images
├── web/                         # Web-specific files
│   ├── index.html
│   ├── manifest.json
│   └── icons/                   # PWA icons
├── test/                        # Unit and widget tests
│   └── widget_test.dart
├── pubspec.yaml                 # Flutter dependencies
├── analysis_options.yaml        # Linter configuration
└── README.md                    # This file
```

## Detailed File Descriptions

### Entry Point

- **`lib/main.dart`**: Application entry point that initializes the Flutter application. Features:
  - **Entry Function**: `main()` calls `runApp(const RTLSApp())`
  - **App Widget**: `RTLSApp` extends `StatelessWidget`
  - **State Management Setup**: 
    - `MultiProvider` wraps entire app with 3 providers:
      - `ChangeNotifierProvider<ConfigService>`: Manages reader configurations
      - `ChangeNotifierProvider<MQTTService>`: Manages MQTT connections
      - `ChangeNotifierProvider<VenueService>`: Manages venue maps
    - All services created via factory functions
  - **Material App**: 
    - Title: "RTLS - Real-Time Location Tracking"
    - Theme: Material Design 3 with blue color scheme seed
    - Home: `MainTabScreen` widget
    - Debug banner: Disabled (`debugShowCheckedModeBanner: false`)
  - **Theme Configuration**: 
    - Uses `ColorScheme.fromSeed(seedColor: Colors.blue)` for Material 3 theming
    - `useMaterial3: true` enables Material Design 3

### Models (`lib/models/`)

Data classes representing core domain entities:

- **`reader_config.dart`**: Represents the configuration for an RFID reader pin on a venue map. Contains:
  - `id`: Unique identifier for the reader configuration (typically generated as `reader_{random}`)
  - `readerName`: Name of the RFID reader (must match MQTT message reader names exactly)
  - `x`, `y`: Coordinates on the venue map (normalized 0.0-1.0, or pixel coordinates depending on context)
  - `venueMapId`: Reference to the venue map this reader belongs to (links to `VenueMap.id`)
  - `toJson()`: Serializes object to JSON map for persistence
  - `fromJson()`: Factory constructor to deserialize from JSON map
  - `copyWith()`: Creates a copy with modified fields (useful for updates)
  - Used by `ConfigService` for storage and retrieval

- **`team_location.dart`**: Represents a team's location detection at a specific reader. Contains:
  - `teamNumber`: FIRST Robotics team number as string (e.g., "2211", "1723")
  - `readerName`: Name of the reader that detected the team (must match configured reader name)
  - `timestamp`: `DateTime` object representing when the team was detected
  - `relativeTime`: Computed getter returning human-readable time since detection:
    - Format examples: "5s ago", "2m 30s ago", "1h 15m ago", "2d 3h ago"
    - Calculates difference from current time
  - `isRecent`: Computed getter returning `true` if detection was within the last 5 minutes
  - Immutable class (all fields are `final`)
  - Created by `MQTTMessageParser` from incoming MQTT messages

- **`venue_map.dart`**: Represents a venue map configuration. Contains:
  - `id`: Unique identifier (typically the asset path, e.g., `"assets/images/venues/military academy.png"`)
  - `name`: Display name for the venue (formatted from filename, e.g., "Military Academy")
  - `imagePath`: Path to the venue map image asset (used for loading image)
  - `toJson()`: Serializes object to JSON map
  - `fromJson()`: Factory constructor to deserialize from JSON map
  - Used by `VenueService` for venue discovery and selection
  - Immutable class (all fields are `final`)

### Services (`lib/services/`)

Business logic and state management:

- **`mqtt_service.dart`**: Main MQTT service that manages connection to the MQTT broker and handles incoming location messages. Responsibilities:
  - Manages connection state (connected/disconnected)
  - Subscribes to "Robot Locations" topic
  - Parses incoming messages and updates team locations
  - Provides connection status to UI
  - Uses platform-specific implementations via conditional imports
  - Implements `ChangeNotifier` for reactive UI updates
  - Handles connection lifecycle (connect, disconnect, reconnect)
  - Stores team locations grouped by reader name
  - Provides methods to configure broker settings (host, port, client ID, topic)
  - Includes debug logging for troubleshooting connection issues

- **`mqtt_service_impl.dart`**: Platform-specific MQTT implementation for native platforms (iOS, Android, Desktop). Uses `MqttServerClient` with TCP connections. This file is conditionally imported for non-web platforms. Features:
  - Creates `MqttServerClient` using `withPort()` constructor with specified broker, client ID, and port
  - Disables verbose logging (`logging(on: false)`)
  - Sets keep-alive period to 20 seconds
  - Configures connection message with:
    - Client identifier
    - Clean session flag (`startClean()`)
    - Will QoS level (`atLeastOnce`)
  - Sets up connection callbacks that forward to parent `MQTTService`:
    - `onConnected`: Calls `_service.onConnected()`
    - `onDisconnected`: Calls `_service.onDisconnected()`
    - `onSubscribed`: Calls `_service.onSubscribed(topic)`
  - `connect()` method: Establishes TCP connection and returns boolean success status
  - `subscribe()` method: Subscribes to topic with QoS `atLeastOnce` and sets up message listener
  - Message listener extracts payload from `MqttPublishMessage` and converts to string
  - Forwards parsed messages to callback function provided by `MQTTService`
  - `disconnect()` method: Cleanly disconnects and nullifies client reference
  - Handles connection errors by returning `false` (errors are caught and not propagated)
  - No timeout handling (relies on platform defaults)

- **`mqtt_service_web_stub.dart`**: Web-specific MQTT implementation using `MqttBrowserClient` with WebSocket connections. This file is conditionally imported for web platforms (`dart.library.html`). Features:
  - **Client Creation**: Creates `MqttBrowserClient` using `withPort()` constructor
  - **URL Handling**: 
    - Converts `localhost` to `127.0.0.1` for WebSocket compatibility
    - Constructs WebSocket URL WITHOUT port in URL string (port specified separately)
    - Uses format: `ws://{broker}/mqtt` (WebSocket path `/mqtt` is hardcoded)
  - **Port Mapping**: Automatically maps standard MQTT port 1883 to WebSocket port 8083, defaults to 8083 if port is not 1883
  - **Connection Configuration**:
    - Sets keep-alive period to 20 seconds
    - Creates `MqttConnectMessage` with client identifier and clean session flag
    - Sets connection message on client before connecting
  - **Callbacks**: Sets up callbacks that forward to parent `MQTTService`:
    - `onConnected`: Calls `_service.onConnected()`
    - `onDisconnected`: Calls `_service.onDisconnected()`
    - `onSubscribed`: Calls `_service.onSubscribed(topic)` with topic string
  - **Connection Method**: 
    - `connect()`: Attempts connection with 5-second timeout
    - Uses `Future.timeout()` with `TimeoutException` on timeout
    - Returns `true` if connection state is `connected`, `false` otherwise
    - Cleans up client reference on failure
  - **Subscription Method**:
    - `subscribe()`: Subscribes to topic with QoS `atLeastOnce`
    - Sets up `updates` stream listener
    - Extracts `MqttPublishMessage` payload and converts bytes to string
    - Forwards message string to callback function
  - **Disconnect Method**: Disconnects client and nullifies reference
  - **Error Handling**: Catches exceptions, prints error messages, ensures cleanup on failure

- **`config_service.dart`**: Manages RFID reader configurations persistence using local storage. Implements `ChangeNotifier` for reactive UI updates. Responsibilities:
  - **Storage**: Uses `SharedPreferences` for persistent local storage
  - **Key Format**: Stores configurations per venue map using key pattern `reader_configs_{venueMapId}`
  - **Data Structure**: Maintains in-memory map `_configs` mapping venue IDs to lists of `ReaderConfig` objects
  - **CRUD Operations**:
    - `loadConfigs()`: Scans all SharedPreferences keys, finds reader config keys, deserializes JSON arrays to `ReaderConfig` lists, populates `_configs` map, notifies listeners
    - `saveConfigsForVenue()`: Serializes `ReaderConfig` list to JSON array, saves to SharedPreferences, updates in-memory map, notifies listeners
    - `addReaderConfig()`: Retrieves existing configs for venue, adds new config, saves via `saveConfigsForVenue()`
    - `updateReaderConfig()`: Finds config by ID in venue's list, replaces with updated config, saves
    - `deleteReaderConfig()`: Removes config from venue's list by ID, saves updated list
    - `clearConfigsForVenue()`: Removes SharedPreferences key, removes from in-memory map, notifies listeners
  - **Read Operations**:
    - `getConfigsForVenue()`: Returns unmodifiable list of configs for venue (empty list if none exist)
    - `configs` getter: Returns unmodifiable map of all configurations
  - **Serialization**: Uses `jsonEncode`/`jsonDecode` with `ReaderConfig.toJson()`/`fromJson()` methods
  - **Error Handling**: Wraps operations in try-catch, prints errors to console, continues gracefully
  - **State Management**: Extends `ChangeNotifier`, calls `notifyListeners()` after state changes

- **`venue_service.dart`**: Manages venue map discovery and selection. Responsibilities:
  - Scans `assets/images/venues/` directory for available venue maps
  - Loads venue metadata from `AssetManifest.json` (generated by Flutter build) or fallback `venues.json`
  - Filters and discovers image files (PNG, JPG, JPEG, WEBP formats)
  - Formats venue filenames into readable display names (e.g., "military academy.png" → "Military Academy")
  - Manages currently selected venue
  - Preserves venue selection when reloading venues
  - Auto-selects first venue if none is selected
  - Implements `ChangeNotifier` for reactive UI updates
  - Includes debug logging for troubleshooting venue loading issues

### Screens (`lib/screens/`)

UI screens for different application modes:

- **`main_tab_screen.dart`**: Main screen with tab navigation between Setup and Viewer modes. Features:
  - Uses `TabController` with 2 tabs (Setup and Viewer)
  - Uses `IndexedStack` to maintain state between tab switches (prevents widget rebuilds)
  - Implements proper lifecycle management (`dispose()` for TabController)
  - Includes debug logging for tab state changes
  - Material Design 3 AppBar with tab bar

- **`setup_mode_screen.dart`**: Stateful widget providing standalone setup screen (alternative to tab-based setup). Features:
  - **Layout**: Full-screen `Scaffold` with AppBar and body
  - **AppBar**: Title: "Setup Mode", Help button (info icon) showing usage instructions dialog
  - **Venue Selector**: Grey bar at top with "Venue Map:" label, `DropdownButton` showing all available venues, clears selected pin when venue changes
  - **Map Display**: `VenueMapWidget` with interactive tap handling, `onTap` callback: `_handleMapTap()` method, shows message if no venue selected
  - **Pin Placement**: `_handleMapTap()` validates venue selection, shows `ReaderNameDialog`, creates `ReaderConfig` with generated ID, saves via `ConfigService.addReaderConfig()`, shows success snackbar. ID generation: `_generateId()` creates IDs like `reader_{random}` (0-9999)
  - **Pin Interaction**: Pins wrapped in `GestureDetector` for long press. Long press: Calls `_deleteReader()` with confirmation dialog. Tap: Sets selected pin ID and calls `_editReader()`
  - **Edit Functionality**: `_editReader()` shows `ReaderNameDialog` with initial name, updates config via `copyWith()`, saves via `ConfigService.updateReaderConfig()`
  - **Delete Functionality**: `_deleteReader()` shows confirmation dialog, deletes via `ConfigService.deleteReaderConfig()`, shows success snackbar
  - **Info Bar**: Grey bar at bottom showing reader count, "Clear All" button (disabled if no readers), Clear All shows confirmation dialog, calls `ConfigService.clearConfigsForVenue()`
  - **State Management**: Uses `Consumer2<VenueService, ConfigService>` for reactive updates, `_selectedPinId` state for tracking selected pin, loads venues and configs in `initState()` via `addPostFrameCallback()`
  - **Pin Rendering**: Maps `readerConfigs` to `Positioned` widgets with `ReaderPinWidget`, coordinates: `config.x - 12, config.y - 12` (centers 24x24 pin)

- **`setup_tab_content.dart`**: Setup mode content widget used in tab-based interface. Features:
  - Similar functionality to `setup_mode_screen.dart` but designed for tab context
  - Venue map selector dropdown
  - Interactive map with tap-to-place reader pins
  - Drag-to-reposition reader pins
  - Long press context menu for edit/delete operations
  - Sidebar showing list of configured readers (`PinListSidebar`)
  - "Add Reader" button to enable pin placement mode
  - Generates unique IDs for reader configurations
  - Automatically saves configurations when pins are added/edited/deleted
  - Handles coordinate conversion between screen and normalized coordinates

- **`viewer_mode_screen.dart`**: Stateful widget providing standalone viewer screen (alternative to tab-based viewer). Features:
  - **Layout**: Full-screen `Scaffold` with AppBar and `Stack` body
  - **AppBar**: Title: "Viewer Mode", Connection status badge: Green/red container with status text, Settings button: Opens MQTT configuration dialog
  - **Connection Status**: `Consumer<MQTTService>` in AppBar actions, badge shows `mqttService.connectionStatus` text, green background when connected, red when disconnected, white dot indicator next to status text
  - **MQTT Settings Dialog**: `_showMQTTSettings()` method creates dialog with 4 text fields (Broker default: "localhost", Port default: "1883", Client ID default: "rtls_flutter_client", Topic default: "Robot Locations"), "Save & Connect" button configures service, disconnects, reconnects, shows result snackbar, uses `TextEditingController` for each field
  - **Venue Selector Overlay**: `Positioned` widget at top of screen (16px padding), white card with shadow containing dropdown, clears selected reader when venue changes
  - **Map Display**: `VenueMapWidget` with `interactive: false`, reader pins positioned using config coordinates, pins show activity indicators based on `teamLocations`
  - **Pin Interaction**: Tap pin toggles `_selectedReaderName` state, if same pin tapped again, deselects (hides bubble)
  - **Team List Bubbles**: Rendered when `_selectedReaderName` is not null, filters configs to match selected reader name, creates `TeamListBubble` for each matching config, shows empty state if no teams detected
  - **Dismiss Overlay**: Transparent `GestureDetector` covering full screen when bubble visible, tap outside clears `_selectedReaderName` to hide bubble
  - **Initialization**: `initState()` loads venues/configs, auto-connects to MQTT, sets up update timer. Connection: Calls `mqttService.connect()`, shows success/failure snackbar. Update timer: `Timer.periodic(1 second)` triggers rebuild for relative time updates
  - **Lifecycle**: `dispose()` cancels update timer
  - **State Management**: Uses `Consumer3<VenueService, ConfigService, MQTTService>` for reactive updates, `_selectedReaderName` state tracks which reader's bubble to show, `_updateTimer` for periodic UI updates

- **`viewer_tab_content.dart`**: Viewer mode content widget used in tab-based interface. Features:
  - Similar functionality to `viewer_mode_screen.dart` but designed for tab context
  - Real-time team locations on venue map
  - Reader pins with visual indicators (red for recent activity, grey for inactive)
  - Team list bubbles appearing when reader pins are tapped
  - Connection status display
  - MQTT settings configuration
  - Auto-connects to MQTT broker on load
  - Updates team locations in real-time as MQTT messages arrive
  - Handles venue selection changes
  - Includes debug logging for troubleshooting
  - Proper lifecycle management with disposal handling

### Widgets (`lib/widgets/`)

Reusable UI components:

- **`venue_map_widget.dart`**: Custom widget for displaying venue map images with overlay support. Features:
  - Maintains aspect ratio while fitting to container (uses `BoxFit.contain`)
  - Supports interactive tap detection for pin placement (`onTap` callback)
  - Calculates image bounds for coordinate conversion (`calculateImageBounds` static method)
  - Renders custom overlay widgets positioned absolutely (reader pins, team markers)
  - Handles image loading from assets with loading indicators
  - Supports error states when images fail to load
  - Notifies parent of image bounds changes via `onImageBoundsChanged` callback
  - Can be made non-interactive (`interactive` parameter)
  - Uses `CustomPaint` and `CustomPainter` for efficient image rendering
  - Calculates proper image positioning (centered, maintaining aspect ratio)

- **`reader_pin_widget.dart`**: Stateless widget representing an RFID reader pin marker on the venue map. Features:
  - **Visual Design**: 24x24 pixel circular pin marker, shadow effect positioned 2 pixels below pin (20x20 black circle with 20% opacity), white border (2px default, 3px when selected), Material Design elevation shadow (4px blur, 2px offset)
  - **Text Display**: Shows first 2 characters of reader name in uppercase, white color, bold, 8px font size, centered
  - **Color Coding**: Red (`Colors.red`) when `hasRecentActivity` is true, Grey (`Colors.grey`) when inactive
  - **Activity Detection**: `hasRecentActivity` computed getter checks if any `teamLocations` have `isRecent == true`, returns `false` if `teamLocations` is null or empty
  - **Activity Indicator**: Green dot (8x8 circle) with glow effect positioned top-right when activity detected
  - **Selection State**: Blue border (`Colors.blue`) with 3px width when `isSelected == true`, white border with 2px width when not selected
  - **Interaction**: `GestureDetector` wraps widget for tap handling, `onTap` callback invoked when pin is tapped
  - **Properties**: `readerName` (required): Name displayed on pin, `teamLocations` (optional): List used to determine activity state, `onTap` (required): Callback function, `isSelected` (optional, default `false`): Selection state

- **`team_list_bubble.dart`**: Stateless widget displaying a floating bubble with list of teams detected at a reader. Life360-style design. Features:
  - **Layout**: `Positioned` widget for absolute positioning relative to pin, `LayoutBuilder` for responsive sizing, Material Design card with 8px elevation, rounded corners (12px border radius), white background with shadow
  - **Positioning Logic**: `_calculateBubblePosition()` method calculates optimal position, initially positions above pin (with 8px spacing), adjusts horizontally to avoid left/right screen edges (16px padding), if too close to top, positions below pin instead, adjusts vertically to avoid bottom edge, returns `Offset` for `Positioned` widget
  - **Size Calculation**: Width: Fixed 250 pixels, Height: Dynamic based on team count (50px header + 40px per team), Max height: 60% of screen height (enforced via `BoxConstraints`)
  - **Header Section**: Grey background (`Colors.grey.shade100`), location icon (16px, grey), reader name text (bold, 14px), rounded top corners only
  - **Table Layout**: `Table` widget with 2 columns, column widths: 1:1.5 ratio (Teams:Last Seen), header row with grey background (`Colors.grey.shade50`), header text: "Teams" and "Last Seen" (bold, 12px)
  - **Team Rows**: Sorted by timestamp (most recent first) before rendering, each row shows team number and relative time, team numbers color-coded by recency: `< 2 minutes`: `Colors.red.shade700` (darkest), `2-4 minutes`: `Colors.red.shade400` (medium), `4-6 minutes`: `Colors.red.shade300` (light), `> 6 minutes`: `Colors.red.shade200` (very light), relative time displayed in grey (`Colors.grey.shade700`, 12px)
  - **Scrolling**: `SingleChildScrollView` wraps table for many teams, scrollable only if content exceeds max height
  - **Empty State**: Returns `SizedBox.shrink()` if `teamLocations` is empty, prevents rendering empty bubble
  - **Properties**: `readerName` (required): Name displayed in header, `teamLocations` (required): List of `TeamLocation` objects, `pinPosition` (required): `Offset` for positioning calculation

- **`reader_name_dialog.dart`**: Stateful widget displaying a dialog for entering or editing reader names. Features:
  - **Dialog Type**: Material Design `AlertDialog` with form validation
  - **Form Structure**: Uses `Form` widget with `GlobalKey<FormState>` for validation, single `TextFormField` for reader name input
  - **Text Field**: Label: "Enter reader name", Hint: "e.g., Reader 1", Outlined border style, Auto-focus enabled for immediate typing, `onFieldSubmitted` triggers form submission on Enter key
  - **Initial Value**: `initialName` parameter (optional) pre-fills field when editing, set via `TextEditingController.text` in `initState()`
  - **Validation**: Validator checks for null, empty, or whitespace-only input, error message: "Please enter a reader name"
  - **Actions**: Cancel button: `TextButton` that closes dialog returning `null`, Save button: `ElevatedButton` that validates and submits
  - **Submission**: `_submit()` method validates form, if valid, trims whitespace and returns string via `Navigator.pop()`, if invalid, validation error is displayed
  - **Lifecycle**: `TextEditingController` disposed in `dispose()` method, Stateful widget for managing text controller lifecycle

- **`pin_list_sidebar.dart`**: Stateless widget displaying a fixed-width sidebar with list of configured reader pins. Features:
  - **Layout**: Fixed width: 300 pixels, grey background (`Colors.grey.shade100`), left border (1px grey) separating from main content, column layout with header and scrollable list
  - **Header Section**: Grey background (`Colors.grey.shade200`), location icon (20px), "Reader Locations" title (bold, 16px), pin count displayed on right (grey text, 14px), bottom border separator
  - **Empty State**: Centered column with large location-off icon (48px, grey), "No pins added yet" message (14px, grey), helper text: "Click on the map to add pins" (12px, lighter grey)
  - **Pin List**: Uses `ListView.builder` for efficient rendering of large lists, each item is an `InkWell` for tap interaction
  - **Pin Item Design**: Padding: 16px horizontal, 12px vertical, selection highlighting: Blue background (`Colors.blue.shade50`) and 3px left border (`Colors.blue`) when selected, location icon (20px) - blue when selected, grey otherwise, reader name text - bold and dark blue when selected, normal black otherwise, edit button: Pencil icon (18px, grey), tooltip "Edit pin", delete button: Trash outline icon (18px, red), tooltip "Delete pin"
  - **Callbacks**: `onPinSelected`: Invoked when pin item is tapped, `onPinEdit`: Invoked when edit button is pressed, `onPinDelete`: Invoked when delete button is pressed
  - **Properties**: `pins` (required): List of `ReaderConfig` objects to display, `selectedPinId` (optional): ID of currently selected pin for highlighting, `onPinSelected`, `onPinEdit`, `onPinDelete` (required): Callback functions

### Utils (`lib/utils/`)

Utility functions and helpers:

- **`mqtt_message_parser.dart`**: Parses incoming MQTT JSON messages into structured data. Features:
  - Static `parseMessage()` method that takes JSON string and returns `Map<String, List<TeamLocation>>`
  - JSON deserialization using `dart:convert`
  - Parses nested JSON structure: `{readerName: {teamNumber: timestamp}}`
  - Timestamp parsing (`_parseTimestamp()` private method) supporting formats:
    - `"MM-dd-yyyy HH:mm:ss:SSS"` (colon separator for milliseconds)
    - `"MM-dd-yyyy HH:mm:ss.SSS"` (dot separator for milliseconds)
  - Normalizes timestamp format (converts dots to colons)
  - Converts parsed data to `TeamLocation` objects grouped by reader name
  - Error handling for malformed JSON, invalid timestamps, and missing fields
  - Returns empty map on parsing errors (graceful degradation)
  - Validates timestamp format before parsing

- **`debug_logger.dart`**: Abstract debug logging interface for platform-specific logging implementations. Features:
  - Defines `debugLog()` function signature
  - Takes file name, message, and optional data map
  - Supports hypothesis ID for debugging multiple code paths
  - Uses conditional imports to select platform-specific implementation
  - Imported as: `import 'debug_logger.dart'` (resolves to platform-specific version)

- **`debug_logger_io.dart`**: IO platform (native) debug logger implementation. Features:
  - Implements `debugLog()` function for iOS, Android, and Desktop platforms
  - Uses `print()` for console output
  - Formats log messages with file name, message, and data
  - Includes hypothesis ID in output if provided
  - Simple, synchronous logging suitable for native platforms

- **`debug_logger_web.dart`**: Web platform debug logger implementation. Features:
  - Implements `debugLog()` function for web platform
  - Uses browser console APIs (`window.console`) for logging
  - Formats log messages with file name, message, and data
  - Includes hypothesis ID in output if provided
  - Uses web-specific logging methods for better browser integration

- **`debug_logger_stub.dart`**: Stub implementation for platforms without specific logging. Features:
  - No-op implementation of `debugLog()` function
  - Used as fallback when platform-specific logger is unavailable
  - Prevents compilation errors on unsupported platforms
  - Can be used for testing or when logging is disabled

## Setup

1. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

2. Add venue map images to `assets/images/venues/` directory (PNG, JPG, JPEG, or WEBP format)

3. Configure MQTT broker settings in Viewer Mode (default: localhost:8083 for web, localhost:1883 for native)

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

- `mqtt_client`: MQTT protocol client (^10.0.0)
- `provider`: State management (^6.1.1)
- `shared_preferences`: Local configuration storage (^2.2.2)
- `image`: Image handling utilities (^4.1.3)
- `json_annotation`: JSON serialization (^4.8.1)
- `web`: Web platform APIs (^0.5.1)
