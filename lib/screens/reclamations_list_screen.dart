// lib/screens/reclamations_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReclamationsListScreen extends StatefulWidget {
  const ReclamationsListScreen({super.key});

  @override
  State<ReclamationsListScreen> createState() => _ReclamationsListScreenState();
}

class _ReclamationsListScreenState extends State<ReclamationsListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _reclamations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatut = 'Tous';
  bool _isAdmin = false;

  final List<String> _statuts = ['Tous', 'En attente', 'En cours', 'Résolu', 'Refusé'];
  final List<String> _priorites = ['Basse', 'Moyenne', 'Haute', 'Urgente'];

  @override
  void initState() {
    super.initState();
    _isAdmin = true; // À remplacer par votre logique de rôle
    _loadReclamations();
  }

  Future<void> _loadReclamations() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore.collection('reclamations').get();

      setState(() {
        _reclamations = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          String statut = data['statut'] ?? 'En attente';
          if (statut == 'en_attente') statut = 'En attente';
          else if (statut == 'en_cours') statut = 'En cours';
          else if (statut == 'resolu') statut = 'Résolu';
          else if (statut == 'refuse') statut = 'Refusé';
          
          String priorite = data['priorite'] ?? 'Moyenne';
          if (priorite == 'basse') priorite = 'Basse';
          else if (priorite == 'moyenne') priorite = 'Moyenne';
          else if (priorite == 'haute') priorite = 'Haute';
          else if (priorite == 'urgente') priorite = 'Urgente';
          
          return {
            'id': doc.id,
            'titre': data['titre'] ?? 'N/A',
            'description': data['description'] ?? '',
            'appartement': data['appartement'] ?? 'N/A',
            'statut': statut,
            'priorite': priorite,
            'dateCreation': data['dateCreation'] != null
                ? (data['dateCreation'] as Timestamp).toDate()
                : DateTime.now(),
            'dateResolution': data['dateResolution'] != null
                ? (data['dateResolution'] as Timestamp).toDate()
                : null,
            // ✅ CORRECTION ICI : On récupère 'reponseAdmin' et on le met dans 'reponse'
            'reponse': data['reponseAdmin'] ?? '', 
            'userId': data['utilisateurId'] ?? '',
            'userName': data['utilisateurNom'] ?? '',
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
  Future<void> _editReclamation(Map<String, dynamic> reclamation) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut modifier'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final TextEditingController titreController = TextEditingController(
      text: reclamation['titre'],
    );
    final TextEditingController descriptionController = TextEditingController(
      text: reclamation['description'],
    );
    final TextEditingController reponseController = TextEditingController(
      text: reclamation['reponse'] ?? '',
    );
    
    String selectedStatut = _statuts.contains(reclamation['statut']) 
        ? reclamation['statut'] 
        : 'En attente';
    String selectedPriorite = _priorites.contains(reclamation['priorite']) 
        ? reclamation['priorite'] 
        : 'Moyenne';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✏️ Modifier la réclamation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titreController,
                decoration: const InputDecoration(
                  labelText: 'Titre *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reponseController,
                decoration: const InputDecoration(
                  labelText: 'Réponse (admin)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedStatut,
                decoration: const InputDecoration(
                  labelText: 'Statut',
                  border: OutlineInputBorder(),
                ),
                items: _statuts.where((s) => s != 'Tous').map((statut) {
                  return DropdownMenuItem<String>(
                    value: statut,
                    child: Text(statut),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedStatut = value;
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedPriorite,
                decoration: const InputDecoration(
                  labelText: 'Priorité',
                  border: OutlineInputBorder(),
                ),
                items: _priorites.map((priorite) {
                  return DropdownMenuItem<String>(
                    value: priorite,
                    child: Text(priorite),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedPriorite = value;
                  }
                },
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
              try {
                String statutDB = selectedStatut;
                if (statutDB == 'En attente') statutDB = 'en_attente';
                else if (statutDB == 'En cours') statutDB = 'en_cours';
                else if (statutDB == 'Résolu') statutDB = 'resolu';
                else if (statutDB == 'Refusé') statutDB = 'refuse';
                
                String prioriteDB = selectedPriorite;
                if (prioriteDB == 'Basse') prioriteDB = 'basse';
                else if (prioriteDB == 'Moyenne') prioriteDB = 'moyenne';
                else if (prioriteDB == 'Haute') prioriteDB = 'haute';
                else if (prioriteDB == 'Urgente') prioriteDB = 'urgente';

                Map<String, dynamic> updates = {
                  'titre': titreController.text,
                  'description': descriptionController.text,
                  'statut': statutDB,
                  'priorite': prioriteDB,
                  'updatedAt': DateTime.now(),
                };
                
                if (reponseController.text.isNotEmpty) {
                  updates['reponseAdmin'] = reponseController.text;
                }
                
                if (selectedStatut == 'Résolu' && reclamation['statut'] != 'Résolu') {
                  updates['dateResolution'] = DateTime.now();
                }

                await _firestore.collection('reclamations').doc(reclamation['id']).update(updates);
                Navigator.pop(context);
                _loadReclamations();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Réclamation modifiée avec succès'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  // ✅ SUPPRESSION - Admin uniquement
  Future<void> _deleteReclamation(Map<String, dynamic> reclamation) async {
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
          'Voulez-vous vraiment supprimer la réclamation : ${reclamation['titre']} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('reclamations').doc(reclamation['id']).delete();
        _loadReclamations();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Réclamation supprimée avec succès'),
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

  Color _getPriorityColor(String priorite) {
    switch (priorite) {
      case 'Basse': return Colors.green;
      case 'Moyenne': return Colors.orange;
      case 'Haute': return Colors.red;
      case 'Urgente': return Colors.deepPurple;
      default: return Colors.grey;
    }
  }

  Color _getStatusColor(String statut) {
    switch (statut) {
      case 'Résolu': return Colors.green;
      case 'En cours': return Colors.blue;
      case 'Refusé': return Colors.red;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredReclamations = _reclamations.where((r) {
      final query = _searchQuery.toLowerCase();
      final matchSearch = r['titre'].toString().toLowerCase().contains(query) ||
          r['appartement'].toString().toLowerCase().contains(query);
      final matchStatut = _filterStatut == 'Tous' || r['statut'] == _filterStatut;
      return matchSearch && matchStatut;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('📝 Gestion des Réclamations'),
        backgroundColor: Colors.deepOrange.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReclamations,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: '🔍 Rechercher une réclamation...',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statuts.map((statut) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(statut),
                      selected: _filterStatut == statut,
                      onSelected: (_) => setState(() => _filterStatut = statut),
                      backgroundColor: Colors.grey.shade200,
                      selectedColor: Colors.deepOrange.shade100,
                      checkmarkColor: Colors.deepOrange.shade700,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredReclamations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.feedback_outlined, size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'Aucune réclamation trouvée',
                              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredReclamations.length,
                        padding: const EdgeInsets.all(8),
                        itemBuilder: (context, index) {
                          final reclamation = filteredReclamations[index];
                          final statusColor = _getStatusColor(reclamation['statut']);
                          final priorityColor = _getPriorityColor(reclamation['priorite']);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: priorityColor.withOpacity(0.3), width: 2),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: priorityColor.withOpacity(0.2),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: priorityColor,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      reclamation['titre'],
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      reclamation['statut'] ?? 'N/A',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Appartement: ${reclamation['appartement']}'),
                                  Text('Priorité: ${reclamation['priorite']}'),
                                  if (reclamation['description'].isNotEmpty)
                                    Text(
                                      reclamation['description'].length > 50
                                          ? '${reclamation['description'].substring(0, 50)}...'
                                          : reclamation['description'],
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                  Text(
                                    'Créé le: ${DateFormat('dd/MM/yy HH:mm').format(reclamation['dateCreation'])}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                  // ✅ AFFICHAGE DE LA RÉPONSE ADMIN
                                  if (reclamation['reponse'].isNotEmpty)
                                    Text(
                                      '📌 Réponse: ${reclamation['reponse']}',
                                      style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                                    ),
                                ],
                              ),
                              trailing: _isAdmin
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                          onPressed: () => _editReclamation(reclamation),
                                          tooltip: 'Modifier',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          onPressed: () => _deleteReclamation(reclamation),
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
}