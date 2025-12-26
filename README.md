# FIRST Robotics RTLS - Real-Time Location Tracking System

A Flutter-based application for tracking FIRST Robotics teams in real-time using RFID reader data transmitted via MQTT. The system allows users to configure reader positions on venue maps and visualize team locations as they pass under RFID readers.

## Overview

This project provides a real-time location tracking solution for FIRST Robotics competitions. Teams are tracked using RFID readers positioned throughout the venue, and their locations are transmitted via MQTT to a Flutter frontend application that displays them on interactive venue maps.

## Project Structure

```
first-robotics-RTLS/
├── backend/                    # Backend services (currently empty)
├── frontend/                   # Flutter application
│   ├── lib/                    # Main application code
│   │   ├── main.dart          # Application entry point
│   │   ├── models/            # Data models
│   │   │   ├── reader_config.dart
│   │   │   ├── team_location.dart
│   │   │   └── venue_map.dart
│   │   ├── services/          # Business logic services
│   │   │   ├── config_service.dart
│   │   │   ├── mqtt_service.dart
│   │   │   ├── mqtt_service_impl.dart
│   │   │   ├── mqtt_service_web_stub.dart
│   │   │   └── venue_service.dart
│   │   ├── screens/           # UI screens
│   │   │   ├── main_tab_screen.dart
│   │   │   ├── setup_mode_screen.dart
│   │   │   ├── setup_tab_content.dart
│   │   │   ├── viewer_mode_screen.dart
│   │   │   └── viewer_tab_content.dart
│   │   ├── widgets/           # Reusable UI components
│   │   │   ├── pin_list_sidebar.dart
│   │   │   ├── reader_name_dialog.dart
│   │   │   ├── reader_pin_widget.dart
│   │   │   ├── team_list_bubble.dart
│   │   │   └── venue_map_widget.dart
│   │   └── utils/             # Utility functions
│   │       ├── debug_logger.dart
│   │       ├── debug_logger_io.dart
│   │       ├── debug_logger_stub.dart
│   │       ├── debug_logger_web.dart
│   │       └── mqtt_message_parser.dart
│   ├── assets/                # Static assets
│   │   ├── configs/           # Configuration files
│   │   │   ├── mqtt_config.json
│   │   │   └── venues.json
│   │   └── images/            # Image assets
│   │       └── venues/        # Venue map images
│   ├── web/                   # Web-specific files
│   │   ├── index.html
│   │   ├── manifest.json
│   │   └── icons/            # PWA icons
│   ├── test/                  # Unit and widget tests
│   │   └── widget_test.dart
│   ├── pubspec.yaml           # Flutter dependencies
│   ├── analysis_options.yaml  # Linter configuration
│   └── README.md              # Frontend-specific documentation
├── scratch/                   # Development/testing files
│   └── mqtt_test/            # MQTT testing utilities
└── README.md                  # This file
```

## Detailed File Descriptions

### Frontend Application (`frontend/`)

#### Entry Point

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

#### Models (`lib/models/`)

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

#### Services (`lib/services/`)

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

#### Screens (`lib/screens/`)

UI screens for different application modes:

- **`main_tab_screen.dart`**: Main screen with tab navigation between Setup and Viewer modes. Features:
  - Uses `TabController` with 2 tabs (Setup and Viewer)
  - Uses `IndexedStack` to maintain state between tab switches (prevents widget rebuilds)
  - Implements proper lifecycle management (`dispose()` for TabController)
  - Includes debug logging for tab state changes
  - Material Design 3 AppBar with tab bar

