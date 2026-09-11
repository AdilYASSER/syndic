// lib/screens/cotisations_table_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:universal_html/html.dart' as html;
import '../models/cotisation.dart';
import '../services/cotisation_service.dart';

class CotisationsTableScreen extends StatefulWidget {
  final String? role;
  final String? appartement;

  const CotisationsTableScreen({
    super.key,
    this.role,
    this.appartement,
  });

  @override
  State<CotisationsTableScreen> createState() => _CotisationsTableScreenState();
}

class _CotisationsTableScreenState extends State<CotisationsTableScreen> {
  final CotisationService _cotisationService = CotisationService();
  List<Cotisation> _cotisations = [];
  List<Cotisation> _allPeriodsCotisations = [];
  Map<String, Map<int, Map<String, double>>> _tableData = {};
  List<String> _appartements = [];
  List<int> _annees = [];
  bool _isLoading = true;
  String _selectedAnnee = 'Toutes';
  
  Map<String, bool> _selectedPeriodes = {};
  List<String> _activePeriodes = [];
  
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  
  static const double MONTANT_ATTENDU = 1800.0;

  double _totalGeneral = 0.0;
  double _totalManqueGeneral = 0.0;
  Map<int, Map<String, double>> _totauxParAnnee = {};
  
  int _nbAppartementsTotal = 0;
  
  bool _isAdmin = false;

  // ✅ SEULES LES COTISATIONS AVEC STATUT "Payé" SONT PRISES EN COMPTE
  static const List<String> _includedStatuts = ['Payé'];

