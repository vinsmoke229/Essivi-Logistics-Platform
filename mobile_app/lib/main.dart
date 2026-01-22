import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import './utils/session_timeout_wrapper.dart';

void main() {
  // C'est ici que l'erreur se cachait peut-être : on lance EssiviApp, pas MyApp
  runApp(const EssiviApp());
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
      // On wrap l'application complète
      home: const SessionTimeoutWrapper(
        child: LoginScreen(),
      ),
    );
  }
}