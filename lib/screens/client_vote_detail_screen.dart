// lib/screens/client_vote_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/vote_model.dart';
import '../services/vote_service.dart';

class ClientVoteDetailScreen extends StatefulWidget {
  final VoteModel vote;
  final String appartement;
  final bool isTermine;

  const ClientVoteDetailScreen({
    super.key,
    required this.vote,
    required this.appartement,
    this.isTermine = false,
  });

  @override
  State<ClientVoteDetailScreen> createState() => _ClientVoteDetailScreenState();
}

class _ClientVoteDetailScreenState extends State<ClientVoteDetailScreen> {
  final VoteService _service = VoteService();
  late VoteModel _voteModel;
  bool _isVoting = false;
  String? _selectedOption;

  @override
  void initState() {
    super.initState();
    _voteModel = widget.vote;
    _selectedOption = _voteModel.getVotedOption(widget.appartement);
  }

  Future<void> _voteAction(String option) async {
    if (_voteModel.hasVoted(widget.appartement)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Vous avez déjà voté'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isVoting = true);

    try {
      await _service.vote(_voteModel.id, option, widget.appartement);
      
      final updatedVote = await _service.getVoteById(_voteModel.id);
      if (updatedVote != null) {
        setState(() {
          _voteModel = updatedVote;
          _selectedOption = option;
          _isVoting = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Vote enregistré avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isVoting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.teal];
    final aVote = _voteModel.hasVoted(widget.appartement);
    final canVote = _voteModel.isEnCours && !aVote && !widget.isTermine;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _voteModel.titre,
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statut
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _voteModel.statutColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _voteModel.statutColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    _voteModel.isEnCours
                        ? Icons.how_to_vote
                        : _voteModel.isTermine
                            ? Icons.check_circle
                            : Icons.schedule,
                    color: _voteModel.statutColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _voteModel.statutText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _voteModel.statutColor,
                          ),
                        ),
                        Text(
                          '🗳️ ${_voteModel.totalVotes} vote(s)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (aVote) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '✅ Vous avez voté pour: $_selectedOption',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📝 Description',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _voteModel.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Dates
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📅 Période',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.calendar_today,
                      'Début',
                      DateFormat('dd/MM/yyyy à HH:mm').format(_voteModel.dateDebut),
                    ),
                    _buildInfoRow(
                      Icons.calendar_today,
                      'Fin',
                      DateFormat('dd/MM/yyyy à HH:mm').format(_voteModel.dateFin),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Options de vote
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canVote ? '📝 Choisissez votre option' : '📊 Résultats',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (canVote)
                      ..._voteModel.options.map((option) {
                        final isSelected = _selectedOption == option;
                        return RadioListTile<String>(
                          title: Text(option),
                          value: option,
                          groupValue: _selectedOption,
                          onChanged: (value) {
                            setState(() {
                              _selectedOption = value;
                            });
                          },
                          activeColor: Colors.purple.shade700,
                          tileColor: isSelected ? Colors.purple.shade50 : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }).toList(),
                    if (canVote) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isVoting || _selectedOption == null
                              ? null
                              : () => _voteAction(_selectedOption!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isVoting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '🗳️ Voter',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                    if (!canVote && _voteModel.totalVotes > 0)
                      ..._voteModel.options.asMap().entries.map((entry) {
                        final index = entry.key;
                        final option = entry.value;
                        final count = _voteModel.getVotesCount(option);
                        final pourcentage = _voteModel.totalVotes > 0
                            ? (count / _voteModel.totalVotes) * 100
                            : 0;

                        final isVotedOption = _selectedOption == option;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        option,
                                        style: TextStyle(
                                          fontWeight: isVotedOption
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isVotedOption
                                              ? Colors.purple.shade700
                                              : null,
                                        ),
                                      ),
                                      if (isVotedOption) ...[
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.purple,
                                          size: 16,
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    '$count voix (${pourcentage.toStringAsFixed(1)}%)',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: FractionallySizedBox(
                                  widthFactor: pourcentage / 100,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isVotedOption
                                          ? Colors.purple.shade700
                                          : colors[index % colors.length],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${pourcentage.toStringAsFixed(0)}%',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    if (!canVote && _voteModel.totalVotes == 0)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Aucun vote pour le moment',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ✅ TABLEAU DES VOTANTS (CLIENT)
            if (_voteModel.totalVotes > 0) ...[
              const SizedBox(height: 16),
              _buildVotersTable(),
            ],
          ],
        ),
      ),
    );
  }

  // ✅ TABLEAU DES VOTANTS
  Widget _buildVotersTable() {
    final allVoters = _voteModel.getAllVotersWithChoice();
    final votersList = allVoters.keys.toList();

    if (votersList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '👥 Participants',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_voteModel.totalVotes} participant(s)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // En-tête du tableau
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      '#',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Appartement',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Vote',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Liste des votants
            ...votersList.asMap().entries.map((entry) {
              final index = entry.key;
              final appartement = entry.value;
              final choix = allVoters[appartement] ?? 'Inconnu';
              final isPour = choix.toLowerCase() == 'pour';

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        appartement,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isPour
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          choix,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isPour
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
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