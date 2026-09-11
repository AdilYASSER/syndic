// lib/screens/admin_initial_password_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminInitialPasswordScreen extends StatefulWidget {
  const AdminInitialPasswordScreen({super.key});

  @override
  State<AdminInitialPasswordScreen> createState() => _AdminInitialPasswordScreenState();
}

class _AdminInitialPasswordScreenState extends State<AdminInitialPasswordScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // ✅ Ajout du contrôleur de recherche
  final TextEditingController _searchController = TextEditingController();
  
  // ✅ Valeur de recherche actuelle
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅ Récupération des documents avec le code INITIAL uniquement
  Stream<QuerySnapshot> get _passwordsStream {
    return _firestore
        .collection('mots_de_passe')
        .orderBy('numAppartement')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('🔑 Codes initiaux des appartements'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
      ),
      body: Column(
        children: [
          // ✅ CHAMP DE RECHERCHE
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase().trim();
                });
              },
              decoration: InputDecoration(
                hintText: '🔍 Rechercher un appartement (ex: A1, D2...)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // ✅ LISTE FILTRÉE
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _passwordsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('❌ Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Aucun document dans la collection mots_de_passe'),
                  );
                }

                final docs = snapshot.data!.docs;

                // ✅ FILTRER LES RÉSULTATS SELON LA RECHERCHE
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final numAppartement = data['numAppartement']?.toString().toLowerCase() ?? '';
                  return numAppartement.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucun appartement trouvé pour "${_searchQuery.toUpperCase()}"',
                      // ✅ CORRECTION : 'const' supprimé ici
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                    
                    // ✅ Lire UNIQUEMENT le code initial (4 chiffres)
                    final String numAppartement = data['numAppartement']?.toString() ?? 'N/A';
                    final String codeInitial = data['codeInitial']?.toString() ?? 'N/A';
                    
                    // ✅ Vérifier le statut du changement (pour afficher le badge)
                    final bool aChange = data['aChange'] ?? false;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Icone selon le statut
                            CircleAvatar(
                              backgroundColor: aChange ? Colors.green.shade100 : Colors.orange.shade100,
                              child: Icon(
                                aChange ? Icons.check_circle : Icons.lock_clock,
                                color: aChange ? Colors.green : Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Appartement: $numAppartement',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Code initial: $codeInitial',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '⛔ Mot de passe changé NON visible',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade700,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Badge statut
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: aChange ? Colors.green.shade100 : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                aChange ? '✅ Changé' : '🔒 Initial',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: aChange ? Colors.green.shade700 : Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}