// lib/screens/client_changer_mot_de_passe_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/mot_de_passe_service.dart';
import 'client_dashboard_screen.dart';

class ClientChangerMotDePasseScreen extends StatefulWidget {
  final String numAppartement;
  final String docId;

  const ClientChangerMotDePasseScreen({
    super.key,
    required this.numAppartement,
    required this.docId,
  });

  @override
  State<ClientChangerMotDePasseScreen> createState() => _ClientChangerMotDePasseScreenState();
}

class _ClientChangerMotDePasseScreenState extends State<ClientChangerMotDePasseScreen> {
  final TextEditingController _nouveauCodeController = TextEditingController();
  final TextEditingController _confirmationController = TextEditingController();
  final MotDePasseService _service = MotDePasseService();
  bool _isLoading = false;
  bool _obscureText = true;
  String _message = '';

  Future<void> _changerMotDePasse() async {
    final nouveauCode = _nouveauCodeController.text.trim();
    final confirmation = _confirmationController.text.trim();

    // ✅ Vérifications
    if (nouveauCode.isEmpty || confirmation.isEmpty) {
      setState(() => _message = '⚠️ Veuillez remplir tous les champs');
      return;
    }

    if (nouveauCode.length < 4) {
      setState(() => _message = '⚠️ Le code doit contenir au moins 4 chiffres');
      return;
    }

    if (nouveauCode != confirmation) {
      setState(() => _message = '⚠️ Les codes ne correspondent pas');
      return;
    }

    // ✅ Vérifier que le code n'est pas déjà utilisé par un autre appartement
    final disponible = await _service.isCodeDisponible(widget.numAppartement, nouveauCode);
    if (!disponible) {
      setState(() => _message = '⚠️ Ce code est déjà utilisé par un autre appartement');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _service.changerMotDePasse(
        widget.numAppartement,
        nouveauCode,
      );

      if (result['success'] == true) {
        // ✅ Mot de passe changé avec succès
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ClientDashboardScreen(
              numAppartement: widget.numAppartement,
            ),
          ),
        );
      } else {
        setState(() => _message = result['message'] ?? 'Erreur');
      }
    } catch (e) {
      setState(() => _message = 'Erreur: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('🔑 Changer votre mot de passe'),
        backgroundColor: Colors.orange.shade800,
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
                    Icons.vpn_key,
                    size: 60,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Première connexion',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Appartement ${widget.numAppartement}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Votre code sera automatiquement préfixé par "${widget.numAppartement}" pour éviter les doublons.\n\n'
                            'Ex: Si vous choisissez "0005", votre mot de passe sera "${widget.numAppartement}0005"',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_message.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _message.contains('⚠️') 
                            ? Colors.red.shade50 
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _message.contains('⚠️') 
                              ? Colors.red.shade200 
                              : Colors.green.shade200,
                        ),
                      ),
                      child: Text(
                        _message,
                        style: TextStyle(
                          color: _message.contains('⚠️') 
                              ? Colors.red.shade700 
                              : Colors.green.shade700,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nouveauCodeController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      labelText: 'Choisissez un code (4 chiffres)',
                      hintText: 'Ex: 1234, 0005, 9876',
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
                      helperText: 'Votre code sera préfixé par "${widget.numAppartement}"',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmationController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      labelText: 'Confirmez le code',
                      prefixIcon: const Icon(Icons.check_circle_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _changerMotDePasse(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _changerMotDePasse,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
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
                              '🔑 Changer le mot de passe',
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