// lib/screens/repertoire/repertoire_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/repertoire_model.dart';
import '../../services/repertoire_service.dart';
import 'repertoire_satisfaction_screen.dart';

class RepertoirePersonnesScreen extends StatefulWidget {
  final String categorie;
  final String sousCategorie;
  final bool isAdmin;
  final String? appartement;

  const RepertoirePersonnesScreen({
    super.key,
    required this.categorie,
    required this.sousCategorie,
    required this.isAdmin,
    this.appartement,
  });

  @override
  State<RepertoirePersonnesScreen> createState() => _RepertoirePersonnesScreenState();
}

class _RepertoirePersonnesScreenState extends State<RepertoirePersonnesScreen> {
  final RepertoireService _service = RepertoireService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sousCategorie),
        backgroundColor: widget.isAdmin ? Colors.blue.shade800 : Colors.green.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<List<Personne>>(
        stream: _service.getPersonnesBySousCategorie(
          widget.categorie,
          widget.sousCategorie,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final personnes = snapshot.data!;
          if (personnes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('Aucune personne dans cette catégorie'),
                  const SizedBox(height: 8),
                  if (widget.isAdmin)
                    Text(
                      'Ajoutez une personne en cliquant sur +',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: personnes.length,
            itemBuilder: (context, index) {
              final personne = personnes[index];
              return _buildPersonneCard(personne);
            },
          );
        },
      ),
    );
  }

  Widget _buildPersonneCard(Personne personne) {
    final taux = personne.tauxSatisfaction;
    final couleurTaux = taux >= 80 ? Colors.green : taux >= 50 ? Colors.orange : Colors.red;

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
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    '${personne.prenom[0]}${personne.nom[0]}',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${personne.prenom} ${personne.nom}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            personne.telephone,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: couleurTaux.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: couleurTaux),
                  ),
                  child: Text(
                    '${taux.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: couleurTaux,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            if (personne.adresse.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.home, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      personne.adresse,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '✅ ${personne.satisfaits} satisfaits',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '❌ ${personne.insatisfaits} insatisfaits',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                if (!widget.isAdmin && widget.appartement != null)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RepertoireSatisfactionScreen(
                            personne: personne,
                            appartement: widget.appartement!,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.star, size: 16),
                    label: const Text('Noter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}