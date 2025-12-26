import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/main_tab_screen.dart';
import 'services/config_service.dart';
import 'services/mqtt_service.dart';
import 'services/venue_service.dart';

void main() {
  runApp(const RTLSApp());
}

class RTLSApp extends StatelessWidget {
  const RTLSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConfigService()),
        ChangeNotifierProvider(create: (_) => MQTTService()),
        ChangeNotifierProvider(create: (_) => VenueService()),
      ],
      child: MaterialApp(
        title: 'RTLS - Real-Time Location Tracking',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const MainTabScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

