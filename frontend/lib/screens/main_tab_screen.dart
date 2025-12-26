import 'package:flutter/material.dart';
import '../utils/debug_logger.dart';
import 'setup_tab_content.dart';
import 'viewer_tab_content.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isDisposed = false;

  // #region agent log
  void _log(String message, Map<String, dynamic> data) {
    debugLog('main_tab_screen.dart', message, data, hypothesisId: 'A');
  }
  // #endregion

  @override
  void initState() {
    super.initState();
    // #region agent log
    _log('initState START', {'mounted': mounted});
    // #endregion
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _tabController.addListener(() {
      if (!_isDisposed) {
        setState(() {
          // Rebuild when tab changes
        });
      }
    });
    // #region agent log
    _log('initState TabController CREATED', {'mounted': mounted, 'tabControllerIndex': _tabController.index});
    // #endregion
  }

  @override
  void dispose() {
    // #region agent log
    _log('dispose START', {'mounted': mounted, 'isDisposed': _isDisposed});
    // #endregion
    _isDisposed = true;
    _tabController.dispose();
    // #region agent log
    _log('dispose TabController DISPOSED', {'mounted': mounted});
    // #endregion
    super.dispose();
    // #region agent log
    _log('dispose COMPLETE', {});
    // #endregion
  }

  @override
  Widget build(BuildContext context) {
    // #region agent log
    _log('build CALLED', {'mounted': mounted, 'isDisposed': _isDisposed, 'tabControllerIndex': _tabController.index});
    // #endregion
    return Scaffold(
      appBar: AppBar(
        title: const Text('RTLS - Real-Time Location Tracking'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.settings),
              text: 'Setup',
            ),
            Tab(
              icon: Icon(Icons.visibility),
              text: 'Viewer',
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _tabController.index,
        children: const [
          SetupTabContent(),
          ViewerTabContent(),
        ],
      ),
    );
  }
}

