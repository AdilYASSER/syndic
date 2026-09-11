import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

class DepensesScreen extends StatefulWidget {
  final bool isClient;
  const DepensesScreen({super.key, this.isClient = false});

  @override
  State<DepensesScreen> createState() => _DepensesScreenState();
}

class _DepensesScreenState extends State<DepensesScreen> {
  List<DocumentSnapshot> _depenses = [];
  bool _isLoading = true;
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _chargerDepenses();
  }

  Future<void> _chargerDepenses() async {
    setState(() {
      _isLoading = true;
      _debugInfo = 'Chargement...';
    });

    try {
      print('📊 === CHARGEMENT DES DÉPENSES ===');
      print('📱 Plateforme: ${await _getPlatform()}');
      print('👤 Client: ${widget.isClient ? "OUI" : "NON"}');

      final snapshot = await FirebaseFirestore.instance
          .collection('depenses')
          .orderBy('createdAt', descending: true)
          .get(const GetOptions(source: Source.server));

      print('📊 Nombre de dépenses trouvées: ${snapshot.docs.length}');

      for (var i = 0; i < snapshot.docs.length && i < 5; i++) {
        final doc = snapshot.docs[i];
        print('📝 Dépense ${i+1}: ${doc.id} -> ${doc.data()}');
      }

      if (snapshot.docs.isEmpty) {
        print('⚠️ Aucune dépense trouvée');
        setState(() {
          _debugInfo = 'Aucune dépense trouvée. Vérifiez que la collection "depenses" contient des documents.';
        });
      }

      setState(() {
        _depenses = snapshot.docs;
        _isLoading = false;
        _debugInfo = '${_depenses.length} dépenses chargées';
      });

    } catch (e) {
      print('❌ Erreur: $e');
      setState(() {
        _isLoading = false;
        _debugInfo = 'Erreur: $e';
      });
    }
  }

  Future<String> _getPlatform() async {
    if (await Firebase.app().options.projectId == null) {
      return 'Firebase non initialisé';
    }
    return '✅ Firebase OK';
  }

  // ✅ Navigation vers l'écran d'ajout (uniquement pour admin)
  void _naviguerVersAjout() {
    // ⛔ Bloqué pour le client
    if (widget.isClient) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⛔ Accès refusé - Les clients ne peuvent pas ajouter de dépenses'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // ✅ Navigation pour admin
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddDepenseScreen(), // Assurez-vous d'importer AddDepenseScreen
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isClient ? '📋 Mes Dépenses' : '📋 Dépenses'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerDepenses,
            tooltip: 'Recharger',
          ),
          IconButton(
            icon: const Icon(Icons.clear_cache),
            onPressed: _viderCache,
            tooltip: 'Vider le cache',
          ),
          // ✅ Indicateur de rôle dans l'AppBar
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: widget.isClient ? Colors.green.shade700 : Colors.orange.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.isClient ? '👤 Client' : '👑 Admin',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Info de debug
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_debugInfo, style: const TextStyle(fontSize: 12)),
                Text(
                  Platform.isAndroid ? '📱 Android' : '💻 Desktop',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _depenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.attach_money, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text('Aucune dépense', style: TextStyle(fontSize: 18)),
                            const SizedBox(height: 8),
                            Text(
                              'Collection: depenses',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 16),
                            // ✅ BOUTON AJOUTER UNIQUEMENT POUR ADMIN
                            if (!widget.isClient)
                              ElevatedButton.icon(
                                onPressed: _naviguerVersAjout,
                                icon: const Icon(Icons.add),
                                label: const Text('Ajouter une dépense'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade700,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            // ✅ Message pour le client
                            if (widget.isClient)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text(
                                  '👋 Mode consultation - Vous ne pouvez pas ajouter de dépenses',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _chargerDepenses,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Recharger'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _depenses.length,
                        itemBuilder: (context, index) {
                          final doc = _depenses[index];
                          final data = doc.data() as Map<String, dynamic>;
                          
                          // ✅ Extraction des données
                          final String description = data['description'] ?? 'Sans description';
                          final double montant = (data['montant'] ?? 0).toDouble();
                          final String categorie = data['categorie'] ?? 'Non catégorisé';
                          final String statut = data['statut'] ?? 'en_attente';
                          final String beneficiaire = data['beneficiaire'] ?? 'Non spécifié';
                          final String modePaiement = data['modePaiement'] ?? 'espece';
                          
                          // ✅ Couleur du statut
                          Color statutColor = Colors.grey;
                          if (statut.toLowerCase() == 'payé' || statut.toLowerCase() == 'paye') {
                            statutColor = Colors.green;
                          } else if (statut.toLowerCase() == 'annulé' || statut.toLowerCase() == 'annule') {
                            statutColor = Colors.red;
                          } else if (statut.toLowerCase() == 'en_attente') {
                            statutColor = Colors.orange;
                          }
                          
                          // ✅ Icône du mode de paiement
                          String paiementIcon = '💰';
                          if (modePaiement == 'virement') paiementIcon = '🏦';
                          if (modePaiement == 'cheque') paiementIcon = '📝';
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              title: Text(
                                description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  // Catégorie
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      categorie,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.orange.shade800,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Bénéficiaire
                                  Row(
                                    children: [
                                      Icon(Icons.person, size: 12, color: Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          beneficiaire,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Mode de paiement
                                  Row(
                                    children: [
                                      Text(
                                        '$paiementIcon $modePaiement',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Statut
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statutColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          statut.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: statutColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${montant.toStringAsFixed(2)} DH',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                  if (data['date'] != null)
                                    Text(
                                      DateFormat('dd/MM/yy').format(
                                        (data['date'] as Timestamp).toDate(),
                                      ),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      // ✅ FLOATING ACTION BUTTON - COMPLÈTEMENT SUPPRIMÉ POUR LE CLIENT
      floatingActionButton: widget.isClient 
          ? null // ⛔ PAS DE BOUTON POUR LE CLIENT
          : FloatingActionButton.extended(
              onPressed: _naviguerVersAjout,
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle Dépense'),
              tooltip: 'Ajouter une dépense',
            ),
    );
  }

  Future<void> _viderCache() async {
    try {
      setState(() {
        _debugInfo = 'Vidage du cache...';
        _isLoading = true;
      });

      await FirebaseFirestore.instance.disablePersistence();
      await Future.delayed(const Duration(seconds: 1));
      await FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
      await _chargerDepenses();

      setState(() {
        _debugInfo = '✅ Cache vidé, ${_depenses.length} dépenses chargées';
      });

      print('✅ Cache vidé avec succès');
    } catch (e) {
      print('❌ Erreur vidage cache: $e');
      setState(() {
        _debugInfo = 'Erreur vidage cache: $e';
        _isLoading = false;
      });
    }
  }
}