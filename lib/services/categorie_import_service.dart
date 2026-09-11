// lib/services/categorie_import_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class CategorieImportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Méthode principale d'importation
  Future<Map<String, dynamic>> importerToutesCategories() async {
    final Map<String, dynamic> result = {
      'success': true,
      'imported': 0,
      'updated': 0,
      'errors': 0,
      'details': [],
    };

    print('🚀 DÉMARRAGE DE L\'IMPORTATION COMPLÈTE\n');

    // ============================================================
    // DÉFINITION DE TOUTES LES CATÉGORIES ET SOUS-CATÉGORIES
    // ============================================================
    final Map<String, List<String>> categories = {
      'Santé': [
        'Médecins généralistes',
        'Médecins spécialistes (cardiologue, dermatologue, etc.)',
        'Dentistes',
        'Ophtalmologues',
        'Pédiatres',
        'Pharmacies',
        'Infirmiers',
        'Sages-femmes',
        'Kinésithérapeutes',
        'Psychologues',
        'Analyses médicales (laboratoires)',
        'Ambulanciers',
        'Opticiens',
      ],
      'Éducation': [
        'Écoles primaires',
        'Collèges',
        'Lycées',
        'Universités',
        'Cours de soutien',
        'Garderies',
        'Écoles de langues',
        'Écoles de musique',
        'Écoles de sport',
        'Informatique / Bureautique',
      ],
      'Bricolage': [
        'Électricité (générale)',
        'Plomberie',
        'Peinture (intérieure/extérieure)',
        'Menuiserie (bois)',
        'Menuiserie aluminium',
        'Ferronnerie (métal, grilles, portails)',
        'Soudeur',
        'Maître plâtre',
        'Maître carrelage',
        'Maître vitre',
        'Décorateur intérieur',
        'Déboucheur d\'égouts',
        'Jardinage / Entretien espaces verts',
        'Terrassement',
        'Chauffage',
        'Climatisation (installation/réparation)',
        'Réparation TV',
        'Électroménager (machines, frigos)',
        'Petit électroménager (micro-ondes, aspirateurs)',
      ],
      'Sécurité': [
        'Serrures (réparation/installation)',
        'Alarmes (installation)',
        'Caméras de surveillance (installation)',
        'Gardiennage',
        'Pompiers',
        'Protection civile',
        'Électricité sécurisée (mise aux normes)',
      ],
      'Services généraux': [
        'Ménage / Nettoyage',
        'Désinfection / Désinsectisation',
        'Déménagement',
        'Location de véhicules',
        'Livraison / Courses',
        'Coursiers / Messagerie',
        'Blanchisserie',
        'Cordonnerie',
      ],
      'Automobile': [
        'Mécanique (réparations générales)',
        'Carrosserie (peinture, tôle)',
        'Pneumatiques (pneus)',
        'Vidange (entretien moteur)',
        'Électricité automobile',
        'Lavage / Nettoyage voiture',
        'Station-service (carburant)',
        'Dépannage 24h/24',
      ],
      'Alimentation': [
        'Boucheries',
        'Poissonneries',
        'Épiceries (alimentation générale)',
        'Boulangeries',
        'Primeurs (fruits et légumes)',
        'Boucheries halal',
        'Traiteurs (plats préparés)',
        'Pâtisseries',
        'Cafés / Restauration rapide',
        'Restaurants',
      ],
      'Commerces': [
        'Quincaillerie / Outillage',
        'Électroménager (vente)',
        'Informatique (ordinateurs)',
        'Téléphonie (téléphones)',
        'Vêtements / Mode',
        'Chaussures',
        'Bijouterie',
        'Horlogerie (montres)',
        'Meubles / Ameublement',
        'Luminaires (éclairage)',
      ],
      'Immobilier': [
        'Agences immobilières (vente, location)',
        'Notaires',
        'Experts immobiliers (estimation)',
        'Syndics (gestion copropriété)',
        'Avocats (conseils juridiques)',
        'Huissiers',
        'Assurances (habitation)',
      ],
      'Services domestiques': [
        'Femmes de ménage',
        'Nounous / Garde d\'enfants',
        'Aide ménagère (aide à domicile)',
        'Repassage',
        'Cuisiniers (préparation repas)',
        'Jardiniers (entretien jardin)',
      ],
      'Électroménager & TV': [
        'Réparation TV (LED, LCD, OLED)',
        'Réparation réfrigérateurs (frigos, congélateurs)',
        'Réparation machines à laver (lave-linge)',
        'Réparation fours (électriques, micro-ondes)',
        'Réparation climatiseurs',
        'Réparation petits appareils (aspirateurs, cafetières)',
        'Installation électroménager',
      ],
      'Divertissement & Loisirs': [
        'Salles de sport (fitness, musculation)',
        'Piscines (publiques, privées)',
        'Clubs de football',
        'Clubs de tennis',
        'Clubs de golf',
        'Cinémas',
        'Théâtres',
        'Centres culturels',
        'Parcs d\'attractions',
        'Location de salles (fêtes, événements)',
      ],
    };

    int totalImporte = 0;
    int totalMisAJour = 0;
    int totalErreurs = 0;

    // Parcourir chaque catégorie
    for (var entry in categories.entries) {
      final nomCategorie = entry.key;
      final sousCategories = entry.value;

      try {
        final resultat = await _creerOuMettreAJourCategorie(
          nomCategorie,
          sousCategories,
        );

        if (resultat['action'] == 'created') {
          totalImporte++;
        } else if (resultat['action'] == 'updated') {
          totalMisAJour++;
        }

        result['details'].add({
          'categorie': nomCategorie,
          'action': resultat['action'],
          'sousCategories': sousCategories.length,
        });

        print('✅ ${resultat['action']}: "$nomCategorie" (${sousCategories.length} sous-catégories)');
      } catch (e) {
        totalErreurs++;
        result['details'].add({
          'categorie': nomCategorie,
          'action': 'error',
          'error': e.toString(),
        });
        print('❌ Erreur pour "$nomCategorie": $e');
      }
    }

    // Résultat final
    result['imported'] = totalImporte;
    result['updated'] = totalMisAJour;
    result['errors'] = totalErreurs;

    print('\n✅ IMPORTATION TERMINÉE !');
    print('📊 $totalImporte catégories créées, $totalMisAJour mises à jour, $totalErreurs erreurs');

    return result;
  }

  // ✅ Créer ou mettre à jour une catégorie
  Future<Map<String, dynamic>> _creerOuMettreAJourCategorie(
    String nom,
    List<String> sousCategories,
  ) async {
    final docRef = _firestore.collection('repertoire_categories').doc(nom);
    final doc = await docRef.get();

    final sousCats = sousCategories.map((s) => ({
      'nom': s,
      'personnes': [],
    })).toList();

    if (doc.exists) {
      // Mettre à jour : fusionner les sous-catégories
      final data = doc.data() as Map<String, dynamic>;
      final existing = List<Map<String, dynamic>>.from(data['sousCategories'] ?? []);
      final existingNames = existing.map((s) => s['nom']).toSet();

      for (var s in sousCats) {
        if (!existingNames.contains(s['nom'])) {
          existing.add(s);
        }
      }

      await docRef.update({'sousCategories': existing});
      return {'action': 'updated'};
    } else {
      // Créer
      await docRef.set({'sousCategories': sousCats});
      return {'action': 'created'};
    }
  }

  // ✅ Vérifier le nombre de catégories importées
  Future<int> compterCategories() async {
    final snapshot = await _firestore.collection('repertoire_categories').get();
    return snapshot.docs.length;
  }

  // ✅ Obtenir la liste des catégories importées
  Future<List<String>> getCategoriesList() async {
    final snapshot = await _firestore.collection('repertoire_categories').get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }
}