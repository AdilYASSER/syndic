// lib/screens/annonces/demande_aide_screen.dart

import 'package:flutter/material.dart';
import '../../models/demande_aide_model.dart';
import '../../services/demande_aide_service.dart';

class DemandeAideScreen extends StatefulWidget {
  final String appartement;
  final String nomPrenom;
  final String telephone;
  final String createdBy;
  final DemandeAideModel? demandeAModifier; // ✅ si non-null → mode édition

  const DemandeAideScreen({
    super.key,
    required this.appartement,
    required this.nomPrenom,
    required this.telephone,
    required this.createdBy,
    this.demandeAModifier,
  });

  @override
  State<DemandeAideScreen> createState() => _DemandeAideScreenState();
}

class _DemandeAideScreenState extends State<DemandeAideScreen> {
  final _service = DemandeAideService();

  late final TextEditingController _objetCtrl;
  late final TextEditingController _descCtrl;
  String _urgence = 'moyenne';
  bool _isLoading = false;

  bool get isEditMode => widget.demandeAModifier != null;

  final List<Map<String, dynamic>> _urgences = [
    {'value': 'faible', 'label': '🟢 Faible', 'color': Colors.green},
    {'value': 'moyenne', 'label': '🟠 Moyenne', 'color': Colors.orange},
    {'value': 'eleve', 'label': '🔴 Élevé', 'color': Colors.red},
    {'value': 'critique', 'label': '🚨 Critique', 'color': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    _objetCtrl = TextEditingController(
      text: widget.demandeAModifier?.objet ?? '',
    );
    _descCtrl = TextEditingController(
      text: widget.demandeAModifier?.description ?? '',
    );
    _urgence = widget.demandeAModifier?.urgence ?? 'moyenne';
  }

  @override
  void dispose() {
    _objetCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Color _colorFor(String v) =>
      _urgences.firstWhere((u) => u['value'] == v)['color'] as Color;

  Future<void> _envoyer() async {
    if (_objetCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Veuillez saisir l\'objet'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (isEditMode) {
        // ✅ MODIFICATION
        await _service.updateDemande(
          widget.demandeAModifier!.id,
          objet: _objetCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          urgence: _urgence,
        );
      } else {
        // ✅ CRÉATION
        final demande = DemandeAideModel(
          id: '',
          objet: _objetCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          urgence: _urgence,
          appartement: widget.appartement,
          nomPrenom: widget.nomPrenom,
          telephone: widget.telephone,
          createdBy: widget.createdBy,
          dateCreation: DateTime.now(),
          luPar: [widget.createdBy], // ✅ l'auteur l'a déjà lue
        );
        await _service.ajouterDemande(demande);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditMode
              ? '✅ Demande modifiée'
              : '✅ Demande d\'aide envoyée'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode
            ? '✏️ Modifier la demande'
            : '🆘 Demande d\'aide'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📌 Objet de la demande *',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _objetCtrl,
              maxLength: 100,
              decoration: const InputDecoration(
                hintText: 'Ex: Fuite d\'eau, panne ascenseur...',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            const Text(
              '⚡ Degré d\'urgence *',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _urgences.map((u) {
                final selected = _urgence == u['value'];
                final color = u['color'] as Color;
                return GestureDetector(
                  onTap: () => setState(() => _urgence = u['value']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withOpacity(0.2)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? color : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      u['label'] as String,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                        color: selected ? color : Colors.grey.shade700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            const Text(
              '📝 Description (optionnel)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Décrivez le problème en détail...',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _envoyer,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(isEditMode ? Icons.save : Icons.send),
                label: Text(
                  _isLoading
                      ? 'Envoi...'
                      : (isEditMode
                          ? '💾 Enregistrer'
                          : '🆘 Envoyer la demande'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}