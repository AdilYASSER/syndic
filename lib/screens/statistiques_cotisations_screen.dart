// lib/screens/statistiques_cotisations_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StatistiquesCotisationsScreen extends StatefulWidget {
  final String role;
  final String? appartement;

  const StatistiquesCotisationsScreen({
    super.key,
    required this.role,
    this.appartement,
  });

  @override
  State<StatistiquesCotisationsScreen> createState() => _StatistiquesCotisationsScreenState();
}

class _StatistiquesCotisationsScreenState extends State<StatistiquesCotisationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = true;
  
  // ✅ Filtres
  List<int> _anneesDisponibles = [];
  List<int> _anneesSelectionnees = [];
  Set<String> _periodesSelectionnees = {'S1', 'S2'};
  
  // ✅ Données
  List<Map<String, dynamic>> _cotisationsData = [];
  Map<String, Map<int, Map<String, double>>> _cotisationsParAppartement = {};
  List<String> _appartements = [];
  Map<String, double> _totauxParAppartement = {};
  Map<String, double> _manquantParAppartement = {};
  double _totalGeneral = 0.0;
  double _totalManquant = 0.0;
  double _totalPaye = 0.0;
  int _nbAppartementsAJour = 0;
  int _nbAppartementsTotal = 0;
  List<Map<String, dynamic>> _classementRetard = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _loadCotisations();
      await _loadHabitants();
      _calculerStatistiques();
      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Erreur: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCotisations() async {
    final snapshot = await _firestore
        .collection('cotisations')
        .get();
    
    _anneesDisponibles = [];
    Set<int> anneesSet = {};
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final annee = data['annee'] as int?;
      if (annee != null) {
        anneesSet.add(annee);
      }
    }
    
    _anneesDisponibles = anneesSet.toList()..sort();
    
    if (_anneesSelectionnees.isEmpty) {
      _anneesSelectionnees = List.from(_anneesDisponibles);
    }
  }

  Future<void> _loadHabitants() async {
    final snapshot = await _firestore
        .collection('habitants')
        .get();
    
    _appartements = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final app = data['numAppartement'] ?? '';
      if (app.isNotEmpty) {
        _appartements.add(app);
      }
    }
    _appartements.sort();
  }

  void _calculerStatistiques() async {
    _cotisationsParAppartement = {};
    _totauxParAppartement = {};
    _manquantParAppartement = {};
    _classementRetard = [];
    _totalGeneral = 0.0;
    _totalManquant = 0.0;
    _totalPaye = 0.0;
    _nbAppartementsAJour = 0;
    _nbAppartementsTotal = _appartements.length;

    const double MONTANT_ATTENDU = 1800.0;

    for (var app in _appartements) {
      _cotisationsParAppartement[app] = {};
      for (var annee in _anneesSelectionnees) {
        _cotisationsParAppartement[app]![annee] = {
          'S1': 0.0,
          'S2': 0.0,
        };
      }
      _totauxParAppartement[app] = 0.0;
      _manquantParAppartement[app] = 0.0;
    }

    for (var annee in _anneesSelectionnees) {
      final snapshot = await _firestore
          .collection('cotisations')
          .where('annee', isEqualTo: annee)
          .get();
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final app = data['numAppartement'] ?? '';
        final montant = (data['montant'] ?? 0.0).toDouble();
        final periode1 = data['periode1'] ?? false;
        final periode2 = data['periode2'] ?? false;
        
        if (app.isNotEmpty && _cotisationsParAppartement.containsKey(app)) {
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
    }

    for (var app in _appartements) {
      double totalApp = 0.0;
      double manquantApp = 0.0;
      int periodesAttendues = 0;
      int periodesPayees = 0;
      
      for (var annee in _anneesSelectionnees) {
        if (_periodesSelectionnees.contains('S1')) {
          periodesAttendues++;
          final montantS1 = _cotisationsParAppartement[app]![annee]!['S1'] ?? 0.0;
          totalApp += montantS1;
          if (montantS1 >= MONTANT_ATTENDU) periodesPayees++;
        }
        if (_periodesSelectionnees.contains('S2')) {
          periodesAttendues++;
          final montantS2 = _cotisationsParAppartement[app]![annee]!['S2'] ?? 0.0;
          totalApp += montantS2;
          if (montantS2 >= MONTANT_ATTENDU) periodesPayees++;
        }
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
      
      _classementRetard.add({
        'appartement': app,
        'total': totalApp,
        'attendu': montantAttendu,
        'manquant': manquantApp,
        'estAJour': estAJour,
        'taux': montantAttendu > 0 ? totalApp / montantAttendu * 100 : 0.0,
      });
    }
    
    _classementRetard.sort((a, b) => b['manquant'].compareTo(a['manquant']));
  }

  void _toggleAnnee(int annee) {
    setState(() {
      if (_anneesSelectionnees.contains(annee)) {
        _anneesSelectionnees.remove(annee);
      } else {
        _anneesSelectionnees.add(annee);
        _anneesSelectionnees.sort();
      }
    });
    _calculerStatistiques();
  }

  void _togglePeriode(String periode) {
    setState(() {
      if (_periodesSelectionnees.contains(periode)) {
        _periodesSelectionnees.remove(periode);
      } else {
        _periodesSelectionnees.add(periode);
      }
    });
    _calculerStatistiques();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '📊 Statistiques Cotisations',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilters(),
                _buildSummary(),
                Expanded(
                  child: _buildTable(),
                ),
              ],
            ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '📅 Années:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _anneesDisponibles.map((annee) {
                      final isSelected = _anneesSelectionnees.contains(annee);
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: FilterChip(
                          label: Text(
                            annee.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) => _toggleAnnee(annee),
                          selectedColor: Colors.blue.shade700,
                          backgroundColor: Colors.grey.shade200,
                          checkmarkColor: Colors.white,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                '📆 Périodes:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              _buildPeriodeChip('S1', '📗'),
              const SizedBox(width: 4),
              _buildPeriodeChip('S2', '📘'),
              const Spacer(),
              Text(
                '${_appartements.length} appartements',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodeChip(String periode, String emoji) {
    final isSelected = _periodesSelectionnees.contains(periode);
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          Text(
            periode,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => _togglePeriode(periode),
      selectedColor: Colors.blue.shade700,
      backgroundColor: Colors.grey.shade200,
      checkmarkColor: Colors.white,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildSummary() {
    final tauxAJour = _nbAppartementsTotal > 0
        ? (_nbAppartementsAJour / _nbAppartementsTotal * 100).toStringAsFixed(1)
        : '0.0';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              '💰 Total payé',
              NumberFormat('#,##0.00', 'fr_MA').format(_totalPaye),
              Colors.green,
              Icons.payments,
            ),
          ),
          Expanded(
            child: _buildSummaryItem(
              '📊 Taux',
              '$tauxAJour%',
              Colors.blue,
              Icons.trending_up,
            ),
          ),
          Expanded(
            child: _buildSummaryItem(
              '✅ À jour',
              '$_nbAppartementsAJour/${_nbAppartementsTotal}',
              Colors.green,
              Icons.check_circle,
            ),
          ),
          Expanded(
            child: _buildSummaryItem(
              '⚠️ Manquant',
              NumberFormat('#,##0.00', 'fr_MA').format(_totalManquant),
              Colors.red,
              Icons.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    if (_classementRetard.isEmpty) {
      return const Center(
        child: Text('Aucune donnée disponible'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Table(
            border: TableBorder.all(
              color: Colors.grey.shade300,
              width: 0.5,
            ),
            columnWidths: {
              0: const FixedColumnWidth(70),
              1: const FixedColumnWidth(80),
              2: const FixedColumnWidth(80),
              3: const FixedColumnWidth(80),
              4: const FixedColumnWidth(80),
              5: const FixedColumnWidth(80),
            },
            children: [
              _buildTableHeader(),
              ..._classementRetard.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                return _buildTableRow(data, index);
              }),
              _buildTotalRow(),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _buildTableHeader() {
    return TableRow(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade700, Colors.blue.shade900],
        ),
      ),
      children: [
        _buildHeaderCell('📊 Rang'),
        _buildHeaderCell('Appartement'),
        _buildHeaderCell('Payé'),
        _buildHeaderCell('Attendu'),
        _buildHeaderCell('Manquant'),
        _buildHeaderCell('Statut'),
      ],
    );
  }

  Widget _buildHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  TableRow _buildTableRow(Map<String, dynamic> data, int index) {
    final estAJour = data['estAJour'] as bool;
    final manquant = data['manquant'] as double;
    final total = data['total'] as double;
    final attendu = data['attendu'] as double;
    
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
    
    String statut;
    Color statutColor;
    if (estAJour) {
      statut = '✅ À jour';
      statutColor = Colors.green;
    } else if (manquant > 1800) {
      statut = '🔴 Très en retard';
      statutColor = Colors.red;
    } else if (manquant > 900) {
      statut = '🟠 En retard';
      statutColor = Colors.orange;
    } else if (manquant > 0) {
      statut = '🟡 Partiel';
      statutColor = Colors.amber;
    } else {
      statut = '⚪ Non cotisé';
      statutColor = Colors.grey;
    }

    return TableRow(
      decoration: BoxDecoration(
        color: bgColor,
      ),
      children: [
        _buildCell(
          '${index + 1}',
          isBold: true,
        ),
        _buildCell(data['appartement'] ?? 'N/A'),
        _buildCell(
          NumberFormat('#,##0.00', 'fr_MA').format(total),
          color: Colors.green.shade700,
        ),
        _buildCell(
          NumberFormat('#,##0.00', 'fr_MA').format(attendu),
          color: Colors.blue.shade700,
        ),
        _buildCell(
          NumberFormat('#,##0.00', 'fr_MA').format(manquant),
          color: manquant > 0 ? Colors.red.shade700 : Colors.green.shade700,
        ),
        _buildCell(
          statut,
          color: statutColor,
          isBold: true,
        ),
      ],
    );
  }

  TableRow _buildTotalRow() {
    return TableRow(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade200, Colors.grey.shade300],
        ),
      ),
      children: [
        _buildCell('', fontSize: 10),
        _buildCell(
          'TOTAL',
          isBold: true,
          fontSize: 12,
        ),
        _buildCell(
          NumberFormat('#,##0.00', 'fr_MA').format(_totalPaye),
          isBold: true,
          color: Colors.green.shade700,
        ),
        _buildCell(
          NumberFormat('#,##0.00', 'fr_MA').format(_totalPaye + _totalManquant),
          isBold: true,
          color: Colors.blue.shade700,
        ),
        _buildCell(
          NumberFormat('#,##0.00', 'fr_MA').format(_totalManquant),
          isBold: true,
          color: Colors.red.shade700,
        ),
        _buildCell(
          '${_nbAppartementsAJour}/${_nbAppartementsTotal} à jour',
          isBold: true,
          fontSize: 11,
        ),
      ],
    );
  }

  // ✅ CORRECTION : La fonction _buildCell avec 'isBold' au lieu de 'fontWeight'
  Widget _buildCell(
    String text, {
    Color? color,
    bool isBold = false,
    double fontSize = 11,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? Colors.black87,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: fontSize,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}