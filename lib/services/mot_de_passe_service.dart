// lib/services/mot_de_passe_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mot_de_passe.dart';

class MotDePasseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String COLLECTION = 'mots_de_passe';

  // ✅ Générer le mot de passe avec préfixe
  static String genererMotDePasseAvecPrefixe(String numAppartement, String codeChoisi) {
    return '${numAppartement.toUpperCase()}$codeChoisi';
  }

  // ✅ Vérifier si un code est disponible
  Future<bool> isCodeDisponible(String numAppartement, String codeChoisi) async {
    try {
      final motDePasseComplet = genererMotDePasseAvecPrefixe(numAppartement, codeChoisi);
      
      final snapshot = await _firestore
          .collection(COLLECTION)
          .where('motDePasseActuel', isEqualTo: motDePasseComplet)
          .limit(1)
          .get();

      return snapshot.docs.isEmpty;
    } catch (e) {
      print('❌ Erreur isCodeDisponible: $e');
      return false;
    }
  }

  // ✅ Obtenir le mot de passe d'un appartement
  Future<MotDePasse?> getMotDePasseByAppartement(String numAppartement) async {
    try {
      final snapshot = await _firestore
          .collection(COLLECTION)
          .where('numAppartement', isEqualTo: numAppartement.toUpperCase())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return MotDePasse.fromFirestore(snapshot.docs.first.data(), snapshot.docs.first.id);
      }
      return null;
    } catch (e) {
      print('❌ Erreur getMotDePasseByAppartement: $e');
      return null;
    }
  }

  // ✅ Vérifier les identifiants de connexion (AVEC PRÉFIXE AUTOMATIQUE)
  Future<Map<String, dynamic>> verifierConnexion(String numAppartement, String motDePasseSaisi) async {
    try {
      final numApp = numAppartement.toUpperCase().trim();
      
      print('🔍 === VÉRIFICATION CONNEXION ===');
      print('🔍 Appartement: $numApp');
      print('🔍 Mot de passe saisi: "$motDePasseSaisi"');

      final snapshot = await _firestore
          .collection(COLLECTION)
          .where('numAppartement', isEqualTo: numApp)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print('❌ Appartement $numApp non trouvé');
        return {'success': false, 'message': 'Appartement non trouvé'};
      }

      final data = snapshot.docs.first.data();
      final docId = snapshot.docs.first.id;
      
      final codeInitial = data['codeInitial'] ?? '';
      final motDePasseActuel = data['motDePasseActuel'] ?? '';
      final aChange = data['aChange'] ?? false;

      print('📊 codeInitial: "$codeInitial"');
      print('📊 motDePasseActuel: "$motDePasseActuel"');
      print('📊 aChange: $aChange');

      // ✅ VÉRIFICATION AVEC PRÉFIXE AUTOMATIQUE
      bool estValide = false;
      
      // 1. Vérifier avec le mot de passe actuel (déjà préfixé)
      if (motDePasseSaisi == motDePasseActuel) {
        estValide = true;
        print('✅ Mot de passe actuel valide (avec préfixe)');
      }
      // 2. Vérifier avec le code initial (si non changé)
      else if (!aChange && motDePasseSaisi == codeInitial) {
        estValide = true;
        print('✅ Code initial valide (première connexion)');
      }
      // 3. ✅ AJOUT : Vérifier avec le préfixe ajouté automatiquement
      else {
        // Tester avec le préfixe ajouté automatiquement
        final avecPrefixe = genererMotDePasseAvecPrefixe(numApp, motDePasseSaisi);
        print('🔍 Test avec préfixe automatique: "$avecPrefixe"');
        
        if (avecPrefixe == motDePasseActuel) {
          estValide = true;
          print('✅ Mot de passe valide avec préfixe automatique');
        }
      }

      if (estValide) {
        if (!aChange) {
          return {
            'success': true,
            'id': docId,
            'numAppartement': numApp,
            'aChange': false,
            'message': 'Première connexion - Veuillez changer votre mot de passe',
          };
        }
        
        return {
          'success': true,
          'id': docId,
          'numAppartement': numApp,
          'aChange': true,
          'message': 'Connexion réussie',
        };
      }

      print('❌ Mot de passe incorrect');
      print('   Saisi: "$motDePasseSaisi"');
      print('   Attendu: "$motDePasseActuel"');
      
      return {'success': false, 'message': 'Mot de passe incorrect'};
    } catch (e) {
      print('❌ Erreur verifierConnexion: $e');
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // ✅ Changer le mot de passe
  Future<Map<String, dynamic>> changerMotDePasse(
    String numAppartement,
    String nouveauCode,
  ) async {
    try {
      // Vérifier si le code est disponible
      final disponible = await isCodeDisponible(numAppartement, nouveauCode);
      if (!disponible) {
        return {
          'success': false,
          'message': 'Ce code est déjà utilisé par un autre appartement',
        };
      }

      final nouveauMotDePasse = genererMotDePasseAvecPrefixe(numAppartement, nouveauCode);

      final snapshot = await _firestore
          .collection(COLLECTION)
          .where('numAppartement', isEqualTo: numAppartement.toUpperCase())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return {'success': false, 'message': 'Appartement non trouvé'};
      }

      final docId = snapshot.docs.first.id;

      await _firestore.collection(COLLECTION).doc(docId).update({
        'motDePasseActuel': nouveauMotDePasse,
        'aChange': true,
        'dateChangement': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Mot de passe changé avec succès',
        'nouveauMotDePasse': nouveauMotDePasse,
      };
    } catch (e) {
      print('❌ Erreur changerMotDePasse: $e');
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // ✅ Initialiser tous les mots de passe
  Future<Map<String, String>> initialiserMotsDePasse(Map<String, String> codesParAppartement) async {
    final resultats = <String, String>{};

    try {
      for (var entry in codesParAppartement.entries) {
        final numAppartement = entry.key.toUpperCase().trim();
        final codeInitial = entry.value;

        final existant = await getMotDePasseByAppartement(numAppartement);
        if (existant != null) {
          resultats[numAppartement] = 'Déjà existant';
          continue;
        }

        final motDePasse = MotDePasse(
          numAppartement: numAppartement,
          codeInitial: codeInitial,
          motDePasseActuel: codeInitial,
          aChange: false,
        );

        await _firestore.collection(COLLECTION).add(motDePasse.toFirestoreMap());
        resultats[numAppartement] = codeInitial;
        print('✅ $numAppartement → $codeInitial');
      }

      return resultats;
    } catch (e) {
      print('❌ Erreur initialiserMotsDePasse: $e');
      return {'erreur': e.toString()};
    }
  }

  // ✅ Créer un mot de passe manuellement
  Future<void> creerMotDePasseManuel(String numAppartement, String codeInitial) async {
    try {
      final numApp = numAppartement.toUpperCase().trim();
      
      final existant = await getMotDePasseByAppartement(numApp);
      if (existant != null) {
        print('⚠️ $numApp existe déjà');
        return;
      }

      final motDePasse = MotDePasse(
        numAppartement: numApp,
        codeInitial: codeInitial,
        motDePasseActuel: codeInitial,
        aChange: false,
      );

      await _firestore.collection(COLLECTION).add(motDePasse.toFirestoreMap());
      print('✅ $numApp créé avec code $codeInitial');
    } catch (e) {
      print('❌ Erreur creerMotDePasseManuel: $e');
      rethrow;
    }
  }
}