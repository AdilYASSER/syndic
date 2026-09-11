// lib/screens/admin/admin_annonces_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/annonce_model.dart';
import '../../services/annonce_service.dart';
import '../annonces/annonce_detail_screen.dart';
import '../annonces/add_annonce_screen.dart';

class AdminAnnoncesScreen extends StatefulWidget {
  const AdminAnnoncesScreen({super.key});

  @override
  State<AdminAnnoncesScreen> createState() => _AdminAnnoncesScreenState();
}

class _AdminAnnoncesScreenState extends State<AdminAnnoncesScreen> {
  final AnnonceService _service = AnnonceService();

  // ============ SUPPRESSION ============
  Future<void> _supprimerAnnonce(AnnonceModel annonce) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'annonce ?'),
        content: Text('Voulez-vous vraiment supprimer "${annonce.nomArticle}" ?'),
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

    if (confirm != true) return;

    try {
      await _service.supprimerAnnonce(annonce.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Annonce supprimée'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============ BASCULER VISIBILITÉ ============
  Future<void> _toggleVisibility(AnnonceModel annonce) async {
    try {
      await _service.toggleVisibility(annonce.id, !annonce.isVisible);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============ CARTE ============
  Widget _buildAnnonceCard(AnnonceModel annonce) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      color: annonce.isVisible ? Colors.white : Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: annonce.isVisible
              ? Colors.transparent
              : Colors.orange.shade300,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnnonceDetailScreen(
                annonce: annonce,
                currentUserAppartement: 'ADMIN',
                isAdmin: true,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ============ MINIATURE ============
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 90,
                  height: 90,
                  color: Colors.grey.shade200,
                  child: annonce.imageUrls.isNotEmpty
                      ? Image.network(
                          annonce.imageUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                          ),
                        )
                      : const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // ============ INFOS ============
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badges
                    Row(
                      children: [
                        if (annonce.isDon)
                          _buildMiniBadge('🎁', Colors.green),
                        if (annonce.isVente)
                          _buildMiniBadge('💰', Colors.blue),
                        if (annonce.isLocation)
                          _buildMiniBadge('🏠', Colors.orange),
                        const Spacer(),
                        if (!annonce.isVisible)
                          _buildMiniBadge('🚫 Masquée', Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Nom
                    Text(
                      annonce.nomArticle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Qualité + Appartement
                    Text(
                      '${annonce.qualiteTexte} • Appt ${annonce.appartement}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Date
                    Text(
                      DateFormat('dd/MM/yy').format(annonce.dateCreation),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Prix
                    if (annonce.prix != null && annonce.prix! > 0)
                      Text(
                        '${annonce.prix!.toStringAsFixed(0)} DH',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      )
                    else if (annonce.isDon)
                      Text(
                        'GRATUIT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                  ],
                ),
              ),

              // ============ ACTIONS ============
              Column(
                children: [
                  IconButton(
                    tooltip: annonce.isVisible ? 'Masquer' : 'Afficher',
                    icon: Icon(
                      annonce.isVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: annonce.isVisible
                          ? Colors.green
                          : Colors.orange,
                    ),
                    onPressed: () => _toggleVisibility(annonce),
                  ),
                  IconButton(
                    tooltip: 'Supprimer',
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _supprimerAnnonce(annonce),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ============ BUILD ============
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Annonces (admin)'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<AnnonceModel>>(
        stream: _service.getAllAnnonces(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          final annonces = snapshot.data ?? [];
          if (annonces.isEmpty) {
            return const Center(
              child: Text('Aucune annonce pour le moment'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: annonces.length,
            itemBuilder: (context, i) => _buildAnnonceCard(annonces[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal.shade700,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddAnnonceScreen(
                appartement: 'ADMIN',
                nomPrenom: 'Admin',
                telephone: '',
                createdBy: 'admin',
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}