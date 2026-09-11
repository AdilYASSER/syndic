// lib/screens/admin/admin_generer_recu.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import '../../services/recu_service.dart';
import '../../models/recu_model.dart';

class AdminGenererRecuScreen extends StatefulWidget {
  final String cotisationId;
  final String numAppartement;
  final String nomPrenom;
  final double montant;
  final int annee;
  final bool periode1;
  final bool periode2;
  final String modePaiement;
  final String statut;
  final String? numeroCheque;

  const AdminGenererRecuScreen({
    super.key,
    required this.cotisationId,
    required this.numAppartement,
    required this.nomPrenom,
    required this.montant,
    required this.annee,
    required this.periode1,
    required this.periode2,
    required this.modePaiement,
    required this.statut,
    this.numeroCheque,
  });

  @override
  State<AdminGenererRecuScreen> createState() => _AdminGenererRecuScreenState();
}

class _AdminGenererRecuScreenState extends State<AdminGenererRecuScreen> {
  final RecuService _recuService = RecuService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isGenerating = false;
  bool _isLoading = true;
  String _nomComplet = '';

  String get _periode {
    if (widget.periode1 && widget.periode2) return 'S1+S2';
    if (widget.periode1) return 'S1';
    if (widget.periode2) return 'S2';
    return 'N/A';
  }

  double? get _montantRestant {
    if (widget.statut == 'Partiel' || widget.montant < 1800.0) {
      return 1800.0 - widget.montant;
    }
    return null;
  }

  String get _statutReel {
    if (widget.montant >= 1800.0) return 'Total';
    if (widget.montant > 0) return 'Partiel';
    return 'Non payé';
  }

  @override
  void initState() {
    super.initState();
    _chargerNomProprietaire();
  }

  // ✅ CHARGER LE NOM DU PROPRIÉTAIRE
  Future<void> _chargerNomProprietaire() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore
          .collection('habitants')
          .where('numAppartement', isEqualTo: widget.numAppartement)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final nom = data['nom'] ?? '';
        final prenom = data['prenom'] ?? '';
        final nomComplet = '$prenom $nom'.trim();
        
