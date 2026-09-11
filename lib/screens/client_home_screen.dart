// lib/screens/client_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'change_password_screen.dart';
import 'cotisations_list_screen.dart';
import 'login_screen.dart';

class ClientHomeScreen extends StatefulWidget {
  final String? appartement;

  const ClientHomeScreen({super.key, this.appartement});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String _userName = 'Client';
  String _userAppartement = '';
  bool _isLoading = true;
  bool _isLoadingCotisations = false;
  List<Map<String, dynamic>> _recentCotisations = [];
  double _totalCotisations = 0.0;
  int _cotisationsCount = 0;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _userAppartement = widget.appartement ?? '';
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          _userData = doc.data();
          _userName = _userData?['nom'] ?? _userData?['prenom'] ?? 'Client';
          if (_userAppartement.isEmpty) {
            _userAppartement = _userData?['appartement'] ?? '';
          }
        } else {
          _userName = user.email?.split('@').first ?? 'Client';
        }
        
        await _loadCotisations();
      } else {
        if (_userAppartement.isNotEmpty) {
          await _loadCotisationsByAppartement();
        }
      }
    } catch (e) {
      print('❌ Erreur chargement données client: $e');
      if (_userAppartement.isNotEmpty) {
        await _loadCotisationsByAppartement();
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadCotisationsByAppartement() async {
    try {
      final snapshot = await _firestore
          .collection('cotisations')
          .where('numAppartement', isEqualTo: _userAppartement)
          .orderBy('dateCreation', descending: true)
          .limit(5)
          .get();

      _recentCotisations = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'dateVersement': (data['dateVersement'] as Timestamp?)?.toDate(),
          'dateCreation': (data['dateCreation'] as Timestamp?)?.toDate(),
        };
      }).toList();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['montant'] ?? 0.0).toDouble();
      }
      _totalCotisations = total;
      _cotisationsCount = snapshot.docs.length;
    } catch (e) {
      print('❌ Erreur chargement cotisations: $e');
    }
  }

  Future<void> _loadCotisations() async {
    setState(() => _isLoadingCotisations = true);
    try {
      final snapshot = await _firestore
          .collection('cotisations')
          .where('numAppartement', isEqualTo: _userAppartement)
          .orderBy('dateCreation', descending: true)
          .limit(5)
          .get();

      _recentCotisations = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'dateVersement': (data['dateVersement'] as Timestamp?)?.toDate(),
          'dateCreation': (data['dateCreation'] as Timestamp?)?.toDate(),
        };
      }).toList();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['montant'] ?? 0.0).toDouble();
      }
      _totalCotisations = total;
      _cotisationsCount = snapshot.docs.length;
    } catch (e) {
      print('❌ Erreur chargement cotisations: $e');
    }
    setState(() => _isLoadingCotisations = false);
  }

  // ✅ Afficher le menu des options
  void _showMenuOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ Indicateur de fermeture
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // ✅ Titre du menu
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '📋 Menu Client',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
              const Divider(height: 24),
              // ✅ Options du menu
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Icon(Icons.person, color: Colors.green.shade700),
                ),
                title: const Text('Mon profil'),
                subtitle: const Text('Voir mes informations personnelles'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _showProfileDialog();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(Icons.payments, color: Colors.blue.shade700),
                ),
                title: const Text('Mes cotisations'),
                subtitle: const Text('Consulter l\'historique des cotisations'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  // ✅ Navigation vers la liste des cotisations
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CotisationsListScreen(
                        filterAppartement: _userAppartement,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 24),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: Icon(Icons.lock_outline, color: Colors.orange.shade700),
                ),
                title: const Text('🔑 Changer le mot de passe'),
                subtitle: const Text('Modifier votre mot de passe (4 chiffres)'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToChangePassword();
                },
              ),
              const Divider(height: 24),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade100,
                  child: Icon(Icons.logout, color: Colors.red.shade700),
                ),
                title: Text('Déconnexion', style: TextStyle(color: Colors.red.shade700)),
                subtitle: Text('Se déconnecter de l\'application', style: TextStyle(color: Colors.red.shade300)),
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red.shade300),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _navigateToChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person, color: Colors.green.shade700),
            const SizedBox(width: 8),
            const Text('Mon profil'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileItem('👤 Nom', _userName),
            const SizedBox(height: 8),
            _buildProfileItem('🏠 Appartement', _userAppartement),
            const SizedBox(height: 8),
            _buildProfileItem('📧 Email', _auth.currentUser?.email ?? 'N/A'),
            const SizedBox(height: 8),
            _buildProfileItem('📱 Téléphone', _userData?['telephone'] ?? 'Non renseigné'),
            const SizedBox(height: 8),
            _buildProfileItem('📌 Statut', _userData?['statut'] ?? 'proprietaire'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏠 Syndic - Client'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        actions: [
          // ✅ Bouton pour changer le mot de passe
          IconButton(
            icon: const Icon(Icons.lock_outline),
            onPressed: _navigateToChangePassword,
            tooltip: 'Changer le mot de passe',
          ),
          // ✅ Bouton Menu
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: _showMenuOptions,
            tooltip: 'Menu',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Carte de bienvenue
                    Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.green.shade700, Colors.green.shade900],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.white,
                                child: Text(
                                  _userName.isNotEmpty ? _userName[0].toUpperCase() : 'C',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bonjour,',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                    Text(
                                      _userName,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'Appartement: ${_userAppartement.isNotEmpty ? _userAppartement : 'Non défini'}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // ✅ Bouton menu dans la carte
                              IconButton(
                                icon: Icon(Icons.more_vert, color: Colors.white),
                                onPressed: _showMenuOptions,
                                tooltip: 'Menu',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ✅ Carte de résumé des cotisations
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.payments, color: Colors.green.shade700),
                                const SizedBox(width: 8),
                                const Text(
                                  '📊 Résumé des cotisations',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _isLoadingCotisations
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: _buildStatCard(
                                          '💰 Total versé',
                                          '${_totalCotisations.toStringAsFixed(2)} DH',
                                          Colors.green,
                                          Icons.account_balance_wallet,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildStatCard(
                                          '📋 Cotisations',
                                          '$_cotisationsCount',
                                          Colors.blue,
                                          Icons.description,
                                        ),
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ✅ Cotisations récentes
                    Row(
                      children: [
                        Icon(Icons.history, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          '📋 Dernières cotisations',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            // ✅ Navigation vers la liste des cotisations
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CotisationsListScreen(
                                  filterAppartement: _userAppartement,
                                ),
                              ),
                            );
                          },
                          child: const Text('Voir tout'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _isLoadingCotisations
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : _recentCotisations.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.payments_outlined, size: 40, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text(
                                        'Aucune cotisation enregistrée',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _recentCotisations.length,
                                itemBuilder: (context, index) {
                                  final cotisation = _recentCotisations[index];
                                  final date = cotisation['dateVersement'] as DateTime?;
                                  final montant = (cotisation['montant'] ?? 0.0).toDouble();
                                  final periode1 = cotisation['periode1'] ?? false;
                                  final periode2 = cotisation['periode2'] ?? false;
                                  
                                  String periode = '';
                                  if (periode1 && periode2) periode = 'S1+S2';
                                  else if (periode1) periode = 'S1';
                                  else if (periode2) periode = 'S2';
                                  
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(color: Colors.grey.shade200),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      leading: CircleAvatar(
                                        backgroundColor: montant > 0 ? Colors.green.shade100 : Colors.red.shade100,
                                        child: Icon(
                                          montant > 0 ? Icons.check : Icons.close,
                                          color: montant > 0 ? Colors.green.shade700 : Colors.red.shade700,
                                          size: 18,
                                        ),
                                      ),
                                      title: Text(
                                        '${DateFormat('dd/MM/yyyy').format(date ?? DateTime.now())}',
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      subtitle: Text(
                                        'Période: $periode • Année: ${cotisation['annee'] ?? ''}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      trailing: Text(
                                        '${montant.toStringAsFixed(2)} DH',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: montant > 0 ? Colors.green.shade700 : Colors.red.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}