  @override
  void initState() {
    super.initState();
    _isAdmin = widget.role == 'admin';
    print('🔍 Rôle reçu: ${widget.role}, isAdmin: $_isAdmin');
    _loadCotisations();
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCotisations() async {
    setState(() => _isLoading = true);
    try {
      _cotisations = await _cotisationService.getCotisationsFromFirestore();
      
      // ✅ Filtrer pour ne garder que les cotisations "Payé"
      final paidCotisations = _cotisations.where((c) => 
        _includedStatuts.contains(c.statut)
      ).toList();
      
      print('📊 ${_cotisations.length} cotisations totales');
      print('📊 ${paidCotisations.length} cotisations avec statut "Payé"');
      
      // ✅ Utiliser uniquement les cotisations payées
      _cotisations = paidCotisations;
      
      _generateMissingPeriods();
      _updateAvailablePeriodes();
      _buildTableData();
      
      print('✅ ${_appartements.length} appartements UNIQUES');
    } catch (e) {
      print('❌ Erreur chargement cotisations: $e');
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

  // ✅ EXPORT EXCEL - UNIQUEMENT ADMIN
  Future<void> _exportExcel() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut exporter'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      var excel = excel_lib.Excel.createExcel();
      excel_lib.Sheet sheet = excel['Tableau Cotisations'];

      List<String> headers = ['Appartement'];
      for (var annee in _annees) {
        if (_isPeriodActive(annee, true)) headers.add('$annee S1');
        if (_isPeriodActive(annee, false)) headers.add('$annee S2');
      }
      headers.addAll(['Manquant', 'Total']);
      
      List<excel_lib.CellValue> headerRow = headers.map((h) => excel_lib.TextCellValue(h)).toList();
      sheet.appendRow(headerRow);

      for (var appartement in _appartements) {
        List<excel_lib.CellValue> row = [
          excel_lib.TextCellValue(appartement),
        ];
        
        for (var annee in _annees) {
          if (_isPeriodActive(annee, true)) {
            double val = _getS1ForAppartementAnnee(appartement, annee);
            row.add(excel_lib.TextCellValue(val.toString()));
          }
          if (_isPeriodActive(annee, false)) {
            double val = _getS2ForAppartementAnnee(appartement, annee);
            row.add(excel_lib.TextCellValue(val.toString()));
          }
        }
        
        double manque = _getTotalManqueForAppartement(appartement);
        double total = _getTotalForAppartement(appartement);
        row.add(excel_lib.TextCellValue(manque.toString()));
        row.add(excel_lib.TextCellValue(total.toString()));
        
        sheet.appendRow(row);
      }

      String filename = 'tableau_cotisations_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      List<int>? excelBytes = excel.save();

      if (excelBytes == null) {
        throw Exception('Erreur lors de la création du fichier Excel');
      }

      if (kIsWeb) {
        final blob = html.Blob([excelBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..target = '_blank'
          ..download = filename;
        anchor.click();
        html.Url.revokeObjectUrl(url);
      } else {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/$filename';
        final file = File(filePath);
        await file.writeAsBytes(excelBytes);
        await Share.shareXFiles([XFile(filePath)]);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Excel exporté: $filename'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur export: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ✅ EXPORT CSV - UNIQUEMENT ADMIN
  Future<void> _exportCSV() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut exporter'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      List<List<dynamic>> rows = [];

      List<dynamic> headers = ['Appartement'];
      for (var annee in _annees) {
        if (_isPeriodActive(annee, true)) headers.add('$annee S1');
        if (_isPeriodActive(annee, false)) headers.add('$annee S2');
      }
      headers.addAll(['Manquant', 'Total']);
      rows.add(headers);

      for (var appartement in _appartements) {
        List<dynamic> row = [appartement];
        
        for (var annee in _annees) {
          if (_isPeriodActive(annee, true)) {
            double val = _getS1ForAppartementAnnee(appartement, annee);
            row.add(val.toString());
          }
          if (_isPeriodActive(annee, false)) {
            double val = _getS2ForAppartementAnnee(appartement, annee);
            row.add(val.toString());
          }
        }
        
        double manque = _getTotalManqueForAppartement(appartement);
        double total = _getTotalForAppartement(appartement);
        row.add(manque.toString());
        row.add(total.toString());
        
        rows.add(row);
      }

      String csv = const ListToCsvConverter().convert(rows);
      String filename = 'tableau_cotisations_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';

      if (kIsWeb) {
        final blob = html.Blob([csv]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..target = '_blank'
          ..download = filename;
        anchor.click();
        html.Url.revokeObjectUrl(url);
      } else {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/$filename';
        final file = File(filePath);
        await file.writeAsString(csv);
        await Share.shareXFiles([XFile(filePath)]);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ CSV exporté: $filename'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur export: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showExportDialog() {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut exporter'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download, color: Colors.green),
            SizedBox(width: 8),
            Text('📤 Exporter le tableau'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue),
              title: const Text('Exporter en CSV'),
              subtitle: const Text('Format compatible avec Excel'),
              onTap: () {
                Navigator.pop(context);
                _exportCSV();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Exporter en Excel'),
              subtitle: const Text('Format Excel avec résumé'),
              onTap: () {
                Navigator.pop(context);
                _exportExcel();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  // ✅ GENERATE MISSING PERIODS - UNIQUEMENT POUR LES COTISATIONS PAYÉES
  void _generateMissingPeriods() {
    _allPeriodsCotisations = List.from(_cotisations);
    
    Set<int> years = {};
    for (var c in _cotisations) {
      years.add(c.annee);
    }
    
    // Si aucune année, ajouter les années par défaut
    if (years.isEmpty) {
      years.add(2025);
      years.add(2026);
      years.add(2027);
    }
    
    Set<String> appartementsSet = {};
    for (var c in _cotisations) {
      if (c.numAppartement.isNotEmpty) {
        String cleanedApp = c.numAppartement.trim().toUpperCase();
        appartementsSet.add(cleanedApp);
      }
    }
    
    List<String> appartementsUniques = appartementsSet.toList()..sort();
    
    for (var app in appartementsUniques) {
      for (var year in years) {
        bool hasS1 = _cotisations.any((c) => 
          c.numAppartement.trim().toUpperCase() == app && 
          c.annee == year && 
          c.periode1
        );
        if (!hasS1) {
          _allPeriodsCotisations.add(Cotisation(
            numAppartement: app,
            nomPrenom: app,
            dateVersement: DateTime(year, 6, 30),
            modeVersement: 'espece',
            montant: 0,
            periode1: true,
            periode2: false,
            annee: year,
            synced: 1,
            statut: 'Non cotisé', // ✅ Ajout du statut
          ));
        }
        
        bool hasS2 = _cotisations.any((c) => 
          c.numAppartement.trim().toUpperCase() == app && 
          c.annee == year && 
          c.periode2
        );
        if (!hasS2) {
          _allPeriodsCotisations.add(Cotisation(
            numAppartement: app,
            nomPrenom: app,
            dateVersement: DateTime(year, 12, 31),
            modeVersement: 'espece',
            montant: 0,
            periode1: false,
            periode2: true,
            annee: year,
            synced: 1,
            statut: 'Non cotisé', // ✅ Ajout du statut
          ));
        }
      }
    }
  }

  void _updateAvailablePeriodes() {
    Set<String> periodes = {};
    Set<int> years = {};
    
    for (var c in _allPeriodsCotisations) {
      years.add(c.annee);
    }
    
    if (years.isEmpty) {
      years.add(2025);
      years.add(2026);
      years.add(2027);
    }
    
    for (var year in years) {
      periodes.add('${year}_S1');
      periodes.add('${year}_S2');
    }
    
    List<String> sortedPeriodes = periodes.toList()..sort((a, b) {
      int anneeA = int.tryParse(a.split('_')[0]) ?? 0;
      int anneeB = int.tryParse(b.split('_')[0]) ?? 0;
      return anneeA.compareTo(anneeB);
    });
    
    Map<String, bool> newPeriodes = {};
    for (var periode in sortedPeriodes) {
      newPeriodes[periode] = _selectedPeriodes[periode] ?? true;
    }
    
    setState(() {
      _selectedPeriodes = newPeriodes;
    });
  }

  void _updateActivePeriodes() {
    _activePeriodes = [];
    var keys = _selectedPeriodes.keys.toList()..sort();
    for (var key in keys) {
      if (_selectedPeriodes[key] == true) {
        _activePeriodes.add(key);
      }
    }
  }

  // ✅ BUILD TABLE DATA - FILTRE SUR LE STATUT "Payé"
  void _buildTableData() {
    if (!mounted) return;
    
    _tableData = {};
    _appartements = [];
    _annees = [];
    _nbAppartementsTotal = 0;
    
    _updateActivePeriodes();
    
    // ✅ Filtrer: ne garder que les cotisations PAYÉES
    var filtered = _allPeriodsCotisations.where((c) {
      // ✅ Exclure "Non cotisé"
      if (c.statut == 'Non cotisé') return false;
      
      // ✅ Vérifier que le statut est "Payé"
      if (!_includedStatuts.contains(c.statut)) return false;
      
      String key;
      if (c.periode1) {
        key = '${c.annee}_S1';
      } else if (c.periode2) {
        key = '${c.annee}_S2';
      } else {
        return false;
      }
      return _selectedPeriodes[key] ?? false;
    }).toList();

    if (_selectedAnnee != 'Toutes') {
      final annee = int.tryParse(_selectedAnnee);
      if (annee != null) {
        filtered = filtered.where((c) => c.annee == annee).toList();
      }
    }

    Set<int> activeYears = {};
    for (var key in _activePeriodes) {
      String yearStr = key.split('_')[0];
      int year = int.tryParse(yearStr) ?? 0;
      if (year > 0) activeYears.add(year);
    }
    _annees = activeYears.toList()..sort();

    // ✅ Récupérer tous les appartements (même sans cotisation payée)
    Set<String> appartementsSet = {};
    for (var c in _allPeriodsCotisations) {
      if (c.numAppartement.isNotEmpty) {
        String cleaned = c.numAppartement.trim().toUpperCase();
        appartementsSet.add(cleaned);
      }
    }
    _appartements = appartementsSet.toList()..sort();
    _nbAppartementsTotal = _appartements.length;

    for (var app in _appartements) {
      _tableData[app] = {};
      for (var annee in _annees) {
        _tableData[app]![annee] = {'s1': 0.0, 's2': 0.0};
      }
    }

    // ✅ Remplir avec les cotisations PAYÉES uniquement
    for (var c in filtered) {
      final app = c.numAppartement.trim().toUpperCase();
      if (_tableData.containsKey(app)) {
        if (c.periode1) {
          _tableData[app]![c.annee]!['s1'] = 
              (_tableData[app]![c.annee]!['s1'] ?? 0.0) + c.montant;
        }
        if (c.periode2) {
          _tableData[app]![c.annee]!['s2'] = 
              (_tableData[app]![c.annee]!['s2'] ?? 0.0) + c.montant;
        }
      }
    }

    _calculerTotaux();
  }

  void _calculerTotaux() {
    _totauxParAnnee = {};
    _totalGeneral = 0.0;
    _totalManqueGeneral = 0.0;

    for (var annee in _annees) {
      _totauxParAnnee[annee] = {'s1': 0.0, 's2': 0.0, 'manque_s1': 0.0, 'manque_s2': 0.0};
      
      if (_isPeriodActive(annee, true)) {
        double totalS1 = 0.0;
        double totalManqueS1 = 0.0;
        for (var appartement in _appartements) {
          double val = _getS1ForAppartementAnnee(appartement, annee);
          totalS1 += val;
          double manque = _getManqueForPeriode(appartement, annee, 's1');
          totalManqueS1 += manque;
        }
        _totauxParAnnee[annee]!['s1'] = totalS1;
        _totauxParAnnee[annee]!['manque_s1'] = totalManqueS1;
        _totalGeneral += totalS1;
        _totalManqueGeneral += totalManqueS1;
      }
      
      if (_isPeriodActive(annee, false)) {
        double totalS2 = 0.0;
        double totalManqueS2 = 0.0;
        for (var appartement in _appartements) {
          double val = _getS2ForAppartementAnnee(appartement, annee);
          totalS2 += val;
          double manque = _getManqueForPeriode(appartement, annee, 's2');
          totalManqueS2 += manque;
        }
        _totauxParAnnee[annee]!['s2'] = totalS2;
        _totauxParAnnee[annee]!['manque_s2'] = totalManqueS2;
        _totalGeneral += totalS2;
        _totalManqueGeneral += totalManqueS2;
      }
    }
  }

  bool _isPeriodActive(int year, bool isS1) {
    String key = '${year}_${isS1 ? 'S1' : 'S2'}';
    return _selectedPeriodes[key] ?? false;
  }

  double _getS1ForAppartementAnnee(String appartement, int annee) {
    double value = _tableData[appartement]?[annee]?['s1'] ?? 0.0;
    return value < 0 ? 0 : value;
  }

  double _getS2ForAppartementAnnee(String appartement, int annee) {
    double value = _tableData[appartement]?[annee]?['s2'] ?? 0.0;
    return value < 0 ? 0 : value;
  }

  double _getManqueForPeriode(String appartement, int annee, String periode) {
    double montant = periode == 's1' 
        ? _getS1ForAppartementAnnee(appartement, annee)
        : _getS2ForAppartementAnnee(appartement, annee);
    
    if (montant == 0) return MONTANT_ATTENDU;
    if (montant >= MONTANT_ATTENDU) return 0;
    return MONTANT_ATTENDU - montant;
  }

  double _getTotalManqueForAppartement(String appartement) {
    double total = 0.0;
    final data = _tableData[appartement];
    if (data != null) {
      for (var annee in data.keys) {
        if (_isPeriodActive(annee, true)) {
          total += _getManqueForPeriode(appartement, annee, 's1');
        }
        if (_isPeriodActive(annee, false)) {
          total += _getManqueForPeriode(appartement, annee, 's2');
        }
      }
    }
    return total;
  }

  double _getTotalForAppartement(String appartement) {
    double total = 0.0;
    final data = _tableData[appartement];
    if (data != null) {
      for (var annee in data.keys) {
        if (_isPeriodActive(annee, true)) {
          double s1 = data[annee]?['s1'] ?? 0.0;
          if (s1 < 0) s1 = 0;
          total += s1;
        }
        if (_isPeriodActive(annee, false)) {
          double s2 = data[annee]?['s2'] ?? 0.0;
          if (s2 < 0) s2 = 0;
          total += s2;
        }
      }
    }
    return total;
  }

  List<int> get _anneesDisponibles {
    final List<int> annees = _allPeriodsCotisations.map((c) => c.annee).toSet().toList();
    annees.sort((a, b) => b.compareTo(a));
    return annees;
  }

  Widget _buildPeriodFilterCompact({
    required String key,
    required String label,
    required Color color,
    required bool hasData,
  }) {
    final isChecked = _selectedPeriodes[key] ?? true;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriodes[key] = !isChecked;
        });
        _buildTableData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: isChecked ? color.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isChecked ? color : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isChecked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 14,
              color: isChecked ? color : Colors.grey.shade400,
            ),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: isChecked ? color : Colors.grey.shade500,
                fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (!hasData)
              Text(
                ' (0)',
                style: TextStyle(
                  fontSize: 7,
                  color: Colors.grey.shade400,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getColorForYear(int year, bool isS1) {
    List<Color> colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
      Colors.deepOrange,
      Colors.lime,
      Colors.deepPurple,
      Colors.brown,
      Colors.red,
    ];
    int index = (year - 2020) * 2 + (isS1 ? 0 : 1);
    return colors[index % colors.length];
  }

  Widget _buildPeriodFiltersHorizontal() {
    if (_selectedPeriodes.isEmpty) {
      return const SizedBox.shrink();
    }
    
    List<String> sortedKeys = _selectedPeriodes.keys.toList()..sort();
    List<Widget> filters = [];
    
    for (var key in sortedKeys) {
      String yearStr = key.split('_')[0];
      String periode = key.split('_')[1];
      int year = int.tryParse(yearStr) ?? 2025;
      bool isS1 = periode == 'S1';
      
      bool hasData = _cotisations.any((c) => 
        c.annee == year && 
        ((isS1 && c.periode1) || (!isS1 && c.periode2)) &&
        _includedStatuts.contains(c.statut)
      );
      
      filters.add(
        _buildPeriodFilterCompact(
          key: key,
          label: '$year ${isS1 ? 'S1' : 'S2'}',
          color: _getColorForYear(year, isS1),
          hasData: hasData,
        ),
      );
    }
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: filters,
      ),
    );
  }

  // ✅ BUILD FILTERS BAR
  Widget _buildFiltersBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Année',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedAnnee,
                            isExpanded: true,
                            underline: const SizedBox(),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.green,
                              size: 28,
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'Toutes',
                                child: Text(
                                  '📅 Toutes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              ..._anneesDisponibles.map((annee) {
                                return DropdownMenuItem(
                                  value: annee.toString(),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_month,
                                        size: 16,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        annee.toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedAnnee = value ?? 'Toutes';
                                _buildTableData();
                              });
                            },
                          ),
                        ),
                      ),
                      if (_anneesDisponibles.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade700,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_anneesDisponibles.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (_isAdmin)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          child: ElevatedButton.icon(
                            onPressed: _showExportDialog,
                            icon: const Icon(Icons.download, size: 16, color: Colors.white),
                            label: const Text(
                              'Exporter',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: const Size(80, 30),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Périodes:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildPeriodFiltersHorizontal(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // ✅ Information sur les statuts inclus
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
                const SizedBox(width: 4),
                Text(
                  '📌 Seules les cotisations avec statut "Payé" sont affichées',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              _buildLegend('✅ Complet', Colors.green.shade100, Colors.green.shade800),
              _buildLegend('⚠️ Manquant', Colors.orange.shade100, Colors.orange.shade800),
              _buildLegend('🔺 Non cotisé', Colors.grey.shade200, Colors.red.shade700),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade800,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '💰 Total général',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${_totalGeneral.toStringAsFixed(0)} DH',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.table_chart, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Aucune donnée disponible',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _loadCotisations,
            icon: const Icon(Icons.refresh),
            label: const Text('Recharger'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableWithFixedHeaderAndTotal() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cellWidth = screenWidth > 600 ? 70 : 50;
    final bool isSmallScreen = screenWidth < 600;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.green.shade700,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          child: _buildTableHeader(cellWidth, isSmallScreen),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.green.shade600,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          child: _buildTotalRow(cellWidth, isSmallScreen),
        ),
        Expanded(
          child: Scrollbar(
            controller: _verticalScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            thickness: 10.0,
            radius: const Radius.circular(8),
            child: SingleChildScrollView(
              controller: _verticalScrollController,
              scrollDirection: Axis.vertical,
              child: _buildTableBody(cellWidth, isSmallScreen),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(double cellWidth, bool isSmallScreen) {
    List<Widget> headerCells = [];

    headerCells.add(
      SizedBox(
        width: isSmallScreen ? 55 : 70,
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Text(
            'Appartement',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );

    for (var annee in _annees) {
      bool hasS1 = _isPeriodActive(annee, true);
      bool hasS2 = _isPeriodActive(annee, false);
      
      if (!hasS1 && !hasS2) continue;
      
      int nbPeriodes = (hasS1 ? 1 : 0) + (hasS2 ? 1 : 0);
      double colWidth = cellWidth * nbPeriodes + (nbPeriodes > 1 ? 10 : 5);
      
      headerCells.add(
        SizedBox(
          width: colWidth,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$annee',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (hasS1)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'S1',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                    if (hasS1 && hasS2) const SizedBox(width: 3),
                    if (hasS2)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'S2',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
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

    headerCells.add(
      SizedBox(
        width: isSmallScreen ? 50 : 65,
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Text(
            'Manquant',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 9,
            ),
          ),
        ),
      ),
    );

    headerCells.add(
      SizedBox(
        width: isSmallScreen ? 45 : 60,
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Text(
            'Total',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: headerCells,
      ),
    );
  }

  Widget _buildTotalRow(double cellWidth, bool isSmallScreen) {
    List<Widget> cells = [];

    cells.add(
      SizedBox(
        width: isSmallScreen ? 55 : 70,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.white, width: 0.5),
            ),
          ),
          child: const Text(
            'TOTAL',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 10,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );

    for (var annee in _annees) {
      bool hasS1 = _isPeriodActive(annee, true);
      bool hasS2 = _isPeriodActive(annee, false);
      
      if (!hasS1 && !hasS2) continue;
      
      double totalS1 = _totauxParAnnee[annee]?['s1'] ?? 0;
      double totalS2 = _totauxParAnnee[annee]?['s2'] ?? 0;

      cells.add(
        SizedBox(
          width: cellWidth * ((hasS1 ? 1 : 0) + (hasS2 ? 1 : 0)) + ((hasS1 && hasS2) ? 10 : 5),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.white, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasS1)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        totalS1 > 0 ? totalS1.toStringAsFixed(0) : '-',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                if (hasS1 && hasS2) const SizedBox(width: 3),
                if (hasS2)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        totalS2 > 0 ? totalS2.toStringAsFixed(0) : '-',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    double totalManqueGeneral = 0.0;
    for (var annee in _annees) {
      totalManqueGeneral += _totauxParAnnee[annee]?['manque_s1'] ?? 0;
      totalManqueGeneral += _totauxParAnnee[annee]?['manque_s2'] ?? 0;
    }

    cells.add(
      SizedBox(
        width: isSmallScreen ? 50 : 65,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.white, width: 0.5),
            ),
          ),
          child: Text(
            totalManqueGeneral > 0 ? totalManqueGeneral.toStringAsFixed(0) : '-',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 9,
            ),
          ),
        ),
      ),
    );

    cells.add(
      SizedBox(
        width: isSmallScreen ? 45 : 60,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Text(
            '${_totalGeneral.toStringAsFixed(0)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: cells,
      ),
    );
  }

  Widget _buildTableBody(double cellWidth, bool isSmallScreen) {
    List<Widget> rows = [];

    for (var appartement in _appartements) {
      rows.add(_buildAppartementRow(appartement, cellWidth, isSmallScreen));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        children: rows,
      ),
    );
  }

  Widget _buildAppartementRow(String appartement, double cellWidth, bool isSmallScreen) {
    List<Widget> cells = [];

    cells.add(
      SizedBox(
        width: isSmallScreen ? 55 : 70,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey, width: 0.5),
              right: BorderSide(color: Colors.grey, width: 0.5),
            ),
          ),
          child: Text(
            appartement,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );

    for (var annee in _annees) {
      bool hasS1 = _isPeriodActive(annee, true);
      bool hasS2 = _isPeriodActive(annee, false);
      
      if (!hasS1 && !hasS2) continue;
      
      double s1 = hasS1 ? _getS1ForAppartementAnnee(appartement, annee) : 0;
      double s2 = hasS2 ? _getS2ForAppartementAnnee(appartement, annee) : 0;

      cells.add(
        SizedBox(
          width: cellWidth * ((hasS1 ? 1 : 0) + (hasS2 ? 1 : 0)) + ((hasS1 && hasS2) ? 10 : 5),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey, width: 0.5),
                right: BorderSide(color: Colors.grey, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasS1)
                  Expanded(
                    child: _buildPeriodeCell(
                      montant: s1,
                      isSmallScreen: isSmallScreen,
                    ),
                  ),
                if (hasS1 && hasS2) const SizedBox(width: 3),
                if (hasS2)
                  Expanded(
                    child: _buildPeriodeCell(
                      montant: s2,
                      isSmallScreen: isSmallScreen,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final totalManqueAppartement = _getTotalManqueForAppartement(appartement);
    cells.add(
      SizedBox(
        width: isSmallScreen ? 50 : 65,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey, width: 0.5),
              right: BorderSide(color: Colors.grey, width: 0.5),
            ),
          ),
          child: Text(
            totalManqueAppartement > 0 ? totalManqueAppartement.toStringAsFixed(0) : '-',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: totalManqueAppartement > 0 ? Colors.red.shade700 : Colors.grey,
              fontSize: isSmallScreen ? 8 : 10,
            ),
          ),
        ),
      ),
    );

    final totalAppartement = _getTotalForAppartement(appartement);
    cells.add(
      SizedBox(
        width: isSmallScreen ? 45 : 60,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey, width: 0.5),
            ),
          ),
          child: Text(
            totalAppartement > 0 ? '${totalAppartement.toStringAsFixed(0)}' : '-',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: totalAppartement > 0 ? Colors.green.shade800 : Colors.grey,
              fontSize: isSmallScreen ? 8 : 10,
            ),
          ),
        ),
      ),
    );

    return Row(
      children: cells,
    );
  }

  Widget _buildLegend(String label, Color bgColor, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: textColor.withOpacity(0.5)),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: textColor),
        ),
      ],
    );
  }

  Widget _buildPeriodeCell({
    required double montant,
    required bool isSmallScreen,
  }) {
    final double montantReel = montant < 0 ? 0 : montant;
    
    if (montantReel == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              painter: TrianglePainter(color: Colors.red.shade700),
              size: Size(isSmallScreen ? 16 : 22, isSmallScreen ? 12 : 16),
            ),
            const SizedBox(height: 1),
            Text(
              '0',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
                fontSize: isSmallScreen ? 7 : 9,
              ),
            ),
          ],
        ),
      );
    } else if (montantReel >= MONTANT_ATTENDU) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          montantReel.toStringAsFixed(0),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
            fontSize: isSmallScreen ? 8 : 10,
          ),
        ),
      );
    } else {
      final manque = MONTANT_ATTENDU - montantReel;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              montantReel.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
                fontSize: isSmallScreen ? 8 : 10,
              ),
            ),
            Text(
              '⚠️ -${manque.toStringAsFixed(0)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 6,
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isAdmin ? '📊 Tableau des cotisations' : '📊 Mes cotisations',
        ),
        backgroundColor: _isAdmin ? Colors.green.shade800 : Colors.green.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade300, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.apartment,
                  size: 16,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_nbAppartementsTotal} App.',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCotisations,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltersBar(),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _appartements.isEmpty || _annees.isEmpty
                    ? _buildEmptyState()
                    : _buildTableWithFixedHeaderAndTotal(),
          ),
        ],
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}