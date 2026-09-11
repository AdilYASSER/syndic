// lib/screens/client/client_ideas_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/idea_service.dart';
import '../../models/idea_model.dart';

class ClientIdeasScreen extends StatefulWidget {
  final String appartement;

  const ClientIdeasScreen({super.key, required this.appartement});

  @override
  State<ClientIdeasScreen> createState() => _ClientIdeasScreenState();
}

class _ClientIdeasScreenState extends State<ClientIdeasScreen> {
  final IdeaService _ideaService = IdeaService();
  final TextEditingController _ideeController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  
  DateTime _date = DateTime.now();
  // Supprimé DateTime _echeance = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _ideeController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _submitIdea() async {
    if (_ideeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Veuillez saisir votre idée'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final idea = IdeaModel(
        id: '',
        numAppart: widget.appartement,
        date: _date,
        ideeProposee: _ideeController.text.trim(),
        budgetPrevisionnel: _budgetController.text.trim(),
        createdAt: DateTime.now(),
        // Supprimé echeanceExecution: _echeance,
      );

      await _ideaService.createIdea(idea);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Idée déposée avec succès !'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate(DateTime initialDate, Function(DateTime) onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('💡 Banque d\'idées'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              initialValue: widget.appartement,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Numéro d\'appartement',
                prefixIcon: Icon(Icons.apartment),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date de dépôt'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_date)),
              onTap: () => _pickDate(_date, (picked) => setState(() => _date = picked)),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _ideeController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Idée proposée (texte) *',
                prefixIcon: Icon(Icons.lightbulb_outline),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) => (value == null || value.isEmpty) ? 'Veuillez saisir votre idée' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Budget prévisionnel (en DH) - cas échéant',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Suppression du ListTile pour Échéance d'exécution
            const SizedBox(height: 24),

            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submitIdea,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '💡 Déposer mon idée',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}