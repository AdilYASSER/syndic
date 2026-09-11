// lib/screens/client_login_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/mot_de_passe_service.dart';
import 'client_changer_mot_de_passe_screen.dart';
import 'client_dashboard_screen.dart';

class ClientLoginScreen extends StatefulWidget {
  const ClientLoginScreen({super.key});

  @override
  State<ClientLoginScreen> createState() => _ClientLoginScreenState();
}

class _ClientLoginScreenState extends State<ClientLoginScreen> {
  final TextEditingController _appartementController = TextEditingController();
  final TextEditingController _motDePasseController = TextEditingController();
  final MotDePasseService _service = MotDePasseService();
  bool _isLoading = false;
  bool _obscureText = true;

  Future<void> _connexion() async {
    final numAppartement = _appartementController.text.trim().toUpperCase();
    final motDePasse = _motDePasseController.text.trim();

    if (numAppartement.isEmpty || motDePasse.isEmpty) {
      _showSnackBar('Veuillez remplir tous les champs', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _service.verifierConnexion(numAppartement, motDePasse);

      if (result['success'] == true) {
        final aChange = result['aChange'] ?? false;
        final id = result['id'];

        if (!aChange) {
          // ✅ Première connexion : obliger à changer le mot de passe
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ClientChangerMotDePasseScreen(
                numAppartement: numAppartement,
                docId: id,
              ),
            ),
          );
        } else {
          // ✅ Connexion normale
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ClientDashboardScreen(
                numAppartement: numAppartement,
              ),
            ),
          );
        }
      } else {
        _showSnackBar(result['message'] ?? 'Erreur de connexion', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Erreur: $e', Colors.red);
    }

    setState(() => _isLoading = false);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('🔐 Espace Client'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.apartment,
                    size: 60,
                    color: Colors.blue.shade800,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Connexion Client',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Entrez vos identifiants pour accéder à votre espace',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Numéro d'appartement
                  TextField(
                    controller: _appartementController,
                    decoration: InputDecoration(
                      labelText: 'Numéro d\'appartement',
                      hintText: 'Ex: A1, B5, C12',
                      prefixIcon: const Icon(Icons.apartment),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 16),
                  // Mot de passe
                  TextField(
                    controller: _motDePasseController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      hintText: 'Entrez votre code d\'accès',
                      prefixIcon: const Icon(Icons.vpn_key),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onSubmitted: (_) => _connexion(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        _showSnackBar('Contactez l\'administrateur', Colors.orange);
                      },
                      child: const Text('Mot de passe oublié ?'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _connexion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Se connecter',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}