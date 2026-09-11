// lib/screens/change_password_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String? appartement;

  const ChangePasswordScreen({super.key, this.appartement});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String? _successMessage;
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = '❌ Les mots de passe ne correspondent pas';
      });
      return;
    }

    if (_newPasswordController.text == _currentPasswordController.text) {
      setState(() {
        _errorMessage = '❌ Le nouveau mot de passe doit être différent de l\'ancien';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      final String newPassword = _newPasswordController.text;
      final String appartement = widget.appartement ?? '';
      
      // ✅ 1. METTRE À JOUR DANS LA COLLECTION "mots_de_passe"
      await _updatePasswordInMotsDePasse(appartement, newPassword);
      
      // ✅ 2. METTRE À JOUR DANS LA COLLECTION "users" (si elle existe)
      await _updatePasswordInUsers(appartement, newPassword);
      
      // ✅ 3. METTRE À JOUR DANS FIREBASE AUTH (si connecté)
      if (user != null) {
        try {
          final credential = EmailAuthProvider.credential(
            email: user.email!,
            password: _currentPasswordController.text,
          );
          await user.reauthenticateWithCredential(credential);
          await user.updatePassword(newPassword);
        } catch (e) {
          print('⚠️ Erreur Firebase Auth: $e');
        }
      }
      
      setState(() {
        _successMessage = '✅ Mot de passe changé avec succès !';
        _isLoading = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Mot de passe changé avec succès !'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });

    } catch (e) {
      setState(() {
        _errorMessage = '❌ Erreur: $e';
        _isLoading = false;
      });
    }
  }

  // ✅ Mettre à jour dans la collection "mots_de_passe"
  Future<void> _updatePasswordInMotsDePasse(String appartement, String newPassword) async {
    try {
      // Rechercher le document dans la collection "mots_de_passe"
      final querySnapshot = await _firestore
          .collection('mots_de_passe')
          .where('numAppartement', isEqualTo: appartement)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        // ✅ Mettre à jour le document existant
        await querySnapshot.docs.first.reference.update({
          'motDePasseActuel': newPassword,
          'dateChangement': FieldValue.serverTimestamp(),
        });
        print('✅ Mot de passe mis à jour dans "mots_de_passe" pour: $appartement');
        return;
      }
      
      // Si aucun document trouvé, en créer un nouveau
      await _firestore.collection('mots_de_passe').add({
        'numAppartement': appartement,
        'motDePasseActuel': newPassword,
        'dateCreation': FieldValue.serverTimestamp(),
        'dateChangement': FieldValue.serverTimestamp(),
      });
      print('✅ Nouveau document créé dans "mots_de_passe" pour: $appartement');
      
    } catch (e) {
      print('❌ Erreur mise à jour "mots_de_passe": $e');
      rethrow;
    }
  }

  // ✅ Mettre à jour dans la collection "users" (si elle existe)
  Future<void> _updatePasswordInUsers(String appartement, String newPassword) async {
    try {
      // Méthode 1: Rechercher par appartement
      final querySnapshot = await _firestore
          .collection('users')
          .where('appartement', isEqualTo: appartement)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({
          'password': newPassword,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Mot de passe mis à jour dans "users" pour: $appartement');
        return;
      }
      
      // Méthode 2: Rechercher par numAppartement
      final querySnapshot2 = await _firestore
          .collection('users')
          .where('numAppartement', isEqualTo: appartement)
          .limit(1)
          .get();
      
      if (querySnapshot2.docs.isNotEmpty) {
        await querySnapshot2.docs.first.reference.update({
          'password': newPassword,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Mot de passe mis à jour dans "users" (numAppartement) pour: $appartement');
        return;
      }
      
      print('⚠️ Aucun utilisateur trouvé dans "users" pour: $appartement');
      
    } catch (e) {
      print('❌ Erreur mise à jour "users": $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔑 Changer le mot de passe'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Message d'information
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🔐 Sécurité du mot de passe',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Votre mot de passe doit être composé de 4 chiffres (ex: 1234)',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ✅ Message de succès
              if (_successMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ✅ Message d'erreur
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ✅ Mot de passe actuel
              _buildPasswordField(
                controller: _currentPasswordController,
                label: 'Mot de passe actuel',
                hint: 'Votre mot de passe actuel (4 chiffres)',
                icon: Icons.lock_outline,
                obscureText: _obscureCurrentPassword,
                onToggle: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer votre mot de passe actuel';
                  }
                  if (value.length != 4 || !RegExp(r'^[0-9]{4}$').hasMatch(value)) {
                    return 'Le mot de passe doit contenir 4 chiffres';
                  }
                  return null;
                },
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
              ),
              const SizedBox(height: 16),

              // ✅ Nouveau mot de passe
              _buildPasswordField(
                controller: _newPasswordController,
                label: 'Nouveau mot de passe',
                hint: 'Nouveau mot de passe (4 chiffres)',
                icon: Icons.lock_open,
                obscureText: _obscureNewPassword,
                onToggle: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un nouveau mot de passe';
                  }
                  if (value.length != 4 || !RegExp(r'^[0-9]{4}$').hasMatch(value)) {
                    return 'Le mot de passe doit contenir 4 chiffres';
                  }
                  return null;
                },
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
              ),
              const SizedBox(height: 16),

              // ✅ Confirmation du nouveau mot de passe
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Confirmer le nouveau mot de passe',
                hint: 'Confirmez le nouveau mot de passe (4 chiffres)',
                icon: Icons.lock_outline,
                obscureText: _obscureConfirmPassword,
                onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez confirmer le nouveau mot de passe';
                  }
                  if (value.length != 4 || !RegExp(r'^[0-9]{4}$').hasMatch(value)) {
                    return 'Le mot de passe doit contenir 4 chiffres';
                  }
                  return null;
                },
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
              ),
              const SizedBox(height: 8),

              // ✅ Indicateur de validation
              if (_newPasswordController.text.length == 4)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '✅ Mot de passe valide (4 chiffres)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // ✅ Boutons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade800,
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Annuler', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool obscureText,
    required VoidCallback onToggle,
    required String? Function(String?)? validator,
    required List<TextInputFormatter> inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      keyboardType: TextInputType.number,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 16, letterSpacing: 4),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.green.shade700),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey.shade600,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        helperText: '4 chiffres uniquement',
        helperStyle: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade500,
        ),
        counterText: '',
      ),
    );
  }
}