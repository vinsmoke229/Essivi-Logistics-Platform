import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // ⬅️ INDISPENSABLE
import 'screens/login_screen.dart';
import './utils/session_timeout_wrapper.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'core/network/api_client.dart';
import 'data/datasources/auth_local_data_source.dart';
import 'data/datasources/auth_remote_data_source.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/core_providers.dart';
import 'services/background_location_service.dart';

void main() async {
  // 1. On s'assure que Flutter est prêt
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialisation du service de fond
  if (!kIsWeb) {
    await BackgroundLocationService.initializeService();
  }

  // 2. Initialisation de SQLite pour desktop (pas pour web)
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    try {
      // Initialize FFI
      sqfliteFfiInit();
      // Set databaseFactory to FFI
      databaseFactory = databaseFactoryFfi;
    } catch (e) {
      print('SQLite FFI initialization failed: $e');
      // Continuer sans SQLite pour le web ou en cas d'erreur
    }
  }

  // 3. On initialise le support des dates en Français
  await initializeDateFormatting('fr_FR', null);

  // 4. Init Hive
  await Hive.initFlutter();

  // 5. Init SharedPrefs
  final sharedPreferences = await SharedPreferences.getInstance();

  // 6. Setup Dependencies
  final apiClient = ApiClient();
  final authLocalDataSource = AuthLocalDataSourceImpl(sharedPreferences: sharedPreferences);
  final authRemoteDataSource = AuthRemoteDataSourceImpl(apiClient: apiClient);
  final authRepository = AuthRepositoryImpl(
    remoteDataSource: authRemoteDataSource,
    localDataSource: authLocalDataSource,
  );

  // 7. On lance l'application avec Riverpod
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        apiClientProvider.overrideWithValue(apiClient),
        authRepositoryProvider.overrideWithValue(authRepository),
      ],
      child: const EssiviApp(),
    ),
  );
}

class EssiviApp extends StatelessWidget {
  const EssiviApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESSIVI Sarl',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // On entoure l'app avec le timeout de session
      home: const SessionTimeoutWrapper(
        child: LoginScreen(),
      ),
    );
  }
}