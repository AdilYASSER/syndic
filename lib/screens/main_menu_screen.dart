// lib/screens/main_menu_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'habitants_list_screen.dart';
import 'cotisations_list_screen.dart';
import 'cotisations_table_screen.dart';
import 'depenses_list_screen.dart';
import 'documentation_screen.dart';
import 'reclamations_screen.dart';
import 'reclamations_list_screen.dart';
import 'mes_reclamations_screen.dart';
import 'historique_acces_screen.dart';
import 'releve_tresor_screen.dart';
import 'espace_vote_screen.dart';
import 'client_vote_screen.dart';
import 'operations_screen.dart';
import 'rapport_financier_screen.dart';
import 'discussion_screen.dart';
import 'change_password_screen.dart';
import 'statistiques_screen.dart';
import 'realisations_screen.dart';
import 'admin_initial_password_screen.dart';
import 'admin/admin_publications_screen.dart';
import 'client/client_publications_screen.dart';
import 'client/client_ideas_screen.dart';
import 'admin/admin_ideas_screen.dart';
import 'admin/admin_generer_recu.dart';
import 'client/client_mes_recus.dart';
import 'admin/admin_repertoire_screen.dart';
import 'client/client_repertoire_screen.dart';
import 'admin/admin_annonces_screen.dart';
import 'client/client_annonces_screen.dart';
// ✅ IMPORTS POUR LES DEMANDES D'AIDE
import 'annonces/demandes_aide_list_screen.dart';
import '../models/demande_aide_model.dart';
import '../services/demande_aide_service.dart';
// ✅ IMPORT POUR LE SERVICE PUBLICATIONS
import '../services/publication_service.dart';

class MainMenuScreen extends StatefulWidget {
  final String role;
  final String? appartement;

  const MainMenuScreen({
    super.key,
    required this.role,
    this.appartement,
  });

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  // ✅ Service pour lire/écrire la date de lecture
  final PublicationService _publicationService = PublicationService();

  // ✅ Getters pour garder le même code qu'avant
  bool get isClient => widget.role != 'admin';
  bool get isAdmin => widget.role == 'admin';
  String get role => widget.role;
  String? get appartement => widget.appartement;
  String get _userId =>
      isAdmin ? 'admin' : 'client_${widget.appartement ?? 'unknown'}';

