// lib/screens/reclamation_detail_client_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/reclamation_model.dart';
import '../services/reclamation_service.dart'; // ✅ AJOUTÉ

class ReclamationDetailClientScreen extends StatelessWidget {
  final ReclamationModel reclamation;

  const ReclamationDetailClientScreen({
    super.key,
    required this.reclamation,
  });

  Future<void> _viewImage(String url) async {
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      // Gérer l'erreur
    }
  }

  Future<void> _marquerResolu(BuildContext context) async {
    try {
      final service = ReclamationService();
      await service.updateStatut(reclamation.id, 'resolu');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Réclamation marquée comme résolue'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = reclamation;
    final hasReponse = r.reponseAdmin != null && r.reponseAdmin!.isNotEmpty;
    final isResolu = r.statut == 'resolu';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          r.titre,
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.deepOrange.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statut et priorité
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: r.statutColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: r.statutColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    r.statut == 'resolu' ? Icons.check_circle : Icons.pending,
                    color: r.statutColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.statutText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: r.statutColor,
                          ),
                        ),
                        Text(
                          'Priorité: ${r.prioriteText}',
                          style: TextStyle(
                            fontSize: 14,
                            color: r.prioriteColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Informations de la réclamation
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 Détails de la réclamation',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(
                      Icons.category,
                      'Catégorie',
                      r.categorie,
                    ),
                    _buildInfoRow(
                      Icons.calendar_today,
                      'Date de création',
                      DateFormat('dd/MM/yyyy à HH:mm').format(r.dateCreation),
                    ),
                    if (r.dateResolution != null)
                      _buildInfoRow(
                        Icons.check_circle,
                        'Résolu le',
                        DateFormat('dd/MM/yyyy à HH:mm').format(r.dateResolution!),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      '📝 Description',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      r.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    if (r.photoUrl != null) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => _viewImage(r.photoUrl!),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.image, color: Colors.blue),
                              const SizedBox(width: 8),
                              const Text('Voir la photo jointe'),
                              const Spacer(),
                              const Icon(Icons.open_in_new, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Réponse de l'admin
            if (hasReponse) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.reply, color: Colors.green),
                          const SizedBox(width: 8),
                          const Text(
                            '📌 Réponse de l\'administrateur',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          if (r.dateReponse != null)
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(r.dateReponse!),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        r.reponseAdmin!,
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (r.reponsePhotoUrl != null) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => _viewImage(r.reponsePhotoUrl!),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.image, color: Colors.blue),
                                const SizedBox(width: 8),
                                const Text('Voir la photo de réponse'),
                                const Spacer(),
                                const Icon(Icons.open_in_new, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Boutons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Retour'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (!isResolu && hasReponse)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _marquerResolu(context);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Marquer résolu'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}