- **`setup_mode_screen.dart`**: Stateful widget providing standalone setup screen (alternative to tab-based setup). Features:
  - **Layout**: Full-screen `Scaffold` with AppBar and body
  - **AppBar**: 
    - Title: "Setup Mode"
    - Help button (info icon) showing usage instructions dialog
  - **Venue Selector**: 
    - Grey bar at top with "Venue Map:" label
    - `DropdownButton` showing all available venues
    - Clears selected pin when venue changes
  - **Map Display**: 
    - `VenueMapWidget` with interactive tap handling
    - `onTap` callback: `_handleMapTap()` method
    - Shows message if no venue selected
  - **Pin Placement**: 
    - `_handleMapTap()`: Validates venue selection, shows `ReaderNameDialog`, creates `ReaderConfig` with generated ID, saves via `ConfigService.addReaderConfig()`, shows success snackbar
    - ID generation: `_generateId()` creates IDs like `reader_{random}` (0-9999)
  - **Pin Interaction**: 
    - Pins wrapped in `GestureDetector` for long press
    - Long press: Calls `_deleteReader()` with confirmation dialog
    - Tap: Sets selected pin ID and calls `_editReader()`
  - **Edit Functionality**: 
    - `_editReader()`: Shows `ReaderNameDialog` with initial name, updates config via `copyWith()`, saves via `ConfigService.updateReaderConfig()`
  - **Delete Functionality**: 
    - `_deleteReader()`: Shows confirmation dialog, deletes via `ConfigService.deleteReaderConfig()`, shows success snackbar
  - **Info Bar**: 
    - Grey bar at bottom showing reader count
    - "Clear All" button (disabled if no readers)
    - Clear All: Shows confirmation dialog, calls `ConfigService.clearConfigsForVenue()`
  - **State Management**: 
    - Uses `Consumer2<VenueService, ConfigService>` for reactive updates
    - `_selectedPinId` state for tracking selected pin
    - Loads venues and configs in `initState()` via `addPostFrameCallback()`
  - **Pin Rendering**: 
    - Maps `readerConfigs` to `Positioned` widgets with `ReaderPinWidget`
    - Coordinates: `config.x - 12, config.y - 12` (centers 24x24 pin)

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
  - **AppBar**: 
    - Title: "Viewer Mode"
    - Connection status badge: Green/red container with status text
    - Settings button: Opens MQTT configuration dialog
  - **Connection Status**: 
    - `Consumer<MQTTService>` in AppBar actions
    - Badge shows `mqttService.connectionStatus` text
    - Green background when connected, red when disconnected
    - White dot indicator next to status text
  - **MQTT Settings Dialog**: 
    - `_showMQTTSettings()` method creates dialog with 4 text fields:
      - Broker (default: "localhost")
      - Port (default: "1883")
      - Client ID (default: "rtls_flutter_client")
      - Topic (default: "Robot Locations")
    - "Save & Connect" button: Configures service, disconnects, reconnects, shows result snackbar
    - Uses `TextEditingController` for each field
  - **Venue Selector Overlay**: 
    - `Positioned` widget at top of screen (16px padding)
    - White card with shadow containing dropdown
    - Clears selected reader when venue changes
  - **Map Display**: 
    - `VenueMapWidget` with `interactive: false`
    - Reader pins positioned using config coordinates
    - Pins show activity indicators based on `teamLocations`
  - **Pin Interaction**: 
    - Tap pin: Toggles `_selectedReaderName` state
    - If same pin tapped again, deselects (hides bubble)
  - **Team List Bubbles**: 
    - Rendered when `_selectedReaderName` is not null
    - Filters configs to match selected reader name
    - Creates `TeamListBubble` for each matching config
    - Shows empty state if no teams detected
  - **Dismiss Overlay**: 
    - Transparent `GestureDetector` covering full screen when bubble visible
    - Tap outside: Clears `_selectedReaderName` to hide bubble
  - **Initialization**: 
    - `initState()`: Loads venues/configs, auto-connects to MQTT, sets up update timer
    - Connection: Calls `mqttService.connect()`, shows success/failure snackbar
    - Update timer: `Timer.periodic(1 second)` triggers rebuild for relative time updates
  - **Lifecycle**: 
    - `dispose()`: Cancels update timer
  - **State Management**: 
    - Uses `Consumer3<VenueService, ConfigService, MQTTService>` for reactive updates
    - `_selectedReaderName` state tracks which reader's bubble to show
    - `_updateTimer` for periodic UI updates

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