  // ============================================================
  // ✅ NAVIGATION VERS LA LISTE DES DEMANDES D'AIDE
  // ============================================================
  void _navigateToDemandesAideList(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DemandesAideListScreen(
          isAdmin: isAdmin,
          userId: _userId,
          appartement: appartement ?? '',
          nomPrenom: isAdmin ? 'Admin' : 'Client App $appartement',
          telephone: '',
        ),
      ),
    );
  }

  // ✅ BOUTON DEMANDE D'AIDE AVEC AMPOULE 💡
  Widget _buildDemandeAideButton(BuildContext context) {
    final service = DemandeAideService();
    return StreamBuilder<List<DemandeAideModel>>(
      stream: service.getAllDemandes(),
      builder: (context, snapshot) {
        bool hasNew = false;
        if (snapshot.hasData) {
          hasNew = snapshot.data!.any((d) => !d.luPar.contains(_userId));
        }

        return SizedBox(
          width: double.infinity,
          height: 65,
          child: ElevatedButton(
            onPressed: () => _navigateToDemandesAideList(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: hasNew ? 6 : 3,
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.help_outline, color: Colors.white, size: 22),
                      SizedBox(height: 3),
                      Text(
                        '🆘 DEMANDES AIDE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // 💡 AMPOULE ALLUMÉE si nouvelles demandes non lues
                if (hasNew)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.8),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lightbulb,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // MÉTHODES EXISTANTES
  // ============================================================

  void _navigateToChangePassword(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangePasswordScreen(appartement: appartement),
      ),
    );
  }

  void _navigateToStatistics(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StatistiquesScreen(role: role, appartement: appartement),
      ),
    );
  }

  void _navigateToRealisations(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RealisationsScreen(role: role),
      ),
    );
  }

  void _navigateToInitialPassword(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminInitialPasswordScreen(),
      ),
    );
  }

  // ✅ IMPORTANT : async + setState au retour
  Future<void> _navigateToPublications(BuildContext context) async {
    if (isAdmin) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AdminPublicationsScreen(),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClientPublicationsScreen(appartement: appartement),
        ),
      );
    }
    // ✅ Recharge le menu au retour → le FutureBuilder relit Firestore
    if (mounted) setState(() {});
  }

  void _navigateToIdeas(BuildContext context) {
    if (isAdmin) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AdminIdeasScreen(),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ClientIdeasScreen(appartement: appartement ?? 'N/A'),
        ),
      );
    }
  }

  void _navigateToGenererRecu(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CotisationsListScreen(
          role: 'admin',
          mode: 'generer_recu',
        ),
      ),
    );
  }

  void _navigateToMesRecus(BuildContext context) {
    if (appartement == null || appartement!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Aucun appartement associé à ce compte'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientMesRecusScreen(numAppartement: appartement!),
      ),
    );
  }

  void _navigateToRepertoireAdmin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminRepertoireScreen()),
    );
  }

  void _navigateToRepertoireClient(BuildContext context) {
    if (appartement == null || appartement!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Aucun appartement associé à ce compte'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientRepertoireScreen(appartement: appartement!),
      ),
    );
  }

  void _navigateToAnnoncesAdmin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminAnnoncesScreen()),
    );
  }

  void _navigateToAnnoncesClient(BuildContext context) {
    if (appartement == null || appartement!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Aucun appartement associé à ce compte'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientAnnoncesScreen(appartement: appartement!),
      ),
    );
  }

  // ==================== BOUTON PUBLICATIONS AVEC POINT ROUGE ====================

  Widget _buildPublicationButton(BuildContext context) {
    // ✅ On lit la date de lecture depuis FIRESTORE (persiste après redémarrage)
    return FutureBuilder<DateTime>(
      future: _publicationService.getLastReadDate(_userId),
      builder: (context, lastCheckSnapshot) {
        if (!lastCheckSnapshot.hasData) {
          return _buildInactivePublicationButton(context);
        }

        final DateTime lastCheck = lastCheckSnapshot.data!;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('publications')
              .orderBy('datePublication', descending: true)
              .limit(1)
              .snapshots(),
          builder: (context, snapshot) {
            bool hasNew = false;

            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              final data =
                  snapshot.data!.docs.first.data() as Map<String, dynamic>;
              final Timestamp? ts = data['datePublication'];
              if (ts != null) {
                final DateTime latestPubDate = ts.toDate();
                if (latestPubDate.isAfter(lastCheck)) {
                  hasNew = true;
                }
              }
            }

            return SizedBox(
              width: double.infinity,
              height: 65,
              child: ElevatedButton(
                onPressed: () => _navigateToPublications(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan.shade800,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.campaign, color: Colors.white, size: 22),
                          SizedBox(height: 3),
                          Text(
                            '📢 PUBLICATIONS',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (hasNew)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              '•',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInactivePublicationButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 65,
      child: ElevatedButton(
        onPressed: () => _navigateToPublications(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.cyan.shade800,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 3,
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign, color: Colors.white, size: 22),
            SizedBox(height: 3),
            Text(
              '📢 PUBLICATIONS',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final bool isAdmin = role == 'admin';
    final ScrollController scrollController = ScrollController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(context).size.height * 0.88),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.info_outline,
                        color: Colors.blue, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('📖 À propos',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Divider(height: 10),
              Expanded(
                child: Column(
                  children: [
                    _buildScrollButton(
                      context: context,
                      icon: Icons.arrow_upward,
                      label: '▲ HAUT',
                      onTap: () {
                        scrollController.animateTo(0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      },
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade700,
                                      Colors.purple.shade700
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.person,
                                        color: Colors.blue, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('👨‍💻 Développé par',
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 10)),
                                        Text('Adil YASSER',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.grey.shade200)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.apartment,
                                          size: 13,
                                          color: Colors.blue.shade700),
                                      const SizedBox(width: 6),
                                      const Text(
                                          'SYNDIC - Gestion Copropriété',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Colors.blue)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Une gestion de copropriété plus simple, plus transparente et plus efficace.\n\n'
                                    'SYNDIC réunit dans une seule application tous les outils indispensables :\n'
                                    '• Suivi des copropriétaires et locataires\n'
                                    '• Cotisations et retardataires\n'
                                    '• Dépenses et trésorerie\n'
                                    '• Rapports financiers et moraux\n'
                                    '• Documents et réclamations\n'
                                    '• Échanges, votes et décisions\n\n'
                                    'Avec ses tableaux de bord et ses statistiques, l\'application permet '
                                    'd\'avoir une vision claire de la copropriété et de faciliter la prise de décision.\n\n'
                                    'Un outil conçu pour gagner du temps, améliorer le suivi et renforcer la transparence.',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                        height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text('📋 Fonctionnalités cliquables',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (isAdmin) ...[
                                  _buildClickableChip(
                                      context: context,
                                      label: '👥 Habitants',
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const HabitantsListScreen()));
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '📋 Cotisations',
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const CotisationsListScreen()));
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '📉 Dépenses',
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    DepensesListScreen(
                                                        isClient: false)));
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '📊 Tableau',
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    CotisationsTableScreen(
                                                        role: role,
                                                        appartement:
                                                            appartement)));
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '📊 Relevé',
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    ReleveTresorScreen(
                                                        role: role,
                                                        appartement:
                                                            appartement)));
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '📊 Rapport',
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    RapportFinancierScreen(
                                                        role: role,
                                                        appartement:
                                                            appartement)));
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '📚 Documents',
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    DocumentationScreen(
                                                        role: role)));
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '📝 Réclamations',
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const ReclamationsListScreen()));
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '💬 Discussions',
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => DiscussionScreen(
                                                    role: role,
                                                    appartement:
                                                        appartement)));
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '🗳️ Vote',
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const EspaceVoteScreen()));
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '📋 Historique',
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const HistoriqueAccesScreen()));
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '🏦 Opérations',
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const OperationsScreen()));
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '🛠️ Réalisations',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _navigateToRealisations(context);
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '📊 Statistiques',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _navigateToStatistics(context);
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '🔑 Codes initiaux',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _navigateToInitialPassword(context);
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '📢 Publications',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _navigateToPublications(context);
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '💡 Banque aux idées',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _navigateToIdeas(context);
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '📄 Production reçus',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _navigateToGenererRecu(context);
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '📂 Répertoire Utile',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _navigateToRepertoireAdmin(context);
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '🛒 Petites annonces',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _navigateToAnnoncesAdmin(context);
                                      }),
                                  // ✅ CHIP DEMANDE D'AIDE (ADMIN)
                                  _buildClickableChip(
                                      context: context,
                                      label: '🆘 Demandes d\'aide',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _navigateToDemandesAideList(context);
                                      },
                                      color: Colors.red.shade50),
                                ],
                                if (!isAdmin) ...[
                                  _buildClickableChip(
                                      context: context,
                                      label: '📋 Cotisations',
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    CotisationsTableScreen(
                                                        role: role,
                                                        appartement:
                                                            appartement)));
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '📉 Dépenses',
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    DepensesListScreen(
                                                        isClient: true)));
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '📝 Réclamations',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _showClientReclamationMenu(context);
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '💬 Discussions',
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => DiscussionScreen(
                                                    role: role,
                                                    appartement:
                                                        appartement)));
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '🗳️ Vote',
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => ClientVoteScreen(
                                                    appartement:
                                                        appartement ??
                                                            'N/A')));
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '🛠️ Réalisations',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _navigateToRealisations(context);
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '📊 Statistiques',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _navigateToStatistics(context);
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '🔑 Mot de passe',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _navigateToChangePassword(context);
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '📢 Publications',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _navigateToPublications(context);
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '💡 Banque aux idées',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _navigateToIdeas(context);
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '📥 Chargez mes reçus',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _navigateToMesRecus(context);
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '📂 Répertoire Utile',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _navigateToRepertoireClient(context);
                                      }),
                                  _buildClickableChip(
                                      context: context,
                                      label: '🛒 Petites annonces',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _navigateToAnnoncesClient(context);
                                      }),
                                  // ✅ CHIP DEMANDE D'AIDE (CLIENT)
                                  _buildClickableChip(
                                      context: context,
                                      label: '🆘 Mes demandes',
                                      onTap: () {
                                        Navigator.pop(context);
                                        _navigateToDemandesAideList(context);
                                      },
                                      color: Colors.red.shade50),
                                ],
                              ],
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  _showExitDialog(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade700,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: Colors.red.shade900, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.red.shade300
                                              .withOpacity(0.5),
                                          blurRadius: 12,
                                          spreadRadius: 2)
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.exit_to_app,
                                          color: Colors.white, size: 18),
                                      SizedBox(width: 10),
                                      Text('🚪 SORTIE',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 1.2)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildScrollButton(
                      context: context,
                      icon: Icons.arrow_downward,
                      label: '▼ BAS',
                      onTap: () {
                        scrollController.animateTo(
                            scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      },
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.copyright, size: 9, color: Colors.grey),
                    const SizedBox(width: 2),
                    const Text('2026 - Syndic v1.0',
                        style: TextStyle(fontSize: 9, color: Colors.grey)),
                    const SizedBox(width: 6),
                    Container(
                        width: 1, height: 10, color: Colors.grey.shade300),
                    const SizedBox(width: 6),
                    Text(isAdmin ? '👑 Admin' : '👤 Client',
                        style: TextStyle(
                            fontSize: 9,
                            color: isAdmin
                                ? Colors.blue.shade700
                                : Colors.green.shade700,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollButton(
      {required BuildContext context,
      required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label,
            style:
                const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade100,
          foregroundColor: Colors.blue.shade800,
          padding: const EdgeInsets.symmetric(vertical: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 1,
          minimumSize: const Size(double.infinity, 30),
        ),
      ),
    );
  }

  Widget _buildClickableChip(
      {required BuildContext context,
      required String label,
      required VoidCallback onTap,
      Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: color ?? Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: color ?? Colors.blue.shade200, width: 1)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color ?? Colors.blue.shade700,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios,
                size: 8, color: color ?? Colors.blue.shade400),
          ],
        ),
      ),
    );
  }

  void _showClientReclamationMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text('📝 Réclamations',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.add, color: Colors.blue)),
                title: const Text('Nouvelle réclamation'),
                subtitle: const Text('Soumettre une nouvelle réclamation'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ReclamationsScreen(
                              role: role,
                              appartement: appartement,
                              userId: 'client_${appartement ?? 'unknown'}',
                              userName: 'Client App $appartement')));
                },
              ),
              ListTile(
                leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: const Icon(Icons.list, color: Colors.green)),
                title: const Text('Mes réclamations'),
                subtitle: const Text('Voir le suivi de mes réclamations'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => MesReclamationsScreen(
                              appartement: appartement ?? 'N/A')));
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.red.shade700, size: 24),
            const SizedBox(width: 8),
            const Text('Confirmation de sortie')
          ],
        ),
        content:
            const Text('Voulez-vous vraiment quitter l\'application ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              SystemNavigator.pop();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Se déconnecter')),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 65,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 3,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = role == 'admin';
    final bool isClient = !isAdmin;

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: Text(isAdmin
            ? '🏢 SYNDIC - Gestion Copropriété'
            : '🏢 SYNDIC - Espace Client (App: $appartement)'),
        backgroundColor:
            isAdmin ? Colors.blue.shade800 : Colors.green.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showAboutDialog(context),
            tooltip: 'À propos',
          ),
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:
                  isClient ? Colors.green.shade700 : Colors.orange.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isClient ? '👤 Client' : '👑 Admin',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
          if (isClient)
            IconButton(
              icon: const Icon(Icons.lock_outline),
              onPressed: () => _navigateToChangePassword(context),
              tooltip: '🔑 Changer le mot de passe',
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ==================== LOGO ====================
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade200.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/LOGO.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.blue.shade100,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.apartment,
                                      size: 35, color: Colors.blue.shade800),
                                  const SizedBox(height: 4),
                                  Text(
                                    'SYNDIC',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SYNDIC',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                        letterSpacing: 4,
                      ),
                    ),
                    Text(
                      'AIN SEBAA - WAHDA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade600,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ==============================================================
                    // 👑 MODE ADMIN
                    // ==============================================================
                    if (isAdmin) ...[
                      // LIGNE 1 : HABITANTS + COTISATIONS
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.people,
                              label: '👥 HABITANTS',
                              color: Colors.blue.shade700,
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const HabitantsListScreen()));
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.payments,
                              label: '📋 COTISATIONS',
                              color: Colors.green.shade700,
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const CotisationsListScreen()));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // LIGNE 2 : DÉPENSES + TABLEAU COTISATIONS
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.receipt_long,
                              label: 'DÉPENSES',
                              color: Colors.orange,
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => DepensesListScreen(
                                            isClient: false)));
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.table_chart,
                              label: 'TABLEAU COTISATIONS',
                              color: const Color(0xFF00897B),
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => CotisationsTableScreen(
                                            role: role,
                                            appartement: appartement)));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // LIGNE 3 : RELEVÉ TRÉSOR + BANQUE AUX IDÉES
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.receipt,
                              label: '📊 RELEVÉ TRÉSOR',
                              color: Colors.indigo.shade700,
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => ReleveTresorScreen(
                                            role: role,
                                            appartement: appartement)));
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.lightbulb_outline,
                              label: '💡 BANQUE AUX IDÉES',
                              color: Colors.yellow.shade700,
                              onTap: () => _navigateToIdeas(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // LIGNE 4 : RAPPORT FINANCIER + DOCUMENTATION
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.analytics,
                              label: '📊 RAPPORT FINANCIER',
                              color: Colors.deepPurple.shade700,
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => RapportFinancierScreen(
                                            role: role,
                                            appartement: appartement)));
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.description,
                              label: '📚 DOCUMENTATION',
                              color: Colors.teal.shade700,
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            DocumentationScreen(role: role)));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // LIGNE 5 : RÉCLAMATIONS + DISCUSSIONS
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.feedback,
                              label: '📝 RÉCLAMATIONS',
                              color: Colors.deepOrange.shade700,
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const ReclamationsListScreen()));
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.forum,
                              label: '💬 DISCUSSIONS',
                              color: Colors.cyan.shade700,
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => DiscussionScreen(
                                            role: role,
                                            appartement: appartement)));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // LIGNE 6 : ESPACE VOTE + RÉALISATIONS
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.how_to_vote,
                              label: '🗳️ ESPACE VOTE',
                              color: Colors.purple.shade700,
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const EspaceVoteScreen()));
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.construction,
                              label: '🛠️ RÉALISATIONS',
                              color: Colors.orange.shade700,
                              onTap: () => _navigateToRealisations(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // LIGNE 7 : STATISTIQUES + HISTORIQUE ACCÈS
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.analytics,
                              label: '📊 STATISTIQUES',
                              color: Colors.purple.shade700,
                              onTap: () => _navigateToStatistics(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.history,
                              label: '📋 HISTORIQUE ACCÈS',
                              color: Colors.indigo.shade700,
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const HistoriqueAccesScreen()));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // LIGNE 8 : OPÉRATIONS + PUBLICATIONS
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.account_balance,
                              label: '🏦 OPÉRATIONS',
                              color: Colors.blue.shade700,
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const OperationsScreen()));
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: _buildPublicationButton(context)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // LIGNE 9 : PRODUCTION REÇUS + CODES INITIAUX
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.receipt,
                              label: '📄 PRODUCTION REÇUS',
                              color: Colors.green.shade700,
                              onTap: () => _navigateToGenererRecu(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.lock_outline,
                              label: '🔑 CODES INITIAUX',
                              color: Colors.red.shade700,
                              onTap: () =>
                                  _navigateToInitialPassword(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // LIGNE 10 : RÉPERTOIRE UTILE + PETITES ANNONCES
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.folder,
                              label: '📂 RÉPERTOIRE UTILE',
                              color: Colors.blue.shade700,
                              onTap: () =>
                                  _navigateToRepertoireAdmin(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.storefront,
                              label: '🛒 PETITES ANNONCES',
                              color: Colors.teal.shade700,
                              onTap: () =>
                                  _navigateToAnnoncesAdmin(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // ✅ LIGNE 11 : DEMANDES AIDE (demi-largeur) + SORTIE
                      Row(
                        children: [
                          Expanded(child: _buildDemandeAideButton(context)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.exit_to_app,
                              label: '🚪 SORTIE',
                              color: Colors.red.shade700,
                              onTap: () => _showExitDialog(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ==============================================================
                    // 👤 MODE CLIENT
                    // ==============================================================
                    if (isClient) ...[
                      // LIGNE 1 : DÉPENSES + TABLEAU COTISATIONS
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.receipt_long,
                              label: 'DÉPENSES',
                              color: Colors.orange,
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => DepensesListScreen(
                                            isClient: true)));
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.table_chart,
                              label: 'TABLEAU COTISATIONS',
                              color: const Color(0xFF00897B),
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => CotisationsTableScreen(
                                            role: role,
                                            appartement: appartement)));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // LIGNE 2 : RELEVÉ TRÉSOR + BANQUE AUX IDÉES
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.receipt,
                              label: '📊 RELEVÉ TRÉSOR',
                              color: Colors.indigo.shade700,
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => ReleveTresorScreen(
                                            role: role,
                                            appartement: appartement)));
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.lightbulb_outline,
                              label: '💡 BANQUE AUX IDÉES',
                              color: Colors.yellow.shade700,
                              onTap: () => _navigateToIdeas(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // LIGNE 3 : RAPPORT FINANCIER + DOCUMENTATION
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.analytics,
                              label: '📊 RAPPORT FINANCIER',
                              color: Colors.deepPurple.shade700,
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => RapportFinancierScreen(
                                            role: role,
                                            appartement: appartement)));
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.description,
                              label: '📚 DOCUMENTATION',
                              color: Colors.teal.shade700,
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            DocumentationScreen(role: role)));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // LIGNE 4 : RÉCLAMATIONS + DISCUSSIONS
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.feedback,
                              label: '📝 RÉCLAMATIONS',
                              color: Colors.deepOrange.shade700,
                              onTap: () =>
                                  _showClientReclamationMenu(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.forum,
                              label: '💬 DISCUSSIONS',
                              color: Colors.cyan.shade700,
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => DiscussionScreen(
                                            role: role,
                                            appartement: appartement)));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // LIGNE 5 : ESPACE VOTE + RÉALISATIONS
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.how_to_vote,
                              label: '🗳️ ESPACE VOTE',
                              color: Colors.purple.shade700,
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => ClientVoteScreen(
                                            appartement:
                                                appartement ?? 'N/A')));
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.construction,
                              label: '🛠️ RÉALISATIONS',
                              color: Colors.orange.shade700,
                              onTap: () => _navigateToRealisations(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // LIGNE 6 : STATISTIQUES + PUBLICATIONS
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.analytics,
                              label: '📊 STATISTIQUES',
                              color: Colors.purple.shade700,
                              onTap: () => _navigateToStatistics(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: _buildPublicationButton(context)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // LIGNE 7 : CHARGEZ MES REÇUS + RÉPERTOIRE UTILE
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.download,
                              label: '📥 CHARGEZ MES REÇUS',
                              color: Colors.blue.shade700,
                              onTap: () => _navigateToMesRecus(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.folder,
                              label: '📂 RÉPERTOIRE UTILE',
                              color: Colors.blue.shade700,
                              onTap: () =>
                                  _navigateToRepertoireClient(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // LIGNE 8 : PETITES ANNONCES + À PROPOS
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.storefront,
                              label: '🛒 PETITES ANNONCES',
                              color: Colors.teal.shade700,
                              onTap: () =>
                                  _navigateToAnnoncesClient(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.info_outline,
                              label: '📖 À PROPOS',
                              color: Colors.blue.shade700,
                              onTap: () => _showAboutDialog(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // ✅ LIGNE 9 : DEMANDES AIDE (demi-largeur) + SORTIE
                      Row(
                        children: [
                          Expanded(child: _buildDemandeAideButton(context)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMenuButton(
                              context: context,
                              icon: Icons.exit_to_app,
                              label: '🚪 SORTIE',
                              color: Colors.red.shade700,
                              onTap: () => _showExitDialog(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ==================== PIED DE PAGE ====================
                    Column(
                      children: [
                        Text(
                          '© 2026 - Syndic Management v1.0',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '👨‍💻 Adil YASSER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}