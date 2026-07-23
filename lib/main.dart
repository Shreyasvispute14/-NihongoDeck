import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_page.dart';
import 'widget_manager.dart';
import 'cloud_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase & Anonymous Auth safely
    await Firebase.initializeApp();
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    // Restore cloud data on startup if online
    await CloudSyncService.downloadCloudDataToLocal();
  } catch (e) {
    print('Firebase initialization skipped or offline: $e');
  }

  runApp(const NihongoDeckApp());
}

class NihongoDeckApp extends StatelessWidget {
  const NihongoDeckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return VocabularyWidgetManager(
      child: MaterialApp(
        title: 'NihongoDeck',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          primaryColor: Colors.amber,
          colorScheme: ColorScheme.dark(
            primary: Colors.amber,
            secondary: Colors.amberAccent,
            surface: const Color(0xFF1E1E1E),
          ),
          useMaterial3: true,
        ),
        home: const DashboardPage(),
      ),
    );
  }
}

class VocabularyWidgetManager extends StatefulWidget {
  final Widget child;
  const VocabularyWidgetManager({super.key, required this.child});

  @override
  State<VocabularyWidgetManager> createState() => _VocabularyWidgetManagerState();
}

class _VocabularyWidgetManagerState extends State<VocabularyWidgetManager> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Auto-backup to Firebase when app is minimized or paused
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      WidgetManager.updateWidgetWord(); 
      CloudSyncService.uploadLocalDataToCloud(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}