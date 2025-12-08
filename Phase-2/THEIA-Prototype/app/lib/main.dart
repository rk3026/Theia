import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'models/emergency_contact.dart';
import 'screens/building_select_screen.dart';
import 'screens/home_screen.dart';
import 'screens/start_select_screen.dart';
import 'services/fall_detection_coordinator.dart';
import 'services/favorites_service.dart';
import 'services/map_loader_service.dart';
import 'services/preferences_service.dart';
import 'services/storage_service.dart';
import 'state/map_state.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final contacts = await storageService.getEmergencyContacts();
  if (contacts.isEmpty) {
    final seedContact = EmergencyContact(
      id: const Uuid().v4(),
      name: 'Campus Security Desk',
      phoneNumber: '+15555555555',
      isPrimary: true,
      relationship: 'Security',
    );
    await storageService.saveEmergencyContact(seedContact);
  }

  final preferencesService = PreferencesService(storageService);
  await preferencesService.loadPreferences();

  final favoritesService = FavoritesService(storageService);
  await favoritesService.loadFavorites();

  final mapLoaderService = MapLoaderService();
  final fallDetectionCoordinator = FallDetectionCoordinator(
    navigatorKey: appNavigatorKey,
    preferencesService: preferencesService,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        Provider<MapLoaderService>.value(value: mapLoaderService),
        ChangeNotifierProvider<MapState>(
          create: (context) => MapState(
            mapLoader: context.read<MapLoaderService>(),
            storage: context.read<StorageService>(),
          ),
        ),
        ChangeNotifierProvider<PreferencesService>.value(value: preferencesService),
        ChangeNotifierProvider<FavoritesService>.value(value: favoritesService),
        Provider<FallDetectionCoordinator>.value(value: fallDetectionCoordinator),
      ],
      child: const TheiaApp(),
    ),
  );
}

class TheiaApp extends StatelessWidget {
  const TheiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Theia Navigation',
      navigatorKey: appNavigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const AppBootstrapper(),
    );
  }
}

class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key});

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  late Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    final mapState = Provider.of<MapState>(context, listen: false);
    _initializationFuture = mapState.initialize(restoreLastSelections: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final coordinator = Provider.of<FallDetectionCoordinator>(context, listen: false);
      unawaited(coordinator.initialize());
      _showHipaaDialog();
    });
  }

  Future<void> _showHipaaDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('HIPAA Compliance Notice'),
        content: const SingleChildScrollView(
          child: Text(
            'This application does NOT comply with HIPAA policies and should not be used for storing, transmitting, or processing protected health information (PHI).\n\n'
            'By using this app, you acknowledge that you understand this limitation and agree not to use it for any HIPAA-regulated purposes.',
            style: TextStyle(fontSize: 16),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('I Understand', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapState = context.watch<MapState>();

    return FutureBuilder<void>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || mapState.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Unable to load maps.\n${snapshot.error}'),
              ),
            ),
          );
        }

        if (mapState.currentBuilding == null) {
          return const BuildingSelectScreen();
        }

        if (mapState.currentStart == null) {
          return const StartSelectScreen();
        }

        return const HomeScreen();
      },
    );
  }
}
