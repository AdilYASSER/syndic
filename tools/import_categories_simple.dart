// tools/import_categories_simple.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import '../lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;

  print('🚀 IMPORTATION DES CATÉGORIES\n');

  final categories = {
    'Santé': [
      'Médecins généralistes',
      'Médecins spécialistes',
      'Dentistes',
      'Ophtalmologues',
      'Pédiatres',
      'Pharmacies',
      'Infirmiers',
      'Sages-femmes',
      'Kinésithérapeutes',
      'Psychologues',
      'Analyses médicales',
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

  for (var entry in categories.entries) {
    final categorieNom = entry.key;
    final sousCategories = entry.value;

    await firestore.collection('repertoire_categories').doc(categorieNom).set({
      'sousCategories': sousCategories.map((s) => ({
        'nom': s,
        'personnes': [],
      })).toList(),
    });

    print('✅ Catégorie "$categorieNom" créée (${sousCategories.length} sous-catégories)');
  }

  print('\n✅ IMPORTATION TERMINÉE !');
  print('📊 ${categories.length} catégories importées');
  print('🔍 Vérifiez dans Firestore : collection "repertoire_categories"');
}