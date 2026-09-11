// lib/screens/habitant_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../models/habitant.dart';
import '../services/database_service.dart';
import '../services/firebase_service.dart';
import 'add_habitant_screen.dart';

// ⬇️ SUPPRIMER import 'dart:io'; (non disponible sur web)

class HabitantDetailsScreen extends StatefulWidget {
  final Habitant habitant;

  const HabitantDetailsScreen({super.key, required this.habitant});

  @override
  State<HabitantDetailsScreen> createState() => _HabitantDetailsScreenState();
}

class _HabitantDetailsScreenState extends State<HabitantDetailsScreen> {
  final DatabaseService _db = DatabaseService();
  final FirebaseService _firebase = FirebaseService();
  bool _isDeleting = false;
  bool _isSyncing = false;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.habitant;

    return Scaffold(
      appBar: AppBar(
        title: Text('${h.prenom} ${h.nom}'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        actions: [
          if (h.synced == 0 && !kIsWeb)
            IconButton(
              icon: _isSyncing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync),
              onPressed: _isSyncing ? null : _syncSingle,
              tooltip: 'Synchroniser avec Firebase',
            ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editHabitant,
            tooltip: 'Modifier',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteHabitant,
            tooltip: 'Supprimer',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(h),
            const SizedBox(height: 20),
            
            // Informations personnelles
            _buildInfoCard(
              title: '📋 Informations personnelles',
              icon: Icons.person,
              children: [
                _buildInfoRow('Nom', h.nom),
                _buildInfoRow('Prénom', h.prenom),
                _buildInfoRow('Téléphone', h.telephone),
                _buildInfoRow('CIN', h.cin.isNotEmpty ? h.cin : 'Non renseigné'),
              ],
            ),
            const SizedBox(height: 12),

            // Informations logement
            _buildInfoCard(
              title: '🏠 Informations logement',
              icon: Icons.apartment,
              children: [
                _buildInfoRow('Appartement', h.numAppartement),
                _buildInfoRow('Statut', h.statutTexte),
              ],
            ),
            const SizedBox(height: 12),

            // Informations bancaires
            _buildInfoCard(
              title: '💰 Informations bancaires',
              icon: Icons.credit_card,
              children: [
                _buildInfoRow('RIB', h.rib.isNotEmpty ? h.rib : 'Non renseigné'),
              ],
            ),
            const SizedBox(height: 12),

            // Informations locataire (si propriétaire avec locataire)
            if (h.estProprietaire && h.locataireNom != null && h.locataireNom!.isNotEmpty)
              _buildInfoCard(
                title: '👤 Informations du locataire',
                icon: Icons.person_add,
                children: [
                  _buildInfoRow('Nom', h.locataireNomComplet),
                  _buildInfoRow('Téléphone', h.locataireTelephone ?? 'Non renseigné'),
                  _buildInfoRow('CIN', h.locataireCin ?? 'Non renseigné'),
                  _buildInfoRow('Email', h.locataireEmail ?? 'Non renseigné'),
                  _buildInfoRow('Adresse', h.locataireAdresse ?? 'Non renseigné'),
                ],
              ),
            const SizedBox(height: 12),

            // CIN Image (si disponible)
            if (h.cinUrl != null && h.cinUrl!.isNotEmpty)
              _buildCINImage(h),
            const SizedBox(height: 12),

            // Date de création
            _buildCreationDate(h),
            const SizedBox(height: 20),

            // Boutons d'action en bas
            _buildActionButtons(h),
          ],
        ),
      ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader(Habitant h) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade800, Colors.blue.shade400],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Text(
              h.numAppartement,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h.nomComplet,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: h.estProprietaire ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        h.statutTexte,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (h.synced == 0 && !kIsWeb)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Non synchronisé',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== INFO CARD ====================
  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ==================== INFO ROW ====================
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: value == 'Non renseigné' ? FontWeight.normal : FontWeight.w500,
                color: value == 'Non renseigné' ? Colors.grey.shade400 : Colors.black,
                fontStyle: value == 'Non renseigné' ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CIN IMAGE ====================
  Widget _buildCINImage(Habitant h) {
    return _buildInfoCard(
      title: '🪪 Copie CIN',
      icon: Icons.badge,
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade100,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              h.cinUrl!,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('Image non disponible', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ==================== CREATION DATE ====================
  Widget _buildCreationDate(Habitant h) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            'Créé le ${DateFormat('dd/MM/yyyy à HH:mm').format(h.dateCreation)}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ==================== ACTION BUTTONS ====================
  Widget _buildActionButtons(Habitant h) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _editHabitant,
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Modifier'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _deleteHabitant,
            icon: _isDeleting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.delete, size: 18),
            label: Text(_isDeleting ? 'Suppression...' : 'Supprimer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== SYNC SINGLE ====================
  Future<void> _syncSingle() async {
    if (!mounted) return;
    setState(() => _isSyncing = true);
    try {
      await _firebase.syncHabitant(widget.habitant);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Synchronisé avec Firebase'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) {
      setState(() => _isSyncing = false);
    }
  }

  // ==================== EDIT ====================
  Future<void> _editHabitant() async {
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddHabitantScreen(habitant: widget.habitant),
      ),
    );
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  // ==================== DELETE ====================
  Future<void> _deleteHabitant() async {
    if (!mounted) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 24),
            const SizedBox(width: 8),
            const Text('Confirmation de suppression'),
          ],
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer ${widget.habitant.prenom} ${widget.habitant.nom} (Appartement ${widget.habitant.numAppartement}) ?\n\nCette action est irréversible.',
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

    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _isDeleting = true);

    try {
      if (!kIsWeb) {
        await _db.deleteHabitant(widget.habitant.id!);
        print('✅ Supprimé de SQLite');
      }
      
      await _firebase.deleteFromFirestore(widget.habitant.id!);
      print('✅ Supprimé de Firestore');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Habitant supprimé avec succès'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) {
      setState(() => _isDeleting = false);
    }
  }
}