#### Widgets (`lib/widgets/`)

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
  - **Visual Design**: 
    - 24x24 pixel circular pin marker
    - Shadow effect positioned 2 pixels below pin (20x20 black circle with 20% opacity)
    - White border (2px default, 3px when selected)
    - Material Design elevation shadow (4px blur, 2px offset)
  - **Text Display**: Shows first 2 characters of reader name in uppercase, white color, bold, 8px font size, centered
  - **Color Coding**: 
    - Red (`Colors.red`) when `hasRecentActivity` is true
    - Grey (`Colors.grey`) when inactive
  - **Activity Detection**: 
    - `hasRecentActivity` computed getter checks if any `teamLocations` have `isRecent == true`
    - Returns `false` if `teamLocations` is null or empty
  - **Activity Indicator**: Green dot (8x8 circle) with glow effect positioned top-right when activity detected
  - **Selection State**: 
    - Blue border (`Colors.blue`) with 3px width when `isSelected == true`
    - White border with 2px width when not selected
  - **Interaction**: 
    - `GestureDetector` wraps widget for tap handling
    - `onTap` callback invoked when pin is tapped
  - **Properties**: 
    - `readerName` (required): Name displayed on pin
    - `teamLocations` (optional): List used to determine activity state
    - `onTap` (required): Callback function
    - `isSelected` (optional, default `false`): Selection state

- **`team_list_bubble.dart`**: Stateless widget displaying a floating bubble with list of teams detected at a reader. Life360-style design. Features:
  - **Layout**: 
    - `Positioned` widget for absolute positioning relative to pin
    - `LayoutBuilder` for responsive sizing
    - Material Design card with 8px elevation
    - Rounded corners (12px border radius)
    - White background with shadow
  - **Positioning Logic**: 
    - `_calculateBubblePosition()` method calculates optimal position
    - Initially positions above pin (with 8px spacing)
    - Adjusts horizontally to avoid left/right screen edges (16px padding)
    - If too close to top, positions below pin instead
    - Adjusts vertically to avoid bottom edge
    - Returns `Offset` for `Positioned` widget
  - **Size Calculation**: 
    - Width: Fixed 250 pixels
    - Height: Dynamic based on team count (50px header + 40px per team)
    - Max height: 60% of screen height (enforced via `BoxConstraints`)
  - **Header Section**: 
    - Grey background (`Colors.grey.shade100`)
    - Location icon (16px, grey)
    - Reader name text (bold, 14px)
    - Rounded top corners only
  - **Table Layout**: 
    - `Table` widget with 2 columns
    - Column widths: 1:1.5 ratio (Teams:Last Seen)
    - Header row with grey background (`Colors.grey.shade50`)
    - Header text: "Teams" and "Last Seen" (bold, 12px)
  - **Team Rows**: 
    - Sorted by timestamp (most recent first) before rendering
    - Each row shows team number and relative time
    - Team numbers color-coded by recency:
      - `< 2 minutes`: `Colors.red.shade700` (darkest)
      - `2-4 minutes`: `Colors.red.shade400` (medium)
      - `4-6 minutes`: `Colors.red.shade300` (light)
      - `> 6 minutes`: `Colors.red.shade200` (very light)
    - Relative time displayed in grey (`Colors.grey.shade700`, 12px)
  - **Scrolling**: 
    - `SingleChildScrollView` wraps table for many teams
    - Scrollable only if content exceeds max height
  - **Empty State**: 
    - Returns `SizedBox.shrink()` if `teamLocations` is empty
    - Prevents rendering empty bubble
  - **Properties**: 
    - `readerName` (required): Name displayed in header
    - `teamLocations` (required): List of `TeamLocation` objects
    - `pinPosition` (required): `Offset` for positioning calculation

- **`reader_name_dialog.dart`**: Stateful widget displaying a dialog for entering or editing reader names. Features:
  - **Dialog Type**: Material Design `AlertDialog` with form validation
  - **Form Structure**: 
    - Uses `Form` widget with `GlobalKey<FormState>` for validation
    - Single `TextFormField` for reader name input
  - **Text Field**: 
    - Label: "Enter reader name"
    - Hint: "e.g., Reader 1"
    - Outlined border style
    - Auto-focus enabled for immediate typing
    - `onFieldSubmitted` triggers form submission on Enter key
  - **Initial Value**: 
    - `initialName` parameter (optional) pre-fills field when editing
    - Set via `TextEditingController.text` in `initState()`
  - **Validation**: 
    - Validator checks for null, empty, or whitespace-only input
    - Error message: "Please enter a reader name"
  - **Actions**: 
    - Cancel button: `TextButton` that closes dialog returning `null`
    - Save button: `ElevatedButton` that validates and submits
  - **Submission**: 
    - `_submit()` method validates form
    - If valid, trims whitespace and returns string via `Navigator.pop()`
    - If invalid, validation error is displayed
  - **Lifecycle**: 
    - `TextEditingController` disposed in `dispose()` method
    - Stateful widget for managing text controller lifecycle

