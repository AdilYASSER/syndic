// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';

// ⬇️ IMPORTS UNIQUES
import 'screens/login_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/habitants_list_screen.dart';
import 'screens/cotisations_list_screen.dart';
import 'screens/cotisations_table_screen.dart';
import 'screens/depenses_list_screen.dart';
import 'screens/documentation_screen.dart';
import 'screens/reclamations_screen.dart';
import 'services/cotisation_service.dart';
import 'services/import_service.dart';

// ✅ IMPORT DU BADGE UPDATER
import 'widgets/badge_updater.dart';

// ✅ IMPORTS POUR LE SCRIPT DE MISE À JOUR
import 'scripts/update_all_cotisations_status.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isInitialized = false;
  String? _errorMessage;
  String _firebaseInfo = '';

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    try {
      print('🔥 === INITIALISATION FIREBASE ===');

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase initialisé avec succès');

      await _verifierFirebase();

      final cotisationService = CotisationService();
      await cotisationService.initializeFirestoreCollection();
      print('✅ Collection cotisations initialisée');

      if (!kIsWeb) {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
        );
        print('✅ Persistance activée');
      }

      await _testerConnexionFirestore();

      // ═══════════════════════════════════════════════════════
      // ✅ SCRIPT DE MISE À JOUR DES STATUTS
      // ═══════════════════════════════════════════════════════
      await UpdateAllCotisationsStatus.execute();
      // ═══════════════════════════════════════════════════════

      setState(() {
        _isInitialized = true;
      });

      print('✅ Application prête');
    } catch (e) {
      print('❌ Erreur d\'initialisation Firebase: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _verifierFirebase() async {
    try {
      final app = Firebase.app();
      print('📱 App: ${app.name}');
      print('📱 Project ID: ${app.options.projectId}');
      print('📱 Platform: ${kIsWeb ? "Web" : "Mobile"}');

      setState(() {
        _firebaseInfo = '''
Project ID: ${app.options.projectId}
Storage: ${app.options.storageBucket}
Platform: ${kIsWeb ? "Web" : "Mobile"}
''';
      });
    } catch (e) {
      setState(() {
        _firebaseInfo = '❌ Erreur: $e';
      });
    }
  }

  Future<void> _testerConnexionFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('depenses')
          .limit(1)
          .get();
      print('📊 Collection "depenses": ${snapshot.docs.length} doc(s)');
    } catch (e) {
      print('❌ Erreur test Firestore: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Syndic - Gestion Copropriété',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('ar', 'AR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('fr', 'FR'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue,
          secondary: Colors.blue.shade700,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 4,
        ),
      ),
      home: _errorMessage != null
          ? _buildErrorScreen()
          : _isInitialized
              ? const LoginScreen()
              : const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Initialisation Firebase...'),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
              const SizedBox(height: 20),
              const Text(
                'Erreur d\'initialisation',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage ?? 'Erreur inconnue',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
              if (_firebaseInfo.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    _firebaseInfo,
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _isInitialized = false;
                  });
                  _initializeFirebase();
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}