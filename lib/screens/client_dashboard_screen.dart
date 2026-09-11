// lib/screens/client_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main_menu_screen.dart';
import 'depenses_list_screen.dart';
import 'cotisations_list_screen.dart';
import 'releve_tresor_screen.dart';
import 'documentation_screen.dart';
import 'reclamations_screen.dart';
import 'discussion_screen.dart';
import 'client_vote_screen.dart';
import 'mes_reclamations_screen.dart';
import 'rapport_financier_screen.dart';

class ClientDashboardScreen extends StatefulWidget {
  final String numAppartement;

  const ClientDashboardScreen({
    super.key,
    required this.numAppartement,
  });

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // ✅ REDIRIGER VERS MAIN MENU SCREEN APRÈS UN COUR INSTANT
    // pour avoir la même interface que l'espace client
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainMenuScreen(
            role: 'client',
            appartement: widget.numAppartement,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('🏢 Espace Client (App: ${widget.numAppartement})'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Redirection vers votre espace...'),
          ],
        ),
      ),
    );
  }
}