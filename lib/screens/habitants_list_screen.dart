// lib/screens/habitants_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HabitantsListScreen extends StatefulWidget {
  const HabitantsListScreen({super.key});

  @override
  State<HabitantsListScreen> createState() => _HabitantsListScreenState();
}

class _HabitantsListScreenState extends State<HabitantsListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _habitants = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatut = 'Tous';
  bool _isAdmin = false;

  final List<String> _statuts = ['Tous', 'Propriétaire', 'Locataire', 'Syndic'];

  @override
  void initState() {
    super.initState();
    _loadHabitants();
  }

  Future<void> _loadHabitants() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore.collection('habitants').get();
      setState(() {
        _habitants = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'nom': data['nom'] ?? 'N/A',
            'prenom': data['prenom'] ?? '',
            'appartement': data['appartement'] ?? 'N/A',
            'cin': data['cin'] ?? 'N/A',
            'telephone': data['telephone'] ?? 'N/A',
            'email': data['email'] ?? 'N/A',
            'statut': data['statut'] ?? 'Propriétaire',
            'dateArrivee': data['dateArrivee'] != null
                ? (data['dateArrivee'] as Timestamp).toDate()
                : null,
            'locataire': data['locataire'] ?? false,
            'proprietaire': data['proprietaire'] ?? true,
            'createdAt': data['createdAt'] != null
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.now(),
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ✅ MODIFICATION - Admin uniquement
  Future<void> _editHabitant(Map<String, dynamic> habitant) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut modifier'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final TextEditingController nomController = TextEditingController(text: habitant['nom']);
    final TextEditingController prenomController = TextEditingController(text: habitant['prenom']);
    final TextEditingController appartementController = TextEditingController(text: habitant['appartement']);
    final TextEditingController cinController = TextEditingController(text: habitant['cin']);
    final TextEditingController telephoneController = TextEditingController(text: habitant['telephone']);
    final TextEditingController emailController = TextEditingController(text: habitant['email']);
    String selectedStatut = habitant['statut'];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✏️ Modifier l\'habitant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nomController,
                decoration: const InputDecoration(labelText: 'Nom *'),
              ),
              TextFormField(
                controller: prenomController,
                decoration: const InputDecoration(labelText: 'Prénom'),
              ),
              TextFormField(
                controller: appartementController,
                decoration: const InputDecoration(labelText: 'Appartement *'),
              ),
              TextFormField(
                controller: cinController,
                decoration: const InputDecoration(labelText: 'CIN'),
              ),
              TextFormField(
                controller: telephoneController,
                decoration: const InputDecoration(labelText: 'Téléphone'),
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              DropdownButtonFormField<String>(
                value: selectedStatut,
                decoration: const InputDecoration(labelText: 'Statut'),
                items: _statuts.where((s) => s != 'Tous').map((statut) {
                  return DropdownMenuItem(value: statut, child: Text(statut));
                }).toList(),
                onChanged: (value) => selectedStatut = value!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nomController.text.isEmpty || appartementController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ Nom et appartement sont obligatoires'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              try {
                await _firestore.collection('habitants').doc(habitant['id']).update({
                  'nom': nomController.text,
                  'prenom': prenomController.text,
                  'appartement': appartementController.text,
                  'cin': cinController.text,
                  'telephone': telephoneController.text,
                  'email': emailController.text,
                  'statut': selectedStatut,
                  'updatedAt': DateTime.now(),
                });
                Navigator.pop(context);
                _loadHabitants();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Habitant modifié avec succès'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  // ✅ SUPPRESSION - Admin uniquement
  Future<void> _deleteHabitant(Map<String, dynamic> habitant) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut supprimer'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Confirmation de suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer ${habitant['nom']} (App: ${habitant['appartement']}) ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('habitants').doc(habitant['id']).delete();
        _loadHabitants();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Habitant supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Vérifier si l'utilisateur est admin (à adapter selon votre logique)
    _isAdmin = true; // À remplacer par votre logique de rôle

    final filteredHabitants = _habitants.where((h) {
      final query = _searchQuery.toLowerCase();
      final matchSearch = h['nom'].toString().toLowerCase().contains(query) ||
          h['appartement'].toString().toLowerCase().contains(query);
      final matchStatut = _filterStatut == 'Tous' || h['statut'] == _filterStatut;
      return matchSearch && matchStatut;
    }).toList();

    final proprietaires = filteredHabitants.where((h) => h['statut'] == 'Propriétaire').length;
    final locataires = filteredHabitants.where((h) => h['statut'] == 'Locataire').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('👥 Gestion Habitants'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔄 Ajout d\'habitant en développement'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              tooltip: 'Ajouter un habitant',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHabitants,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: '🔍 Rechercher un habitant...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          // Filtres
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Text('Filtrer par statut : ', style: TextStyle(fontWeight: FontWeight.w500)),
                Expanded(
                  child: DropdownButton<String>(
                    value: _filterStatut,
                    isExpanded: true,
                    items: _statuts.map((statut) {
                      return DropdownMenuItem(value: statut, child: Text(statut));
                    }).toList(),
                    onChanged: (value) => setState(() => _filterStatut = value!),
                  ),
                ),
              ],
            ),
          ),
          // Statistiques
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _buildStatCard('Propriétaires', proprietaires, Colors.blue),
                const SizedBox(width: 8),
                _buildStatCard('Locataires', locataires, Colors.green),
                const SizedBox(width: 8),
                _buildStatCard('Total', filteredHabitants.length, Colors.purple),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Liste
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredHabitants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun habitant trouvé',
                              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredHabitants.length,
                        padding: const EdgeInsets.all(8),
                        itemBuilder: (context, index) {
                          final habitant = filteredHabitants[index];
                          final isProprietaire = habitant['statut'] == 'Propriétaire';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: isProprietaire ? Colors.blue.shade100 : Colors.green.shade100,
                                child: Icon(
                                  isProprietaire ? Icons.home : Icons.person,
                                  color: isProprietaire ? Colors.blue : Colors.green,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${habitant['nom']} ${habitant['prenom']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isProprietaire ? Colors.blue : Colors.green,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      habitant['statut'] ?? 'N/A',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Appartement: ${habitant['appartement']}'),
                                  Text('CIN: ${habitant['cin']}'),
                                  Text('Tél: ${habitant['telephone']}'),
                                  if (habitant['dateArrivee'] != null)
                                    Text(
                                      'Arrivée: ${DateFormat('dd/MM/yyyy').format(habitant['dateArrivee'])}',
                                    ),
                                ],
                              ),
                              trailing: _isAdmin
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                          onPressed: () => _editHabitant(habitant),
                                          tooltip: 'Modifier',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          onPressed: () => _deleteHabitant(habitant),
                                          tooltip: 'Supprimer',
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}