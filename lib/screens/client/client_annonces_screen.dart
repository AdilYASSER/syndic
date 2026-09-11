// lib/screens/client/client_annonces_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/annonce_model.dart';
import '../../services/annonce_service.dart';
import '../annonces/annonce_detail_screen.dart';

class ClientAnnoncesScreen extends StatefulWidget {
  final String appartement;

  const ClientAnnoncesScreen({
    super.key,
    required this.appartement,
  });

  @override
  State<ClientAnnoncesScreen> createState() => _ClientAnnoncesScreenState();
}

class _ClientAnnoncesScreenState extends State<ClientAnnoncesScreen> {
  final AnnonceService _service = AnnonceService();

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📋 Lien copié dans le presse-papier !'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildTypeBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

  Widget _buildAnnonceCard(AnnonceModel annonce) {
    final isOwner = annonce.appartement == widget.appartement;
    final imageUrls = annonce.imageUrls;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnnonceDetailScreen(
                annonce: annonce,
                currentUserAppartement: widget.appartement,
                isAdmin: false,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============ APERÇU PREMIÈRE IMAGE ============
            if (imageUrls.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: GestureDetector(
                  onTap: () => _openUrl(imageUrls.first),
                  child: Image.network(
                    imageUrls.first,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 180,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stack) {
                      return Container(
                        height: 180,
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ============ BADGES TYPE ============
                  Row(
                    children: [
                      if (annonce.isDon)
                        _buildTypeBadge('🎁 Don', Colors.green),
                      if (annonce.isVente) ...[
                        const SizedBox(width: 4),
                        _buildTypeBadge('💰 Vente', Colors.blue),
                      ],
                      if (annonce.isLocation) ...[
                        const SizedBox(width: 4),
                        _buildTypeBadge('🏠 Location', Colors.orange),
                      ],
                      const Spacer(),
                      if (isOwner)
                        _buildTypeBadge('Ma publication', Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ============ NOM ============
                  Text(
                    annonce.nomArticle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // ============ QUALITÉ ============
                  Text(
                    annonce.qualiteTexte,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ============ PRIX ============
                  if (annonce.prix != null && annonce.prix! > 0)
                    Text(
                      '${annonce.prix!.toStringAsFixed(0)} DH',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    )
                  else if (annonce.isDon)
                    Text(
                      'GRATUIT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),

                  const SizedBox(height: 8),

                  // ============ INFOS VENDEUR ============
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        annonce.appartement,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd/MM/yy').format(annonce.dateCreation),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),

                  // ============ SECTION PHOTOS ============
                  if (imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _openUrl(imageUrls.first),
                      child: Row(
                        children: [
                          Icon(
                            Icons.image,
                            color: Colors.blue.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '📸 Afficher la photo (${imageUrls.length} image${imageUrls.length > 1 ? 's' : ''})',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (imageUrls.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 24, top: 2),
                        child: Text(
                          '+ ${imageUrls.length - 1} autre(s) photo(s) disponible(s)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
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
    );
  }

  // ============ BUILD ============
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AnnonceModel>>(
      stream: _service.getAnnonces(),
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
          itemBuilder: (_, i) => _buildAnnonceCard(annonces[i]),
        );
      },
    );
  }
}