// lib/screens/vote_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/vote_model.dart';
import '../services/vote_service.dart';

class VoteEditScreen extends StatefulWidget {
  final VoteModel vote;

  const VoteEditScreen({super.key, required this.vote});

  @override
  State<VoteEditScreen> createState() => _VoteEditScreenState();
}

class _VoteEditScreenState extends State<VoteEditScreen> {
  final VoteService _service = VoteService();
  final TextEditingController _titreController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [];
  
  late DateTime _dateDebut;
  late DateTime _dateFin;
  late TimeOfDay _timeDebut;
  late TimeOfDay _timeFin;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titreController.text = widget.vote.titre;
    _descriptionController.text = widget.vote.description;
    _dateDebut = widget.vote.dateDebut;
    _dateFin = widget.vote.dateFin;
    _timeDebut = TimeOfDay.fromDateTime(widget.vote.dateDebut);
    _timeFin = TimeOfDay.fromDateTime(widget.vote.dateFin);
    
    for (var option in widget.vote.options) {
      _optionControllers.add(TextEditingController(text: option));
    }
  }

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Minimum 2 options'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  Future<void> _selectDateDebut() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateDebut,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() {
        _dateDebut = date;
        if (_dateFin.isBefore(_dateDebut)) {
          _dateFin = _dateDebut.add(const Duration(days: 7));
        }
      });
    }
  }

  Future<void> _selectDateFin() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateFin,
      firstDate: _dateDebut,
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() {
        _dateFin = date;
      });
    }
  }

  Future<void> _selectTimeDebut() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _timeDebut,
    );
    if (time != null) {
      setState(() {
        _timeDebut = time;
      });
    }
  }

  Future<void> _selectTimeFin() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _timeFin,
    );
    if (time != null) {
      setState(() {
        _timeFin = time;
      });
    }
  }

  Future<void> _submitEdit() async {
    if (_titreController.text.isEmpty) {
      _showSnackBar('⚠️ Veuillez saisir un titre', Colors.orange);
      return;
    }

    if (_descriptionController.text.isEmpty) {
      _showSnackBar('⚠️ Veuillez saisir une description', Colors.orange);
      return;
    }

    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (options.length < 2) {
      _showSnackBar('⚠️ Ajoutez au moins 2 options valides', Colors.orange);
      return;
    }

    final dateDebut = DateTime(
      _dateDebut.year,
      _dateDebut.month,
      _dateDebut.day,
      _timeDebut.hour,
      _timeDebut.minute,
    );
    final dateFin = DateTime(
      _dateFin.year,
      _dateFin.month,
      _dateFin.day,
      _timeFin.hour,
      _timeFin.minute,
    );

    if (dateFin.isBefore(dateDebut)) {
      _showSnackBar('⚠️ La date de fin doit être après la date de début', Colors.orange);
      return;
    }

    String statut;
    final now = DateTime.now();
    if (dateDebut.isAfter(now)) {
      statut = 'a_venir';
    } else if (dateFin.isBefore(now)) {
      statut = 'termine';
    } else {
      statut = 'en_cours';
    }

    setState(() => _isLoading = true);

    try {
      final updatedVote = VoteModel(
        id: widget.vote.id,
        titre: _titreController.text,
        description: _descriptionController.text,
        options: options,
        votes: widget.vote.votes,
        dateDebut: dateDebut,
        dateFin: dateFin,
        statut: statut,
        createdBy: widget.vote.createdBy,
        createdAt: widget.vote.createdAt,
        totalVotes: widget.vote.totalVotes,
      );

      // Mettre à jour dans Firestore
      await _service.updateVote(widget.vote.id, updatedVote);

      setState(() => _isLoading = false);

      if (mounted) {
        _showSnackBar('✅ Vote modifié avec succès', Colors.green);
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('❌ Erreur: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('✏️ Modifier le vote'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
            TextField(
              controller: _titreController,
              decoration: const InputDecoration(
                labelText: 'Titre du vote *',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description *',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Date début
            _buildDatePicker(
              label: '📅 Date de début *',
              date: _dateDebut,
              time: _timeDebut,
              onDateTap: _selectDateDebut,
              onTimeTap: _selectTimeDebut,
            ),
            const SizedBox(height: 12),

            // Date fin
            _buildDatePicker(
              label: '📅 Date de fin *',
              date: _dateFin,
              time: _timeFin,
              onDateTap: _selectDateFin,
              onTimeTap: _selectTimeFin,
            ),
            const SizedBox(height: 16),

            // Options
            const Text(
              '📝 Options de vote *',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ..._optionControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'Option ${index + 1}',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: (value) {
                          if (value.isNotEmpty && index == _optionControllers.length - 1) {
                            _addOption();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.remove_circle,
                        color: Colors.red.shade400,
                      ),
                      onPressed: () => _removeOption(index),
                    ),
                  ],
                ),
              );
            }).toList(),
            TextButton.icon(
              onPressed: _addOption,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une option'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.purple.shade700,
              ),
            ),
            const SizedBox(height: 24),

            // Boutons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitEdit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                            '💾 Enregistrer',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
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
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime date,
    required TimeOfDay time,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onDateTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd/MM/yyyy').format(date),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: onTimeTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          time.format(context),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}