        if (nomComplet.isNotEmpty) {
          setState(() {
            _nomComplet = nomComplet;
          });
          print('✅ Nom du propriétaire chargé: $_nomComplet');
        } else {
          setState(() {
            _nomComplet = widget.nomPrenom.isNotEmpty 
                ? widget.nomPrenom 
                : widget.numAppartement;
          });
        }
      } else {
        setState(() {
          _nomComplet = widget.nomPrenom.isNotEmpty 
              ? widget.nomPrenom 
              : widget.numAppartement;
        });
        print('⚠️ Aucun habitant trouvé pour l\'appartement ${widget.numAppartement}');
      }
    } catch (e) {
      print('❌ Erreur chargement nom: $e');
      setState(() {
        _nomComplet = widget.nomPrenom.isNotEmpty 
            ? widget.nomPrenom 
            : widget.numAppartement;
      });
    }
    setState(() => _isLoading = false);
  }

  // ✅ VÉRIFICATION DES DOUBLONS "TOTAL"
  Future<bool> _verifierDoublonTotal() async {
    try {
      final snapshot = await _firestore
          .collection('recus')
          .where('numAppartement', isEqualTo: widget.numAppartement)
          .where('annee', isEqualTo: widget.annee)
          .where('periode', isEqualTo: _periode)
          .where('statut', isEqualTo: 'Total')
          .get();

      if (snapshot.docs.isNotEmpty) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ Reçu Total existant'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Un reçu "Total" existe déjà pour cette période.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('🏠 Appartement: ${widget.numAppartement}'),
                Text('📅 Période: ${widget.annee} - $_periode'),
                Text('💰 Montant: ${widget.montant.toStringAsFixed(2)} DH'),
                const SizedBox(height: 12),
                Text(
                  'Voulez-vous remplacer le reçu existant ?',
                  style: TextStyle(color: Colors.orange),
                ),
              ],
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
                child: const Text('Remplacer'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          for (var doc in snapshot.docs) {
            await doc.reference.delete();
          }
          print('🗑️ Ancien reçu supprimé');
          return true;
        }
        return false;
      }
      return true;
    } catch (e) {
      print('❌ Erreur vérification: $e');
      return true;
    }
  }

  Future<void> _genererEtEnvoyerRecu() async {
    // ✅ Vérifier les doublons
    final peutContinuer = await _verifierDoublonTotal();
    if (!peutContinuer) {
      setState(() => _isGenerating = false);
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final recu = RecuModel(
        id: '',
        numAppartement: widget.numAppartement,
        nomPrenom: _nomComplet.isNotEmpty ? _nomComplet : widget.numAppartement,
        montant: widget.montant,
        dateEmission: DateTime.now(),
        annee: widget.annee,
        periode: _periode,
        modePaiement: widget.modePaiement,
        statut: _statutReel,
        montantRestant: _montantRestant,
        numeroCheque: widget.numeroCheque,
        cotisationId: widget.cotisationId,
        generatedBy: 'admin',
        dateCreation: DateTime.now(),
        montantAttendu: 1800.0,
      );

      final docRef = await _firestore.collection('recus').add(recu.toJson());
      
      final recuWithId = RecuModel(
        id: docRef.id,
        numAppartement: recu.numAppartement,
        nomPrenom: recu.nomPrenom,
        montant: recu.montant,
        dateEmission: recu.dateEmission,
        annee: recu.annee,
        periode: recu.periode,
        modePaiement: recu.modePaiement,
        statut: recu.statut,
        montantRestant: recu.montantRestant,
        numeroCheque: recu.numeroCheque,
        cotisationId: recu.cotisationId,
        generatedBy: recu.generatedBy,
        dateCreation: recu.dateCreation,
        montantAttendu: recu.montantAttendu,
      );
      
      final file = await _recuService.generateRecuPDF(recuWithId);
      await _envoyerRecuAuClient(file, recuWithId);

      setState(() => _isGenerating = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Reçu généré avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }

    } catch (e) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _envoyerRecuAuClient(File file, RecuModel recu) async {
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..target = '_blank'
        ..download = 'recu_${recu.id}.pdf';
      anchor.click();
      html.Url.revokeObjectUrl(url);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📄 Reçu téléchargé avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '📄 Reçu de paiement - Appartement ${recu.numAppartement}\n'
              'Période: ${recu.annee} - ${recu.periode}\n'
              'Montant: ${recu.montant.toStringAsFixed(2)} DH\n'
              'Statut: ${recu.statutTexte}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statutReel = _statutReel;
    final Color statutColor = statutReel == 'Total' 
        ? Colors.green 
        : statutReel == 'Partiel' 
            ? Colors.orange 
            : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📄 Générer un reçu'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statutColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statutReel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                  Text('Chargement des informations...'),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📋 Récapitulatif du paiement',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoCard(),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progression du paiement',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              '${((widget.montant / 1800.0) * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: statutColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: FractionallySizedBox(
                            widthFactor: widget.montant / 1800.0,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [statutColor, statutColor.withOpacity(0.6)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isGenerating ? null : _genererEtEnvoyerRecu,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '📤 Générer et envoyer le reçu',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    final statutReel = _statutReel;
    final Color statutColor = statutReel == 'Total' 
        ? Colors.green 
        : statutReel == 'Partiel' 
            ? Colors.orange 
            : Colors.red;

    final nomAffiche = _nomComplet.isNotEmpty 
        ? _nomComplet 
        : (widget.nomPrenom.isNotEmpty ? widget.nomPrenom : widget.numAppartement);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statutColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Appartement', widget.numAppartement),
            _buildInfoRow('Nom du propriétaire', nomAffiche),
            _buildInfoRow('Montant', '${widget.montant.toStringAsFixed(2)} DH'),
            _buildInfoRow('Année', widget.annee.toString()),
            _buildInfoRow('Période', _periode),
            _buildInfoRow('Mode de paiement', _getModePaiementLabel(widget.modePaiement)),
            if (widget.numeroCheque != null)
              _buildInfoRow('N° Chèque', widget.numeroCheque!),
            _buildInfoRow('Statut', statutReel),
            if (_montantRestant != null && _montantRestant! > 0)
              _buildInfoRow('Restant', '${_montantRestant!.toStringAsFixed(2)} DH'),
            _buildInfoRow('Date d\'émission', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final statutReel = _statutReel;
    final Color statutColor = statutReel == 'Total' 
        ? Colors.green 
        : statutReel == 'Partiel' 
            ? Colors.orange 
            : Colors.red;
            
    bool isStatut = label == 'Statut';
    bool isRestant = label == 'Restant';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isRestant ? Colors.red.shade700 : Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isStatut ? FontWeight.bold : FontWeight.normal,
              color: isStatut ? statutColor : (isRestant ? Colors.red.shade700 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  String _getModePaiementLabel(String mode) {
    switch (mode) {
      case 'espece': return 'Espèces';
      case 'virement': return 'Virement bancaire';
      case 'cheque': return 'Chèque';
      default: return mode;
    }
  }
}