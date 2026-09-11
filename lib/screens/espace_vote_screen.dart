// lib/screens/espace_vote_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EspaceVoteScreen extends StatefulWidget {
  const EspaceVoteScreen({super.key});

  @override
  State<EspaceVoteScreen> createState() => _EspaceVoteScreenState();
}

class _EspaceVoteScreenState extends State<EspaceVoteScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _votes = [];
  List<String> _allAppartements = [];
  
  // ✅ FORCER LE NOMBRE TOTAL D'APPARTEMENTS À 128
  final int _totalAppartements = 128;
  
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _errorMessage;
  String? _currentUserAppartement;
  Set<String> _processingVotes = {};

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadAllAppartements();
    _loadVotes();
    _listenToVotes();
  }

  void _listenToVotes() {
    _firestore.collection('votes').snapshots().listen((snapshot) {
      if (mounted) {
        _loadVotes();
      }
    });
  }

  // ✅ Charger tous les appartements
  Future<void> _loadAllAppartements() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      final appartements = snapshot.docs
          .map((doc) => doc.data()['appartement']?.toString() ?? '')
          .where((app) => app.isNotEmpty)
          .toList()
        ..sort();
      
      setState(() {
        _allAppartements = appartements;
        // ✅ Le total reste 128 quoi qu'il arrive
      });
      
      print('📊 Total appartements (FORCÉ): $_totalAppartements');
      print('📊 Appartements trouvés dans Firestore: ${_allAppartements.length}');
    } catch (e) {
      print('❌ Erreur chargement appartements: $e');
      // ✅ Garder 128 en cas d'erreur
      setState(() {
        _allAppartements = List.generate(128, (i) => '${i + 1}');
      });
    }
  }

  Future<void> _checkUserRole() async {
    try {
      final userId = _auth.currentUser?.uid;
      print('👤 User ID: $userId');
      
      setState(() {
        _isAdmin = true;
        _currentUserAppartement = 'Admin';
      });
      
      print('✅ Mode admin FORCÉ: $_isAdmin');
      
    } catch (e) {
      print('❌ Erreur vérification rôle: $e');
    }
  }

  Future<void> _loadVotes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final snapshot = await _firestore.collection('votes').get();

      setState(() {
        _votes = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          List<String> options = [];
          if (data['options'] != null && data['options'] is List) {
            options = List<String>.from(data['options']);
          }
          
          Map<String, List<String>> votesWithVoters = {};
          if (data['votes'] != null && data['votes'] is Map) {
            final votesData = data['votes'] as Map;
            votesData.forEach((key, value) {
              if (value is List) {
                votesWithVoters[key.toString()] = value.map((e) => e.toString()).toList();
              } else {
                votesWithVoters[key.toString()] = [];
              }
            });
          }
          
          Map<String, int> votesCount = {};
          int totalVotes = 0;
          votesWithVoters.forEach((key, value) {
            votesCount[key] = value.length;
            totalVotes += value.length;
          });
          
          String statut = data['statut'] ?? 'En cours';
          
          DateTime? dateDebut;
          DateTime? dateFin;
          DateTime? createdAt;
          
          if (data['dateDebut'] != null && data['dateDebut'] is Timestamp) {
            dateDebut = (data['dateDebut'] as Timestamp).toDate();
          }
          if (data['dateFin'] != null && data['dateFin'] is Timestamp) {
            dateFin = (data['dateFin'] as Timestamp).toDate();
          }
          if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
            createdAt = (data['createdAt'] as Timestamp).toDate();
          }
          
          if (statut == 'En cours' && dateFin != null && dateFin.isBefore(DateTime.now())) {
            statut = 'Terminé';
          }

          return {
            'id': doc.id,
            'titre': data['titre'] ?? 'Sans titre',
            'description': data['description'] ?? '',
            'statut': statut,
            'dateDebut': dateDebut,
            'dateFin': dateFin,
            'options': options,
            'votesWithVoters': votesWithVoters,
            'votesCount': votesCount,
            'totalVotes': totalVotes,
            'createdAt': createdAt ?? DateTime.now(),
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _castVote(Map<String, dynamic> vote, String option) async {
    if (_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ℹ️ Les administrateurs ne peuvent pas voter'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_currentUserAppartement == null || _currentUserAppartement!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Appartement non trouvé'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (vote['statut'] != 'En cours') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Ce vote est terminé, vous ne pouvez plus voter'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final votesWithVoters = vote['votesWithVoters'] ?? {};
    final hasVoted = vote['options'].any((option) => 
      votesWithVoters[option]?.contains(_currentUserAppartement) ?? false
    );

    if (hasVoted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Vous avez déjà voté pour ce scrutin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_processingVotes.contains(vote['id'])) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗳️ Confirmation de vote'),
        content: Text(
          'Voulez-vous vraiment voter pour : "$option" ?\n\n⚠️ Ce vote est définitif et ne pourra pas être modifié.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _processingVotes.add(vote['id']);
    });

    try {
      final docRef = _firestore.collection('votes').doc(vote['id']);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Le vote n\'existe plus');
        }

        final data = snapshot.data() as Map<String, dynamic>;
        
        Map<String, List<String>> votesMap = {};
        final votesData = data['votes'] as Map? ?? {};
        votesData.forEach((key, value) {
          if (value is List) {
            votesMap[key.toString()] = value.map((e) => e.toString()).toList();
          } else {
            votesMap[key.toString()] = [];
          }
        });
        
        bool alreadyVoted = false;
        for (var voters in votesMap.values) {
          if (voters.contains(_currentUserAppartement)) {
            alreadyVoted = true;
            break;
          }
        }
        
        if (alreadyVoted) {
          throw Exception('Vous avez déjà voté pour ce scrutin');
        }
        
        if (!votesMap.containsKey(option)) {
          votesMap[option] = [];
        }
        votesMap[option]!.add(_currentUserAppartement!);
        
        int total = 0;
        for (var list in votesMap.values) {
          total += list.length;
        }
        
        transaction.update(docRef, {
          'votes': votesMap,
          'totalVotes': total,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Vote enregistré avec succès !'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      
      _loadVotes();

    } catch (e) {
      String errorMessage = '❌ Erreur lors du vote';
      if (e.toString().contains('déjà voté')) {
        errorMessage = '❌ Vous avez déjà voté pour ce scrutin';
      } else if (e.toString().contains('n\'existe plus')) {
        errorMessage = '❌ Ce vote n\'existe plus';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _processingVotes.remove(vote['id']);
      });
    }
  }

  Future<void> _deleteVote(Map<String, dynamic> vote) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut supprimer'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Confirmation de suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer le vote : "${vote['titre']}" ?\n\nCette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('votes').doc(vote['id']).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Vote supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _createVote() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut créer un vote'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final TextEditingController titreController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController optionsController = TextEditingController();
    DateTime selectedDateDebut = DateTime.now();
    DateTime selectedDateFin = DateTime.now().add(const Duration(days: 7));

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('🗳️ Créer un vote'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titreController,
                    decoration: const InputDecoration(
                      labelText: 'Titre *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: optionsController,
                    decoration: const InputDecoration(
                      labelText: 'Options (séparées par des virgules) *',
                      hintText: 'Ex: Oui, Non, Peut-être',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDateDebut,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDateDebut = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date de début',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(DateFormat('dd/MM/yyyy').format(selectedDateDebut)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDateFin,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDateFin = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date de fin',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(DateFormat('dd/MM/yyyy').format(selectedDateFin)),
                          ),
                        ),
                      ),
                    ],
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
                  if (titreController.text.isEmpty || optionsController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ Titre et options sont obligatoires'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final options = optionsController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();

                  if (options.length < 2) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ Au moins 2 options sont nécessaires'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  try {
                    Map<String, List<String>> initialVotes = {};
                    for (var option in options) {
                      initialVotes[option] = [];
                    }

                    await _firestore.collection('votes').add({
                      'titre': titreController.text,
                      'description': descriptionController.text,
                      'options': options,
                      'votes': initialVotes,
                      'statut': 'En cours',
                      'dateDebut': Timestamp.fromDate(selectedDateDebut),
                      'dateFin': Timestamp.fromDate(selectedDateFin),
                      'createdAt': Timestamp.now(),
                      'createdBy': 'admin',
                      'totalVotes': 0,
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Vote créé avec succès'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: const Text('Créer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getStatusColor(String statut) {
    switch (statut) {
      case 'Terminé': return Colors.green;
      case 'En cours': return Colors.blue;
      case 'Annulé': return Colors.red;
      default: return Colors.orange;
    }
  }

  List<Map<String, String>> _getParticipantsList(Map<String, dynamic> vote) {
    final votesWithVoters = vote['votesWithVoters'] ?? {};
    final participants = <Map<String, String>>[];
    
    votesWithVoters.forEach((option, voters) {
      if (voters is List) {
        for (var voter in voters) {
          participants.add({
            'appartement': voter.toString(),
            'vote': option,
          });
        }
      }
    });
    
    participants.sort((a, b) {
      final numA = int.tryParse(a['appartement']?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
      final numB = int.tryParse(b['appartement']?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
      return numA.compareTo(numB);
    });
    
    return participants;
  }

  // ✅ Graphique en barres
  Widget _buildBarChart(Map<String, dynamic> vote) {
    final List<String> options = vote['options'] ?? [];
    final Map<String, int> votesCount = vote['votesCount'] ?? {};
    final int totalVotes = vote['totalVotes'] ?? 0;
    
    if (totalVotes == 0) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('Aucun vote enregistré', style: TextStyle(fontSize: 12)),
      );
    }

    final int maxVotes = options.map((opt) => votesCount[opt] ?? 0).reduce((a, b) => a > b ? a : b);
    const double maxHeight = 120.0;

    final List<Widget> barWidgets = [];

    for (var option in options) {
      final int count = votesCount[option] ?? 0;
      final double percentage = totalVotes > 0 ? (count / totalVotes * 100) : 0;
      final double height = maxVotes > 0 ? (count / maxVotes * maxHeight) : 0;
      
      final Color color = option.toLowerCase().contains('oui') 
          ? Colors.green 
          : option.toLowerCase().contains('non') 
              ? Colors.red 
              : Colors.blue;

      barWidgets.add(
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$count',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 40,
              height: height,
              decoration: BoxDecoration(
                color: color.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              option,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📊 Graphique comparatif',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: barWidgets,
          ),
        ),
      ],
    );
  }

  // ✅ Synthèse avec TOTAL FORCÉ À 128
  Widget _buildSynthesis(Map<String, dynamic> vote) {
    final List<String> options = vote['options'] ?? [];
    final Map<String, int> votesCount = vote['votesCount'] ?? {};
    final int totalVotes = vote['totalVotes'] ?? 0;
    
    // ✅ UTILISER DIRECTEMENT 128
    final int totalAppartements = 128;
    final double participationRate = (totalVotes / totalAppartements * 100);

    // ✅ Trouver le gagnant ou égalité
    String? winner;
    int maxVotes = 0;
    bool isTie = false;
    int equalCount = 0;
    
    for (var option in options) {
      final int count = votesCount[option] ?? 0;
      if (count > maxVotes) {
        maxVotes = count;
        winner = option;
        isTie = false;
        equalCount = 1;
      } else if (count == maxVotes && count > 0) {
        equalCount++;
        if (equalCount >= 2) {
          isTie = true;
        }
      }
    }

    // Résultat
    String resultText;
    if (totalVotes == 0) {
      resultText = 'Aucun vote';
    } else if (isTie || equalCount >= 2) {
      resultText = '⚖️ Égalité';
    } else {
      resultText = '🏆 $winner';
    }

    final List<Widget> synthesisRows = [];

    synthesisRows.add(_buildSynthesisRow('📊 Total des votes', '$totalVotes'));
    synthesisRows.add(_buildSynthesisRow('🏢 Taux de participation', 
        '${participationRate.toStringAsFixed(1)}% ($totalVotes/$totalAppartements)'));
    synthesisRows.add(_buildSynthesisRow('🏆 Résultat', resultText));
    
    if (!isTie && maxVotes > 0 && totalVotes > 0) {
      synthesisRows.add(_buildSynthesisRow('📈 Votes gagnants', '$maxVotes voix'));
    }
    
    for (var option in options) {
      final int count = votesCount[option] ?? 0;
      final double percentage = totalVotes > 0 ? (count / totalVotes * 100) : 0;
      
      final bool isWinner = !isTie && option == winner && maxVotes > 0 && totalVotes > 0;
      
      final Color textColor = option.toLowerCase().contains('oui') 
          ? Colors.green.shade700
          : option.toLowerCase().contains('non') 
              ? Colors.red.shade700
              : Colors.black87;
      
      synthesisRows.add(
        _buildSynthesisRow(
          '${isWinner ? '⭐ ' : ''}${option}',
          '$count voix (${percentage.toStringAsFixed(1)}%)${isWinner ? ' 🏆' : ''}',
          isWinner: isWinner,
          textColor: textColor,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📋 Synthèse des résultats',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ...synthesisRows,
        ],
      ),
    );
  }

  Widget _buildSynthesisRow(String label, String value, {bool isWinner = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isWinner ? Colors.green.shade700 : Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
              color: textColor ?? (isWinner ? Colors.green.shade700 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isAdmin ? '🗳️ Administration des votes' : '🗳️ Espace Vote'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _isAdmin ? Colors.amber : Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _isAdmin ? '👑 ADMIN' : '👤 CLIENT',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _createVote,
              tooltip: 'Créer un vote',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVotes,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur de chargement',
                        style: TextStyle(fontSize: 18, color: Colors.red.shade700),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadVotes,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _votes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.how_to_vote, size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun vote disponible',
                            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                          ),
                          if (_isAdmin) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Cliquez sur + pour créer un vote',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: _votes.length,
                      itemBuilder: (context, index) {
                        final Map<String, dynamic> vote = _votes[index];
                        final Color statusColor = _getStatusColor(vote['statut']);
                        final int totalVotes = vote['totalVotes'] ?? 0;
                        final List<String> options = vote['options'] ?? [];
                        final Map<String, List<String>> votesWithVoters = vote['votesWithVoters'] ?? {};
                        final Map<String, int> votesCount = vote['votesCount'] ?? {};
                        final DateTime? dateDebut = vote['dateDebut'];
                        final DateTime? dateFin = vote['dateFin'];

                        final bool hasVoted = !_isAdmin && _currentUserAppartement != null && 
                            options.any((option) => 
                              votesWithVoters[option]?.contains(_currentUserAppartement) ?? false
                            );
                        final String votedOption = hasVoted ? options.firstWhere(
                          (option) => votesWithVoters[option]?.contains(_currentUserAppartement) ?? false,
                          orElse: () => '',
                        ) : '';

                        final bool isProcessing = _processingVotes.contains(vote['id']);

                        // ✅ Construire la liste des options
                        final List<Widget> optionWidgets = [];
                        
                        for (var option in options) {
                          final int count = votesCount[option] ?? 0;
                          final double percentage = totalVotes > 0 ? (count / totalVotes * 100) : 0;
                          final List<String> voters = votesWithVoters[option] ?? [];
                          
                          final bool canVote = !_isAdmin && 
                              vote['statut'] == 'En cours' && 
                              !hasVoted && 
                              !isProcessing;

                          final Color optionColor = option.toLowerCase().contains('oui') 
                              ? Colors.green.shade700
                              : option.toLowerCase().contains('non') 
                                  ? Colors.red.shade700
                                  : Colors.black87;

                          optionWidgets.add(
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
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
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                              color: optionColor,
                                            ),
                                          ),
                                          if (!_isAdmin && votedOption == option)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 6),
                                              child: Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                                size: 16,
                                              ),
                                            ),
                                          if (!_isAdmin && hasVoted && votedOption == option)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 4),
                                              child: Text(
                                                '(votre vote)',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            '$count voix (${percentage.toStringAsFixed(1)}%)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                              color: optionColor,
                                            ),
                                          ),
                                          if (canVote) ...[
                                            const SizedBox(width: 6),
                                            ElevatedButton(
                                              onPressed: () => _castVote(vote, option),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.purple,
                                                minimumSize: const Size(50, 24),
                                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                              ),
                                              child: const Text(
                                                'Voter',
                                                style: TextStyle(fontSize: 10),
                                              ),
                                            ),
                                          ],
                                          if (!_isAdmin && hasVoted && votedOption == option) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '✓',
                                                style: TextStyle(
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (isProcessing) ...[
                                            const SizedBox(width: 6),
                                            const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 2),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: percentage / 100,
                                      minHeight: 6,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        option.toLowerCase().contains('oui') ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  ),
                                  
                                  if (_isAdmin && voters.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 2,
                                      children: voters.map((voter) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: option.toLowerCase().contains('oui') 
                                                ? Colors.green.shade50 
                                                : Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: option.toLowerCase().contains('oui') 
                                                  ? Colors.green.shade200 
                                                  : Colors.red.shade200,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            voter,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: option.toLowerCase().contains('oui') 
                                                  ? Colors.green.shade700 
                                                  : Colors.red.shade700,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }

                        // ✅ Construire le tableau des participants
                        final List<Map<String, String>> participantsList = _getParticipantsList(vote);
                        final List<Widget> participantWidgets = [];

                        for (var i = 0; i < participantsList.length; i++) {
                          final participant = participantsList[i];
                          final bool isOui = participant['vote']?.toLowerCase().contains('oui') ?? false;
                          final bool isNon = participant['vote']?.toLowerCase().contains('non') ?? false;
                          
                          participantWidgets.add(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: i < participantsList.length - 1
                                      ? BorderSide(color: Colors.grey.shade200)
                                      : BorderSide.none,
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 25,
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      participant['appartement'] ?? '',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text(
                                          participant['vote'] ?? '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isOui ? Colors.green.shade700 : 
                                                   isNon ? Colors.red.shade700 : 
                                                   Colors.black87,
                                          ),
                                        ),
                                        if (isOui)
                                          const Icon(Icons.arrow_upward, color: Colors.green, size: 14)
                                        else if (isNon)
                                          const Icon(Icons.arrow_downward, color: Colors.red, size: 14),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ✅ En-tête
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        vote['titre'] ?? 'Sans titre',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        vote['statut'] ?? 'N/A',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (_isAdmin)
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                        onPressed: () => _deleteVote(vote),
                                        tooltip: 'Supprimer ce vote',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                  ],
                                ),
                                
                                if (vote['description'].isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    vote['description'],
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                  ),
                                ],
                                
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Début: ${dateDebut != null ? DateFormat('dd/MM/yy HH:mm').format(dateDebut) : 'N/A'}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Fin: ${dateFin != null ? DateFormat('dd/MM/yy HH:mm').format(dateFin) : 'N/A'}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 6),
                                Text(
                                  'Total votes: $totalVotes',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                
                                const SizedBox(height: 6),
                                
                                // ✅ Options avec résultats
                                ...optionWidgets,
                                
                                // ✅ ADMIN : Graphique en barres
                                if (_isAdmin && totalVotes > 0) ...[
                                  const Divider(height: 16),
                                  _buildBarChart(vote),
                                ],
                                
                                // ✅ ADMIN : Synthèse
                                if (_isAdmin && totalVotes > 0) ...[
                                  const SizedBox(height: 10),
                                  _buildSynthesis(vote),
                                ],
                                
                                // ✅ ADMIN : Tableau des participants
                                if (_isAdmin && totalVotes > 0) ...[
                                  const Divider(height: 16),
                                  const Text(
                                    '👥 Participants',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                          ),
                                          child: const Row(
                                            children: [
                                              SizedBox(width: 25, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                              Expanded(child: Text('Appartement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                              Expanded(child: Text('Vote', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                            ],
                                          ),
                                        ),
                                        ...participantWidgets,
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                                          ),
                                          child: Text(
                                            '${participantsList.length} participant(s) sur $_totalAppartements appartements',
                                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                
                                if (!_isAdmin && hasVoted) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.green.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          '✅ Vous avez déjà voté pour ce scrutin',
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                
                                if (!_isAdmin && vote['statut'] == 'Terminé' && !hasVoted) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.orange.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.lock, color: Colors.orange.shade700, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          '🔒 Ce vote est terminé',
                                          style: TextStyle(
                                            color: Colors.orange.shade700,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}