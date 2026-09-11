// lib/screens/repertoire/repertoire_satisfaction_screen.dart
import 'package:flutter/material.dart';
import '../../services/repertoire_service.dart';
import '../../models/repertoire_model.dart';

class RepertoireSatisfactionScreen extends StatefulWidget {
  final Personne personne;
  final String appartement;

  const RepertoireSatisfactionScreen({
    super.key,
    required this.personne,
    required this.appartement,
  });

  @override
  State<RepertoireSatisfactionScreen> createState() => _RepertoireSatisfactionScreenState();
}

class _RepertoireSatisfactionScreenState extends State<RepertoireSatisfactionScreen> {
  final RepertoireService _service = RepertoireService();
  final TextEditingController _commentaireController = TextEditingController();
  bool _satisfait = true;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📝 Donner votre avis'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.personne.prenom} ${widget.personne.nom}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '📞 ${widget.personne.telephone}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  if (widget.personne.adresse.isNotEmpty)
                    Text(
                      '📍 ${widget.personne.adresse}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Évaluez votre expérience :',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.thumb_up, size: 16, color: Colors.green),
                        SizedBox(width: 4),
                        Text('Satisfait'),
                      ],
                    ),
                    selected: _satisfait,
                    onSelected: (_) {
                      setState(() => _satisfait = true);
                    },
                    selectedColor: Colors.green.shade100,
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ChoiceChip(
                    label: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.thumb_down, size: 16, color: Colors.red),
                        SizedBox(width: 4),
                        Text('Insatisfait'),
                      ],
                    ),
                    selected: !_satisfait,
                    onSelected: (_) {
                      setState(() => _satisfait = false);
                    },
                    selectedColor: Colors.red.shade100,
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _commentaireController,
              decoration: const InputDecoration(
                labelText: 'Commentaire (optionnel)',
                hintText: 'Partagez votre expérience...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.comment),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _envoyerAvis,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '📤 Envoyer mon avis',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _envoyerAvis() async {
    setState(() => _isLoading = true);

    try {
      final commentaire = _commentaireController.text.trim();
      await _service.ajouterSatisfaction(
        widget.personne.id,
        _satisfait,
        commentaire.isNotEmpty ? commentaire : null,
      );

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Votre avis a été enregistré'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}