- **`pin_list_sidebar.dart`**: Stateless widget displaying a fixed-width sidebar with list of configured reader pins. Features:
  - **Layout**: 
    - Fixed width: 300 pixels
    - Grey background (`Colors.grey.shade100`)
    - Left border (1px grey) separating from main content
    - Column layout with header and scrollable list
  - **Header Section**: 
    - Grey background (`Colors.grey.shade200`)
    - Location icon (20px)
    - "Reader Locations" title (bold, 16px)
    - Pin count displayed on right (grey text, 14px)
    - Bottom border separator
  - **Empty State**: 
    - Centered column with large location-off icon (48px, grey)
    - "No pins added yet" message (14px, grey)
    - Helper text: "Click on the map to add pins" (12px, lighter grey)
  - **Pin List**: 
    - Uses `ListView.builder` for efficient rendering of large lists
    - Each item is an `InkWell` for tap interaction
  - **Pin Item Design**: 
    - Padding: 16px horizontal, 12px vertical
    - Selection highlighting: Blue background (`Colors.blue.shade50`) and 3px left border (`Colors.blue`) when selected
    - Location icon (20px) - blue when selected, grey otherwise
    - Reader name text - bold and dark blue when selected, normal black otherwise
    - Edit button: Pencil icon (18px, grey), tooltip "Edit pin"
    - Delete button: Trash outline icon (18px, red), tooltip "Delete pin"
  - **Callbacks**: 
    - `onPinSelected`: Invoked when pin item is tapped
    - `onPinEdit`: Invoked when edit button is pressed
    - `onPinDelete`: Invoked when delete button is pressed
  - **Properties**: 
    - `pins` (required): List of `ReaderConfig` objects to display
    - `selectedPinId` (optional): ID of currently selected pin for highlighting
    - `onPinSelected`, `onPinEdit`, `onPinDelete` (required): Callback functions

#### Utils (`lib/utils/`)

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

#### Assets (`assets/`)

Static resources:

- **`configs/mqtt_config.json`**: MQTT broker configuration defaults:
  - Allowed origins for CORS
  - Default broker address
  - Default port (8083 for WebSocket)
  - WebSocket path

- **`configs/venues.json`**: Fallback venue manifest file. Used when `AssetManifest.json` is unavailable. Contains array of venue map metadata.

- **`images/venues/`**: Directory containing venue map images. Images are automatically discovered and loaded by `VenueService`. Supported formats: PNG, JPG, JPEG, WEBP.

#### Configuration Files

- **`pubspec.yaml`**: Flutter project configuration and dependencies:
  - `mqtt_client`: MQTT protocol client library
  - `provider`: State management
  - `shared_preferences`: Local storage
  - `image`: Image processing utilities
  - `json_annotation`: JSON serialization annotations

- **`analysis_options.yaml`**: Dart/Flutter linter configuration.

- **`web/`**: Web-specific files including:
  - `index.html`: Web app entry point
  - `manifest.json`: PWA manifest
  - Icons and favicons

### Backend (`backend/`)

Currently empty. Intended for future backend services such as:
- MQTT broker configuration
- Data aggregation and analytics
- Historical location data storage
- API endpoints for configuration management

### Scratch (`scratch/`)

Development and testing files. Contains:
- `mqtt_test/`: MQTT testing utilities and scripts

## Features

### Setup Mode
- **Venue Map Selection**: Choose from available venue maps
- **Reader Pin Placement**: Tap on map to place RFID reader pins
- **Reader Configuration**: Name readers and position them precisely
- **Pin Management**: Edit, delete, or reposition reader pins
- **Persistent Storage**: Configurations saved locally and persist between sessions

### Viewer Mode
- **Real-Time Tracking**: Live display of team locations as they pass under readers
- **MQTT Integration**: Automatic connection to MQTT broker
- **Interactive Map**: Tap reader pins to see detected teams
- **Team List Display**: Life360-style bubbles showing teams and last seen times
- **Connection Status**: Visual indicators for MQTT connection state

