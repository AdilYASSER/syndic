// lib/services/releve_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/cotisation.dart';
import '../models/depense.dart';

class ReleveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ⬇️ RÉCUPÉRER LES DONNÉES POUR LE RELEVÉ
  Future<Map<String, dynamic>> getReleveData({
    String? appartement,
    int? annee,
    String? periode,
  }) async {
    try {
      // Récupérer les cotisations
      QuerySnapshot cotisationsSnapshot;
      if (appartement != null && appartement.isNotEmpty) {
        cotisationsSnapshot = await _firestore
            .collection('cotisations')
            .where('numAppartement', isEqualTo: appartement)
            .orderBy('dateCreation', descending: true)
            .get();
      } else {
        cotisationsSnapshot = await _firestore
            .collection('cotisations')
            .orderBy('dateCreation', descending: true)
            .get();
      }

      // Récupérer les dépenses
      QuerySnapshot depensesSnapshot;
      if (appartement != null && appartement.isNotEmpty) {
        depensesSnapshot = await _firestore
            .collection('depenses')
            .where('beneficiaire', isEqualTo: appartement)
            .orderBy('date', descending: true)
            .get();
      } else {
        depensesSnapshot = await _firestore
            .collection('depenses')
            .orderBy('date', descending: true)
            .get();
      }

      // Convertir les données
      final List<Cotisation> cotisations = cotisationsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final id = data['id'] as int? ?? int.tryParse(doc.id) ?? 0;
        return Cotisation.fromFirestore(data, id);
      }).toList();

      // ⬇️ CORRECTION : Utiliser fromFirestore avec l'ID du document
      final List<Depense> depenses = depensesSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Depense.fromFirestore(data, doc.id);
      }).toList();

      // Calculer les totaux
      double totalCotisations = 0;
      for (var c in cotisations) {
        totalCotisations += c.montant;
      }

      double totalDepenses = 0;
      for (var d in depenses) {
        totalDepenses += d.montant;
      }

      double solde = totalCotisations - totalDepenses;

      return {
        'cotisations': cotisations,
        'depenses': depenses,
        'totalCotisations': totalCotisations,
        'totalDepenses': totalDepenses,
        'solde': solde,
        'nbCotisations': cotisations.length,
        'nbDepenses': depenses.length,
      };
    } catch (e) {
      print('❌ Erreur getReleveData: $e');
      return {};
    }
  }

  // ⬇️ GÉNÉRER LE CONTENU CSV
  String generateCSV(Map<String, dynamic> data) {
    final cotisations = data['cotisations'] as List<Cotisation>? ?? [];
    final depenses = data['depenses'] as List<Depense>? ?? [];
    final totalCotisations = data['totalCotisations'] ?? 0;
    final totalDepenses = data['totalDepenses'] ?? 0;
    final solde = data['solde'] ?? 0;

    StringBuffer csv = StringBuffer();

    // En-tête
    csv.writeln('RELEVÉ TRÉSOR');
    csv.writeln('Date: ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}');
    csv.writeln('');

    // Cotisations
    csv.writeln('=== COTISATIONS ===');
    csv.writeln('Appartement;Nom;Montant;Période;Année;Date Versement;Mode');
    for (var c in cotisations) {
      final periode = c.periode1 ? 'S1' : (c.periode2 ? 'S2' : '');
      csv.writeln('${c.numAppartement};${c.nomPrenom};${c.montant.toStringAsFixed(2)};$periode;${c.annee};${DateFormat('dd/MM/yyyy').format(c.dateVersement)};${c.modeTexte}');
    }
    csv.writeln('');
    csv.writeln('Total Cotisations: ${totalCotisations.toStringAsFixed(2)} DH');
    csv.writeln('');

    // Dépenses
    csv.writeln('=== DÉPENSES ===');
    csv.writeln('Titre;Catégorie;Montant;Bénéficiaire;Date;Statut;Mode');
    for (var d in depenses) {
      csv.writeln('${d.titre};${d.categorie};${d.montant.toStringAsFixed(2)};${d.beneficiaire};${DateFormat('dd/MM/yyyy').format(d.date)};${d.statut};${d.modePaiementTexte}');
    }
    csv.writeln('');
    csv.writeln('Total Dépenses: ${totalDepenses.toStringAsFixed(2)} DH');
    csv.writeln('');

    // Synthèse
    csv.writeln('=== SYNTHÈSE ===');
    csv.writeln('Total Cotisations: ${totalCotisations.toStringAsFixed(2)} DH');
    csv.writeln('Total Dépenses: ${totalDepenses.toStringAsFixed(2)} DH');
    csv.writeln('Solde: ${solde.toStringAsFixed(2)} DH');

    return csv.toString();
  }

  // ⬇️ GÉNÉRER LE CONTENU HTML (pour PDF)
  String generateHTML(Map<String, dynamic> data) {
    final cotisations = data['cotisations'] as List<Cotisation>? ?? [];
    final depenses = data['depenses'] as List<Depense>? ?? [];
    final totalCotisations = data['totalCotisations'] ?? 0;
    final totalDepenses = data['totalDepenses'] ?? 0;
    final solde = data['solde'] ?? 0;

    StringBuffer html = StringBuffer();

    html.writeln('''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        body { font-family: Arial, sans-serif; padding: 20px; }
        h1 { color: #1a237e; text-align: center; }
        h2 { color: #0d47a1; margin-top: 20px; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th { background-color: #1a237e; color: white; padding: 8px; text-align: left; }
        td { padding: 6px; border-bottom: 1px solid #ddd; }
        .total { font-weight: bold; font-size: 16px; }
        .solde-positive { color: green; }
        .solde-negative { color: red; }
        .summary { background-color: #e8eaf6; padding: 15px; border-radius: 8px; margin: 20px 0; }
        .header { text-align: center; border-bottom: 2px solid #1a237e; padding-bottom: 10px; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>🏢 RELEVÉ TRÉSOR</h1>
        <p>Date: ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}</p>
      </div>
    ''');

    // Cotisations
    html.writeln('<h2>📊 COTISATIONS</h2>');
    html.writeln('<table>');
    html.writeln('<tr><th>Appartement</th><th>Nom</th><th>Montant</th><th>Période</th><th>Année</th><th>Date Versement</th><th>Mode</th></tr>');
    for (var c in cotisations) {
      final periode = c.periode1 ? 'S1' : (c.periode2 ? 'S2' : '');
      html.writeln('<tr>');
      html.writeln('<td>${c.numAppartement}</td>');
      html.writeln('<td>${c.nomPrenom}</td>');
      html.writeln('<td>${c.montant.toStringAsFixed(2)} DH</td>');
      html.writeln('<td>$periode</td>');
      html.writeln('<td>${c.annee}</td>');
      html.writeln('<td>${DateFormat('dd/MM/yyyy').format(c.dateVersement)}</td>');
      html.writeln('<td>${c.modeTexte}</td>');
      html.writeln('</tr>');
    }
    html.writeln('</table>');
    html.writeln('<p class="total">Total Cotisations: ${totalCotisations.toStringAsFixed(2)} DH</p>');

    // Dépenses
    html.writeln('<h2>💳 DÉPENSES</h2>');
    html.writeln('<table>');
    html.writeln('<tr><th>Titre</th><th>Catégorie</th><th>Montant</th><th>Bénéficiaire</th><th>Date</th><th>Statut</th><th>Mode</th></tr>');
    for (var d in depenses) {
      html.writeln('<tr>');
      html.writeln('<td>${d.titre}</td>');
      html.writeln('<td>${d.categorie}</td>');
      html.writeln('<td>${d.montant.toStringAsFixed(2)} DH</td>');
      html.writeln('<td>${d.beneficiaire}</td>');
      html.writeln('<td>${DateFormat('dd/MM/yyyy').format(d.date)}</td>');
      html.writeln('<td>${d.statut}</td>');
      html.writeln('<td>${d.modePaiementTexte}</td>');
      html.writeln('</tr>');
    }
    html.writeln('</table>');
    html.writeln('<p class="total">Total Dépenses: ${totalDepenses.toStringAsFixed(2)} DH</p>');

    // Synthèse
    html.writeln('<div class="summary">');
    html.writeln('<h2>📈 SYNTHÈSE</h2>');
    html.writeln('<p class="total">Total Cotisations: ${totalCotisations.toStringAsFixed(2)} DH</p>');
    html.writeln('<p class="total">Total Dépenses: ${totalDepenses.toStringAsFixed(2)} DH</p>');
    html.writeln('<p class="total ${solde >= 0 ? 'solde-positive' : 'solde-negative'}">Solde: ${solde.toStringAsFixed(2)} DH</p>');
    html.writeln('</div>');

    html.writeln('</body></html>');

    return html.toString();
  }
}