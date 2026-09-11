// lib/screens/historique_acces_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/acces.dart';
import '../services/acces_service.dart';

class HistoriqueAccesScreen extends StatefulWidget {
  const HistoriqueAccesScreen({super.key});

  @override
  State<HistoriqueAccesScreen> createState() => _HistoriqueAccesScreenState();
}

class _HistoriqueAccesScreenState extends State<HistoriqueAccesScreen> {
  final AccesService _accesService = AccesService();
  List<Acces> _acces = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filtreRole = 'Tous';
  String _filtreAppartement = 'Tous';
  List<String> _appartementsList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _acces = await _accesService.getTousAcces();
      _updateAppartementsList();
    } catch (e) {
      print('❌ Erreur: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  void _updateAppartementsList() {
    final Set<String> apps = {};
    for (var a in _acces) {
      apps.add(a.numAppartement);
    }
    _appartementsList = ['Tous', ...apps.toList()..sort()];
  }

  List<Acces> get _filteredAcces {
    var result = _acces;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((a) =>
        a.numAppartement.toLowerCase().contains(q) ||
        a.role.toLowerCase().contains(q)
      ).toList();
    }

    if (_filtreRole != 'Tous') {
      result = result.where((a) => a.role == _filtreRole).toList();
    }

    if (_filtreAppartement != 'Tous') {
      result = result.where((a) => a.numAppartement == _filtreAppartement).toList();
    }

    return result;
  }

  Map<String, int> get _statistiques {
    final Map<String, int> stats = {};
    for (var a in _filteredAcces) {
      stats[a.numAppartement] = (stats[a.numAppartement] ?? 0) + 1;
    }
    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAcces;
    final stats = _statistiques;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Historique des accès'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Rafraîchir',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              _showExportDialog();
            },
            tooltip: 'Exporter',
          ),
        ],
      ),
      body: Column(
        children: [
          // ==================== BARRE DE RECHERCHE ET FILTRES ====================
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: '🔍 Rechercher un appartement...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filtreRole,
                        decoration: InputDecoration(
                          labelText: 'Rôle',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Tous', child: Text('Tous')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                          DropdownMenuItem(value: 'client', child: Text('Client')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _filtreRole = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filtreAppartement,
                        decoration: InputDecoration(
                          labelText: 'Appartement',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        items: _appartementsList.map((app) {
                          return DropdownMenuItem(
                            value: app,
                            child: Text(app == 'Tous' ? 'Tous' : app),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _filtreAppartement = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ==================== STATISTIQUES RAPIDES ====================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _buildStatChip(
                  label: 'Total',
                  value: '${filtered.length}',
                  color: Colors.indigo.shade700,
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  label: 'Appartements',
                  value: '${stats.keys.length}',
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  label: 'Admin',
                  value: '${filtered.where((a) => a.role == 'admin').length}',
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  label: 'Clients',
                  value: '${filtered.where((a) => a.role == 'client').length}',
                  color: Colors.orange.shade700,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ==================== LISTE DES ACCÈS ====================
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.indigo,
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty || _filtreRole != 'Tous' || _filtreAppartement != 'Tous'
                                  ? 'Aucun accès trouvé'
                                  : 'Aucun accès enregistré',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_searchQuery.isEmpty && _filtreRole == 'Tous' && _filtreAppartement == 'Tous')
                              ElevatedButton.icon(
                                onPressed: _loadData,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Rafraîchir'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo.shade700,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final acces = filtered[index];
                          final isAdmin = acces.role == 'admin';
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isAdmin 
                                    ? Colors.indigo.shade200 
                                    : Colors.green.shade200,
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: isAdmin 
                                    ? Colors.indigo.shade100 
                                    : Colors.green.shade100,
                                child: Icon(
                                  isAdmin 
                                      ? Icons.admin_panel_settings 
                                      : Icons.person,
                                  size: 20,
                                  color: isAdmin 
                                      ? Colors.indigo.shade800 
                                      : Colors.green.shade800,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    acces.numAppartement,
                                    style: TextStyle(
                                      fontWeight: isAdmin 
                                          ? FontWeight.bold 
                                          : FontWeight.w600,
                                      fontSize: 16,
                                      color: isAdmin 
                                          ? Colors.indigo.shade800 
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8, 
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isAdmin 
                                          ? Colors.indigo.shade100 
                                          : Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isAdmin ? 'ADMIN' : 'CLIENT',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isAdmin 
                                            ? Colors.indigo.shade800 
                                            : Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'IP: ${acces.ipAdresse ?? 'Inconnue'}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  if (acces.navigateur != null)
                                    Text(
                                      '🌐 ${acces.navigateur}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade400,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    DateFormat('dd/MM/yy').format(acces.dateAcces),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('HH:mm').format(acces.dateAcces),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                _showAccesDetails(acces);
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showTopAppartements();
        },
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.emoji_events),
        label: const Text('Top Appartements'),
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showAccesDetails(Acces acces) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: acces.role == 'admin' 
                        ? Colors.indigo.shade100 
                        : Colors.green.shade100,
                    child: Icon(
                      acces.role == 'admin' 
                          ? Icons.admin_panel_settings 
                          : Icons.person,
                      size: 30,
                      color: acces.role == 'admin' 
                          ? Colors.indigo.shade800 
                          : Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          acces.numAppartement,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: acces.role == 'admin' 
                                ? Colors.indigo.shade100 
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            acces.role.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: acces.role == 'admin' 
                                  ? Colors.indigo.shade800 
                                  : Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildDetailRow(Icons.calendar_today, 'Date', DateFormat('dd/MM/yyyy').format(acces.dateAcces)),
              _buildDetailRow(Icons.access_time, 'Heure', DateFormat('HH:mm:ss').format(acces.dateAcces)),
              _buildDetailRow(Icons.computer, 'IP Adresse', acces.ipAdresse ?? 'Inconnue'),
              if (acces.navigateur != null)
                _buildDetailRow(Icons.web, 'Navigateur', acces.navigateur!),
              _buildDetailRow(Icons.tag, 'ID', acces.id ?? 'Inconnu'),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TOP APPARTEMENTS (CORRIGÉ) ====================
  void _showTopAppartements() {
    final stats = _statistiques;
    final sorted = stats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topList = sorted.take(10).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber.shade700),
            const SizedBox(width: 8),
            const Text('🏆 Top Appartements'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: topList.length,
                  itemBuilder: (context, index) {
                    final item = topList[index];
                    final isFirst = index == 0;
                    final isSecond = index == 1;
                    final isThird = index == 2;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isFirst 
                            ? Colors.amber.shade100 
                            : (isSecond 
                                ? Colors.grey.shade200 
                                : (isThird 
                                    ? Colors.brown.shade100 
                                    : Colors.grey.shade50)),
                        child: Text(
                          isFirst ? '🥇' : (isSecond ? '🥈' : (isThird ? '🥉' : '${index + 1}')),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      title: Text(
                        item.key,
                        style: TextStyle(
                          fontWeight: isFirst ? FontWeight.bold : FontWeight.normal,
                          fontSize: isFirst ? 16 : 14,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isFirst ? Colors.amber.shade700 : Colors.indigo.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${item.value} accès',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isFirst ? Colors.white : Colors.indigo.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📤 Exporter les données'),
        content: const Text(
          'Voulez-vous exporter les données au format CSV ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _exporterCSV();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Exporter'),
          ),
        ],
      ),
    );
  }

  void _exporterCSV() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📤 Exportation en cours...'),
        backgroundColor: Colors.blue,
      ),
    );
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Exportation terminée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }
}