## Setup Instructions

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Dart SDK (included with Flutter)
- MQTT broker (for receiving location data)

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd first-robotics-RTLS
   ```

2. **Install Flutter dependencies**:
   ```bash
   cd frontend
   flutter pub get
   ```

3. **Add venue map images**:
   - Place venue map images (PNG, JPG, JPEG, or WEBP) in `frontend/assets/images/venues/`
   - Images will be automatically discovered and loaded

4. **Configure MQTT broker** (optional):
   - Edit `frontend/assets/configs/mqtt_config.json` to set default broker settings
   - Or configure via the UI in Viewer Mode

### Running the Application

**Web:**
```bash
cd frontend
flutter run -d chrome
```

**Desktop (Windows/Mac/Linux):**
```bash
cd frontend
flutter run -d windows  # or macos, linux
```

**Mobile (iOS/Android):**
```bash
cd frontend
flutter run
```

## MQTT Message Format

The application subscribes to the **"Robot Locations"** topic and expects JSON messages in the following format:

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

**Message Structure:**
- Top-level keys: Reader names (must match configured reader names in Setup Mode)
- Second-level keys: Team numbers (as strings)
- Values: Timestamps in format `"MM-dd-yyyy HH:mm:ss:SSS"` or `"MM-dd-yyyy HH:mm:ss.SSS"`

**Example:**
- Reader "Reader 1" detected team "2211" at timestamp "12-11-2025 1:50:10:231"
- Reader "Reader 1" detected team "1723" at timestamp "12-11-2025 1:58:23.235"
- Reader "Reader 2" detected team "4995" at timestamp "12-11-2025 2:01:15:123"

## Usage Guide

### Setup Mode

1. **Select a Venue Map**: Choose from the dropdown at the top
2. **Place Reader Pins**: 
   - Tap "Add Reader" button
   - Tap anywhere on the map to place a pin
   - Enter a reader name when prompted
3. **Edit Reader Pins**:
   - Long press a pin to open context menu
   - Choose "Edit" to rename or "Delete" to remove
   - Drag pins to reposition them
4. **View Reader List**: Use the sidebar to see all configured readers

### Viewer Mode

1. **Select a Venue Map**: Choose the same map used in Setup Mode
2. **Connect to MQTT**: 
   - The app automatically attempts to connect
   - Configure broker settings via the settings icon if needed
   - Default: `localhost:8083` (WebSocket) or `localhost:1883` (native)
3. **View Team Locations**:
   - Reader pins show indicators when teams are detected
   - Tap a reader pin to see the list of teams detected there
   - Team list bubbles show team numbers and "last seen" times
   - Colors indicate recency (darker = more recent detection)

## Architecture

### State Management
- Uses **Provider** pattern for state management
- Three main services:
  - `MQTTService`: MQTT connection and message handling
  - `ConfigService`: Reader configuration persistence
  - `VenueService`: Venue map management

### Platform Support
- **Web**: Uses WebSocket connections via `MqttBrowserClient`
- **Native** (iOS/Android/Desktop): Uses TCP connections via `MqttClient`
- Conditional imports handle platform-specific implementations

### Data Flow
1. MQTT broker publishes team location messages
2. `MQTTService` receives and parses messages
3. `MQTTMessageParser` converts JSON to `TeamLocation` objects
4. UI widgets listen to `MQTTService` updates via Provider
5. `VenueMapWidget` displays team locations on map overlays

## Dependencies

### Core Dependencies
- **flutter**: UI framework
- **mqtt_client**: MQTT protocol client (^10.0.0)
- **provider**: State management (^6.1.1)
- **shared_preferences**: Local storage (^2.2.2)
- **image**: Image processing (^4.1.3)
- **json_annotation**: JSON serialization (^4.8.1)
- **web**: Web platform APIs (^0.5.1)

### Dev Dependencies
- **flutter_test**: Testing framework
- **flutter_lints**: Linting rules (^3.0.0)
- **build_runner**: Code generation (^2.4.7)
- **json_serializable**: JSON code generation (^6.7.1)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Ensure code follows Flutter/Dart style guidelines
5. Submit a pull request

## License

[Add license information here]

## Support

For issues, questions, or contributions, please open an issue on the repository.
