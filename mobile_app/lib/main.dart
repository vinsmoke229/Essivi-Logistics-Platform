import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // ⬅️ INDISPENSABLE
import 'package:mobile_app/screens/login_screen.dart';
import 'package:mobile_app/utils/session_timeout_wrapper.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/data/datasources/auth_local_data_source.dart';
import 'package:mobile_app/data/datasources/auth_remote_data_source.dart';
import 'package:mobile_app/data/repositories/auth_repository_impl.dart';
import 'package:mobile_app/presentation/providers/auth_provider.dart';
import 'package:mobile_app/presentation/providers/core_providers.dart';
import 'package:mobile_app/services/background_location_service.dart';

import 'package:mobile_app/screens/client_dashboard_screen.dart';
import 'package:mobile_app/screens/dashboard_screen.dart';

void main() async {
  // 1. Assurer l'initialisation de Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Initialisation du service de fond (Mobile uniquement)
  if (!kIsWeb) {
    await BackgroundLocationService.initializeService();
  }

  // 3. Setup SQLite FFI (Desktop/Test)
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } catch (e) {
      print('SQLite FFI initialization failed: $e');
    }
  }

  // 4. Initialisations Vitales
  await initializeDateFormatting('fr_FR', null);
  await Hive.initFlutter();

  // 5. Lecture des SharedPreferences pour le Routage au Boot
  final sharedPreferences = await SharedPreferences.getInstance();
  final token = sharedPreferences.getString('auth_token');
  final role = sharedPreferences.getString('role');
  final name = sharedPreferences.getString('name');
  
  print("🚗 BOOTING - Role: $role, Name: $name");

  // 🚀 DÉTERMINATION DE L'ÉCRAN INITIAL
  Widget initialScreen;
  if (token != null && token.isNotEmpty) {
    if (role == 'client') {
      initialScreen = const ClientDashboardScreen();
    } else if (role == 'agent') {
      initialScreen = const DashboardScreen();
    } else {
      initialScreen = const LoginScreen();
    }
  } else {
    initialScreen = const LoginScreen();
  }

  // 6. Setup Dependencies (API & Repositories)
  final apiClient = ApiClient();
  final authLocalDataSource = AuthLocalDataSourceImpl(sharedPreferences: sharedPreferences);
  final authRemoteDataSource = AuthRemoteDataSourceImpl(apiClient: apiClient);
  final authRepository = AuthRepositoryImpl(
    remoteDataSource: authRemoteDataSource,
    localDataSource: authLocalDataSource,
  );

  // 7. Lancement de l'App (runApp)
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        apiClientProvider.overrideWithValue(apiClient),
        authRepositoryProvider.overrideWithValue(authRepository),
      ],
      child: EssiviApp(initialScreen: initialScreen),
    ),
  );
}

class EssiviApp extends StatelessWidget {
  final Widget initialScreen;
  const EssiviApp({super.key, required this.initialScreen});

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
      home: SessionTimeoutWrapper(
        child: initialScreen,
      ),
    );
  }
}
