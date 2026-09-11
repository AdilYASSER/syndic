// lib/screens/cotisations_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

import 'add_cotisation_screen.dart';
import '../models/cotisation.dart';
import '../services/cotisation_service.dart';
// ✅ AJOUT DE L'IMPORT POUR LE REÇU
import 'admin/admin_generer_recu.dart';

class CotisationsListScreen extends StatefulWidget {
  final String? role;
  final String? appartement;
  final String? mode; // ✅ AJOUT DU MODE POUR LA PRODUCTION DE REÇUS

  const CotisationsListScreen({
    super.key,
    this.role,
    this.appartement,
    this.mode,
  });

  @override
  State<CotisationsListScreen> createState() => _CotisationsListScreenState();
}

class _CotisationsListScreenState extends State<CotisationsListScreen> {
  final CotisationService _cotisationService = CotisationService();
  List<Cotisation> _cotisations = [];
  List<Cotisation> _filteredCotisations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatut = 'Tous';
  bool _isAdmin = true;
  bool _isGenererRecuMode = false;

  final List<String> _statuts = ['Tous', 'Payé', 'En attente', 'Annulée', 'Impayé'];

  // Statistiques
  int _totalCount = 0;
  int _payeCount = 0;
  int _enAttenteCount = 0;
  int _annuleeCount = 0;
  int _impayeCount = 0;
  double _totalMontant = 0.0;

  @override
  void initState() {
    super.initState();
    _isAdmin = widget.role == 'admin' || true;
    _isGenererRecuMode = widget.mode == 'generer_recu';
    _loadCotisations();
  }

  // ✅ CHARGER LES COTISATIONS DEPUIS FIRESTORE
  Future<void> _loadCotisations() async {
    setState(() => _isLoading = true);
    try {
      print('📡 Début du chargement des cotisations...');
      
      _cotisations = await _loadCotisationsFromFirestore();
      
      print('📊 ${_cotisations.length} cotisations chargées');
      
      for (var c in _cotisations) {
        print('📄 App: ${c.numAppartement}, Année: ${c.annee}, S1: ${c.periode1}, S2: ${c.periode2}, Montant: ${c.montant}, Statut: ${c.statut}');
      }
      
      _applyFilters();
      _updateStats();
      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Erreur chargement: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ✅ CHARGEMENT DIRECT DEPUIS FIRESTORE
  Future<List<Cotisation>> _loadCotisationsFromFirestore() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('cotisations')
          .orderBy('annee', descending: true)
          .get();

      print('📡 ${snapshot.docs.length} documents trouvés dans Firestore');

      final List<Cotisation> cotisations = [];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          
          final cotisation = Cotisation(
            id: doc.id,
            numAppartement: data['numAppartement']?.toString() ?? '',
            nomPrenom: data['nomPrenom']?.toString() ?? '',
            dateVersement: data['dateVersement'] != null 
                ? (data['dateVersement'] as Timestamp).toDate() 
                : null,
            modeVersement: data['modeVersement']?.toString() ?? 'espece',
            montant: (data['montant'] as num?)?.toDouble() ?? 0.0,
            periode1: data['periode1'] == true || data['periode1'] == 1,
            periode2: data['periode2'] == true || data['periode2'] == 1,
            annee: data['annee'] is int ? data['annee'] : int.tryParse(data['annee']?.toString() ?? '') ?? 2025,
            synced: data['synced'] is int ? data['synced'] : 0,
            justificatifUrl: data['justificatifUrl']?.toString(),
            statut: data['statut']?.toString() ?? 'En attente',
            dateCreation: data['dateCreation'] != null 
                ? (data['dateCreation'] as Timestamp).toDate() 
                : null,
            appartement: data['appartement']?.toString() ?? data['numAppartement']?.toString() ?? '',
          );
          
          cotisations.add(cotisation);
          print('✅ Cotisation ajoutée: ${cotisation.numAppartement} - ${cotisation.annee} - S1:${cotisation.periode1} S2:${cotisation.periode2}');
          
        } catch (e) {
          print('❌ Erreur conversion doc ${doc.id}: $e');
          continue;
        }
      }

