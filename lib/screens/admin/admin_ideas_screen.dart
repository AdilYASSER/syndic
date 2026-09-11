// lib/screens/admin/admin_ideas_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/idea_service.dart';
import '../../models/idea_model.dart';

class AdminIdeasScreen extends StatefulWidget {
  const AdminIdeasScreen({super.key});

  @override
  State<AdminIdeasScreen> createState() => _AdminIdeasScreenState();
}

class _AdminIdeasScreenState extends State<AdminIdeasScreen> {
  final IdeaService _ideaService = IdeaService();
  final TextEditingController _ideeController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _appartementController = TextEditingController();
  
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _ideeController.dispose();
    _budgetController.dispose();
    _appartementController.dispose();
    super.dispose();
  }

  // ✅ Méthode pour supprimer toutes les idées
  Future<void> _deleteAllIdeas() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Confirmation'),
        content: const Text('Voulez-vous supprimer TOUTES les idées ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer tout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _ideaService.deleteAllIdeas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Toutes les idées supprimées !'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ✅ Méthode pour supprimer une seule idée
  Future<void> _deleteOneIdea(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Confirmation'),
        content: const Text('Voulez-vous supprimer cette idée ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _ideaService.deleteIdea(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Idée supprimée !'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _openAddIdeaForm() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('💡 Déposer une idée (Admin)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _appartementController,
                decoration: const InputDecoration(
                  labelText: 'Numéro d\'appartement (ex: Admin)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ideeController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Idée proposée *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Budget prévisionnel (DH)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('Date de dépôt'),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(_date)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
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
                  numAppart: _appartementController.text.trim().isEmpty ? 'Admin' : _appartementController.text.trim(),
                  date: _date,
                  ideeProposee: _ideeController.text.trim(),
                  budgetPrevisionnel: _budgetController.text.trim(),
                  createdAt: DateTime.now(),
                );

                await _ideaService.createIdea(idea);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Idée déposée !'), backgroundColor: Colors.green),
                  );
                  // Réinitialiser les champs
                  _ideeController.clear();
                  _budgetController.clear();
                  _appartementController.clear();
                  setState(() => _date = DateTime.now());
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (context.mounted) setState(() => _isSaving = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
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
                : const Text('Déposer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('💡 Gestion des idées'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openAddIdeaForm,
            tooltip: 'Déposer une idée',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _deleteAllIdeas,
            tooltip: 'Supprimer tout',
          ),
        ],
      ),
      body: StreamBuilder<List<IdeaModel>>(
        stream: _ideaService.getAllIdeas(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('❌ Erreur: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final ideas = snapshot.data!;
          if (ideas.isEmpty) {
            return const Center(
              child: Text('Aucune idée déposée pour le moment'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: ideas.length,
            itemBuilder: (context, index) {
              final idea = ideas[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
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
                          Icon(Icons.lightbulb_outline, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Appartement: ${idea.numAppart}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy').format(idea.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(idea.ideeProposee, style: const TextStyle(fontSize: 15)),
                      if (idea.budgetPrevisionnel.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Budget prévisionnel: ${idea.budgetPrevisionnel} DH',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteOneIdea(idea.id),
                          tooltip: 'Supprimer cette idée',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}