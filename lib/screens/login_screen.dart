// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main_menu_screen.dart';
import '../services/acces_service.dart';
import '../services/mot_de_passe_service.dart';
import 'client_changer_mot_de_passe_screen.dart';
// ✅ IMPORT DU BADGE UPDATER
import '../widgets/badge_updater.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _selectedRole = 'admin';
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _appartementController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  static const String ADMIN_PASSWORD = 'WAHDA2026@';

  final MotDePasseService _motDePasseService = MotDePasseService();

  @override
  void dispose() {
    _passwordController.dispose();
    _appartementController.dispose();
    super.dispose();
  }

  void _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (_selectedRole == 'admin') {
      if (_passwordController.text == ADMIN_PASSWORD) {
        final accesService = AccesService();
        await accesService.enregistrerAcces(
          numAppartement: 'ADMIN',
          role: 'admin',
        );

        if (mounted) {
          // ✅ BadgeUpdater enveloppe MainMenuScreen (ADMIN)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BadgeUpdater(
                userId: 'admin',
                child: const MainMenuScreen(
                  role: 'admin',
                ),
              ),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = '❌ Mot de passe administrateur incorrect';
          _isLoading = false;
        });
      }
    } else {
      final appartement = _appartementController.text.trim().toUpperCase();
      final motDePasse = _passwordController.text.trim();

      if (appartement.isEmpty) {
        setState(() {
          _errorMessage = '❌ Veuillez entrer un numéro d\'appartement';
          _isLoading = false;
        });
        return;
      }

      if (motDePasse.isEmpty) {
        setState(() {
          _errorMessage = '❌ Veuillez entrer votre mot de passe (4 chiffres)';
          _isLoading = false;
        });
        return;
      }

      if (motDePasse.length != 4) {
        setState(() {
          _errorMessage = '❌ Le mot de passe doit contenir exactement 4 chiffres';
          _isLoading = false;
        });
        return;
      }

      try {
        final result = await _motDePasseService.verifierConnexion(
          appartement,
          motDePasse,
        );

        if (result['success'] == true) {
          final aChange = result['aChange'] ?? false;
          final id = result['id'] ?? '';

          final accesService = AccesService();
          await accesService.enregistrerAcces(
            numAppartement: appartement,
            role: 'client',
          );

          if (!aChange) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ClientChangerMotDePasseScreen(
                    numAppartement: appartement,
                    docId: id,
                  ),
                ),
              );
            }
          } else {
            if (mounted) {
              // ✅ BadgeUpdater enveloppe MainMenuScreen (CLIENT)
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => BadgeUpdater(
                    userId: 'client_$appartement',
                    child: MainMenuScreen(
                      role: 'client',
                      appartement: appartement,
                    ),
                  ),
                ),
              );
            }
          }
        } else {
          setState(() {
            _errorMessage = '❌ ${result['message'] ?? 'Mot de passe client incorrect'}';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = '❌ Erreur de connexion: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade200.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/LOGO.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.blue.shade100,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.apartment,
                                size: 45,
                                color: Colors.blue.shade800,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'SYNDIC',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'SYNDIC',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                    letterSpacing: 4,
                  ),
                ),
                Text(
                  'AIN SEBAA - WAHDA',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue.shade600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 40),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🔐 Connexion',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choisissez votre profil et connectez-vous',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: _buildRoleCard(
                              icon: Icons.admin_panel_settings,
                              label: 'Admin',
                              color: Colors.blue,
                              isSelected: _selectedRole == 'admin',
                              onTap: () {
                                setState(() {
                                  _selectedRole = 'admin';
                                  _errorMessage = null;
                                  _passwordController.clear();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildRoleCard(
                              icon: Icons.person,
                              label: 'Client',
                              color: Colors.green,
                              isSelected: _selectedRole == 'client',
                              onTap: () {
                                setState(() {
                                  _selectedRole = 'client';
                                  _errorMessage = null;
                                  _passwordController.clear();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (_selectedRole == 'client') ...[
                        TextFormField(
                          controller: _appartementController,
                          decoration: const InputDecoration(
                            labelText: 'Numéro d\'appartement',
                            hintText: 'Ex: A1, B2, D2...',
                            prefixIcon: Icon(Icons.apartment),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (value) {
                            setState(() {
                              _errorMessage = null;
                            });
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: _selectedRole == 'admin'
                              ? 'Mot de passe Admin'
                              : 'Mot de passe Client (4 chiffres)',
                          hintText: _selectedRole == 'admin'
                              ? 'Entrez le mot de passe Admin'
                              : 'Entrez 4 chiffres (ex: 1234)',
                          prefixIcon: Icon(
                            _selectedRole == 'admin'
                                ? Icons.lock
                                : Icons.vpn_key,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                        onFieldSubmitted: (_) => _login(),
                        inputFormatters: [
                          if (_selectedRole == 'client')
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                          if (_selectedRole == 'client')
                            LengthLimitingTextInputFormatter(4),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_selectedRole == 'client')
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info,
                                size: 16,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '🔑 Pour saisir votre mot de passe, tapez 4 chiffres (ex: 1234)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 12),

                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 18,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedRole == 'admin'
                                ? Colors.blue.shade800
                                : Colors.green.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
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
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _selectedRole == 'admin'
                                          ? Icons.admin_panel_settings
                                          : Icons.login,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Se connecter en tant que ${_selectedRole == 'admin' ? 'Admin' : 'Client'}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Text(
                  '© 2026 - Syndic Management v1.0',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required IconData icon,
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey.shade500,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}