      print('✅ ${cotisations.length} cotisations chargées avec succès');
      return cotisations;
    } catch (e) {
      print('❌ Erreur chargement Firestore: $e');
      return [];
    }
  }

  // ✅ APPLIQUER LES FILTRES
  void _applyFilters() {
    _filteredCotisations = _cotisations.where((c) {
      final query = _searchQuery.toLowerCase();
      final matchSearch = c.numAppartement.toLowerCase().contains(query) ||
          c.nomPrenom.toLowerCase().contains(query);
      final matchStatut = _filterStatut == 'Tous' || c.statut == _filterStatut;
      
      if (widget.appartement != null && widget.appartement!.isNotEmpty) {
        return matchSearch && matchStatut && 
            c.numAppartement.toUpperCase() == widget.appartement!.toUpperCase();
      }
      
      return matchSearch && matchStatut;
    }).toList();
    
    print('🔍 ${_filteredCotisations.length} cotisations après filtrage');
  }

  // ✅ METTRE À JOUR LES STATISTIQUES
  void _updateStats() {
    _totalCount = _filteredCotisations.length;
    _payeCount = _filteredCotisations.where((c) => c.statut == 'Payé').length;
    _enAttenteCount = _filteredCotisations.where((c) => c.statut == 'En attente').length;
    _annuleeCount = _filteredCotisations.where((c) => c.statut == 'Annulée').length;
    _impayeCount = _filteredCotisations.where((c) => c.statut == 'Impayé').length;
    _totalMontant = _filteredCotisations.fold(0, (sum, c) => sum + c.montant);
  }

  // ✅ MÉTHODE POUR GÉNÉRER LE REÇU
  void _genererRecu(Cotisation cotisation) {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut générer des reçus'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String periode = 'N/A';
    if (cotisation.periode1 && cotisation.periode2) {
      periode = 'S1+S2';
    } else if (cotisation.periode1) {
      periode = 'S1';
    } else if (cotisation.periode2) {
      periode = 'S2';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminGenererRecuScreen(
          cotisationId: cotisation.id!,
          numAppartement: cotisation.numAppartement,
          nomPrenom: cotisation.nomPrenom.isNotEmpty 
              ? cotisation.nomPrenom 
              : cotisation.numAppartement,
          montant: cotisation.montant,
          annee: cotisation.annee,
          periode1: cotisation.periode1,
          periode2: cotisation.periode2,
          modePaiement: cotisation.modeVersement,
          statut: cotisation.statut ?? 'Payé',
          numeroCheque: null,
        ),
      ),
    );
  }

  // ✅ AJOUTER UNE COTISATION
  Future<void> _ajouterCotisation() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut ajouter des cotisations'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddCotisationScreen(),
      ),
    );

    if (result == true) {
      _loadCotisations();
    }
  }

  // ✅ ÉDITER UNE COTISATION
  Future<void> _editCotisation(Cotisation cotisation) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut modifier'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCotisationScreen(
          cotisation: cotisation,
          fonction: 'edit',
        ),
      ),
    );

    if (result == true) {
      _loadCotisations();
    }
  }

  // ✅ SUPPRIMER UNE COTISATION
  Future<void> _deleteCotisation(Cotisation cotisation) async {
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
          'Voulez-vous vraiment supprimer la cotisation de l\'appartement ${cotisation.numAppartement} ?',
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
        await _cotisationService.deleteCotisation(cotisation.id!);
        _loadCotisations();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cotisation supprimée avec succès'),
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

  // ✅ AFFICHER LES DÉTAILS
  void _showCotisationDetails(Cotisation cotisation) {
    final statusColor = Cotisation.getStatutColor(cotisation.statut ?? 'En attente');
    final statusIcon = Cotisation.getStatutIcon(cotisation.statut ?? 'En attente');

    String periodeAffichee = 'N/A';
    if (cotisation.periode1 && cotisation.periode2) {
      periodeAffichee = 'S1 + S2';
    } else if (cotisation.periode1) {
      periodeAffichee = 'S1';
    } else if (cotisation.periode2) {
      periodeAffichee = 'S2';
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 500,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      statusIcon,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Appartement ${cotisation.numAppartement}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Statut : ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              cotisation.statut ?? 'N/A',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            'Montant : ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${cotisation.montant.toStringAsFixed(2)} DH',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.apartment, 'Appartement', cotisation.numAppartement),
                      if (cotisation.nomPrenom.isNotEmpty && cotisation.nomPrenom != 'N/A')
                        _buildDetailRow(Icons.person, 'Propriétaire', cotisation.nomPrenom),
                      _buildDetailRow(Icons.calendar_month, 'Période', periodeAffichee),
                      _buildDetailRow(Icons.calendar_view_day, 'Année', cotisation.annee.toString()),
                      if (cotisation.dateVersement != null)
                        _buildDetailRow(
                          Icons.payment,
                          'Date versement',
                          DateFormat('dd/MM/yyyy').format(cotisation.dateVersement!),
                        ),
                      if (cotisation.modeVersement.isNotEmpty)
                        _buildDetailRow(Icons.credit_card, 'Mode versement', cotisation.modeVersement),
                      _buildDetailRow(
                        Icons.timer,
                        'Date création',
                        DateFormat('dd/MM/yyyy HH:mm').format(cotisation.dateCreation ?? DateTime.now()),
                      ),
                      if (cotisation.justificatifUrl != null && cotisation.justificatifUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '📎 Justificatif :',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => _showJustificatifFullScreen(context, cotisation.justificatifUrl!),
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      cotisation.justificatifUrl!,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                      loadingProgress.expectedTotalBytes!
                                                  : null,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey.shade200,
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: Colors.grey,
                                            size: 30,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 16),
              if (_isAdmin)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // ✅ BOUTON REÇU DANS LES DÉTAILS
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _genererRecu(cotisation);
                      },
                      icon: const Icon(Icons.receipt, size: 18, color: Colors.green),
                      label: const Text(
                        '📄 Reçu',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteCotisation(cotisation);
                      },
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      label: const Text(
                        'Supprimer',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _editCotisation(cotisation);
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Modifier'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
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

  // ✅ AFFICHER LE JUSTIFICATIF EN PLEIN ÉCRAN
  void _showJustificatifFullScreen(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 400,
                        width: 300,
                        color: Colors.grey.shade100,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, size: 50, color: Colors.red),
                              SizedBox(height: 8),
                              Text(
                                'Erreur de chargement',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.5),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              '$label :',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ EXPORT EXCEL
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
      excel_lib.Sheet sheet = excel['Cotisations'];

      List<String> headers = ['Appartement', 'Propriétaire', 'Montant (DH)', 'Période', 'Année', 'Statut', 'Mode versement', 'Date versement'];
      List<excel_lib.CellValue> headerRow = headers.map((h) => excel_lib.TextCellValue(h)).toList();
      sheet.appendRow(headerRow);

      for (var c in _filteredCotisations) {
        String periodeAffichee = 'N/A';
        if (c.periode1 && c.periode2) {
          periodeAffichee = 'S1 + S2';
        } else if (c.periode1) {
          periodeAffichee = 'S1';
        } else if (c.periode2) {
          periodeAffichee = 'S2';
        }
        String dateVersement = c.dateVersement != null 
            ? DateFormat('dd/MM/yyyy').format(c.dateVersement!) 
            : 'N/A';

        List<excel_lib.CellValue> row = [
          excel_lib.TextCellValue(c.numAppartement),
          excel_lib.TextCellValue(c.nomPrenom),
          excel_lib.TextCellValue(c.montant.toString()),
          excel_lib.TextCellValue(periodeAffichee),
          excel_lib.TextCellValue(c.annee.toString()),
          excel_lib.TextCellValue(c.statut ?? 'En attente'),
          excel_lib.TextCellValue(c.modeVersement),
          excel_lib.TextCellValue(dateVersement),
        ];
        sheet.appendRow(row);
      }

      String filename = 'cotisations_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
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

  // ✅ EXPORT CSV
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
      List<List<dynamic>> rows = [
        ['Appartement', 'Propriétaire', 'Montant (DH)', 'Période', 'Année', 'Statut', 'Mode versement', 'Date versement']
      ];

      for (var c in _filteredCotisations) {
        String periodeAffichee = 'N/A';
        if (c.periode1 && c.periode2) {
          periodeAffichee = 'S1 + S2';
        } else if (c.periode1) {
          periodeAffichee = 'S1';
        } else if (c.periode2) {
          periodeAffichee = 'S2';
        }
        String dateVersement = c.dateVersement != null 
            ? DateFormat('dd/MM/yyyy').format(c.dateVersement!) 
            : 'N/A';

        rows.add([
          c.numAppartement,
          c.nomPrenom,
          c.montant.toString(),
          periodeAffichee,
          c.annee.toString(),
          c.statut ?? 'En attente',
          c.modeVersement,
          dateVersement,
        ]);
      }

      String csv = const ListToCsvConverter().convert(rows);
      String filename = 'cotisations_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';

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
            Text('📤 Exporter les cotisations'),
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

  // ✅ BUILD STATS CARDS
  Widget _buildStatsCards() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildStatCard('Total', _totalCount, _totalMontant, Colors.blue),
          _buildStatCard('Payé', _payeCount, 0, Colors.green),
          _buildStatCard('En attente', _enAttenteCount, 0, Colors.orange),
          _buildStatCard('Annulée', _annuleeCount, 0, Colors.red),
          _buildStatCard('Impayé', _impayeCount, 0, Colors.red.shade700),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, double montant, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey.shade600,
              ),
            ),
            if (montant > 0)
              Text(
                '${montant.toStringAsFixed(0)} DH',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isGenererRecuMode = widget.mode == 'generer_recu';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          isGenererRecuMode 
              ? '📄 PRODUCTION DE REÇUS' 
              : (_isAdmin ? '📋 Cotisations' : '📋 Mes cotisations'),
        ),
        backgroundColor: isGenererRecuMode 
            ? Colors.green.shade800 
            : (_isAdmin ? Colors.blue.shade700 : Colors.green.shade700),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        actions: [
          if (isGenererRecuMode)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '📄 REÇUS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (_isAdmin && !isGenererRecuMode)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _ajouterCotisation,
              tooltip: 'Ajouter une cotisation',
            ),
          if (_isAdmin && _filteredCotisations.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _showExportDialog,
              tooltip: 'Exporter',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCotisations,
            tooltip: 'Rafraîchir',
          ),
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
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: '🔍 Rechercher par appartement, nom...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _applyFilters();
                            _updateStats();
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                  _updateStats();
                });
              },
            ),
          ),
          // Filtre statut
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statuts.map((statut) {
                  final isSelected = _filterStatut == statut;
                  Color color;
                  switch (statut) {
                    case 'Payé':
                      color = Colors.green;
                      break;
                    case 'En attente':
                      color = Colors.orange;
                      break;
                    case 'Annulée':
                      color = Colors.red;
                      break;
                    case 'Impayé':
                      color = Colors.red.shade700;
                      break;
                    default:
                      color = Colors.blue;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(statut),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _filterStatut = statut;
                          _applyFilters();
                          _updateStats();
                        });
                      },
                      backgroundColor: Colors.grey.shade200,
                      selectedColor: color.withOpacity(0.2),
                      checkmarkColor: color,
                      labelStyle: TextStyle(
                        color: isSelected ? color : Colors.grey.shade700,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Cartes de statistiques
          if (_filteredCotisations.isNotEmpty) _buildStatsCards(),
          const SizedBox(height: 4),
          // ✅ INFO POUR LE MODE REÇU
          if (isGenererRecuMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '📄 Cliquez sur le bouton "Reçu" pour générer le PDF',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          // Liste des cotisations
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCotisations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payment, size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              _cotisations.isEmpty
                                  ? 'Aucune cotisation trouvée dans la base de données'
                                  : 'Aucune cotisation ne correspond aux filtres',
                              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                            ),
                            if (_cotisations.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _filterStatut = 'Tous';
                                    _applyFilters();
                                    _updateStats();
                                  });
                                },
                                child: const Text('Réinitialiser les filtres'),
                              ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _loadCotisations,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Recharger'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredCotisations.length,
                        padding: const EdgeInsets.all(8),
                        itemBuilder: (context, index) {
                          final cotisation = _filteredCotisations[index];
                          final statusColor = Cotisation.getStatutColor(cotisation.statut ?? 'En attente');
                          final statusIcon = Cotisation.getStatutIcon(cotisation.statut ?? 'En attente');

                          String periodeAffichee = 'N/A';
                          if (cotisation.periode1 && cotisation.periode2) {
                            periodeAffichee = 'S1 + S2';
                          } else if (cotisation.periode1) {
                            periodeAffichee = 'S1';
                          } else if (cotisation.periode2) {
                            periodeAffichee = 'S2';
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () => _showCotisationDetails(cotisation),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    // Icône de statut
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: statusColor.withOpacity(0.2),
                                      child: Icon(
                                        statusIcon,
                                        color: statusColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Informations principales
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'App ${cotisation.numAppartement}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: Colors.blue.shade700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.purple.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  periodeAffichee,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Colors.purple.shade700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  cotisation.statut ?? 'En attente',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: statusColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          if (cotisation.nomPrenom.isNotEmpty && cotisation.nomPrenom != 'N/A')
                                            Text(
                                              cotisation.nomPrenom,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          Text(
                                            'Année: ${cotisation.annee}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Montant et boutons
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${cotisation.montant.toStringAsFixed(2)} DH',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: statusColor,
                                          ),
                                        ),
                                        if (cotisation.dateVersement != null)
                                          Text(
                                            DateFormat('dd/MM/yyyy').format(cotisation.dateVersement!),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        // ✅ BOUTONS D'ACTION
                                        if (_isAdmin)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // ✅ BOUTON REÇU (pour tous les modes admin)
                                              ElevatedButton.icon(
                                                onPressed: () {
                                                  _genererRecu(cotisation);
                                                },
                                                icon: const Icon(Icons.receipt, size: 14),
                                                label: const Text('Reçu'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green.shade700,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  minimumSize: const Size(50, 24),
                                                  textStyle: const TextStyle(fontSize: 10),
                                                ),
                                              ),
                                              if (!isGenererRecuMode) ...[
                                                const SizedBox(width: 4),
                                                IconButton(
                                                  icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                                                  onPressed: () => _editCotisation(cotisation),
                                                  tooltip: 'Modifier',
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                                  onPressed: () => _deleteCotisation(cotisation),
                                                  tooltip: 'Supprimer',
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                              ],
                                            ],
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey.shade400,
                                    ),
                                  ],
                                ),
                              ),
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