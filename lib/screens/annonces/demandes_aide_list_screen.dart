// lib/screens/annonces/demandes_aide_list_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/demande_aide_model.dart';
import '../../services/demande_aide_service.dart';
import 'demande_aide_screen.dart';

class DemandesAideListScreen extends StatefulWidget {
  final bool isAdmin;
  final String userId;
  final String appartement;
  final String nomPrenom;
  final String telephone;

  const DemandesAideListScreen({
    super.key,
    required this.userId,
    required this.appartement,
    this.nomPrenom = '',
    this.telephone = '',
    this.isAdmin = false,
  });

  @override
  State<DemandesAideListScreen> createState() =>
      _DemandesAideListScreenState();
}

class _DemandesAideListScreenState extends State<DemandesAideListScreen> {
  final _service = DemandeAideService();

  Color _urgenceColor(String u) {
    switch (u) {
      case 'critique':
        return Colors.purple;
      case 'eleve':
        return Colors.red;
      case 'moyenne':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  Color _statutColor(String s) {
    switch (s) {
      case 'resolu':
        return Colors.green;
      case 'en_cours':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  // ============================================================
  // ✅ OUVRIR UNE DEMANDE (et la marquer comme LUE)
  // ============================================================
  Future<void> _ouvrirDemande(DemandeAideModel d) async {
    // ✅ Marquer comme LUE → l'ampoule s'éteint automatiquement
    if (!d.luPar.contains(widget.userId)) {
      await _service.marquerCommeLu(d.id, widget.userId);
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(d.objet),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('👤 ${d.nomPrenom} • Appt ${d.appartement}'),
              const SizedBox(height: 6),
              Text('⚡ Urgence: ${d.urgenceLabel}'),
              const SizedBox(height: 6),
              Text('📊 Statut: ${d.statutLabel}'),
              const SizedBox(height: 6),
              Text(
                '📅 ${DateFormat('dd/MM/yyyy HH:mm').format(d.dateCreation)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (d.description.isNotEmpty) ...[
                const Divider(),
                Text(d.description),
              ],
              if (d.reponse != null && d.reponse!.isNotEmpty) ...[
                const Divider(),
                Text('💬 Réponse: ${d.reponse}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ CRÉER UNE NOUVELLE DEMANDE (via FAB)
  // ============================================================
  Future<void> _creerNouvelleDemande() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DemandeAideScreen(
          appartement: widget.appartement,
          nomPrenom: widget.nomPrenom,
          telephone: widget.telephone,
          createdBy: widget.userId,
        ),
      ),
    );
    if (result == true) setState(() {});
  }

  Future<void> _modifier(DemandeAideModel d) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DemandeAideScreen(
          appartement: d.appartement,
          nomPrenom: widget.nomPrenom,
          telephone: widget.telephone,
          createdBy: widget.userId,
          demandeAModifier: d,
        ),
      ),
    );
    if (result == true) setState(() {});
  }

  Future<void> _supprimer(DemandeAideModel d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer la demande "${d.objet}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true) await _service.supprimerDemande(d.id);
  }

  Future<void> _changerStatut(DemandeAideModel d, String statut) async {
    final reponseCtrl = TextEditingController(text: d.reponse ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Marquer comme "$statut" ?'),
        content: TextField(
          controller: reponseCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Réponse / commentaire (optionnel)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.updateDemande(
        d.id,
        statut: statut,
        reponse: reponseCtrl.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAdmin
            ? '🆘 Demandes d\'aide'
            : '🆘 Mes demandes d\'aide'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<DemandeAideModel>>(
        stream: _service.getAllDemandes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final demandes = snapshot.data ?? [];
          if (demandes.isEmpty) {
            return const Center(
              child: Text(
                'Aucune demande d\'aide pour le moment\n\n'
                'Appuyez sur ➕ pour créer une demande',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: demandes.length,
            itemBuilder: (context, i) {
              final d = demandes[i];
              final nonLue = !d.luPar.contains(widget.userId);

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: nonLue ? 4 : 2,
                color: nonLue ? Colors.yellow.shade50 : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: nonLue
                        ? Colors.amber.shade600
                        : _urgenceColor(d.urgence).withOpacity(0.4),
                    width: nonLue ? 2 : 1.5,
                  ),
                ),
                child: InkWell(
                  onTap: () => _ouvrirDemande(d),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (nonLue)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade200,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.lightbulb,
                                  size: 16,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            if (nonLue) const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _urgenceColor(d.urgence)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _urgenceColor(d.urgence),
                                ),
                              ),
                              child: Text(
                                d.urgenceLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _urgenceColor(d.urgence),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    _statutColor(d.statut).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                d.statutLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _statutColor(d.statut),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat('dd/MM/yy HH:mm')
                                  .format(d.dateCreation),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          d.objet,
                          style: TextStyle(
                            fontWeight: nonLue
                                ? FontWeight.w900
                                : FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (d.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            d.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${d.nomPrenom} • Appt ${d.appartement}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        if (d.reponse != null && d.reponse!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.reply,
                                    size: 14, color: Colors.blue.shade700),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    d.reponse!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (d.statut == 'en_attente')
                              TextButton.icon(
                                icon: const Icon(Icons.play_arrow, size: 16),
                                label: const Text('En cours',
                                    style: TextStyle(fontSize: 11)),
                                onPressed: () =>
                                    _changerStatut(d, 'en_cours'),
                              ),
                            if (d.statut != 'resolu')
                              TextButton.icon(
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Résolu',
                                    style: TextStyle(fontSize: 11)),
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.green),
                                onPressed: () => _changerStatut(d, 'resolu'),
                              ),
                            IconButton(
                              tooltip: 'Modifier',
                              icon: const Icon(Icons.edit,
                                  color: Colors.blue, size: 18),
                              onPressed: () => _modifier(d),
                            ),
                            IconButton(
                              tooltip: 'Supprimer',
                              icon: const Icon(Icons.delete,
                                  color: Colors.red, size: 18),
                              onPressed: () => _supprimer(d),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      // ✅ FAB : Créer une nouvelle demande d'aide
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        onPressed: _creerNouvelleDemande,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle demande'),
      ),
    );
  }
}