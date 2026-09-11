// lib/screens/rapport_financier_screen.dart
// ✅ CORRECTION: FILTRAGE DES COTISATIONS PAR STATUT "Payé"

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

class RapportFinancierScreen extends StatefulWidget {
  final String role;
  final String? appartement;

  const RapportFinancierScreen({
    super.key,
    required this.role,
    this.appartement,
  });

  @override
  State<RapportFinancierScreen> createState() => _RapportFinancierScreenState();
}

class _RapportFinancierScreenState extends State<RapportFinancierScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Variables pour l'admin
  DateTime? _dateDebut;
  DateTime? _dateFin;
  bool _isGenerating = false;
  Map<String, dynamic>? _rapportData;
  String? _errorMessage;
  List<Map<String, dynamic>> _journalEntries = [];
  List<Map<String, dynamic>> _depensesEnAttente = [];
  
  // Animation pour le clignotement
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  // Variables pour le client
  Map<String, dynamic>? _clientRapportData;
  bool _isLoadingClient = true;
  DateTime? _lastUpdate;
  List<Map<String, dynamic>> _clientJournalEntries = [];

  // Solde initial
  double _soldeInitial = 0.0;

  // Dates par défaut
  static final DateTime DEFAULT_DATE_DEBUT = DateTime(2026, 6, 30);
  static final DateTime DEFAULT_DATE_FIN = DateTime.now();
  static const double DEFAULT_SOLDE_INITIAL = 85295.26;

  // Formatteurs
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'fr_MA',
    symbol: 'DH',
    decimalDigits: 2,
  );

  // ✅ Vérifier si une cotisation est payée
  bool _isCotisationPayee(Map<String, dynamic> data) {
    final String? statut = data['statut'] as String?;
    if (statut == null) return false;
    final String s = statut.toLowerCase().trim();
    return s == 'payé' || 
           s == 'paye' || 
           s == 'payee' ||
           s.contains('payé') || 
           s.contains('paye');
  }

  @override
  void initState() {
    super.initState();
    _dateDebut = DEFAULT_DATE_DEBUT;
    _dateFin = DateTime.now();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _initialize();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadSoldeInitial();
    
    if (widget.role == 'admin') {
      setState(() {
        _isLoadingClient = false;
      });
      _genererRapport();
    } else {
      await _loadClientRapport();
    }
  }

  Future<void> _loadSoldeInitial() async {
    try {
      final doc = await _firestore
          .collection('parametres')
          .doc('solde_initial')
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            _soldeInitial = (data['montant'] ?? DEFAULT_SOLDE_INITIAL).toDouble();
          });
        }
      } else {
        await _firestore.collection('parametres').doc('solde_initial').set({
          'montant': DEFAULT_SOLDE_INITIAL,
          'updatedAt': DateTime.now(),
          'updatedBy': 'system',
        });
        setState(() {
          _soldeInitial = DEFAULT_SOLDE_INITIAL;
        });
      }
    } catch (e) {
      setState(() {
        _soldeInitial = DEFAULT_SOLDE_INITIAL;
      });
    }
  }

  Future<void> _modifierSoldeInitial() async {
    if (widget.role != 'admin') return;

    final TextEditingController controller = TextEditingController(
      text: _soldeInitial.toStringAsFixed(2),
    );

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('💰 Modifier le Solde Initial'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Entrez le nouveau solde initial :',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Montant (DH)',
                prefixIcon: Icon(Icons.currency_exchange),
                border: OutlineInputBorder(),
                suffixText: 'DH',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nouveauSolde = double.tryParse(controller.text);
              if (nouveauSolde != null) {
                await _firestore.collection('parametres').doc('solde_initial').set({
                  'montant': nouveauSolde,
                  'updatedAt': DateTime.now(),
                  'updatedBy': 'admin',
                });
                setState(() {
                  _soldeInitial = nouveauSolde;
                });
                Navigator.pop(context, true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Solde initial mis à jour'),
                    backgroundColor: Colors.green,
                  ),
                );
                _genererRapport();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ Veuillez entrer un nombre valide'),
                    backgroundColor: Colors.red,
                  ),
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

  Future<void> _loadClientRapport() async {
    setState(() {
      _isLoadingClient = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _firestore
          .collection('rapports_financiers')
          .orderBy('generatedAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        
        final journalData = data['journalEntries'] as List<dynamic>? ?? [];
        List<Map<String, dynamic>> convertedEntries = [];
        
        for (var entry in journalData) {
          final Map<String, dynamic> entryMap = Map<String, dynamic>.from(entry);
          if (entryMap['date'] is Timestamp) {
            entryMap['date'] = (entryMap['date'] as Timestamp).toDate();
          }
          convertedEntries.add(entryMap);
        }
        
        setState(() {
          _clientRapportData = data;
          _clientJournalEntries = convertedEntries;
          _lastUpdate = (data['generatedAt'] as Timestamp?)?.toDate();
          _isLoadingClient = false;
        });
      } else {
        setState(() {
          _clientRapportData = null;
          _clientJournalEntries = [];
          _isLoadingClient = false;
          _errorMessage = 'Aucun rapport disponible pour le moment.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingClient = false;
        _errorMessage = 'Erreur de chargement: $e';
      });
    }
  }

  // ✅ EXPORTER EN CSV
  Future<void> _exporterCSV() async {
    try {
      if (_journalEntries.isEmpty && _clientJournalEntries.isEmpty) {
        _showSnackBar('❌ Aucune donnée à exporter', Colors.orange);
        return;
      }

      final entries = widget.role == 'admin' ? _journalEntries : _clientJournalEntries;
      final rapport = widget.role == 'admin' ? _rapportData : _clientRapportData;
      
      if (rapport == null) {
        _showSnackBar('❌ Aucun rapport disponible', Colors.orange);
        return;
      }

      if (!kIsWeb) {
        final hasPermission = await _requestPermissions();
        if (!hasPermission) {
          _showSnackBar('❌ Permission de stockage refusée', Colors.red);
          return;
        }
      }

      String csvContent = 'Date;Libellé;Débit;Crédit;Solde\n';
      
      double soldeCourant = _soldeInitial;
      
      csvContent += '${DateFormat('dd/MM/yyyy').format(_dateDebut!)};💰 Solde Initial;0;${_soldeInitial.toStringAsFixed(2)};${_soldeInitial.toStringAsFixed(2)}\n';
      
      for (var op in entries) {
        final date = op['date'] as DateTime;
        final libelle = (op['libelle'] as String).replaceAll(';', ',');
        final debit = op['debit'] ?? 0.0;
        final credit = op['credit'] ?? 0.0;
        final isEnAttente = op['type'] == 'depense_attente';
        
        if (!isEnAttente) {
          soldeCourant = soldeCourant + credit - debit;
        }
        
        csvContent += '${DateFormat('dd/MM/yyyy').format(date)};$libelle;${debit.toStringAsFixed(2)};${credit.toStringAsFixed(2)};${soldeCourant.toStringAsFixed(2)}\n';
      }

      if (kIsWeb) {
        _downloadFile(csvContent, 'csv');
      } else {
        await _saveFile(csvContent, 'csv');
      }
      
    } catch (e) {
      print('❌ Erreur export CSV: $e');
      _showSnackBar('❌ Erreur export: $e', Colors.red);
    }
  }

  // ✅ EXPORTER EN EXCEL
  Future<void> _exporterExcel() async {
    try {
      if (_journalEntries.isEmpty && _clientJournalEntries.isEmpty) {
        _showSnackBar('❌ Aucune donnée à exporter', Colors.orange);
        return;
      }

      final entries = widget.role == 'admin' ? _journalEntries : _clientJournalEntries;
      final rapport = widget.role == 'admin' ? _rapportData : _clientRapportData;
      
      if (rapport == null) {
        _showSnackBar('❌ Aucun rapport disponible', Colors.orange);
        return;
      }

      if (!kIsWeb) {
        final hasPermission = await _requestPermissions();
        if (!hasPermission) {
          _showSnackBar('❌ Permission de stockage refusée', Colors.red);
          return;
        }
      }

      String excelContent = '\uFEFF';
      excelContent += 'Date;Libellé;Débit;Crédit;Solde\n';
      
      double soldeCourant = _soldeInitial;
      
      excelContent += '${DateFormat('dd/MM/yyyy').format(_dateDebut!)};💰 Solde Initial;0;${_soldeInitial.toStringAsFixed(2)};${_soldeInitial.toStringAsFixed(2)}\n';
      
      for (var op in entries) {
        final date = op['date'] as DateTime;
        final libelle = (op['libelle'] as String).replaceAll(';', ',');
        final debit = op['debit'] ?? 0.0;
        final credit = op['credit'] ?? 0.0;
        final isEnAttente = op['type'] == 'depense_attente';
        
        if (!isEnAttente) {
          soldeCourant = soldeCourant + credit - debit;
        }
        
        excelContent += '${DateFormat('dd/MM/yyyy').format(date)};$libelle;${debit.toStringAsFixed(2)};${credit.toStringAsFixed(2)};${soldeCourant.toStringAsFixed(2)}\n';
      }

      final totalCredit = rapport['totalCredit'] ?? 0.0;
      final totalDebit = rapport['totalDebit'] ?? 0.0;
      final soldeFinal = rapport['soldeFinal'] ?? (totalCredit - totalDebit);
      
      excelContent += '\n\nRÉSUMÉ;\n';
      excelContent += 'Total Crédits;;;${totalCredit.toStringAsFixed(2)};\n';
      excelContent += 'Total Débits;;;${totalDebit.toStringAsFixed(2)};\n';
      excelContent += 'Solde Final;;;${soldeFinal.toStringAsFixed(2)};\n';

      if (kIsWeb) {
        _downloadFile(excelContent, 'csv');
      } else {
        await _saveFile(excelContent, 'csv');
      }
      
    } catch (e) {
      print('❌ Erreur export Excel: $e');
      _showSnackBar('❌ Erreur export: $e', Colors.red);
    }
  }

  // ✅ Télécharger un fichier (Web)
  void _downloadFile(String content, String extension) {
    try {
      final bytes = utf8.encode(content);
      final base64 = base64Encode(bytes);
      
      final anchor = html.AnchorElement(
        href: 'data:text/csv;charset=utf-8;base64,$base64'
      )
        ..target = '_blank'
        ..download = 'Journal_Comptable_${DateFormat('dd-MM-yyyy').format(DateTime.now())}.$extension'
        ..click();
      
      _showSnackBar('✅ Fichier téléchargé avec succès', Colors.green);
    } catch (e) {
      print('❌ Erreur téléchargement: $e');
      _showSnackBar('❌ Erreur: $e', Colors.red);
    }
  }

  // ✅ Sauvegarder un fichier (Mobile/Desktop)
  Future<void> _saveFile(String content, String extension) async {
    try {
      final fileName = 'Journal_Comptable_${DateFormat('dd-MM-yyyy').format(DateTime.now())}.$extension';
      
      String? filePath;
      
      if (Platform.isAndroid) {
        final status = await Permission.manageExternalStorage.request();
        if (status.isGranted) {
          final dir = await getExternalStorageDirectory();
          filePath = '${dir?.path}/$fileName';
        } else {
          final dir = await getApplicationDocumentsDirectory();
          filePath = '${dir.path}/$fileName';
        }
      } else if (Platform.isIOS) {
        final dir = await getApplicationDocumentsDirectory();
        filePath = '${dir.path}/$fileName';
      } else {
        final dir = await getDownloadsDirectory();
        filePath = '${dir?.path}/$fileName';
      }
      
      if (filePath == null) {
        throw Exception('Impossible d\'obtenir le chemin de sauvegarde');
      }
      
      final file = File(filePath);
      await file.writeAsString(content);
      
      _showSnackBar('✅ Fichier exporté: $fileName', Colors.green);
      
      try {
        await OpenFile.open(filePath);
      } catch (e) {
        print('⚠️ Impossible d\'ouvrir le fichier: $e');
      }
      
    } catch (e) {
      print('❌ Erreur sauvegarde: $e');
      
      final dir = await getTemporaryDirectory();
      final fileName = 'Journal_Comptable_${DateFormat('dd-MM-yyyy').format(DateTime.now())}.$extension';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(content);
      
      _showSnackBar('✅ Fichier sauvegardé dans le dossier temporaire', Colors.green);
    }
  }

  Future<bool> _requestPermissions() async {
    if (kIsWeb) return true;
    if (Platform.isWindows) return true;

    try {
      if (Platform.isAndroid) {
        if (await Permission.manageExternalStorage.isGranted) return true;
        final status = await Permission.manageExternalStorage.request();
        if (status.isGranted) return true;
        if (await Permission.storage.isGranted) return true;
        final storageStatus = await Permission.storage.request();
        return storageStatus.isGranted;
      }
      return true;
    } catch (e) {
      print('❌ Erreur permissions: $e');
      return true;
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download, color: Colors.green),
            SizedBox(width: 8),
            Text('📤 Exporter le journal'),
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
                _exporterCSV();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Exporter en Excel'),
              subtitle: const Text('Format Excel avec résumé'),
              onTap: () {
                Navigator.pop(context);
                _exporterExcel();
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

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ✅ GÉNÉRER LE RAPPORT - AVEC FILTRAGE DES COTISATIONS PAYÉES
  Future<void> _genererRapport() async {
    if (widget.role != 'admin') return;

    _dateDebut ??= DEFAULT_DATE_DEBUT;
    _dateFin ??= DateTime.now();

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _rapportData = null;
      _journalEntries = [];
      _depensesEnAttente = [];
    });

    try {
      // ✅ Récupérer TOUTES les cotisations
      final cotisationsSnapshot = await _firestore
          .collection('cotisations')
          .get();

      // ✅ Récupérer les dépenses
      final depensesSnapshot = await _firestore
          .collection('depenses')
          .where('date', isGreaterThanOrEqualTo: _dateDebut)
          .where('date', isLessThanOrEqualTo: _dateFin)
          .get();

      // ✅ FILTRER: Ne garder que les cotisations PAYÉES
      List<Map<String, dynamic>> cotisationsPayees = [];
      
      for (var doc in cotisationsSnapshot.docs) {
        final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        final Timestamp? dateVersementTimestamp = data['dateVersement'] as Timestamp?;
        final DateTime? dateVersement = dateVersementTimestamp?.toDate();
        
        // ✅ Vérifier que la cotisation a une date de versement dans la période
        if (dateVersement != null) {
          if (dateVersement.isAfter(_dateDebut!.subtract(const Duration(days: 1))) && 
              dateVersement.isBefore(_dateFin!.add(const Duration(days: 1)))) {
            
            // ✅ Vérifier que la cotisation a le statut "Payé"
            if (_isCotisationPayee(data)) {
              cotisationsPayees.add({
                ...data,
                'dateVersement': dateVersement,
              });
            }
          }
        }
      }

      print('📊 ${cotisationsSnapshot.docs.length} cotisations totales');
      print('✅ ${cotisationsPayees.length} cotisations PAYÉES');

      List<Map<String, dynamic>> journalEntries = [];

      // SOLDE INITIAL
      journalEntries.add({
        'date': _dateDebut!,
        'libelle': '💰 Solde Initial',
        'debit': 0.0,
        'credit': _soldeInitial,
        'type': 'solde_initial',
        'isSoldeInitial': true,
      });

      // ✅ COTISATIONS PAYÉES UNIQUEMENT
      for (var data in cotisationsPayees) {
        final DateTime dateVersement = data['dateVersement'] as DateTime;
        final double montant = (data['montant'] ?? 0).toDouble();
        final String numAppartement = (data['numAppartement'] ?? data['nomPrenom'] ?? 'N/A').toString();
        final String annee = (data['annee'] ?? '').toString();
        final bool periode1 = data['periode1'] ?? false;
        final bool periode2 = data['periode2'] ?? false;
        
        String periodeLibelle = '';
        if (periode1 && periode2) {
          periodeLibelle = ' (S1+S2 $annee)';
        } else if (periode1) {
          periodeLibelle = ' (S1 $annee)';
        } else if (periode2) {
          periodeLibelle = ' (S2 $annee)';
        } else {
          periodeLibelle = annee.isNotEmpty ? ' ($annee)' : '';
        }
        
        journalEntries.add({
          'date': dateVersement,
          'libelle': '📈 Cotisation - App $numAppartement$periodeLibelle',
          'debit': 0.0,
          'credit': montant,
          'type': 'cotisation',
          'appartement': numAppartement,
          'annee': annee,
        });
      }

      // Filtrer les dépenses par statut
      List<Map<String, dynamic>> depensesPayees = [];
      List<Map<String, dynamic>> depensesEnAttente = [];
      
      for (var doc in depensesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String statut = data['statut'] ?? 'en_attente';
        
        if (statut == 'paye' || statut == 'payé') {
          depensesPayees.add(data);
        } else if (statut == 'en_attente') {
          depensesEnAttente.add(data);
        }
      }

      // Trier les dépenses payées par date
      depensesPayees.sort((a, b) {
        final dateA = (a['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        final dateB = (b['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        return dateA.compareTo(dateB);
      });

      // DÉPENSES PAYÉES
      for (var data in depensesPayees) {
        final Timestamp? dateTimestamp = data['date'] as Timestamp?;
        final DateTime date = dateTimestamp?.toDate() ?? DateTime.now();
        final double montant = (data['montant'] ?? 0).toDouble();
        final String titre = (data['titre'] ?? data['description'] ?? 'Dépense').toString();
        final String categorie = (data['categorie'] ?? 'Non catégorisé').toString();
        
        String libelle = titre;
        if (libelle.length > 40) {
          libelle = libelle.substring(0, 38) + '...';
        }
        libelle = '📉 $libelle ($categorie)';
        
        journalEntries.add({
          'date': date,
          'libelle': libelle,
          'debit': montant,
          'credit': 0.0,
          'type': 'depense',
          'categorie': categorie,
          'statut': 'paye',
        });
      }

      // DÉPENSES EN ATTENTE (affichées mais non comptabilisées)
      for (var data in depensesEnAttente) {
        final Timestamp? dateTimestamp = data['date'] as Timestamp?;
        final DateTime date = dateTimestamp?.toDate() ?? DateTime.now();
        final double montant = (data['montant'] ?? 0).toDouble();
        final String titre = (data['titre'] ?? data['description'] ?? 'Dépense').toString();
        final String categorie = (data['categorie'] ?? 'Non catégorisé').toString();
        
        String libelle = titre;
        if (libelle.length > 35) {
          libelle = libelle.substring(0, 33) + '...';
        }
        
        journalEntries.add({
          'date': date,
          'libelle': '⏳ [EN ATTENTE] $libelle ($categorie)',
          'debit': 0.0,
          'credit': 0.0,
          'type': 'depense_attente',
          'categorie': categorie,
          'statut': 'en_attente',
          'montant_attente': montant,
          'montant_affichage': montant,
        });
      }

      journalEntries.sort((a, b) => a['date'].compareTo(b['date']));

      // Calcul des totaux (UNIQUEMENT les éléments non "en attente")
      double totalDebit = 0.0;
      double totalCredit = 0.0;
      
      for (var entry in journalEntries) {
        if (entry['type'] != 'depense_attente') {
          totalDebit += entry['debit'] ?? 0.0;
          totalCredit += entry['credit'] ?? 0.0;
        }
      }
      
      double soldeFinal = totalCredit - totalDebit;

      final rapport = {
        'periode': '${DateFormat('dd/MM/yy').format(_dateDebut!)} – ${DateFormat('dd/MM/yy').format(_dateFin!)}',
        'dateDebut': _dateDebut!,
        'dateFin': _dateFin!,
        'soldeInitial': _soldeInitial,
        'totalDebit': totalDebit,
        'totalCredit': totalCredit,
        'soldeFinal': soldeFinal,
        'journalEntries': journalEntries,
        'nombreDepensesPayees': depensesPayees.length,
        'nombreDepensesEnAttente': depensesEnAttente.length,
        'montantDepensesEnAttente': depensesEnAttente.fold(0.0, (sum, d) => sum + (d['montant'] ?? 0.0)),
        'generatedAt': DateTime.now(),
        'generatedBy': 'admin',
        'depensesEnAttente': depensesEnAttente,
        'nombreCotisationsPayees': cotisationsPayees.length,
        'totalCotisationsPayees': cotisationsPayees.fold(0.0, (sum, d) => sum + (d['montant'] ?? 0.0)),
      };

      await _firestore.collection('rapports_financiers').add(rapport);

      setState(() {
        _rapportData = rapport;
        _journalEntries = journalEntries;
        _depensesEnAttente = depensesEnAttente;
        _isGenerating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Rapport généré : ${cotisationsPayees.length} cotisations payées, ${depensesPayees.length} dépenses payées, ${depensesEnAttente.length} en attente'
          ),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print('❌ Erreur génération rapport: $e');
      setState(() {
        _isGenerating = false;
        _errorMessage = 'Erreur: $e';
      });
    }
  }

  void _resetToDefaultDates() {
    setState(() {
      _dateDebut = DEFAULT_DATE_DEBUT;
      _dateFin = DateTime.now();
    });
    _genererRapport();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = widget.role == 'admin';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('📊 Journal Comptable'),
        backgroundColor: isAdmin ? Colors.blue.shade800 : Colors.green.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        actions: [
          if (isAdmin && _journalEntries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              onPressed: _showExportDialog,
              tooltip: 'Exporter',
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _modifierSoldeInitial,
              tooltip: 'Modifier le solde initial',
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.restore),
              onPressed: _resetToDefaultDates,
              tooltip: 'Réinitialiser les dates',
            ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isAdmin ? Colors.orange.shade700 : Colors.green.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isAdmin ? '👑 Admin' : '👤 Client',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: isAdmin ? _buildAdminView() : _buildClientView(),
    );
  }

  Widget _buildAdminView() {
    final String periodeText = _dateDebut != null && _dateFin != null
        ? '${DateFormat('dd/MM/yy').format(_dateDebut!)} → ${DateFormat('dd/MM/yy').format(_dateFin!)}'
        : 'Sélectionnez une période';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Solde Initial
          Card(
            elevation: 2,
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.account_balance, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '💰 Solde Initial: ${_currencyFormat.format(_soldeInitial)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _modifierSoldeInitial,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Modifier'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Période
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '📅 Période',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_dateFin != null && 
                          _dateFin!.year == DateTime.now().year &&
                          _dateFin!.month == DateTime.now().month &&
                          _dateFin!.day == DateTime.now().day &&
                          _dateDebut == DEFAULT_DATE_DEBUT)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: const Text(
                            '📌 Actuelle',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    periodeText,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatePicker(
                          label: 'Date de départ',
                          date: _dateDebut,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _dateDebut ?? DEFAULT_DATE_DEBUT,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              locale: const Locale('fr', 'FR'),
                            );
                            if (picked != null) {
                              setState(() {
                                _dateDebut = picked;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDatePicker(
                          label: 'Date de fin',
                          date: _dateFin,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _dateFin ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              locale: const Locale('fr', 'FR'),
                            );
                            if (picked != null) {
                              setState(() {
                                _dateFin = picked;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isGenerating ? null : _genererRapport,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            _isGenerating ? 'Génération...' : 'Générer le rapport',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetToDefaultDates,
                          icon: const Icon(Icons.restore),
                          label: const Text('Défaut'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (_rapportData != null)
            _buildJournalTable(_journalEntries, _rapportData!)
          else if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            )
          else if (_isGenerating)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Génération en cours...'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClientView() {
    if (_isLoadingClient) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement du journal...'),
          ],
        ),
      );
    }

    if (_clientRapportData != null && _clientJournalEntries.isNotEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: _buildJournalTable(_clientJournalEntries, _clientRapportData!),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Aucun journal disponible',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Le journal comptable sera disponible dès que l\'administrateur l\'aura généré.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadClientRapport,
              icon: const Icon(Icons.refresh),
              label: const Text('Vérifier la disponibilité'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalTable(List<Map<String, dynamic>> entries, Map<String, dynamic> rapport) {
    final soldeInitial = rapport['soldeInitial'] ?? 0.0;
    final totalDebit = rapport['totalDebit'] ?? 0.0;
    final totalCredit = rapport['totalCredit'] ?? 0.0;
    final soldeFinal = rapport['soldeFinal'] ?? (totalCredit - totalDebit);
    final nbCotisations = entries.where((e) => e['type'] == 'cotisation').length;
    final nbDepensesEnAttente = rapport['nombreDepensesEnAttente'] ?? 0;
    final montantDepensesEnAttente = rapport['montantDepensesEnAttente'] ?? 0.0;
    final nbCotisationsPayees = rapport['nombreCotisationsPayees'] ?? nbCotisations;
    final totalCotisationsPayees = rapport['totalCotisationsPayees'] ?? (totalCredit - soldeInitial);
    final screenWidth = MediaQuery.of(context).size.width;

    double soldeCourant = 0.0;
    List<Map<String, dynamic>> entriesWithSolde = entries.map((entry) {
      final debit = entry['debit'] ?? 0.0;
      final credit = entry['credit'] ?? 0.0;
      final bool isEnAttente = entry['type'] == 'depense_attente';
      
      if (!isEnAttente) {
        soldeCourant = soldeCourant + credit - debit;
      }
      
      return {
        ...entry,
        'soldeCourant': soldeCourant,
        'isEnAttente': isEnAttente,
      };
    }).toList();

    final double dateWidth = screenWidth < 600 ? 70 : 90;
    final double libelleWidth = screenWidth < 600 ? 200 : 400;
    final double montantWidth = screenWidth < 600 ? 85 : 120;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête du journal
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    '📊 Journal Comptable',
                    style: TextStyle(
                      fontSize: screenWidth < 600 ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Période: ${rapport['periode'] ?? 'Non spécifiée'}',
                    style: TextStyle(
                      fontSize: screenWidth < 600 ? 13 : 15,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildSummaryCard('💰 Solde Initial', _currencyFormat.format(soldeInitial), Colors.blue),
                      _buildSummaryCard('📈 Cotisations Payées ($nbCotisationsPayees)', _currencyFormat.format(totalCotisationsPayees), Colors.green),
                      _buildSummaryCard('📉 Dépenses Payées', _currencyFormat.format(totalDebit), Colors.red),
                      if (nbDepensesEnAttente > 0)
                        _buildSummaryCard(
                          '⏳ En Attente ($nbDepensesEnAttente)', 
                          _currencyFormat.format(montantDepensesEnAttente), 
                          Colors.orange,
                        ),
                      _buildSummaryCard('🏦 Solde Final', _currencyFormat.format(soldeFinal), soldeFinal >= 0 ? Colors.green : Colors.red),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            // Tableau du journal
            Container(
              height: screenWidth < 600 ? 400 : 500,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Table(
                      border: TableBorder.all(
                        color: Colors.grey.shade300,
                        width: 0.5,
                      ),
                      columnWidths: {
                        0: FixedColumnWidth(dateWidth),
                        1: FixedColumnWidth(libelleWidth),
                        2: FixedColumnWidth(montantWidth),
                        3: FixedColumnWidth(montantWidth),
                        4: FixedColumnWidth(montantWidth),
                      },
                      children: [
                        // En-tête du tableau
                        TableRow(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.blue.shade700, Colors.blue.shade900],
                            ),
                          ),
                          children: [
                            _buildHeaderCell('DATE'),
                            _buildHeaderCell('LIBELLÉ'),
                            _buildHeaderCell('DÉBIT'),
                            _buildHeaderCell('CRÉDIT'),
                            _buildHeaderCell('SOLDE'),
                          ],
                        ),
                        
                        // Lignes du journal
                        ...entriesWithSolde.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final date = item['date'] as DateTime;
                          final libelle = item['libelle'] ?? '';
                          final debit = item['debit'] ?? 0.0;
                          final credit = item['credit'] ?? 0.0;
                          final solde = item['soldeCourant'] ?? 0.0;
                          final isSoldeInitial = item['isSoldeInitial'] ?? false;
                          final isCotisation = item['type'] == 'cotisation';
                          final isEnAttente = item['isEnAttente'] ?? false;
                          final montantAttente = item['montant_affichage'] ?? 0.0;
                          
                          Color? bgColor;
                          if (isSoldeInitial) {
                            bgColor = Colors.blue.shade50;
                          } else if (isCotisation) {
                            bgColor = Colors.green.shade50;
                          } else if (isEnAttente) {
                            bgColor = Colors.orange.shade50;
                          } else {
                            bgColor = index % 2 == 0 
                                ? Colors.red.shade50 
                                : Colors.red.shade50.withOpacity(0.5);
                          }
                          
                          return TableRow(
                            decoration: BoxDecoration(
                              color: bgColor,
                            ),
                            children: [
                              _buildCell(
                                DateFormat('dd/MM/yy').format(date),
                                fontSize: screenWidth < 600 ? 11 : 13,
                                fontWeight: FontWeight.w500,
                              ),
                              isEnAttente
                                  ? AnimatedBuilder(
                                      animation: _animation,
                                      builder: (context, child) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.warning_amber_rounded,
                                                color: Colors.orange.shade700.withOpacity(_animation.value),
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  libelle,
                                                  style: TextStyle(
                                                    color: Colors.orange.shade700.withOpacity(_animation.value),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: screenWidth < 600 ? 11 : 13,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                ' ${_currencyFormat.format(montantAttente)}',
                                                style: TextStyle(
                                                  color: Colors.orange.shade700.withOpacity(_animation.value),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: screenWidth < 600 ? 11 : 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    )
                                  : _buildCell(
                                      libelle,
                                      bold: isSoldeInitial,
                                      color: isSoldeInitial ? Colors.blue.shade700 : null,
                                      fontSize: screenWidth < 600 ? 11 : 13,
                                      alignment: TextAlign.left,
                                      fontWeight: isSoldeInitial ? FontWeight.bold : FontWeight.normal,
                                    ),
                              _buildCell(
                                debit > 0 ? _currencyFormat.format(debit) : '',
                                color: Colors.red.shade700,
                                bold: debit > 0,
                                fontSize: screenWidth < 600 ? 11 : 13,
                                fontWeight: debit > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                              _buildCell(
                                credit > 0 ? _currencyFormat.format(credit) : '',
                                color: Colors.green.shade700,
                                bold: credit > 0,
                                fontSize: screenWidth < 600 ? 11 : 13,
                                fontWeight: credit > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                              _buildCell(
                                _currencyFormat.format(solde),
                                color: solde >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                bold: true,
                                fontSize: screenWidth < 600 ? 11 : 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ],
                          );
                        }).toList(),
                        
                        // Ligne TOTAL
                        TableRow(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.blue.shade100, Colors.blue.shade200],
                            ),
                          ),
                          children: [
                            _buildCell('', fontSize: 12),
                            _buildCell(
                              'TOTAUX',
                              bold: true,
                              alignment: TextAlign.right,
                              fontSize: screenWidth < 600 ? 12 : 14,
                              fontWeight: FontWeight.bold,
                            ),
                            _buildCell(
                              _currencyFormat.format(totalDebit),
                              color: Colors.red.shade700,
                              bold: true,
                              fontSize: screenWidth < 600 ? 12 : 14,
                              fontWeight: FontWeight.bold,
                            ),
                            _buildCell(
                              _currencyFormat.format(totalCredit),
                              color: Colors.green.shade700,
                              bold: true,
                              fontSize: screenWidth < 600 ? 12 : 14,
                              fontWeight: FontWeight.bold,
                            ),
                            _buildCell(
                              _currencyFormat.format(totalCredit - totalDebit),
                              color: (totalCredit - totalDebit) >= 0 ? Colors.orange.shade700 : Colors.red.shade700,
                              bold: true,
                              fontSize: screenWidth < 600 ? 12 : 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ],
                        ),
                        
                        // Ligne SOLDE FINAL
                        TableRow(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: soldeFinal >= 0 
                                  ? [Colors.green.shade100, Colors.green.shade200]
                                  : [Colors.red.shade100, Colors.red.shade200],
                            ),
                          ),
                          children: [
                            _buildCell('', fontSize: 12),
                            _buildCell(
                              'SOLDE FINAL',
                              bold: true,
                              alignment: TextAlign.right,
                              fontSize: screenWidth < 600 ? 12 : 14,
                              fontWeight: FontWeight.bold,
                            ),
                            _buildCell('', fontSize: 12),
                            _buildCell('', fontSize: 12),
                            _buildCell(
                              _currencyFormat.format(soldeFinal),
                              color: soldeFinal >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                              bold: true,
                              fontSize: screenWidth < 600 ? 14 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Légende
            Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                _buildLegendItem(Colors.blue.shade100, '💰 Solde Initial'),
                _buildLegendItem(Colors.green.shade50, '✅ Cotisations Payées'),
                _buildLegendItem(Colors.red.shade50, '❌ Dépenses Payées'),
                _buildLegendItem(Colors.orange.shade50, '⏳ En Attente (clignotant)'),
              ],
            ),
            
            const SizedBox(height: 4),
            
            Center(
              child: Text(
                '👆 Glissez horizontalement et verticalement',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: screenWidth < 600 ? 9 : 11,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: screenWidth < 600 ? 11 : 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCell(
    String text, {
    Color? color,
    bool bold = false,
    TextAlign alignment = TextAlign.center,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? Colors.black87,
          fontWeight: bold ? FontWeight.bold : fontWeight,
          fontSize: fontSize,
        ),
        textAlign: alignment,
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 14,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                date != null 
                    ? DateFormat('dd/MM/yyyy').format(date)
                    : label,
                style: TextStyle(
                  color: date != null ? Colors.black : Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}