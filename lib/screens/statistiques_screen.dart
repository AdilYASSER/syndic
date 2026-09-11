// lib/screens/statistiques_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

class StatistiquesScreen extends StatefulWidget {
  final String role;
  final String? appartement;

  const StatistiquesScreen({
    super.key,
    required this.role,
    this.appartement,
  });

  @override
  State<StatistiquesScreen> createState() => _StatistiquesScreenState();
}

class _StatistiquesScreenState extends State<StatistiquesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _errorMessage;

  // ✅ Filtres de date
  DateTime _dateDebut = DateTime(2020, 1, 1);
  DateTime _dateFin = DateTime.now();
  
  // ✅ Données des statistiques
  Map<String, dynamic> _statsReclamations = {};
  Map<String, dynamic> _statsDiscussions = {};
  Map<String, dynamic> _statsCotisations = {};
  Map<String, dynamic> _statsRealisations = {};
  Map<String, dynamic> _statsDepenses = {};
  
  // ✅ Classements
  List<Map<String, dynamic>> _classementReclamations = [];
  List<Map<String, dynamic>> _classementCotisations = [];
  List<Map<String, dynamic>> _classementRealisations = [];
  List<Map<String, dynamic>> _classementDiscussions = [];
  
  // ✅ Journal des réalisations
  List<Map<String, dynamic>> _journalRealisations = [];
  
  // ✅ Données pour le tableau des cotisations
  List<String> _appartements = [];
  List<int> _anneesDisponibles = [];
  List<String> _periodesDisponibles = [];
  Set<String> _periodesSelectionnees = {};
  Map<String, Map<int, Map<String, double>>> _cotisationsParAppartement = {};
  Map<String, double> _totauxParAppartement = {};
  Map<String, double> _manquantParAppartement = {};
  double _totalGeneral = 0.0;
  double _totalManquant = 0.0;
  double _totalPaye = 0.0;
  int _nbAppartementsAJour = 0;
  int _nbAppartementsTotal = 0;
  
  // ✅ Données pour les graphiques par période
  Map<String, Map<String, int>> _statsParPeriode = {};
  
  // ✅ Données pour les dépenses
  Map<String, double> _depensesParPeriode = {};
  Map<String, double> _cotisationsParPeriode = {};
  List<String> _periodesDepenses = [];
  Set<String> _periodesDepensesSelectionnees = {};
  List<Map<String, dynamic>> _depensesDetails = [];
  double _totalDepenses = 0.0;
  double _totalCotisations = 0.0;
  
  // ✅ Onglet sélectionné
  int _selectedTab = 0;
  
  // ✅ Volets disponibles
  final List<String> _volets = [
    'Réclamations',
    'Cotisations',
    'Discussions',
    'Réalisations',
    'Dépenses',
  ];

  // ✅ Couleurs par volet
  final Map<String, Color> _couleursVolets = {
    'Réclamations': Colors.red,
    'Cotisations': Colors.green,
    'Discussions': Colors.blue,
    'Réalisations': Colors.orange,
    'Dépenses': Colors.purple,
  };

  @override
  void initState() {
    super.initState();
    _isAdmin = widget.role == 'admin';
    _loadAllStats();
  }

  // ✅ Charger toutes les statistiques
  Future<void> _loadAllStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _loadReclamationsStats();
      await _loadDiscussionsStats();
      await _loadCotisationsStats();
      await _loadRealisationsStats();
      await _loadCotisationsTable();
      await _loadDepensesStats();
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Erreur chargement stats: $e');
      setState(() {
        _errorMessage = 'Erreur de chargement: $e';
        _isLoading = false;
      });
    }
  }

  // ============ STATISTIQUES RÉCLAMATIONS ============
  Future<void> _loadReclamationsStats() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('reclamations')
          .get();

      print('📊 Réclamations trouvées: ${snapshot.docs.length}');

      Map<String, int> appartementCount = {};
      Map<String, int> categorieCount = {};
      int total = snapshot.docs.length;
      int resolved = 0, pending = 0, urgent = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        String status = data['statut'] ?? data['status'] ?? 'en_attente';
        String appartement = data['appartement'] ?? 'N/A';
        String priority = data['priorité'] ?? data['priorite'] ?? 'normale';
        String categorie = data['catégorie'] ?? data['categorie'] ?? 'Non catégorisé';
        
        appartementCount[appartement] = (appartementCount[appartement] ?? 0) + 1;
        categorieCount[categorie] = (categorieCount[categorie] ?? 0) + 1;
        
        if (status == 'resolu' || status == 'résolu' || status == 'resolue') {
          resolved++;
        } else if (status == 'en_attente') {
          pending++;
        }
        
        if (priority == 'urgent' || priority == 'urgente') {
          urgent++;
        }
      }

      List<Map<String, dynamic>> classement = appartementCount.entries
          .map((e) => {'appartement': e.key, 'count': e.value})
          .toList();
      classement.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      List<Map<String, dynamic>> categories = categorieCount.entries
          .map((e) => {'categorie': e.key, 'count': e.value})
          .toList();
      categories.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      setState(() {
        _statsReclamations = {
          'total': total,
          'resolved': resolved,
          'pending': pending,
          'urgent': urgent,
          'taux': total > 0 ? (resolved / total * 100) : 0,
          'categories': categories.take(5).toList(),
        };
        _classementReclamations = classement;
      });
      
      print('✅ Réclamations: $total trouvées, $resolved résolues');
    } catch (e) {
      print('❌ Erreur réclamations: $e');
    }
  }

  // ============ STATISTIQUES DISCUSSIONS ============
  Future<void> _loadDiscussionsStats() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('discussions')
          .get();

      print('📊 Discussions trouvées: ${snapshot.docs.length}');

      int total = snapshot.docs.length;
      int messages = 0;
      Map<String, int> appartementCount = {};
      Map<String, int> voletCount = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        String appartement = data['createdByAppartement'] ?? 
                            data['appartement'] ?? 
                            'N/A';
        String volet = data['volet'] ?? 'Général';
        
        int nbMessages = 0;
        if (data['messageCount'] != null) {
          nbMessages = (data['messageCount'] as num).toInt();
        } else if (data['messages'] is List) {
          nbMessages = (data['messages'] as List).length;
        } else if (data['messages'] is Map) {
          nbMessages = (data['messages'] as Map).length;
        } else {
          nbMessages = 1;
        }
        
        messages += nbMessages;
        appartementCount[appartement] = (appartementCount[appartement] ?? 0) + nbMessages;
        voletCount[volet] = (voletCount[volet] ?? 0) + nbMessages;
      }

      List<Map<String, dynamic>> classementApp = appartementCount.entries
          .map((e) => {'appartement': e.key, 'count': e.value})
          .toList();
      classementApp.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      List<Map<String, dynamic>> classementVolet = voletCount.entries
          .map((e) => {'volet': e.key, 'count': e.value})
          .toList();
      classementVolet.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      setState(() {
        _statsDiscussions = {
          'total': total,
          'messages': messages,
          'moyenne': total > 0 ? (messages / total) : 0,
          'topVolets': classementVolet.take(5).toList(),
        };
        _classementDiscussions = classementApp;
      });
      
      print('✅ Discussions: $total trouvées, $messages messages');
    } catch (e) {
      print('❌ Erreur discussions: $e');
    }
  }

  // ============ STATISTIQUES COTISATIONS ============
  Future<void> _loadCotisationsStats() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('cotisations')
          .get();

      print('📊 Cotisations trouvées: ${snapshot.docs.length}');

      Map<String, double> totauxParAppartement = {};
      double totalPaye = 0.0;
      int payes = 0, impayes = 0;
      double montantTotal = 0.0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        String appartement = data['numAppartement'] ?? 'N/A';
        double montant = (data['montant'] as num?)?.toDouble() ?? 0;
        
        bool periode1 = data['periode1'] ?? false;
        bool periode2 = data['periode2'] ?? false;
        
        montantTotal += montant;
        
        if (periode1 || periode2) {
          totalPaye += montant;
          payes++;
        } else {
          impayes++;
        }
        
        totauxParAppartement[appartement] = (totauxParAppartement[appartement] ?? 0) + montant;
      }

      List<Map<String, dynamic>> classement = totauxParAppartement.entries
          .map((e) => {'appartement': e.key, 'total': e.value})
          .toList();
      classement.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

      setState(() {
        _statsCotisations = {
          'total': snapshot.docs.length,
          'montant_total': montantTotal,
          'payes': payes,
          'impayes': impayes,
          'taux_paiement': snapshot.docs.isEmpty ? 0 : (payes / snapshot.docs.length * 100),
          'total_paye': totalPaye,
        };
        _classementCotisations = classement;
      });
      
      print('✅ Cotisations: ${snapshot.docs.length} trouvées');
    } catch (e) {
      print('❌ Erreur cotisations: $e');
    }
  }

  // ============ STATISTIQUES RÉALISATIONS ============
  Future<void> _loadRealisationsStats() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('realisations')
          .get();

      print('📊 Réalisations trouvées: ${snapshot.docs.length}');

      Map<String, int> voletCount = {};
      List<Map<String, dynamic>> journal = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        String volet = data['volet'] ?? 'Autres';
        String description = data['description'] ?? '';
        List<String> images = List<String>.from(data['images'] ?? []);
        
        DateTime date;
        if (data['date'] is Timestamp) {
          date = (data['date'] as Timestamp).toDate();
        } else if (data['date'] is DateTime) {
          date = data['date'] as DateTime;
        } else if (data['createdAt'] is Timestamp) {
          date = (data['createdAt'] as Timestamp).toDate();
        } else {
          date = DateTime.now();
        }
        
        voletCount[volet] = (voletCount[volet] ?? 0) + 1;
        
        journal.add({
          'id': doc.id,
          'date': date,
          'volet': volet,
          'description': description,
          'images': images,
          'nbImages': images.length,
        });
      }

      journal.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      List<Map<String, dynamic>> classement = voletCount.entries
          .map((e) => {'volet': e.key, 'count': e.value})
          .toList();
      classement.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      setState(() {
        _statsRealisations = {
          'total': snapshot.docs.length,
          'volets': voletCount,
        };
        _journalRealisations = journal;
        _classementRealisations = classement;
      });
      
      print('✅ Réalisations: ${snapshot.docs.length} trouvées');
    } catch (e) {
      print('❌ Erreur réalisations: $e');
    }
  }

  // ============ STATISTIQUES DÉPENSES ============
  Future<void> _loadDepensesStats() async {
    try {
      // ✅ Charger toutes les dépenses
      QuerySnapshot snapshot = await _firestore
          .collection('depenses')
          .get();

      print('📊 Dépenses trouvées: ${snapshot.docs.length}');

      // ✅ Initialiser les données
      _depensesParPeriode = {};
      _cotisationsParPeriode = {};
      _periodesDepenses = [];
      _depensesDetails = [];
      _totalDepenses = 0.0;
      _totalCotisations = 0.0;
      
      // ✅ Récupérer les périodes disponibles des cotisations depuis _periodesDisponibles
      Set<String> periodesSet = {};
      for (var periode in _periodesDisponibles) {
        periodesSet.add(periode);
      }
      
      // ✅ Si aucune période n'est disponible, ajouter les périodes par défaut
      if (periodesSet.isEmpty) {
        for (int annee = 2025; annee <= 2027; annee++) {
          periodesSet.add('${annee}_S1');
          periodesSet.add('${annee}_S2');
        }
      }
      
      _periodesDepenses = periodesSet.toList()..sort((a, b) {
        int anneeA = int.tryParse(a.split('_')[0]) ?? 0;
        int anneeB = int.tryParse(b.split('_')[0]) ?? 0;
        if (anneeA != anneeB) return anneeA.compareTo(anneeB);
        return a.compareTo(b);
      });
      
      print('📋 Périodes disponibles pour les dépenses: $_periodesDepenses');
      
      // ✅ Initialiser les sélections des périodes pour les dépenses (tout coché par défaut)
      if (_periodesDepensesSelectionnees.isEmpty && _periodesDepenses.isNotEmpty) {
        _periodesDepensesSelectionnees = Set.from(_periodesDepenses);
      }

      // ✅ Calculer les dépenses par période
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final montant = (data['montant'] as num?)?.toDouble() ?? 0.0;
        final titre = data['titre'] ?? data['description'] ?? 'Sans titre';
        final categorie = data['categorie'] ?? 'Non catégorisé';
        final description = data['description'] ?? '';
        
        DateTime date;
        if (data['date'] is Timestamp) {
          date = (data['date'] as Timestamp).toDate();
        } else if (data['date'] is DateTime) {
          date = data['date'] as DateTime;
        } else if (data['createdAt'] is Timestamp) {
          date = (data['createdAt'] as Timestamp).toDate();
        } else {
          date = DateTime.now();
        }
        
        final annee = date.year;
        final mois = date.month;
        final isS1 = mois <= 6;
        final periodeKey = '${annee}_${isS1 ? 'S1' : 'S2'}';
        
        _totalDepenses += montant;
        
        if (_periodesDepenses.contains(periodeKey)) {
          _depensesParPeriode[periodeKey] = (_depensesParPeriode[periodeKey] ?? 0.0) + montant;
        }
        
        _depensesDetails.add({
          'titre': titre,
          'categorie': categorie,
          'description': description,
          'montant': montant,
          'date': date,
          'periode': periodeKey,
        });
      }

      _depensesDetails.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      // ✅ Calculer les cotisations par période à partir de _cotisationsParAppartement
      for (var periode in _periodesDepenses) {
        final parts = periode.split('_');
        final annee = int.tryParse(parts[0]) ?? 0;
        final isS1 = parts[1] == 'S1';
        
        double totalCotisations = 0.0;
        
        if (_cotisationsParAppartement.isNotEmpty && _appartements.isNotEmpty) {
          for (var app in _appartements) {
            final montant = _cotisationsParAppartement[app]?[annee]?[isS1 ? 'S1' : 'S2'] ?? 0.0;
            totalCotisations += montant;
          }
        }
        
        _cotisationsParPeriode[periode] = totalCotisations;
        _totalCotisations += totalCotisations;
        
        print('📊 Période $periode: Cotisations=$totalCotisations, Dépenses=${_depensesParPeriode[periode] ?? 0}');
      }

      setState(() {});
      
      print('✅ ${_depensesParPeriode.length} périodes avec dépenses');
      print('💰 Total dépenses: $_totalDepenses');
      print('💰 Total cotisations: $_totalCotisations');
      
    } catch (e) {
      print('❌ Erreur dépenses: $e');
    }
  }

  // ============ TABLEAU DES COTISATIONS ============
  Future<void> _loadCotisationsTable() async {
    try {
      final habitantsSnapshot = await _firestore
          .collection('habitants')
          .get();

      Set<String> appartementsSet = {};
      
      for (var doc in habitantsSnapshot.docs) {
        final data = doc.data();
        final app = data['numAppartement']?.toString().trim() ?? '';
        
        if (app.isNotEmpty && 
            app != '0' && 
            app != 'N/A' && 
            app != 'null' && 
            app != '' &&
            app != 'undefined') {
          
          final cleanedApp = app.replaceAll(RegExp(r'\s+'), ' ').trim();
          appartementsSet.add(cleanedApp);
        }
      }
      
      _appartements = appartementsSet.toList()..sort();
      _nbAppartementsTotal = _appartements.length;
      
      print('✅ ${_appartements.length} appartements UNIQUES chargés');

      final snapshot = await _firestore
          .collection('cotisations')
          .get();

      Set<String> periodesSet = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final annee = data['annee'] as int?;
        if (annee != null) {
          if (data['periode1'] == true) {
            periodesSet.add('${annee}_S1');
          }
          if (data['periode2'] == true) {
            periodesSet.add('${annee}_S2');
          }
        }
      }
      
      _periodesDisponibles = periodesSet.toList()..sort((a, b) {
        int anneeA = int.tryParse(a.split('_')[0]) ?? 0;
        int anneeB = int.tryParse(b.split('_')[0]) ?? 0;
        if (anneeA != anneeB) return anneeA.compareTo(anneeB);
        return a.compareTo(b);
      });
      
      if (_periodesSelectionnees.isEmpty) {
        _periodesSelectionnees = Set.from(_periodesDisponibles);
      }

      Set<int> anneesSet = {};
      for (var periode in _periodesDisponibles) {
        final annee = int.tryParse(periode.split('_')[0]) ?? 0;
        if (annee > 0) anneesSet.add(annee);
      }
      _anneesDisponibles = anneesSet.toList()..sort();

      const double MONTANT_ATTENDU = 1800.0;
      _cotisationsParAppartement = {};
      _totauxParAppartement = {};
      _manquantParAppartement = {};
      _totalGeneral = 0.0;
      _totalManquant = 0.0;
      _totalPaye = 0.0;
      _nbAppartementsAJour = 0;
      _statsParPeriode = {};

      for (var app in _appartements) {
        _cotisationsParAppartement[app] = {};
        for (var annee in _anneesDisponibles) {
          _cotisationsParAppartement[app]![annee] = {
            'S1': 0.0,
            'S2': 0.0,
          };
        }
        _totauxParAppartement[app] = 0.0;
        _manquantParAppartement[app] = 0.0;
      }

      for (var periode in _periodesDisponibles) {
        _statsParPeriode[periode] = {
          'honores': 0,
          'nonHonores': 0,
        };
      }

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final app = data['numAppartement']?.toString().trim() ?? '';
        final annee = data['annee'] as int?;
        final montant = (data['montant'] ?? 0.0).toDouble();
        final periode1 = data['periode1'] ?? false;
        final periode2 = data['periode2'] ?? false;
        
        if (app.isNotEmpty && 
            annee != null && 
            _cotisationsParAppartement.containsKey(app)) {
          if (periode1) {
            _cotisationsParAppartement[app]![annee]!['S1'] = 
                (_cotisationsParAppartement[app]![annee]!['S1'] ?? 0.0) + montant;
          }
          if (periode2) {
            _cotisationsParAppartement[app]![annee]!['S2'] = 
                (_cotisationsParAppartement[app]![annee]!['S2'] ?? 0.0) + montant;
          }
        }
      }

      for (var periode in _periodesDisponibles) {
        final parts = periode.split('_');
        final annee = int.tryParse(parts[0]) ?? 0;
        final isS1 = parts[1] == 'S1';
        
        int honores = 0;
        int nonHonores = 0;
        
        for (var app in _appartements) {
          final montant = _cotisationsParAppartement[app]?[annee]?[isS1 ? 'S1' : 'S2'] ?? 0.0;
          if (montant >= MONTANT_ATTENDU) {
            honores++;
          } else {
            nonHonores++;
          }
        }
        
        _statsParPeriode[periode] = {
          'honores': honores,
          'nonHonores': nonHonores,
        };
      }

      for (var app in _appartements) {
        double totalApp = 0.0;
        double manquantApp = 0.0;
        int periodesAttendues = 0;
        
        for (var periode in _periodesDisponibles) {
          if (!_periodesSelectionnees.contains(periode)) continue;
          
          final parts = periode.split('_');
          final annee = int.tryParse(parts[0]) ?? 0;
          final isS1 = parts[1] == 'S1';
          
          periodesAttendues++;
          final montant = _cotisationsParAppartement[app]?[annee]?[isS1 ? 'S1' : 'S2'] ?? 0.0;
          totalApp += montant;
        }
        
        final montantAttendu = periodesAttendues * MONTANT_ATTENDU;
        manquantApp = montantAttendu - totalApp;
        if (manquantApp < 0) manquantApp = 0;
        
        _totauxParAppartement[app] = totalApp;
        _manquantParAppartement[app] = manquantApp;
        _totalGeneral += totalApp;
        _totalManquant += manquantApp;
        _totalPaye += totalApp;
        
        final estAJour = manquantApp == 0 && totalApp >= montantAttendu;
        if (estAJour) _nbAppartementsAJour++;
      }
      
      setState(() {});
      
    } catch (e) {
      print('❌ Erreur chargement tableau cotisations: $e');
    }
  }

  // ============ CHANGER FILTRES ============
  Future<void> _changerFiltres() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📅 Filtres de date'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Date début'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_dateDebut)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateDebut,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  locale: const Locale('fr', 'FR'),
                );
                if (picked != null) {
                  setState(() => _dateDebut = picked);
                }
              },
            ),
            ListTile(
              title: const Text('Date fin'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_dateFin)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateFin,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  locale: const Locale('fr', 'FR'),
                );
                if (picked != null) {
                  setState(() => _dateFin = picked);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadAllStats();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
  }

  // ============ TOGGLE PÉRIODE ============
  void _togglePeriode(String periode) {
    setState(() {
      if (_periodesSelectionnees.contains(periode)) {
        _periodesSelectionnees.remove(periode);
      } else {
        _periodesSelectionnees.add(periode);
      }
    });
    _loadCotisationsTable();
  }

  void _togglePeriodeDepense(String periode) {
    setState(() {
      if (_periodesDepensesSelectionnees.contains(periode)) {
        _periodesDepensesSelectionnees.remove(periode);
      } else {
        _periodesDepensesSelectionnees.add(periode);
      }
    });
  }

  IconData _getIconForVolet(String volet) {
    switch (volet) {
      case 'Réclamations':
        return Icons.feedback;
      case 'Cotisations':
        return Icons.payments;
      case 'Discussions':
        return Icons.forum;
      case 'Réalisations':
        return Icons.construction;
      case 'Dépenses':
        return Icons.receipt_long;
      default:
        return Icons.circle;
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
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
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, {
    bool isHeader = false,
    bool isBold = false,
    Color? color,
    double fontSize = 10,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isHeader ? Colors.white : (color ?? Colors.black87),
          fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: fontSize,
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ============ GRAPHIQUE DE COMPARAISON ============
  Widget _buildComparisonChart() {
    final List<String> periodes = _periodesDepenses
        .where((p) => _periodesDepensesSelectionnees.contains(p))
        .toList();
    
    if (periodes.isEmpty) {
      return const SizedBox.shrink();
    }

    double maxValue = 0;
    for (var periode in periodes) {
      final cotisation = _cotisationsParPeriode[periode] ?? 0.0;
      final depense = _depensesParPeriode[periode] ?? 0.0;
      if (cotisation > maxValue) maxValue = cotisation;
      if (depense > maxValue) maxValue = depense;
    }
    maxValue = maxValue * 1.2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildLegendItem('Cotisations', Colors.green),
              const SizedBox(width: 16),
              _buildLegendItem('Dépenses', Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: Row(
              children: periodes.asMap().entries.map((entry) {
                final index = entry.key;
                final periode = entry.value;
                final cotisation = _cotisationsParPeriode[periode] ?? 0.0;
                final depense = _depensesParPeriode[periode] ?? 0.0;
                final isS1 = periode.split('_')[1] == 'S1';
                final label = periode.replaceAll('_', ' ');
                
                final double cotisationHeight = maxValue > 0 ? (cotisation / maxValue) * 200 : 0;
                final double depenseHeight = maxValue > 0 ? (depense / maxValue) * 200 : 0;
                
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // ✅ Barres côte à côte avec montants en haut
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // ✅ Barre Cotisations avec montant
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // ✅ Montant au-dessus de la barre
                              Text(
                                cotisation > 0 ? '${cotisation.toStringAsFixed(0)}' : '0',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                height: cotisationHeight,
                                width: 30,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          // ✅ Barre Dépenses avec montant
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // ✅ Montant au-dessus de la barre
                              Text(
                                depense > 0 ? '${depense.toStringAsFixed(0)}' : '0',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                height: depenseHeight,
                                width: 30,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // ✅ Étiquette
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isS1 ? Colors.green.shade100 : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            color: isS1 ? Colors.green.shade700 : Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // ✅ Échelle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0 DH', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              Text('${maxValue.toStringAsFixed(0)} DH', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodeChart(String periode, int honores, int nonHonores, String taux) {
    final parts = periode.split('_');
    final annee = parts[0];
    final type = parts[1];
    final isS1 = type == 'S1';
    final total = honores + nonHonores;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isS1 ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$annee $type',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isS1 ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '$total appartements',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(
                    painter: _PieChartPainter(
                      honores: honores,
                      nonHonores: nonHonores,
                      total: total,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Honorés: $honores',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Non honorés: $nonHonores',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Taux: $taux%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCotisationsTable() {
    const double MONTANT_ATTENDU = 1800.0;
    
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cellWidth = screenWidth > 600 ? 95 : 75;
    final bool isSmallScreen = screenWidth < 600;
    
    Set<int> anneesSelectionnees = {};
    for (var periode in _periodesSelectionnees) {
      final annee = int.tryParse(periode.split('_')[0]) ?? 0;
      if (annee > 0) anneesSelectionnees.add(annee);
    }
    List<int> anneesTriees = anneesSelectionnees.toList()..sort();
    
    List<Widget> headers = [
      _buildTableCell('Appartement', isHeader: true, fontSize: 12),
    ];
    
    for (var annee in anneesTriees) {
      final keyS1 = '${annee}_S1';
      final keyS2 = '${annee}_S2';
      final hasS1 = _periodesSelectionnees.contains(keyS1);
      final hasS2 = _periodesSelectionnees.contains(keyS2);
      
      if (hasS1) {
        headers.add(_buildTableCell('$annee\nS1', isHeader: true, fontSize: 11));
      }
      if (hasS2) {
        headers.add(_buildTableCell('$annee\nS2', isHeader: true, fontSize: 11));
      }
    }
    headers.add(_buildTableCell('Manquant', isHeader: true, fontSize: 11));
    headers.add(_buildTableCell('Total', isHeader: true, fontSize: 12));
    headers.add(_buildTableCell('Statut', isHeader: true, fontSize: 11));

    List<Widget> totalRow = [
      _buildTableCell('TOTAL', isHeader: true, isBold: true, fontSize: 12),
    ];
    
    Map<String, double> totauxParPeriode = {};
    for (var periode in _periodesSelectionnees) {
      totauxParPeriode[periode] = 0.0;
    }
    
    for (var app in _appartements) {
      for (var periode in _periodesSelectionnees) {
        final parts = periode.split('_');
        final annee = int.tryParse(parts[0]) ?? 0;
        final isS1 = parts[1] == 'S1';
        final montant = _cotisationsParAppartement[app]?[annee]?[isS1 ? 'S1' : 'S2'] ?? 0.0;
        totauxParPeriode[periode] = (totauxParPeriode[periode] ?? 0.0) + montant;
      }
    }
    
    for (var periode in _periodesSelectionnees) {
      totalRow.add(_buildTableCell(
        '${totauxParPeriode[periode]?.toStringAsFixed(0) ?? '0'}',
        isBold: true,
        fontSize: 11,
      ));
    }
    
    totalRow.add(_buildTableCell(
      '${_totalManquant.toStringAsFixed(0)}',
      isBold: true,
      color: Colors.red.shade700,
      fontSize: 11,
    ));
    totalRow.add(_buildTableCell(
      '${_totalPaye.toStringAsFixed(0)}',
      isBold: true,
      color: Colors.green.shade700,
      fontSize: 12,
    ));
    totalRow.add(_buildTableCell(
      '${_nbAppartementsAJour}/${_nbAppartementsTotal}',
      isBold: true,
      color: Colors.blue.shade700,
      fontSize: 11,
    ));

    List<TableRow> rows = [];
    
    rows.add(TableRow(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade900],
        ),
      ),
      children: headers,
    ));
    
    rows.add(TableRow(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
      ),
      children: totalRow,
    ));
    
    for (var app in _appartements) {
      List<Widget> cells = [
        _buildTableCell(app, fontSize: 11),
      ];
      
      double totalApp = 0.0;
      
      for (var periode in _periodesSelectionnees) {
        final parts = periode.split('_');
        final annee = int.tryParse(parts[0]) ?? 0;
        final isS1 = parts[1] == 'S1';
        final montant = _cotisationsParAppartement[app]?[annee]?[isS1 ? 'S1' : 'S2'] ?? 0.0;
        totalApp += montant;
        cells.add(_buildTableCell(
          montant > 0 ? montant.toStringAsFixed(0) : '-',
          color: montant > 0 ? Colors.green.shade700 : Colors.grey.shade400,
          fontSize: 10,
        ));
      }
      
      final nbPeriodes = _periodesSelectionnees.length;
      final montantAttendu = nbPeriodes * MONTANT_ATTENDU;
      final manquant = montantAttendu - totalApp > 0 ? montantAttendu - totalApp : 0.0;
      final estAJour = manquant == 0 && totalApp >= montantAttendu;
      
      cells.add(_buildTableCell(
        manquant > 0 ? manquant.toStringAsFixed(0) : '0',
        color: manquant > 0 ? Colors.red.shade700 : Colors.green.shade700,
        isBold: manquant > 0,
        fontSize: 10,
      ));
      cells.add(_buildTableCell(
        totalApp.toStringAsFixed(0),
        color: Colors.blue.shade700,
        isBold: true,
        fontSize: 11,
      ));
      cells.add(_buildTableCell(
        estAJour ? '✅' : '⏳',
        color: estAJour ? Colors.green : Colors.orange,
        fontSize: 12,
      ));
      
      Color? bgColor;
      if (estAJour) {
        bgColor = Colors.green.shade50;
      } else if (manquant > 1800) {
        bgColor = Colors.red.shade50;
      } else if (manquant > 900) {
        bgColor = Colors.orange.shade50;
      } else if (manquant > 0) {
        bgColor = Colors.yellow.shade50;
      }
      
      rows.add(TableRow(
        decoration: BoxDecoration(
          color: bgColor,
        ),
        children: cells,
      ));
    }

    Map<int, TableColumnWidth> columnWidths = {};
    columnWidths[0] = const FixedColumnWidth(100);
    
    int colIndex = 1;
    int nbPeriodesTotal = _periodesSelectionnees.length;
    
    for (int i = 0; i < nbPeriodesTotal; i++) {
      columnWidths[colIndex + i] = FixedColumnWidth(cellWidth);
    }
    
    int lastIndex = colIndex + nbPeriodesTotal;
    columnWidths[lastIndex] = const FixedColumnWidth(100);
    columnWidths[lastIndex + 1] = const FixedColumnWidth(90);
    columnWidths[lastIndex + 2] = const FixedColumnWidth(80);

    return Table(
      border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
      columnWidths: columnWidths,
      children: rows,
    );
  }

  // ============ TAB RÉCLAMATIONS ============
  Widget _buildReclamationsTab() {
    final stats = _statsReclamations;
    final categories = stats['categories'] as List? ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: '📋 Total',
                  value: '${stats['total'] ?? 0}',
                  color: Colors.blue,
                  icon: Icons.receipt_long,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  title: '✅ Résolues',
                  value: '${stats['resolved'] ?? 0}',
                  color: Colors.green,
                  icon: Icons.check_circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: '⏳ En attente',
                  value: '${stats['pending'] ?? 0}',
                  color: Colors.orange,
                  icon: Icons.hourglass_empty,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  title: '🔴 Urgentes',
                  value: '${stats['urgent'] ?? 0}',
                  color: Colors.red,
                  icon: Icons.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: '📊 Taux',
                  value: '${(stats['taux'] ?? 0).toStringAsFixed(1)}%',
                  color: Colors.purple,
                  icon: Icons.percent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  title: '🏆 Top',
                  value: _classementReclamations.isNotEmpty 
                      ? '${_classementReclamations[0]['appartement']}' 
                      : '-',
                  color: Colors.teal,
                  icon: Icons.emoji_events,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (categories.isNotEmpty) ...[
            const Text(
              '📊 Réclamations par catégorie',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: categories.map((item) {
                  final total = stats['total'] ?? 1;
                  final percentage = (item['count'] as int) / total * 100;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['categorie'],
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              '${item['count']} (${percentage.toStringAsFixed(1)}%)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          if (_classementReclamations.isNotEmpty) ...[
            const Text(
              '🏆 Classement des appartements',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._classementReclamations.take(10).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isFirst = index == 0;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isFirst ? Colors.amber.shade100 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFirst ? Colors.amber.shade700 : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${index + 1}.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isFirst ? Colors.amber.shade700 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isFirst ? Icons.emoji_events : Icons.circle,
                      size: 16,
                      color: isFirst ? Colors.amber : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Appartement ${item['appartement']}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Text(
                      '${item['count']} réclamation${(item['count'] as int) > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
          
          if ((stats['total'] ?? 0) == 0)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.feedback_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Aucune réclamation trouvée'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============ TAB COTISATIONS ============
  Widget _buildCotisationsTab() {
    final stats = _statsCotisations;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: '📋 Total',
                  value: '${stats['total'] ?? 0}',
                  color: Colors.blue,
                  icon: Icons.receipt_long,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  title: '💰 Montant total',
                  value: '${(stats['montant_total'] ?? 0).toStringAsFixed(0)} DH',
                  color: Colors.green,
                  icon: Icons.attach_money,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: '✅ Payées',
                  value: '${stats['payes'] ?? 0}',
                  color: Colors.green,
                  icon: Icons.check_circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  title: '❌ Impayées',
                  value: '${stats['impayes'] ?? 0}',
                  color: Colors.red,
                  icon: Icons.cancel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: '📊 Taux paiement',
                  value: '${(stats['taux_paiement'] ?? 0).toStringAsFixed(1)}%',
                  color: Colors.purple,
                  icon: Icons.percent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  title: '💵 Total payé',
                  value: '${(stats['total_paye'] ?? 0).toStringAsFixed(0)} DH',
                  color: Colors.teal,
                  icon: Icons.payments,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Périodes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_periodesSelectionnees.length == _periodesDisponibles.length) {
                            _periodesSelectionnees.clear();
                          } else {
                            _periodesSelectionnees = Set.from(_periodesDisponibles);
                          }
                        });
                        _loadCotisationsTable();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _periodesSelectionnees.length == _periodesDisponibles.length
                            ? 'Tout désélectionner'
                            : 'Tout sélectionner',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_nbAppartementsTotal} appartements',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _periodesDisponibles.map((periode) {
                    final isSelected = _periodesSelectionnees.contains(periode);
                    final parts = periode.split('_');
                    final annee = parts[0];
                    final type = parts[1];
                    final isS1 = type == 'S1';
                    
                    bool hasData = false;
                    for (var app in _appartements) {
                      final anneeInt = int.tryParse(annee) ?? 0;
                      final montant = _cotisationsParAppartement[app]?[anneeInt]?[isS1 ? 'S1' : 'S2'] ?? 0.0;
                      if (montant > 0) {
                        hasData = true;
                        break;
                      }
                    }
                    
                    return GestureDetector(
                      onTap: () => _togglePeriode(periode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? (isS1 ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15))
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected 
                                ? (isS1 ? Colors.green : Colors.orange)
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                              size: 16,
                              color: isSelected 
                                  ? (isS1 ? Colors.green : Colors.orange)
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$annee ${isS1 ? 'S1' : 'S2'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected 
                                    ? (isS1 ? Colors.green.shade700 : Colors.orange.shade700)
                                    : Colors.grey.shade500,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            if (!hasData)
                              Text(
                                ' (0)',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Total général ${_totalPaye.toStringAsFixed(0)} DH',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          if (_periodesSelectionnees.isNotEmpty) ...[
            const Text(
              '📊 Taux d\'honorés par période',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._periodesSelectionnees.toList().map((periode) {
              final stats = _statsParPeriode[periode] ?? {'honores': 0, 'nonHonores': 0};
              final honores = stats['honores'] ?? 0;
              final nonHonores = stats['nonHonores'] ?? 0;
              final total = honores + nonHonores;
              final taux = total > 0 ? (honores / total * 100).toStringAsFixed(1) : '0.0';
              
              return _buildPeriodeChart(periode, honores, nonHonores, taux);
            }).toList(),
          ],
          
          const SizedBox(height: 16),
          
          if (_appartements.isNotEmpty && _periodesSelectionnees.isNotEmpty) ...[
            const Text(
              '📊 Tableau des cotisations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Total général',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        Text(
                          '${_totalPaye.toStringAsFixed(0)} DH',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Manquant',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        Text(
                          '${_totalManquant.toStringAsFixed(0)} DH',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'À jour',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        Text(
                          '${_nbAppartementsAJour}/${_nbAppartementsTotal}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: _buildCotisationsTable(),
                  ),
                ),
              ),
            ),
          ],
          
          if (_appartements.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.payments_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Aucune cotisation trouvée'),
                  ],
                ),
              ),
            ),
          
          if (_periodesSelectionnees.isEmpty && _appartements.isNotEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.filter_alt_off, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Aucune période sélectionnée'),
                    SizedBox(height: 8),
                    Text(
                      'Cochez au moins une période pour afficher les données',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============ TAB DISCUSSIONS ============
  Widget _buildDiscussionsTab() {
    final stats = _statsDiscussions;
    final topVolets = stats['topVolets'] as List? ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: '💬 Discussions',
                  value: '${stats['total'] ?? 0}',
                  color: Colors.cyan,
                  icon: Icons.forum,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  title: '✉️ Messages',
                  value: '${stats['messages'] ?? 0}',
                  color: Colors.purple,
                  icon: Icons.message,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: '📊 Moyenne/msg',
                  value: '${(stats['moyenne'] ?? 0).toStringAsFixed(1)}',
                  color: Colors.orange,
                  icon: Icons.calculate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  title: '🏆 Top App',
                  value: _classementDiscussions.isNotEmpty 
                      ? _classementDiscussions[0]['appartement'] 
                      : '-',
                  color: Colors.teal,
                  icon: Icons.emoji_events,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (topVolets.isNotEmpty) ...[
            const Text(
              '📊 Volets les plus discutés',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: topVolets.map((item) {
                  final total = stats['messages'] ?? 1;
                  final percentage = (item['count'] as int) / total * 100;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['volet'],
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              '${item['count']} (${percentage.toStringAsFixed(1)}%)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            color: Colors.cyan.shade700,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          if (_classementDiscussions.isNotEmpty) ...[
            const Text(
              '🏆 Appartements actifs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._classementDiscussions.take(10).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isFirst = index == 0;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isFirst ? Colors.amber.shade100 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFirst ? Colors.amber.shade700 : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${index + 1}.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isFirst ? Colors.amber.shade700 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isFirst ? Icons.emoji_events : Icons.circle,
                      size: 16,
                      color: isFirst ? Colors.amber : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Appartement ${item['appartement']}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Text(
                      '${item['count']} message${(item['count'] as int) > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
          
          if ((stats['total'] ?? 0) == 0)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.forum_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Aucune discussion trouvée'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============ TAB RÉALISATIONS ============
  Widget _buildRealisationsTab() {
    final stats = _statsRealisations;
    final total = stats['total'] ?? 0;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: '🛠️ Total réalisations',
                  value: '$total',
                  color: Colors.blue,
                  icon: Icons.construction,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  title: '📂 Volets',
                  value: '${_classementRealisations.length}',
                  color: Colors.green,
                  icon: Icons.folder,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_classementRealisations.isNotEmpty) ...[
            const Text(
              '🏆 Classement des volets',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ..._classementRealisations.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isFirst = index == 0;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isFirst ? Colors.amber.shade100 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFirst ? Colors.amber.shade700 : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${index + 1}.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isFirst ? Colors.amber.shade700 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isFirst ? Icons.emoji_events : Icons.circle,
                      size: 16,
                      color: isFirst ? Colors.amber : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item['volet'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Text(
                      '${item['count']} réalisation${(item['count'] as int) > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
          
          const SizedBox(height: 16),
          
          const Text(
            '📋 Journal des réalisations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          if (_journalRealisations.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Aucune réalisation trouvée',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ..._journalRealisations.map((realisation) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade100,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd/MM/yyyy').format(realisation['date'] as DateTime),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            realisation['volet'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if ((realisation['nbImages'] as int) > 0)
                          Row(
                            children: [
                              Icon(Icons.photo, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                '${realisation['nbImages']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      realisation['description'] as String,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  // ============ TAB DÉPENSES ============
  Widget _buildDepensesTab() {
    List<Widget> children = [];

    // ✅ Titre
    children.add(
      const Text(
        '📊 Comparaison Cotisations vs Dépenses',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    children.add(const SizedBox(height: 8));
    children.add(
      const Text(
        'Visualisez les cotisations encaissées et les dépenses réalisées par période',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
    );
    children.add(const SizedBox(height: 16));

    // ✅ Résumé des totaux
    children.add(
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    '💰 Cotisations',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${_totalCotisations.toStringAsFixed(0)} DH',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.grey.shade300,
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '💳 Dépenses',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${_totalDepenses.toStringAsFixed(0)} DH',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.grey.shade300,
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '📊 Solde',
                    style: TextStyle(
                      fontSize: 10,
                      color: (_totalCotisations - _totalDepenses) >= 0 
                          ? Colors.blue.shade700 
                          : Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${(_totalCotisations - _totalDepenses).toStringAsFixed(0)} DH',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: (_totalCotisations - _totalDepenses) >= 0 
                          ? Colors.blue.shade700 
                          : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    children.add(const SizedBox(height: 16));

    // ✅ Filtres Périodes
    children.add(
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Périodes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.purple,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_periodesDepensesSelectionnees.length == _periodesDepenses.length) {
                        _periodesDepensesSelectionnees.clear();
                      } else {
                        _periodesDepensesSelectionnees = Set.from(_periodesDepenses);
                      }
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _periodesDepensesSelectionnees.length == _periodesDepenses.length
                        ? 'Tout désélectionner'
                        : 'Tout sélectionner',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_depensesDetails.length} dépenses',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _periodesDepenses.map((periode) {
                final isSelected = _periodesDepensesSelectionnees.contains(periode);
                final parts = periode.split('_');
                final annee = parts[0];
                final type = parts[1];
                final isS1 = type == 'S1';
                
                final cotisation = _cotisationsParPeriode[periode] ?? 0.0;
                final depense = _depensesParPeriode[periode] ?? 0.0;
                final hasData = cotisation > 0 || depense > 0;
                
                return GestureDetector(
                  onTap: () => _togglePeriodeDepense(periode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? (isS1 ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15))
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? (isS1 ? Colors.green : Colors.orange)
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                          size: 16,
                          color: isSelected 
                              ? (isS1 ? Colors.green : Colors.orange)
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$annee ${isS1 ? 'S1' : 'S2'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected 
                                ? (isS1 ? Colors.green.shade700 : Colors.orange.shade700)
                                : Colors.grey.shade500,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (!hasData)
                          Text(
                            ' (0)',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade400,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
    children.add(const SizedBox(height: 16));

    // ✅ Graphique de comparaison
    if (_periodesDepensesSelectionnees.isNotEmpty) {
      children.add(_buildComparisonChart());
    } else {
      children.add(
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Center(
            child: Column(
              children: [
                Icon(Icons.filter_alt_off, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Aucune période sélectionnée',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Cochez au moins une période pour afficher les données',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }
    children.add(const SizedBox(height: 16));

    // ✅ Tableau récapitulatif par période
    if (_periodesDepensesSelectionnees.isNotEmpty) {
      children.add(
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📋 Récapitulatif par période',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._periodesDepenses.where((p) => _periodesDepensesSelectionnees.contains(p)).map((periode) {
                final cotisation = _cotisationsParPeriode[periode] ?? 0.0;
                final depense = _depensesParPeriode[periode] ?? 0.0;
                final solde = cotisation - depense;
                final isS1 = periode.split('_')[1] == 'S1';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isS1 ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isS1 ? Colors.green.shade200 : Colors.orange.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          periode.replaceAll('_', ' '),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Cotisations',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${cotisation.toStringAsFixed(0)} DH',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Dépenses',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${depense.toStringAsFixed(0)} DH',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Solde',
                              style: TextStyle(
                                fontSize: 9,
                                color: solde >= 0 ? Colors.blue.shade700 : Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${solde.toStringAsFixed(0)} DH',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: solde >= 0 ? Colors.blue.shade700 : Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      );
    }
    children.add(const SizedBox(height: 16));

    // ✅ Détail des dépenses
    if (_depensesDetails.isNotEmpty) {
      children.add(
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📋 Détail des dépenses',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._depensesDetails
                  .where((d) => _periodesDepensesSelectionnees.contains(d['periode']))
                  .take(20)
                  .map((depense) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt,
                        size: 16,
                        color: Colors.purple.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              depense['titre'] ?? 'Sans titre',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${depense['categorie']} • ${DateFormat('dd/MM/yyyy').format(depense['date'])}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${(depense['montant'] as double).toStringAsFixed(0)} DH',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              if (_depensesDetails
                  .where((d) => _periodesDepensesSelectionnees.contains(d['periode']))
                  .length > 20)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '... et ${_depensesDetails.where((d) => _periodesDepensesSelectionnees.contains(d['periode'])).length - 20} autres dépenses',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // ============ BUILD ============
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _volets.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('📊 Statistiques'),
          backgroundColor: _isAdmin ? Colors.purple.shade700 : Colors.green.shade700,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 4,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isAdmin ? Colors.orange.shade700 : Colors.green.shade700,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isAdmin ? '👑 Admin' : '👤 Client',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _changerFiltres,
              tooltip: 'Filtres de date',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAllStats,
              tooltip: 'Rafraîchir',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Chargement des statistiques...'),
                  ],
                ),
              )
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.grey.shade100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Du ${DateFormat('dd/MM/yyyy').format(_dateDebut)} au ${DateFormat('dd/MM/yyyy').format(_dateFin)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Container(
                    color: Colors.grey.shade100,
                    child: TabBar(
                      isScrollable: true,
                      indicatorColor: _isAdmin ? Colors.purple.shade700 : Colors.green.shade700,
                      indicatorWeight: 3,
                      labelColor: _isAdmin ? Colors.purple.shade700 : Colors.green.shade700,
                      unselectedLabelColor: Colors.grey.shade600,
                      onTap: (index) {
                        setState(() => _selectedTab = index);
                      },
                      tabs: _volets.map((volet) {
                        return Tab(
                          child: Row(
                            children: [
                              Icon(
                                _getIconForVolet(volet),
                                size: 16,
                                color: _couleursVolets[volet],
                              ),
                              const SizedBox(width: 4),
                              Text(volet),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildReclamationsTab(),
                        _buildCotisationsTab(),
                        _buildDiscussionsTab(),
                        _buildRealisationsTab(),
                        _buildDepensesTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ============ CUSTOM PAINTER POUR LE CAMEMBERT ============
class _PieChartPainter extends CustomPainter {
  final int honores;
  final int nonHonores;
  final int total;

  _PieChartPainter({
    required this.honores,
    required this.nonHonores,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    if (total == 0) {
      final paint = Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, paint);
      
      final textSpan = TextSpan(
        text: '0%',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      final painter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      painter.layout();
      painter.paint(
        canvas,
        Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
      );
      return;
    }

    final startAngle = -90 * 3.14159 / 180;
    final sweepHonores = (honores / total) * 2 * 3.14159;
    final sweepNonHonores = (nonHonores / total) * 2 * 3.14159;

    final paintHonores = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepHonores,
      true,
      paintHonores,
    );

    final paintNonHonores = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle + sweepHonores,
      sweepNonHonores,
      true,
      paintNonHonores,
    );

    final paintCenter = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.6, paintCenter);

    final taux = (honores / total * 100).toStringAsFixed(1);
    final textSpan = TextSpan(
      text: '$taux%',
      style: TextStyle(
        color: Colors.green.shade800,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
    final painter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    );
    painter.layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}