// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/firebase_service.dart';
import '../models/habitant.dart';
import 'add_habitant_screen.dart';
import 'habitants_list_screen.dart';
import 'habitant_details_screen.dart';
import '../services/import_service.dart'; // ⬅️ AJOUT

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService();
  final FirebaseService _firebase = FirebaseService();
  bool _isLoading = true;
  int _totalHabitants = 0;
  Map<String, int> _stats = {};
  List<Habitant> _recentHabitants = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      _totalHabitants = await _db.getTotalCount();
      _stats = await _db.getStatsByStatut();
      final all = await _db.getAllHabitants();
      _recentHabitants = all.length > 5 ? all.sublist(0, 5) : all;
    } catch (e) {
      print('❌ Erreur chargement: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _firebase.syncAllUnsynced();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Synchronisation terminée'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ⬇️ AFFICHER LE DIALOGUE D'IMPORT
  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.upload_file, color: Colors.green.shade700),
            const SizedBox(width: 8),
            const Text('Importer les habitants'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sélectionnez un fichier CSV :',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📄 Format attendu :'),
                  SizedBox(height: 4),
                  Text(
                    'Colonne 1: Appartement (ex: A1)',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Colonne 2: Nom complet (ex: AHMED TISSIR)',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Colonne 3: CIN (ex: J226742)',
                    style: TextStyle(fontSize: 12),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '💡 Le fichier doit être encodé en UTF-8',
                    style: TextStyle(fontSize: 11, color: Colors.blue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '⚠️ Attention :',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Les appartements déjà existants seront ignorés',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    '• Import limité à 3 habitants (test)',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _importData(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.folder_open),
            label: const Text('Choisir le fichier'),
          ),
        ],
      ),
    );
  }

  // ⬇️ IMPORTER LES DONNÉES
  void _importData(BuildContext context) async {
    final importService = ImportService();
    final scaffold = ScaffoldMessenger.of(context);

    // Afficher un dialogue de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Importation en cours...',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Veuillez patienter...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      // ⬇️ Appel de l'import avec sélection de fichier
      final results = await importService.importFromCSVWithPicker();

      // Fermer le dialogue
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Vérifier si l'utilisateur a annulé
      final cancelled = results['cancelled'] as bool? ?? false;
      if (cancelled) {
        if (mounted) {
          scaffold.showSnackBar(
            const SnackBar(
              content: Text('ℹ️ Import annulé'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      final imported = results['imported'] as int? ?? 0;
      final skipped = results['skipped'] as int? ?? 0;
      final errors = results['errors'] as int? ?? 0;

      // Recharger les données
      await _loadData();

      // Afficher le résultat
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  errors == 0 && imported > 0 ? Icons.check_circle : Icons.warning,
                  color: errors == 0 && imported > 0 ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  errors == 0 && imported > 0 ? '✅ Import réussi' : '⚠️ Import terminé',
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📊 $imported habitants importés'),
                Text('⏭️ $skipped doublons ignorés'),
                if (errors > 0)
                  Text(
                    '❌ $errors erreurs',
                    style: const TextStyle(color: Colors.red),
                  ),
                if (imported == 0 && errors == 0)
                  const Text(
                    '💡 Aucun nouvel habitant à importer',
                    style: TextStyle(color: Colors.blue),
                  ),
                const SizedBox(height: 8),
                Text(
                  '💡 Pour importer plus, modifiez "maxLignes" dans import_service.dart',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      // Snackbar
      if (imported > 0 && mounted) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text('✅ $imported habitants importés'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (errors > 0 && mounted) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text('⚠️ $errors erreurs'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        scaffold.showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏢 Syndic - Gestion Copropriété'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        actions: [
          // ⬇️ BOUTON D'IMPORT
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => _showImportDialog(context),
            tooltip: 'Importer CSV',
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncAll,
            tooltip: 'Synchroniser avec Firebase',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Cards
                  Row(
                    children: [
                      _buildStatCard('Total', '$_totalHabitants', Icons.people, Colors.blue),
                      _buildStatCard(
                        'Propriétaires',
                        '${_stats['proprietaire'] ?? 0}',
                        Icons.home,
                        Colors.green,
                      ),
                      _buildStatCard(
                        'Locataires',
                        '${_stats['locataire'] ?? 0}',
                        Icons.apartment,
                        Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Quick Actions
                  const Text('⚡ Actions rapides', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.add,
                          label: 'Ajouter un habitant',
                          color: Colors.blue,
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddHabitantScreen()),
                            );
                            if (result == true) await _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.list,
                          label: 'Voir tous',
                          color: Colors.green,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const HabitantsListScreen()),
                            );
                            await _loadData();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Recent Habitants
                  if (_recentHabitants.isNotEmpty) ...[
                    const Text('🕐 Derniers habitants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ..._recentHabitants.map((h) => _buildRecentCard(h)),
                  ],

                  const SizedBox(height: 20),
                  // Firebase status
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('habitants').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_done, color: Colors.green.shade700),
                            const SizedBox(width: 10),
                            Text(
                              '${snapshot.data!.docs.length} habitants synchronisés',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddHabitantScreen()),
          );
          if (result == true) await _loadData();
        },
        backgroundColor: Colors.blue.shade800,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Ajouter un habitant',
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentCard(Habitant h) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: h.estProprietaire ? Colors.green : Colors.orange,
          child: Text(
            h.numAppartement,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(h.nomComplet),
        subtitle: Text('📞 ${h.telephone} • ${h.statutTexte}'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => HabitantDetailsScreen(habitant: h)),
          );
          await _loadData();
        },
      ),
    );
  }
}