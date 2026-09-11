// tools/import_categories.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

class ImportCategories {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> importerCategories() async {
    print('🚀 DÉMARRAGE DE L\'IMPORTATION DES CATÉGORIES\n');

    // ============================================================
    // 1. SANTÉ
    // ============================================================
    await _creerCategorie('Santé', [
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
    ]);

    // ============================================================
    // 2. ÉDUCATION
    // ============================================================
    await _creerCategorie('Éducation', [
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
    ]);

    // ============================================================
    // 3. BRICOLAGE
    // ============================================================
    await _creerCategorie('Bricolage', [
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
      'Réparation TV',         // ✅ AJOUTÉ
      'Électroménager (machines, frigos)',  // ✅ AJOUTÉ
      'Petit électroménager (micro-ondes, aspirateurs)',  // ✅ AJOUTÉ
    ]);

    // ============================================================
    // 4. SÉCURITÉ
    // ============================================================
    await _creerCategorie('Sécurité', [
      'Serrures (réparation/installation)',
      'Alarmes (installation)',
      'Caméras de surveillance (installation)',
      'Gardiennage',
      'Pompiers',
      'Protection civile',
      'Électricité sécurisée (mise aux normes)',
    ]);

    // ============================================================
    // 5. SERVICES GÉNÉRAUX
    // ============================================================
    await _creerCategorie('Services généraux', [
      'Ménage / Nettoyage',
      'Désinfection / Désinsectisation',
      'Déménagement',
      'Location de véhicules',
      'Livraison / Courses',
      'Coursiers / Messagerie',
      'Blanchisserie',
      'Cordonnerie',
    ]);

    // ============================================================
    // 6. AUTOMOBILE
    // ============================================================
    await _creerCategorie('Automobile', [
      'Mécanique (réparations générales)',
      'Carrosserie (peinture, tôle)',
      'Pneumatiques (pneus)',
      'Vidange (entretien moteur)',
      'Électricité automobile',
      'Lavage / Nettoyage voiture',
      'Station-service (carburant)',
      'Dépannage 24h/24',
    ]);

    // ============================================================
    // 7. ALIMENTATION
    // ============================================================
    await _creerCategorie('Alimentation', [
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
    ]);

    // ============================================================
    // 8. COMMERCES
    // ============================================================
    await _creerCategorie('Commerces', [
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
    ]);

    // ============================================================
    // 9. IMMOBILIER
    // ============================================================
    await _creerCategorie('Immobilier', [
      'Agences immobilières (vente, location)',
      'Notaires',
      'Experts immobiliers (estimation)',
      'Syndics (gestion copropriété)',
      'Avocats (conseils juridiques)',
      'Huissiers',
      'Assurances (habitation)',
    ]);

    // ============================================================
    // 10. SERVICES DOMESTIQUES
    // ============================================================
    await _creerCategorie('Services domestiques', [
      'Femmes de ménage',
      'Nounous / Garde d\'enfants',
      'Aide ménagère (aide à domicile)',
      'Repassage',
      'Cuisiniers (préparation repas)',
      'Jardiniers (entretien jardin)',
    ]);

    // ============================================================
    // 11. ÉLECTROMÉNAGER & TV (NOUVELLE CATÉGORIE)
    // ============================================================
    await _creerCategorie('Électroménager & TV', [
      'Réparation TV (LED, LCD, OLED)',
      'Réparation réfrigérateurs (frigos, congélateurs)',
      'Réparation machines à laver (lave-linge)',
      'Réparation fours (électriques, micro-ondes)',
      'Réparation climatiseurs',
      'Réparation petits appareils (aspirateurs, cafetières)',
      'Installation électroménager',
    ]);

    // ============================================================
    // 12. DIVERTISSEMENT & LOISIRS (NOUVEAU)
    // ============================================================
    await _creerCategorie('Divertissement & Loisirs', [
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
    ]);

    print('\n✅ IMPORTATION TERMINÉE !');
    print('📊 12 catégories importées avec leurs sous-catégories.');
    print('🔍 Vérifiez dans Firestore : collection "repertoire_categories"');
  }

  Future<void> _creerCategorie(String nom, List<String> sousCategories) async {
    try {
      final docRef = _firestore.collection('repertoire_categories').doc(nom);
      final doc = await docRef.get();

      if (doc.exists) {
        print('⚠️ Catégorie "$nom" existe déjà - mise à jour...');
        final data = doc.data() as Map<String, dynamic>;
        final existingSousCategories = List<Map<String, dynamic>>.from(data['sousCategories'] ?? []);
        final existingNames = existingSousCategories.map((s) => s['nom']).toSet();

        for (var sousCategorie in sousCategories) {
          if (!existingNames.contains(sousCategorie)) {
            existingSousCategories.add({
              'nom': sousCategorie,
              'personnes': []
            });
            print('   ✅ Ajout: "$sousCategorie"');
          }
        }

        await docRef.update({'sousCategories': existingSousCategories});
        print('✅ Catégorie "$nom" mise à jour (${existingSousCategories.length} sous-catégories)');
      } else {
        // Créer la catégorie
        await docRef.set({
          'sousCategories': sousCategories.map((s) => ({
            'nom': s,
            'personnes': []
          })).toList()
        });
        print('✅ Catégorie "$nom" créée (${sousCategories.length} sous-catégories)');
      }
    } catch (e) {
      print('❌ Erreur pour "$nom": $e');
    }
  }
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final importer = ImportCategories();
    await importer.importerCategories();
  } catch (e) {
    print('❌ Erreur d\'initialisation: $e');
  }
}