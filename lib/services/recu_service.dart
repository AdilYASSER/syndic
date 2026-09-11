// lib/services/recu_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import '../models/recu_model.dart';

class RecuService {
  // ✅ Méthode pour charger la signature
  Future<Uint8List> _getSignatureBytes() async {
    try {
      final byteData = await rootBundle.load('assets/images/signature.png');
      return byteData.buffer.asUint8List();
    } catch (e) {
      print('❌ Erreur chargement signature: $e');
      return Uint8List.fromList([]);
    }
  }

  // ✅ Méthode pour obtenir un numéro de reçu sécurisé
  String _getRecuNumber(String id) {
    if (id.isEmpty) {
      final now = DateTime.now();
      return 'REC${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    }
    if (id.length < 8) {
      return id.padRight(8, '0').toUpperCase();
    }
    return id.substring(0, 8).toUpperCase();
  }

  // ✅ GÉNÉRER LE FICHIER PDF (POUR MOBILE/DESKTOP)
  Future<File> generateRecuPDF(RecuModel recu) async {
    final pdf = await _generatePdfDocument(recu);
    final bytes = await pdf.save();

    if (kIsWeb) {
      // ✅ Pour le Web : télécharger directement
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..target = '_blank'
        ..download = 'recu_${recu.id}.pdf';
      anchor.click();
      html.Url.revokeObjectUrl(url);
      
      return File('recu_${recu.id}.pdf');
    } else {
      // ✅ Pour Mobile/Desktop : sauvegarder dans le système de fichiers
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/recu_${recu.id}.pdf');
      await file.writeAsBytes(bytes);
      return file;
    }
  }

  // ✅ GÉNÉRER LE DOCUMENT PDF
  Future<pw.Document> _generatePdfDocument(RecuModel recu) async {
    final pdf = pw.Document();

    // ✅ Pour l'imprimante monochrome : utiliser des nuances de gris
    final statutColor = recu.statut == 'Total' 
        ? PdfColors.black 
        : recu.statut == 'Partiel' 
            ? PdfColors.grey600 
            : PdfColors.grey800;

    // ✅ Charger la signature
    final signatureBytes = await _getSignatureBytes();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ==================== EN-TÊTE ====================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SYNDIC',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.Text(
                        'AIN SEBAA - WAHDA',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.grey,
                        ),
                      ),
                      pw.Text(
                        'Gestion Copropriété',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: statutColor,
                        width: 2,
                      ),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'REÇU DE PAIEMENT',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: statutColor,
                          ),
                        ),
                        pw.Text(
                          recu.statutTexte,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: statutColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // ==================== INFORMATIONS GÉNÉRALES ====================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'N° Reçu: ${_getRecuNumber(recu.id)}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.Text(
                        'Date: ${_formatDate(recu.dateEmission)}',
                        style: pw.TextStyle(
                          color: PdfColors.black,
                        ),
                      ),
                    ],
                  ),
                  // ✅ Badge statut : Texte noir sur fond blanc encadré en noir
                  pw.Container(
                    padding: pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(
                        color: PdfColors.black,
                        width: 1,
                      ),
                    ),
                    child: pw.Text(
                      recu.statutTexte,
                      style: pw.TextStyle(
                        color: PdfColors.black,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              
              pw.SizedBox(height: 20),

              // ==================== INFORMATIONS DU CLIENT ====================
              pw.Container(
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '👤 INFORMATIONS DU CLIENT',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      '🏠 Appartement: ${recu.numAppartement}',
                      style: pw.TextStyle(
                        color: PdfColors.black,
                      ),
                    ),
                    pw.Text(
                      '👤 Nom: ${recu.nomPrenom}',
                      style: pw.TextStyle(
                        color: PdfColors.black,
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),

              // ==================== DÉTAILS DU PAIEMENT ====================
              pw.Container(
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  border: pw.Border.all(color: PdfColors.black),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '📋 DÉTAILS DU PAIEMENT',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    _buildDetailRow('📅 Année', recu.annee.toString()),
                    _buildDetailRow('📆 Période', recu.periode),
                    _buildDetailRow('💳 Mode de paiement', _getModePaiementLabel(recu.modePaiement)),
                    if (recu.numeroCheque != null)
                      _buildDetailRow('📝 N° Chèque', recu.numeroCheque!),
                    
                    pw.SizedBox(height: 8),
                    pw.Divider(),
                    pw.SizedBox(height: 8),
                    
                    // ✅ STATUT DU PAIEMENT (texte noir sur fond blanc encadré noir)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '📊 Statut du paiement',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(4),
                            border: pw.Border.all(
                              color: PdfColors.black,
                              width: 1,
                            ),
                          ),
                          child: pw.Text(
                            recu.statutTexte,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    pw.SizedBox(height: 8),
                    
                    // ✅ BARRE DE PROGRESSION (noir et blanc)
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Container(
                            height: 12,
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey200,
                              borderRadius: pw.BorderRadius.circular(6),
                              border: pw.Border.all(color: PdfColors.grey400),
                            ),
                            child: pw.Container(
                              width: (recu.pourcentagePaye / 100) * 400,
                              decoration: pw.BoxDecoration(
                                color: PdfColors.black,
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          '${recu.pourcentagePaye.toStringAsFixed(0)}%',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ],
                    ),
                    
                    pw.SizedBox(height: 8),
                    
                    // ✅ MONTANT PAYÉ
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '💰 Montant payé',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.Text(
                          '${recu.montant.toStringAsFixed(2)} DH',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                            color: PdfColors.black,
                          ),
                        ),
                      ],
                    ),
                    
                    // ✅ MONTANT RESTANT
                    if (recu.montantRestant != null && recu.montantRestant! > 0) ...[
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '⚠️ Montant restant',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                              color: PdfColors.black,
                            ),
                          ),
                          pw.Text(
                            '${recu.montantRestant!.toStringAsFixed(2)} DH',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                              color: PdfColors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),

              // ==================== RÉSUMÉ FINAL ====================
              pw.Container(
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.black),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '📌 RÉSUMÉ',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.Text(
                          'Période: ${recu.annee} - ${recu.periode}',
                          style: pw.TextStyle(
                            fontSize: 11,
                            color: PdfColors.black,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          recu.statutTexte,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.Text(
                          '${recu.montant.toStringAsFixed(2)} DH / ${recu.montantAttendu.toStringAsFixed(2)} DH',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 30),

              // ==================== PIED DE PAGE AVEC SIGNATURE ====================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Signature du Syndic',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        width: 150,
                        height: 50,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Center(
                          child: signatureBytes.isNotEmpty
                              ? pw.Image(
                                  pw.MemoryImage(signatureBytes),
                                  width: 140,
                                  height: 40,
                                  fit: pw.BoxFit.contain,
                                )
                              : pw.Text(
                                  'Signature',
                                  style: pw.TextStyle(
                                    fontSize: 12,
                                    color: PdfColors.grey500,
                                  ),
                                ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Cachet du Syndic',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey500,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Fait à Casablanca, le ${_formatDate(DateTime.now())}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Pour copie certifiée conforme',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey500,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 12),
              
              // Ligne de séparation
              pw.Divider(),
              
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'Ce reçu fait foi de paiement - SYNDIC Gestion Copropriété',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'Généré le ${_formatDate(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildDetailRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: PdfColors.black,
            fontSize: 12,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: PdfColors.black,
            fontWeight: pw.FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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